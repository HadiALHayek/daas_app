import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:signature/signature.dart';

import '../../core/constants/strings_ar.dart';
import '../../models/bill.dart';
import '../../models/customer.dart';
import '../../models/item.dart';
import '../../services/pdf_service.dart';
import '../../services/services.dart';

class _DraftLine {
  _DraftLine({
    required this.catalogItem,
    required this.quantity,
  });

  final CatalogItem catalogItem;
  double quantity;
}

class CreateBillScreen extends ConsumerStatefulWidget {
  const CreateBillScreen({super.key});

  @override
  ConsumerState<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends ConsumerState<CreateBillScreen> {
  List<Customer>? _customers;
  List<CatalogItem>? _catalog;
  Customer? _selectedCustomer;
  String _currency = 'SYP';
  final List<_DraftLine> _lines = [];
  bool _loading = true;
  bool _saving = false;

  final _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final customers = await ref.read(customersServiceProvider).getCustomers();
      final catalog = await ref.read(itemsServiceProvider).getItems();
      setState(() {
        _customers = customers;
        _catalog = catalog;
      });
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

  void _addLine() {
    if (_catalog == null || _catalog!.isEmpty) return;

    CatalogItem? selected = _catalog!.first;
    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(StringsAr.selectItem),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<CatalogItem>(
                    value: selected,
                    items: _catalog!
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialogState(() => selected = v),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(StringsAr.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    if (selected != null) {
                      setState(() {
                        _lines.add(_DraftLine(
                          catalogItem: selected!,
                          quantity: 1,
                        ));
                      });
                    }
                    Navigator.pop(context);
                  },
                  child: const Text(StringsAr.add),
                ),
              ],
            );
          },
        );
      },
    );
  }

  double get _subtotal {
    return _lines.fold(0, (sum, line) {
      return sum + line.catalogItem.sellPrice * line.quantity;
    });
  }

  Future<void> _saveAndPrint() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(StringsAr.selectCustomer)),
      );
      return;
    }
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف صنفاً واحداً على الأقل')),
      );
      return;
    }
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('التوقيع مطلوب')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final signatureBytes = await _signatureController.toPngBytes();
      final signatureBase64 = base64Encode(signatureBytes!);

      final items = _lines
          .map(
            (line) => BillItem(
              itemId: line.catalogItem.id,
              itemName: line.catalogItem.name,
              quantity: line.quantity,
              unitSellPrice: line.catalogItem.sellPrice,
              totalSell: line.catalogItem.sellPrice * line.quantity,
              unitItemCost: line.catalogItem.cost,
              totalItemCost: line.catalogItem.cost * line.quantity,
            ),
          )
          .toList();

      final bill = await ref.read(billsServiceProvider).createBill(
            customerId: _selectedCustomer!.id,
            currency: _currency,
            sellerSignature: signatureBase64,
            items: items,
          );

      if (mounted) {
        await pdfService.printBill(bill);
        if (mounted) context.go('/bills/${bill.id}');
      }
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
      appBar: AppBar(title: const Text(StringsAr.newBill)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<Customer>(
                    value: _selectedCustomer,
                    decoration:
                        const InputDecoration(labelText: StringsAr.selectCustomer),
                    items: (_customers ?? [])
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCustomer = v),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _currency,
                    decoration:
                        const InputDecoration(labelText: StringsAr.currency),
                    items: const [
                      DropdownMenuItem(value: 'SYP', child: Text(StringsAr.syp)),
                      DropdownMenuItem(value: 'USD', child: Text(StringsAr.usd)),
                    ],
                    onChanged: (v) => setState(() => _currency = v ?? 'SYP'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        StringsAr.addItem,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      IconButton(
                        onPressed: _addLine,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  ..._lines.asMap().entries.map((entry) {
                    final index = entry.key;
                    final line = entry.value;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(line.catalogItem.name)),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () {
                                    setState(() => _lines.removeAt(index));
                                  },
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Text('${StringsAr.quantity}: '),
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: line.quantity > 1
                                      ? () => setState(() => line.quantity--)
                                      : null,
                                ),
                                Text(line.quantity.toString()),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () => setState(() => line.quantity++),
                                ),
                                const Spacer(),
                                Text(
                                  '${line.catalogItem.sellPrice * line.quantity} '
                                  '${line.catalogItem.currency == 'SYP' ? StringsAr.syp : StringsAr.usd}',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  Text(
                    '${StringsAr.subtotal}: $_subtotal',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    StringsAr.sellerSignature,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Signature(
                      controller: _signatureController,
                      height: 150,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _signatureController.clear(),
                    child: const Text(StringsAr.clearSignature),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _saveAndPrint,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(StringsAr.createBill),
                  ),
                ],
              ),
            ),
    );
  }
}
