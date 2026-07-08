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

class UnpaidBillsScreen extends ConsumerStatefulWidget {
  const UnpaidBillsScreen({super.key});

  @override
  ConsumerState<UnpaidBillsScreen> createState() => _UnpaidBillsScreenState();
}

class _UnpaidBillsScreenState extends ConsumerState<UnpaidBillsScreen> {
  List<Bill>? _bills;
  bool _loading = true;
  String? _loadError;

  final _priceFormat = NumberFormat('#,##0.##', 'ar');

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
      final bills = await ref.read(billsServiceProvider).getUnpaidBills();
      if (!mounted) return;
      setState(() => _bills = bills);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = formatAppError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _totalRemainingSyp => (_bills ?? [])
      .where((b) => b.currency == 'SYP')
      .fold<double>(0, (sum, b) => sum + b.amountRemaining);

  double get _totalRemainingUsd => (_bills ?? [])
      .where((b) => b.currency == 'USD')
      .fold<double>(0, (sum, b) => sum + b.amountRemaining);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');

    return AppScaffold(
      title: StringsAr.unpaidBills,
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
              : _bills == null || _bills!.isEmpty
                  ? const EmptyState(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'لا توجد مبالغ متبقية',
                      subtitle: 'جميع الفواتير مدفوعة بالكامل',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'إجمالي المبالغ المتبقية',
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (_totalRemainingSyp > 0)
                                  Text(
                                    '${_priceFormat.format(_totalRemainingSyp)} ${StringsAr.syp}',
                                    style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                      color: AppColors.error,
                                    ),
                                  ),
                                if (_totalRemainingUsd > 0)
                                  Text(
                                    '${_priceFormat.format(_totalRemainingUsd)} ${StringsAr.usd}',
                                    style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                      color: AppColors.error,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_bills!.length} فاتورة غير مسددة',
                                  style: GoogleFonts.cairo(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _bills!.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final bill = _bills![index];
                                final customerName = bill.customerName ??
                                    bill.manualCustomerName ??
                                    'بيع مباشر';

                                return ListItemCard(
                                  leading: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors.errorSoft,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '#${bill.billNumber}',
                                        style: GoogleFonts.cairo(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: customerName,
                                  subtitle:
                                      '${dateFormat.format(bill.createdAt)}\n'
                                      'الإجمالي: ${_priceFormat.format(bill.total)} ${bill.currencyLabel}',
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'المتبقي',
                                        style: GoogleFonts.cairo(
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                      Text(
                                        '${_priceFormat.format(bill.amountRemaining)} ${bill.currencyLabel}',
                                        style: GoogleFonts.cairo(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.error,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (bill.currentRate > 0)
                                        Text(
                                          'بسعر 1\$ = ${_priceFormat.format(bill.currentRate)} ل.س',
                                          style: GoogleFonts.cairo(
                                            color: AppColors.textSecondary,
                                            fontSize: 10,
                                          ),
                                        ),
                                    ],
                                  ),
                                  onTap: () async {
                                    await context.push('/bills/${bill.id}');
                                    _load();
                                  },
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
