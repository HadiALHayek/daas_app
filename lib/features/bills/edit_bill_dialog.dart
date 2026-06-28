import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/strings_ar.dart';
import '../../core/widgets/arabic_text_field.dart';
import '../../models/bill.dart';

class EditBillDialogResult {
  const EditBillDialogResult({required this.discount, required this.items});
  final double discount;
  final List<BillItem> items;
}

Future<EditBillDialogResult?> showEditBillDialog({
  required BuildContext context,
  required Bill bill,
}) {
  return showDialog<EditBillDialogResult>(
    context: context,
    builder: (context) => _EditBillDialog(bill: bill),
  );
}

class _EditBillDialog extends StatefulWidget {
  const _EditBillDialog({required this.bill});
  final Bill bill;

  @override
  State<_EditBillDialog> createState() => _EditBillDialogState();
}

class _EditBillDialogState extends State<_EditBillDialog> {
  late final TextEditingController _discountController;
  late final List<_EditableLine> _lines;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _discountController =
        TextEditingController(text: widget.bill.discount.toString());
    _lines = widget.bill.items
        .map(
          (item) => _EditableLine(
            item: item,
            unitPriceController:
                TextEditingController(text: item.unitSellPrice.toString()),
            quantityController:
                TextEditingController(text: item.quantity.toString()),
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _discountController.dispose();
    for (final line in _lines) {
      line.unitPriceController.dispose();
      line.quantityController.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (_isSubmitting) return;

    final discount = double.tryParse(_discountController.text) ?? 0;
    final updatedItems = <BillItem>[];

    for (final line in _lines) {
      final qty = double.tryParse(line.quantityController.text);
      final price = double.tryParse(line.unitPriceController.text);
      if (qty == null || qty <= 0 || price == null || price < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تحقق من الأسعار والكميات')),
        );
        return;
      }
      updatedItems.add(
        BillItem(
          id: line.item.id,
          itemId: line.item.itemId,
          itemName: line.item.itemName,
          quantity: qty,
          unitSellPrice: price,
          totalSell: price * qty,
        ),
      );
    }

    setState(() => _isSubmitting = true);
    FocusScope.of(context).unfocus();

    Navigator.pop(
      context,
      EditBillDialogResult(discount: discount, items: updatedItems),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(StringsAr.editBill),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._lines.map((line) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.item.itemName,
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: NumberTextField(
                              controller: line.quantityController,
                              label: StringsAr.quantity,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: NumberTextField(
                              controller: line.unitPriceController,
                              label: StringsAr.unitPrice,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              NumberTextField(
                controller: _discountController,
                label: StringsAr.discount,
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
          child: const Text(StringsAr.save),
        ),
      ],
    );
  }
}

class _EditableLine {
  _EditableLine({
    required this.item,
    required this.unitPriceController,
    required this.quantityController,
  });

  final BillItem item;
  final TextEditingController unitPriceController;
  final TextEditingController quantityController;
}
