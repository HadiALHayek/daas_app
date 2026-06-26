import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/strings_ar.dart';
import '../../core/widgets/arabic_text_field.dart';

class BillPaymentFormResult {
  const BillPaymentFormResult({
    required this.amount,
    this.notes,
  });

  final double amount;
  final String? notes;
}

Future<BillPaymentFormResult?> showBillPaymentDialog({
  required BuildContext context,
  required double maxAmount,
  required String currencyLabel,
}) {
  return showDialog<BillPaymentFormResult>(
    context: context,
    builder: (context) => _BillPaymentDialog(
      maxAmount: maxAmount,
      currencyLabel: currencyLabel,
    ),
  );
}

class _BillPaymentDialog extends StatefulWidget {
  const _BillPaymentDialog({
    required this.maxAmount,
    required this.currencyLabel,
  });

  final double maxAmount;
  final String currencyLabel;

  @override
  State<_BillPaymentDialog> createState() => _BillPaymentDialogState();
}

class _BillPaymentDialogState extends State<_BillPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(
      context,
      BillPaymentFormResult(
        amount: double.parse(_amountController.text),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(StringsAr.addPayment),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'المتبقي: ${widget.maxAmount} ${widget.currencyLabel}',
              style: GoogleFonts.cairo(fontSize: 13),
            ),
            const SizedBox(height: 12),
            NumberTextField(
              controller: _amountController,
              label: StringsAr.amount,
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return 'أدخل مبلغاً صحيحاً';
                if (n > widget.maxAmount + 0.001) {
                  return 'المبلغ أكبر من المتبقي';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            ArabicTextField(
              controller: _notesController,
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
          child: const Text(StringsAr.add),
        ),
      ],
    );
  }
}
