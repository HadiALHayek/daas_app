import 'package:flutter/material.dart';

import '../../core/constants/strings_ar.dart';
import '../../core/widgets/arabic_text_field.dart';
import '../../models/expense_payment.dart';
import 'expense_categories.dart';

class ExpenseFormResult {
  const ExpenseFormResult({
    required this.title,
    required this.category,
    required this.amount,
    required this.currency,
    this.notes,
  });

  final String title;
  final String category;
  final double amount;
  final String currency;
  final String? notes;
}

Future<ExpenseFormResult?> showExpenseFormDialog({
  required BuildContext context,
  ExpensePayment? expense,
}) {
  return showDialog<ExpenseFormResult>(
    context: context,
    builder: (context) => _ExpenseFormDialog(expense: expense),
  );
}

class _ExpenseFormDialog extends StatefulWidget {
  const _ExpenseFormDialog({this.expense});

  final ExpensePayment? expense;

  @override
  State<_ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<_ExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late String _category;
  late String _currency;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.expense?.title ?? '');
    _amountController = TextEditingController(
      text: widget.expense?.amount.toString() ?? '',
    );
    _notesController = TextEditingController(text: widget.expense?.notes ?? '');
    _category = widget.expense?.category ?? 'materials';
    _currency = widget.expense?.currency ?? 'SYP';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(
      context,
      ExpenseFormResult(
        title: _titleController.text.trim(),
        category: _category,
        amount: double.parse(_amountController.text),
        currency: _currency,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.expense != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(isEdit ? 'تعديل مصروف' : StringsAr.addExpense),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ArabicTextField(
                controller: _titleController,
                label: StringsAr.expenseTitle,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'الوصف مطلوب' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: StringsAr.category),
                items: expenseCategories
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(expenseCategoryLabel(c)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? 'materials'),
              ),
              const SizedBox(height: 12),
              NumberTextField(
                controller: _amountController,
                label: StringsAr.amount,
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'أدخل مبلغاً صحيحاً';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _currency,
                decoration: const InputDecoration(labelText: StringsAr.currency),
                items: const [
                  DropdownMenuItem(value: 'SYP', child: Text(StringsAr.syp)),
                  DropdownMenuItem(value: 'USD', child: Text(StringsAr.usd)),
                ],
                onChanged: (v) => setState(() => _currency = v ?? 'SYP'),
              ),
              const SizedBox(height: 12),
              ArabicTextField(
                controller: _notesController,
                label: StringsAr.notes,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(StringsAr.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEdit ? StringsAr.save : StringsAr.add),
        ),
      ],
    );
  }
}
