import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_errors.dart';
import '../../core/constants/strings_ar.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/bill.dart';
import '../../services/services.dart';

class DirectPayBillsScreen extends ConsumerStatefulWidget {
  const DirectPayBillsScreen({super.key});

  @override
  ConsumerState<DirectPayBillsScreen> createState() =>
      _DirectPayBillsScreenState();
}

class _DirectPayBillsScreenState extends ConsumerState<DirectPayBillsScreen> {
  List<Bill>? _bills;
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
      final bills = await ref.read(billsServiceProvider).getDirectPayBills();
      if (!mounted) return;
      setState(() => _bills = bills);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = formatAppError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteBill(Bill bill) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          StringsAr.confirmDelete,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text('حذف الفاتورة رقم #${bill.billNumber}؟'),
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
      await ref.read(billsServiceProvider).deleteBill(bill.id);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الفاتورة')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatAppError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    final priceFormat = NumberFormat('#,##0.##', 'ar');

    return AppScaffold(
      title: StringsAr.directPay,
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
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: SectionCard(
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  AppColors.accentSoft.withValues(alpha: 0.5),
                              foregroundColor: AppColors.warning,
                              child: const Icon(Icons.storefront_rounded),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    StringsAr.directPay,
                                    style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'فواتير البيع المباشر بدون عميل مسجل',
                                    style: GoogleFonts.cairo(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
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
                              subtitle: 'لا توجد فواتير بيع مباشر بعد',
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
                                  final customerName =
                                      bill.manualCustomerName ??
                                          bill.customerName ??
                                          '—';
                                  final customerPhone =
                                      bill.manualCustomerPhone ??
                                          bill.customerPhone;

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
                                    title: customerName,
                                    subtitle:
                                        '${dateFormat.format(bill.createdAt)}'
                                        '${customerPhone?.isNotEmpty == true ? '\n$customerPhone' : ''}',
                                    trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${priceFormat.format(bill.total)} ${bill.currencyLabel}',
                                          style: GoogleFonts.cairo(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (bill.amountRemaining > 0.01) ...[
                                          Text(
                                            'المتبقي: ${priceFormat.format(bill.amountRemaining)} ${bill.currencyLabel}',
                                            style: GoogleFonts.cairo(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.error,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (bill.currentRate > 0)
                                            Text(
                                              'بسعر 1\$ = ${priceFormat.format(bill.currentRate)} ل.س',
                                              style: GoogleFonts.cairo(
                                                color: AppColors.textSecondary,
                                                fontSize: 10,
                                              ),
                                            ),
                                        ] else
                                          Text(
                                            'مدفوعة بالكامل',
                                            style: GoogleFonts.cairo(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.success,
                                              fontSize: 11,
                                            ),
                                          ),
                                      ],
                                    ),
                                    onTap: () async {
                                      await context.push('/bills/${bill.id}');
                                      _load();
                                    },
                                    onDelete: () => _deleteBill(bill),
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
