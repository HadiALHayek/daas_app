import 'package:flutter/material.dart';

import '../../core/constants/strings_ar.dart';
import '../../core/widgets/arabic_text_field.dart';
import '../../models/customer.dart';

/// Shows add/edit customer dialog. Returns updated fields on save, or null if cancelled.
Future<({String name, String? phone})?> showCustomerFormDialog({
  required BuildContext context,
  Customer? customer,
}) {
  final nameController = TextEditingController(text: customer?.name ?? '');
  final phoneController = TextEditingController(text: customer?.phone ?? '');
  final isEdit = customer != null;

  return showDialog<({String name, String? phone})?>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(isEdit ? StringsAr.editCustomer : StringsAr.addCustomer),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ArabicTextField(
              controller: nameController,
              label: StringsAr.customerName,
            ),
            const SizedBox(height: 12),
            NumberTextField(
              controller: phoneController,
              label: StringsAr.phone,
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
          onPressed: () {
            final name = nameController.text.trim();
            if (name.isEmpty) return;
            final phone = phoneController.text.trim();
            Navigator.pop(
              context,
              (name: name, phone: phone.isEmpty ? null : phone),
            );
          },
          child: const Text(StringsAr.save),
        ),
      ],
    ),
  );
}
