import 'package:flutter/material.dart';

import '../../core/constants/strings_ar.dart';
import '../../core/widgets/arabic_text_field.dart';
import '../../models/customer.dart';

class CustomerFormResult {
  const CustomerFormResult({required this.name, this.phone, this.address});
  final String name;
  final String? phone;
  final String? address;
}

/// Shows add/edit customer dialog. Returns updated fields on save, or null if cancelled.
Future<CustomerFormResult?> showCustomerFormDialog({
  required BuildContext context,
  Customer? customer,
}) {
  return showDialog<CustomerFormResult>(
    context: context,
    builder: (context) => _CustomerFormDialog(customer: customer),
  );
}

class _CustomerFormDialog extends StatefulWidget {
  const _CustomerFormDialog({this.customer});
  final Customer? customer;

  @override
  State<_CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<_CustomerFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer?.name ?? '');
    _phoneController = TextEditingController(text: widget.customer?.phone ?? '');
    _addressController =
        TextEditingController(text: widget.customer?.address ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_isSubmitting) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSubmitting = true);
    FocusScope.of(context).unfocus();

    Navigator.pop(
      context,
      CustomerFormResult(
        name: name,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.customer != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(isEdit ? StringsAr.editCustomer : StringsAr.addCustomer),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ArabicTextField(
              controller: _nameController,
              label: StringsAr.customerName,
            ),
            const SizedBox(height: 12),
            NumberTextField(
              controller: _phoneController,
              label: StringsAr.phone,
            ),
            const SizedBox(height: 12),
            ArabicTextField(
              controller: _addressController,
              label: StringsAr.address,
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
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
