import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/strings_ar.dart';
import '../../models/bill.dart';
import '../../services/pdf_service.dart';
import '../../services/services.dart';

class BillDetailScreen extends ConsumerStatefulWidget {
  const BillDetailScreen({super.key, required this.billId});

  final String billId;

  @override
  ConsumerState<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends ConsumerState<BillDetailScreen> {
  Bill? _bill;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final bill = await ref.read(billsServiceProvider).getBill(widget.billId);
      setState(() => _bill = bill);
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
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm', 'ar');

    return Scaffold(
      appBar: AppBar(title: const Text(StringsAr.billDetails)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bill == null
              ? const Center(child: Text(StringsAr.noData))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${StringsAr.billNumber}: #${_bill!.billNumber}',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${StringsAr.date}: ${dateFormat.format(_bill!.createdAt)}',
                              ),
                              Text(
                                '${StringsAr.customerName}: ${_bill!.customerName ?? ''}',
                              ),
                              Text(
                                '${StringsAr.total}: ${_bill!.total} ${_bill!.currencyLabel}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._bill!.items.map(
                        (item) => Card(
                          child: ListTile(
                            title: Text(item.itemName),
                            subtitle: Text(
                              '${StringsAr.quantity}: ${item.quantity} | '
                              '${StringsAr.unitCost}: ${item.unitSellPrice}',
                            ),
                            trailing: Text(
                              '${item.totalSell} ${_bill!.currencyLabel}',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => pdfService.printBill(_bill!),
                        icon: const Icon(Icons.print),
                        label: const Text(StringsAr.reprint),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => pdfService.shareBill(_bill!),
                        icon: const Icon(Icons.share),
                        label: const Text(StringsAr.share),
                      ),
                    ],
                  ),
                ),
    );
  }
}
