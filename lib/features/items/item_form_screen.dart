import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/strings_ar.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/arabic_text_field.dart';
import '../../models/item.dart';
import '../../services/services.dart';

class ItemFormScreen extends ConsumerStatefulWidget {
  const ItemFormScreen({super.key, this.itemId});

  final String? itemId;

  @override
  ConsumerState<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends ConsumerState<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _sellPriceController = TextEditingController();
  String _currency = 'SYP';
  bool _loading = false;
  bool _saving = false;

  bool get _isEdit => widget.itemId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadItem();
  }

  Future<void> _loadItem() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final items = await ref.read(itemsServiceProvider).getItems();
      final item = items.firstWhere((i) => i.id == widget.itemId);
      if (!mounted) return;
      _nameController.text = item.name;
      _sellPriceController.text = item.sellPrice.toString();
      _currency = item.currency;
      setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(StringsAr.error)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sellPriceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final item = CatalogItem(
      id: widget.itemId ?? '',
      name: _nameController.text.trim(),
      sellPrice: double.parse(_sellPriceController.text),
      currency: _currency,
    );

    try {
      if (_isEdit) {
        await ref.read(itemsServiceProvider).updateItem(widget.itemId!, item);
      } else {
        await ref.read(itemsServiceProvider).createItem(item);
      }
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(StringsAr.error)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEdit ? StringsAr.edit : StringsAr.add,
      body: _loading
          ? const AppLoading()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SectionCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PageHeader(
                        title: _isEdit ? 'تعديل الصنف' : 'صنف جديد',
                        subtitle: 'أدخل اسم الصنف وسعر البيع',
                      ),
                      const SizedBox(height: 24),
                      ArabicTextField(
                        controller: _nameController,
                        label: StringsAr.name,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null,
                      ),
                      const SizedBox(height: 16),
                      NumberTextField(
                        controller: _sellPriceController,
                        label: StringsAr.sellPrice,
                        validator: (v) {
                          if (v == null || double.tryParse(v) == null) {
                            return 'أدخل سعر بيع صحيح';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _currency,
                        decoration: const InputDecoration(labelText: StringsAr.currency),
                        items: const [
                          DropdownMenuItem(value: 'SYP', child: Text(StringsAr.syp)),
                          DropdownMenuItem(value: 'USD', child: Text(StringsAr.usd)),
                        ],
                        onChanged: (v) => setState(() => _currency = v ?? 'SYP'),
                      ),
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(StringsAr.save),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
