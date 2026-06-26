import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/strings_ar.dart';
import '../../models/bill.dart';
import '../../services/services.dart';

class CustomerBillsScreen extends ConsumerStatefulWidget {
  const CustomerBillsScreen({super.key, required this.customerId});

  final String customerId;

  @override
  ConsumerState<CustomerBillsScreen> createState() =>
      _CustomerBillsScreenState();
}

class _CustomerBillsScreenState extends ConsumerState<CustomerBillsScreen> {
  List<Bill>? _bills;
  bool _loading = true;
  String _customerName = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final bills = await ref
          .read(customersServiceProvider)
          .getCustomerBills(widget.customerId);
      setState(() {
        _bills = bills;
        if (bills.isNotEmpty) {
          _customerName = bills.first.customerName ?? '';
        }
      });
      if (_customerName.isEmpty) {
        final customers = await ref.read(customersServiceProvider).getCustomers();
        for (final customer in customers) {
          if (customer.id == widget.customerId) {
            _customerName = customer.name;
            break;
          }
        }
      }
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
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _customerName.isEmpty ? StringsAr.billingBook : _customerName,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bills == null || _bills!.isEmpty
              ? const Center(child: Text(StringsAr.noData))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _bills!.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final bill = _bills![index];
                      return Card(
                        child: ListTile(
                          title: Text('${StringsAr.billNumber} #${bill.billNumber}'),
                          subtitle: Text(dateFormat.format(bill.createdAt)),
                          trailing: Text(
                            '${bill.total} ${bill.currencyLabel}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          onTap: () => context.push('/bills/${bill.id}'),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
