import 'package:flutter/material.dart';

import '../../core/constants/strings_ar.dart';
import '../../core/widgets/arabic_text_field.dart';

class LoanResult {
  const LoanResult({required this.amount, this.note});
  final double amount;
  final String? note;
}

/// Dialog to add a loan for an employee. Returns a [LoanResult] on save,
/// or null if cancelled.
Future<LoanResult?> showAddLoanDialog(BuildContext context) {
  return showDialog<LoanResult>(
    context: context,
    builder: (context) => const _AddLoanDialog(),
  );
}

class _AddLoanDialog extends StatefulWidget {
  const _AddLoanDialog();

  @override
  State<_AddLoanDialog> createState() => _AddLoanDialogState();
}

class _AddLoanDialogState extends State<_AddLoanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      LoanResult(
        amount: double.parse(_amountController.text),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(StringsAr.addLoan),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NumberTextField(
              controller: _amountController,
              label: '${StringsAr.loanAmount} (${StringsAr.syp})',
              validator: (v) {
                final n = v == null ? null : double.tryParse(v);
                if (n == null || n <= 0) return 'أدخل مبلغاً صحيحاً';
                return null;
              },
            ),
            const SizedBox(height: 16),
            ArabicTextField(
              controller: _noteController,
              label: StringsAr.notes,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(StringsAr.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text(StringsAr.save),
        ),
      ],
    );
  }
}
