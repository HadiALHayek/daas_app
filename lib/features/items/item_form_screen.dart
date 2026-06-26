import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/strings_ar.dart';
import '../../models/item.dart';
import '../../services/services.dart';

class ItemFormScreen extends ConsumerStatefulWidget {
  const ItemFormScreen({super.key, this.itemId});

  final String? itemId;

  @override
  ConsumerState<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends ConsumerState<ItemFormScreen> {
  final _nameController = TextEditingController();
  final _costController = TextEditingController();
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
    setState(() => _loading = true);
    try {
      final items = await ref.read(itemsServiceProvider).getItems();
      final item = items.firstWhere((i) => i.id == widget.itemId);
      _nameController.text = item.name;
      _costController.text = item.cost.toString();
      _sellPriceController.text = item.sellPrice.toString();
      _currency = item.currency;
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
    _costController.dispose();
    _sellPriceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final cost = double.tryParse(_costController.text);
    final sellPrice = double.tryParse(_sellPriceController.text);

    if (name.isEmpty || cost == null || sellPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء جميع الحقول بشكل صحيح')),
      );
      return;
    }

    setState(() => _saving = true);

    final item = CatalogItem(
      id: widget.itemId ?? '',
      name: name,
      cost: cost,
      sellPrice: sellPrice,
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? StringsAr.edit : StringsAr.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: StringsAr.name),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _costController,
                    decoration: const InputDecoration(labelText: StringsAr.cost),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _sellPriceController,
                    decoration:
                        const InputDecoration(labelText: StringsAr.sellPrice),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _currency,
                    decoration: const InputDecoration(labelText: StringsAr.currency),
                    items: const [
                      DropdownMenuItem(value: 'SYP', child: Text(StringsAr.syp)),
                      DropdownMenuItem(value: 'USD', child: Text(StringsAr.usd)),
                    ],
                    onChanged: (v) => setState(() => _currency = v ?? 'SYP'),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(StringsAr.save),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
