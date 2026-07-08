import 'package:flutter/material.dart';

import '../../core/constants/strings_ar.dart';
import '../../core/widgets/arabic_text_field.dart';
import '../../models/employee.dart';

class EmployeeFormResult {
  const EmployeeFormResult({required this.name, required this.weeklySalary});
  final String name;
  final double weeklySalary;
}

/// Dialog to add or edit an employee. Returns an [EmployeeFormResult] on save,
/// or null if cancelled.
Future<EmployeeFormResult?> showEmployeeFormDialog(
  BuildContext context, {
  Employee? employee,
}) {
  return showDialog<EmployeeFormResult>(
    context: context,
    builder: (context) => _EmployeeFormDialog(employee: employee),
  );
}

class _EmployeeFormDialog extends StatefulWidget {
  const _EmployeeFormDialog({this.employee});

  final Employee? employee;

  @override
  State<_EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends State<_EmployeeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _salaryController;

  bool get _isEdit => widget.employee != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.employee?.name ?? '');
    _salaryController = TextEditingController(
      text: widget.employee != null
          ? widget.employee!.weeklySalary.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      EmployeeFormResult(
        name: _nameController.text.trim(),
        weeklySalary: double.parse(_salaryController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? StringsAr.editEmployee : StringsAr.addEmployee),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ArabicTextField(
              controller: _nameController,
              label: StringsAr.employeeName,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null,
            ),
            const SizedBox(height: 16),
            NumberTextField(
              controller: _salaryController,
              label: '${StringsAr.weeklySalary} (${StringsAr.syp})',
              validator: (v) {
                final n = v == null ? null : double.tryParse(v);
                if (n == null || n < 0) return 'أدخل راتباً صحيحاً';
                return null;
              },
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
