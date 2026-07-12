import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_errors.dart';
import '../../core/constants/strings_ar.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/employee.dart';
import '../../services/services.dart';
import 'add_loan_dialog.dart';

/// Opens a dialog to view, add, edit and delete an employee's loans.
/// Returns true if any change was made (so the caller can refresh).
Future<bool?> showEmployeeLoansDialog(BuildContext context, Employee employee) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _EmployeeLoansDialog(employee: employee),
  );
}

class _EmployeeLoansDialog extends ConsumerStatefulWidget {
  const _EmployeeLoansDialog({required this.employee});

  final Employee employee;

  @override
  ConsumerState<_EmployeeLoansDialog> createState() =>
      _EmployeeLoansDialogState();
}

class _EmployeeLoansDialogState extends ConsumerState<_EmployeeLoansDialog> {
  List<EmployeeLoan>? _loans;
  bool _loading = true;
  String? _error;
  bool _changed = false;

  final _numberFormat = NumberFormat('#,##0.##', 'ar');
  final _dateFormat = DateFormat('yyyy/MM/dd', 'ar');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loans = await ref
          .read(employeesServiceProvider)
          .getLoans(widget.employee.id);
      if (!mounted) return;
      setState(() => _loans = loans);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = formatAppError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addLoan() async {
    final result = await showAddLoanDialog(context);
    if (result == null) return;
    try {
      await ref.read(employeesServiceProvider).addLoan(
            employeeId: widget.employee.id,
            amount: result.amount,
            note: result.note,
          );
      _changed = true;
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _editLoan(EmployeeLoan loan) async {
    final result = await showAddLoanDialog(
      context,
      initialAmount: loan.amount,
      initialNote: loan.note,
    );
    if (result == null) return;
    try {
      await ref.read(employeesServiceProvider).updateLoan(
            loanId: loan.id,
            amount: result.amount,
            note: result.note,
          );
      _changed = true;
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteLoan(EmployeeLoan loan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(StringsAr.confirmDelete),
        content: Text(
          '${StringsAr.loanAmount}: ${_numberFormat.format(loan.amount)} ${StringsAr.syp}',
        ),
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
      await ref.read(employeesServiceProvider).deleteLoan(loan.id);
      _changed = true;
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(formatAppError(e))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loans = _loans ?? const <EmployeeLoan>[];
    final total = loans.fold<double>(0, (s, l) => s + l.amount);

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              '${StringsAr.manageLoans} - ${widget.employee.name}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!,
                        style: const TextStyle(color: AppColors.error)),
                  )
                : loans.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          StringsAr.noLoans,
                          textAlign: TextAlign.center,
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (total > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Text(
                                    '${StringsAr.total}:',
                                    style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${_numberFormat.format(total)} ${StringsAr.syp}',
                                    style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: loans.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final loan = loans[index];
                                return ListItemCard(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        AppColors.warning.withValues(alpha: 0.12),
                                    foregroundColor: AppColors.warning,
                                    child: const Icon(
                                      Icons.request_quote_outlined,
                                      size: 20,
                                    ),
                                  ),
                                  title:
                                      '${_numberFormat.format(loan.amount)} ${StringsAr.syp}',
                                  subtitle: loan.note == null ||
                                          loan.note!.isEmpty
                                      ? _dateFormat.format(loan.loanDate)
                                      : '${_dateFormat.format(loan.loanDate)}  •  ${loan.note}',
                                  onEdit: () => _editLoan(loan),
                                  onDelete: () => _deleteLoan(loan),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _changed),
          child: const Text(StringsAr.cancel),
        ),
        FilledButton.icon(
          onPressed: _addLoan,
          icon: const Icon(Icons.add, size: 18),
          label: const Text(StringsAr.addLoan),
        ),
      ],
    );
  }
}
