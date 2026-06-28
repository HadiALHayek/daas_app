import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/constants/strings_ar.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/bill.dart';
import '../../models/customer.dart';
import '../../services/services.dart';
import 'customer_form_dialog.dart';

class CustomerBillsScreen extends ConsumerStatefulWidget {
  const CustomerBillsScreen({super.key, required this.customerId});

  final String customerId;

  @override
  ConsumerState<CustomerBillsScreen> createState() =>
      _CustomerBillsScreenState();
}

class _CustomerBillsScreenState extends ConsumerState<CustomerBillsScreen> {
  List<Bill>? _bills;
  Customer? _customer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final bills = await ref
          .read(customersServiceProvider)
          .getCustomerBills(widget.customerId);

      Customer? customer;
      final customers = await ref.read(customersServiceProvider).getCustomers();
      for (final c in customers) {
        if (c.id == widget.customerId) {
          customer = c;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _bills = bills;
        _customer = customer;
      });
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
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editCustomer() async {
    if (_customer == null) return;

    final data = await showCustomerFormDialog(
      context: context,
      customer: _customer,
    );
    if (data == null) return;

    try {
      final updated = await ref.read(customersServiceProvider).updateCustomer(
            _customer!.id,
            Customer(
              id: _customer!.id,
              name: data.name,
              phone: data.phone,
              address: data.address,
            ),
          );
      if (!mounted) return;
      setState(() => _customer = updated);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث بيانات العميل')),
        );
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
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    final priceFormat = NumberFormat('#,##0.##', 'ar');
    final title = _customer?.name ?? StringsAr.billingBook;

    return AppScaffold(
      title: title,
      actions: [
        if (_customer != null)
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: StringsAr.editCustomer,
            onPressed: _editCustomer,
          ),
      ],
      body: _loading
          ? const AppLoading()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_customer != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: SectionCard(
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.1),
                            foregroundColor: AppColors.primary,
                            child: Text(
                              _customer!.name.isNotEmpty
                                  ? _customer!.name.characters.first
                                  : '?',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _customer!.name,
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _customer!.phone ?? 'بدون رقم هاتف',
                                  style: GoogleFonts.cairo(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: StringsAr.edit,
                            onPressed: _editCustomer,
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: _bills == null || _bills!.isEmpty
                      ? const EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: StringsAr.noData,
                          subtitle: 'لا توجد فواتير لهذا العميل بعد',
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _bills!.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final bill = _bills![index];
                              return ListItemCard(
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.accentSoft,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '#${bill.billNumber}',
                                      style: GoogleFonts.cairo(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: AppColors.warning,
                                      ),
                                    ),
                                  ),
                                ),
                                title:
                                    '${StringsAr.billNumber} #${bill.billNumber}',
                                subtitle: dateFormat.format(bill.createdAt),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${priceFormat.format(bill.total)} ${bill.currencyLabel}',
                                      style: GoogleFonts.cairo(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_left_rounded,
                                      size: 20,
                                      color: AppColors.textSecondary,
                                    ),
                                  ],
                                ),
                                onTap: () => context.push('/bills/${bill.id}'),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
