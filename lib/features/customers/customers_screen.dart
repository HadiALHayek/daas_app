import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_errors.dart';
import '../../core/constants/strings_ar.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/customer.dart';
import '../../services/services.dart';
import 'customer_form_dialog.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  List<Customer>? _customers;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final customers = await ref.read(customersServiceProvider).getCustomers();
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = formatAppError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addCustomer() async {
    final data = await showCustomerFormDialog(context: context);
    if (data == null) return;

    try {
      await ref.read(customersServiceProvider).createCustomer(
            Customer(
              id: '',
              name: data.name,
              phone: data.phone,
              address: data.address,
            ),
          );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is Exception
                  ? e.toString().replaceFirst('Exception: ', '')
                  : StringsAr.error,
            ),
          ),
        );
      }
    }
  }

  Future<void> _editCustomer(Customer customer) async {
    final data = await showCustomerFormDialog(
      context: context,
      customer: customer,
    );
    if (data == null) return;

    try {
      await ref.read(customersServiceProvider).updateCustomer(
            customer.id,
            Customer(
              id: customer.id,
              name: data.name,
              phone: data.phone,
              address: data.address,
            ),
          );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is Exception
                  ? e.toString().replaceFirst('Exception: ', '')
                  : StringsAr.error,
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteCustomer(Customer customer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          StringsAr.confirmDelete,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text('حذف "${customer.name}"؟ سيتم حذف جميع فواتيره أيضاً.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(StringsAr.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(StringsAr.delete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(customersServiceProvider).deleteCustomer(customer.id);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف العميل')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is Exception
                  ? e.toString().replaceFirst('Exception: ', '')
                  : StringsAr.error,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: StringsAr.customers,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCustomer,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text(StringsAr.addCustomer),
      ),
      body: _loading
          ? const AppLoading()
          : _loadError != null
              ? EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: _loadError!,
                  action: FilledButton(
                    onPressed: _load,
                    child: const Text(StringsAr.retry),
                  ),
                )
              : _customers == null || _customers!.isEmpty
              ? EmptyState(
                  icon: Icons.people_outline,
                  title: StringsAr.noData,
                  subtitle: 'أضف عملاء لإنشاء دفاتر الفواتير',
                  action: FilledButton.icon(
                    onPressed: _addCustomer,
                    icon: const Icon(Icons.person_add),
                    label: const Text(StringsAr.addCustomer),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _customers!.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final customer = _customers![index];
                      return ListItemCard(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                          foregroundColor: AppColors.primary,
                          child: Text(
                            customer.name.isNotEmpty
                                ? customer.name.characters.first
                                : '?',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        title: customer.name,
                        subtitle: customer.phone ?? 'بدون رقم هاتف',
                        trailing: const Icon(
                          Icons.receipt_long_rounded,
                          color: AppColors.primary,
                        ),
                        onTap: () =>
                            context.push('/customers/${customer.id}/bills'),
                        onEdit: () => _editCustomer(customer),
                        onDelete: () => _deleteCustomer(customer),
                      );
                    },
                  ),
                ),
    );
  }
}
