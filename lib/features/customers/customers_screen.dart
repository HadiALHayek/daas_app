import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/strings_ar.dart';
import '../../models/customer.dart';
import '../../services/services.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  List<Customer>? _customers;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final customers = await ref.read(customersServiceProvider).getCustomers();
      setState(() => _customers = customers);
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

  Future<void> _addCustomer() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(StringsAr.addCustomer),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: StringsAr.customerName),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: StringsAr.phone),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(StringsAr.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(StringsAr.save),
          ),
        ],
      ),
    );

    if (result != true || nameController.text.trim().isEmpty) return;

    try {
      await ref.read(customersServiceProvider).createCustomer(
            Customer(
              id: '',
              name: nameController.text.trim(),
              phone: phoneController.text.trim().isEmpty
                  ? null
                  : phoneController.text.trim(),
            ),
          );
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(StringsAr.error)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(StringsAr.customers)),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCustomer,
        child: const Icon(Icons.person_add_outlined),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _customers == null || _customers!.isEmpty
              ? const Center(child: Text(StringsAr.noData))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _customers!.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final customer = _customers![index];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_outline),
                          ),
                          title: Text(customer.name),
                          subtitle: customer.phone != null
                              ? Text(customer.phone!)
                              : null,
                          trailing: const Icon(Icons.receipt_long_outlined),
                          onTap: () =>
                              context.push('/customers/${customer.id}/bills'),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
