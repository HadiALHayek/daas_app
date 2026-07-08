import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_errors.dart';
import '../../core/constants/strings_ar.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/expense_payment.dart';
import '../../services/services.dart';
import 'expense_categories.dart';
import 'expense_form_dialog.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  List<ExpensePayment>? _expenses;
  bool _loading = true;
  String? _loadError;

  final _priceFormat = NumberFormat('#,##0.##', 'ar');
  final _dateFormat = DateFormat('yyyy/MM/dd', 'ar');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final expenses = await ref.read(expensesServiceProvider).getExpenses();
      if (!mounted) return;
      setState(() => _expenses = expenses);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = formatAppError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addExpense() async {
    final data = await showExpenseFormDialog(context: context);
    if (data == null) return;

    try {
      await ref.read(expensesServiceProvider).createExpense(
            ExpensePayment(
              id: '',
              title: data.title,
              category: data.category,
              amount: data.amount,
              currency: data.currency,
              paymentDate: DateTime.now(),
              notes: data.notes,
            ),
          );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatAppError(e))),
        );
      }
    }
  }

  Future<void> _editExpense(ExpensePayment expense) async {
    final data = await showExpenseFormDialog(
      context: context,
      expense: expense,
    );
    if (data == null) return;

    try {
      await ref.read(expensesServiceProvider).updateExpense(
            expense.id,
            ExpensePayment(
              id: expense.id,
              title: data.title,
              category: data.category,
              amount: data.amount,
              currency: data.currency,
              paymentDate: expense.paymentDate,
              notes: data.notes,
            ),
          );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatAppError(e))),
        );
      }
    }
  }

  Future<void> _deleteExpense(ExpensePayment expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(StringsAr.confirmDelete),
        content: Text('حذف "${expense.title}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(StringsAr.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(StringsAr.delete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(expensesServiceProvider).deleteExpense(expense.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatAppError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: StringsAr.expenses,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExpense,
        icon: const Icon(Icons.add_rounded),
        label: const Text(StringsAr.addExpense),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _loading
          ? const AppLoading(key: ValueKey('loading'))
          : KeyedSubtree(
              key: const ValueKey('content'),
              child: _loadError != null
              ? EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: _loadError!,
                  action: FilledButton(
                    onPressed: _load,
                    child: const Text(StringsAr.retry),
                  ),
                )
              : _expenses == null || _expenses!.isEmpty
                  ? EmptyState(
                      icon: Icons.payments_outlined,
                      title: StringsAr.noData,
                      subtitle: 'سجّل مصروفات المواد والنقل وغيرها',
                      action: FilledButton.icon(
                        onPressed: _addExpense,
                        icon: const Icon(Icons.add),
                        label: const Text(StringsAr.addExpense),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _expenses!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final expense = _expenses![index];
                          return ListItemCard(
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppColors.error.withValues(alpha: 0.1),
                              foregroundColor: AppColors.error,
                              child: const Icon(Icons.receipt_outlined, size: 20),
                            ),
                            title: expense.title,
                            subtitle:
                                '${expenseCategoryLabel(expense.category)}  •  '
                                '${_dateFormat.format(expense.paymentDate)}',
                            trailing: Text(
                              '${_priceFormat.format(expense.amount)} ${expense.currencyLabel}',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.w800,
                                color: AppColors.error,
                              ),
                            ),
                            onEdit: () => _editExpense(expense),
                            onDelete: () => _deleteExpense(expense),
                          );
                        },
                      ),
                    ),
            ),
      ),
    );
  }
}
