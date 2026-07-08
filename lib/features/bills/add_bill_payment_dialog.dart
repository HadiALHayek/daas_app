import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/constants/strings_ar.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/arabic_text_field.dart';

class BillPaymentFormResult {
  const BillPaymentFormResult({
    required this.amount,
    required this.currency,
    this.notes,
  });

  /// Amount as entered, in [currency].
  final double amount;

  /// Currency the payment was entered in ('SYP' or 'USD').
  final String currency;
  final String? notes;
}

Future<BillPaymentFormResult?> showBillPaymentDialog({
  required BuildContext context,
  required double maxAmount,
  required String billCurrency,
  required double exchangeRate,
  String? title,
}) {
  return showDialog<BillPaymentFormResult>(
    context: context,
    builder: (context) => _BillPaymentDialog(
      maxAmount: maxAmount,
      billCurrency: billCurrency,
      exchangeRate: exchangeRate,
      title: title,
    ),
  );
}

class _BillPaymentDialog extends StatefulWidget {
  const _BillPaymentDialog({
    required this.maxAmount,
    required this.billCurrency,
    required this.exchangeRate,
    this.title,
  });

  /// Remaining amount, expressed in [billCurrency].
  final double maxAmount;
  final String billCurrency;
  final double exchangeRate;
  final String? title;

  @override
  State<_BillPaymentDialog> createState() => _BillPaymentDialogState();
}

class _BillPaymentDialogState extends State<_BillPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late String _currency;
  bool _isSubmitting = false;

  final _sypFormat = NumberFormat('#,##0.##', 'ar');
  final _usdFormat = NumberFormat('#,##0.##', 'en_US');

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _notesController = TextEditingController();
    _currency = widget.billCurrency == 'USD' ? 'USD' : 'SYP';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _rate => widget.exchangeRate <= 0 ? 15000 : widget.exchangeRate;

  void _submit() {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.selectionClick();
    setState(() => _isSubmitting = true);
    FocusScope.of(context).unfocus();

    Navigator.pop(
      context,
      BillPaymentFormResult(
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
    final entered = double.tryParse(_amountController.text) ?? 0;
    final sypValue =
        _currency == 'SYP' ? entered : entered * _rate; // display helpers
    final usdValue = _currency == 'USD' ? entered : entered / _rate;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.title ?? StringsAr.addPayment),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'SYP', label: Text('ليرة (ل.س)')),
                ButtonSegment(value: 'USD', label: Text('دولار (\$)')),
              ],
              selected: {_currency},
              onSelectionChanged: (v) =>
                  setState(() => _currency = v.first),
            ),
            const SizedBox(height: 14),
            NumberTextField(
              controller: _amountController,
              label: '${StringsAr.amount} (${_currency == 'USD' ? '\$' : 'ل.س'})',
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return 'أدخل مبلغاً صحيحاً';
                return null;
              },
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _conversionRow('ل.س', _sypFormat.format(sypValue)),
                  const SizedBox(height: 6),
                  _conversionRow(r'$', _usdFormat.format(usdValue)),
                  const SizedBox(height: 6),
                  Text(
                    '${StringsAr.rate}: 1\$ = ${_sypFormat.format(_rate)} ل.س',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
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

  Widget _conversionRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
