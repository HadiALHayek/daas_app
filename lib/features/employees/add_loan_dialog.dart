import 'package:flutter/material.dart';

import '../../core/constants/strings_ar.dart';
import '../../core/widgets/arabic_text_field.dart';

class LoanResult {
  const LoanResult({required this.amount, this.note});
  final double amount;
  final String? note;
}

/// Dialog to add or edit a loan for an employee. Returns a [LoanResult] on
/// save, or null if cancelled. Pass [initialAmount]/[initialNote] to edit.
Future<LoanResult?> showAddLoanDialog(
  BuildContext context, {
  double? initialAmount,
  String? initialNote,
}) {
  return showDialog<LoanResult>(
    context: context,
    builder: (context) => _AddLoanDialog(
      initialAmount: initialAmount,
      initialNote: initialNote,
    ),
  );
}

class _AddLoanDialog extends StatefulWidget {
  const _AddLoanDialog({this.initialAmount, this.initialNote});

  final double? initialAmount;
  final String? initialNote;

  @override
  State<_AddLoanDialog> createState() => _AddLoanDialogState();
}

class _AddLoanDialogState extends State<_AddLoanDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _amountController = TextEditingController(
    text: widget.initialAmount != null
        ? (widget.initialAmount! % 1 == 0
            ? widget.initialAmount!.toInt().toString()
            : widget.initialAmount!.toString())
        : '',
  );
  late final _noteController =
      TextEditingController(text: widget.initialNote ?? '');

  bool get _isEdit => widget.initialAmount != null;

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
      title: Text(_isEdit ? StringsAr.editLoan : StringsAr.addLoan),
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
