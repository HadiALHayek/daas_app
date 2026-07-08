import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_errors.dart';
import '../../core/constants/strings_ar.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/profit_report.dart';
import '../../services/services.dart';

class ProfitsScreen extends ConsumerStatefulWidget {
  const ProfitsScreen({super.key});

  @override
  ConsumerState<ProfitsScreen> createState() => _ProfitsScreenState();
}

class _ProfitsScreenState extends ConsumerState<ProfitsScreen> {
  String _period = 'monthly';
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  ProfitReport? _report;
  bool _loading = false;
  String? _loadError;

  final _usdFormat = NumberFormat('#,##0.##', 'en_US');
  final _sypFormat = NumberFormat('#,###', 'ar');

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
      final report = await ref.read(reportsServiceProvider).getProfits(
            period: _period,
            year: _year,
            month: _period == 'monthly' ? _month : null,
          );
      if (!mounted) return;
      setState(() {
        _report = report;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = formatAppError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _usd(double amount) => '\$${_usdFormat.format(amount)}';
  String _syp(double amount) => '${_sypFormat.format(amount)} ل.س';

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: StringsAr.profits,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SectionCard(
              child: Column(
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'monthly',
                        label: Text(StringsAr.monthly),
                        icon: Icon(Icons.calendar_month_rounded, size: 18),
                      ),
                      ButtonSegment(
                        value: 'yearly',
                        label: Text(StringsAr.yearly),
                        icon: Icon(Icons.calendar_today_rounded, size: 18),
                      ),
                    ],
                    selected: {_period},
                    onSelectionChanged: (values) {
                      setState(() => _period = values.first);
                      _load();
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _year,
                          decoration:
                              const InputDecoration(labelText: StringsAr.year),
                          items: List.generate(5, (i) {
                            final year = DateTime.now().year - i;
                            return DropdownMenuItem(
                              value: year,
                              child: Text(year.toString()),
                            );
                          }),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _year = v);
                              _load();
                            }
                          },
                        ),
                      ),
                      if (_period == 'monthly') ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _month,
                            decoration: const InputDecoration(
                                labelText: StringsAr.month),
                            items: List.generate(12, (i) {
                              return DropdownMenuItem(
                                value: i + 1,
                                child: Text('${i + 1}'),
                              );
                            }),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _month = v);
                                _load();
                              }
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
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
                    : _report == null
                        ? const EmptyState(
                            icon: Icons.bar_chart_rounded,
                            title: StringsAr.noData,
                          )
                        : _buildReport(_report!),
          ),
        ],
      ),
    );
  }

  @override
  Widget buildReport(ProfitReport report) {
    // This is a placeholder to satisfy potential build requirements if needed.
    return _buildReport(report);
  }

  Widget _buildReport(ProfitReport report) {
    final totals = report.report;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StatMetricCard(
          title: 'إجمالي المبيعات (قيمة الفواتير بالدولار)',
          value: _usd(totals.incoming),
          icon: Icons.receipt_long_rounded,
          color: AppColors.primary,
        ),
        const SizedBox(height: 12),
        StatMetricCard(
          title: 'التحصيل النقدي (المبالغ المقبوضة بالدولار)',
          value: _usd(totals.collected),
          icon: Icons.payments_rounded,
          color: AppColors.success,
          backgroundColor: AppColors.successSoft,
        ),
        const SizedBox(height: 12),
        StatMetricCard(
          title: 'المبالغ المتبقية (ديون)',
          value: _usd(totals.uncollectedUsd),
          secondaryValue: _syp(totals.uncollectedSyp),
          icon: Icons.pending_actions_rounded,
          color: AppColors.warning,
          backgroundColor: AppColors.accentSoft,
          onTap: () => context.push('/profits/unpaid'),
        ),
        const SizedBox(height: 12),
        StatMetricCard(
          title: 'إجمالي المصروفات (بالدولار)',
          value: _usd(totals.outgoing),
          icon: Icons.trending_down_rounded,
          color: AppColors.error,
          backgroundColor: AppColors.errorSoft,
        ),
        const SizedBox(height: 12),
        StatMetricCard(
          title: 'صافي الربح المحقق (بالدولار)',
          value: _usd(totals.profit),
          icon: Icons.account_balance_wallet_rounded,
          color: AppColors.info,
        ),
        const SizedBox(height: 12),
        StatMetricCard(
          title: StringsAr.billCount,
          value: report.billCount.toString(),
          icon: Icons.receipt_rounded,
          color: AppColors.primary,
        ),
        if (report.period == 'yearly' && report.breakdown.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'التفصيل الشهري',
            style: GoogleFonts.cairo(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...report.breakdown.map((row) {
            if (row.billCount == 0 &&
                row.report.collected == 0 &&
                row.report.incoming == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ListItemCard(
                title: 'الشهر ${row.month}',
                subtitle: 'المقبوض: ${_usd(row.report.collected)}\n'
                    'المتبقي: ${_usd(row.report.uncollectedUsd)} • ${_syp(row.report.uncollectedSyp)}\n'
                    'الربح الصافي: ${_usd(row.report.profit)}',
                trailing: Text(
                  '${row.billCount} فاتورة',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }),
        ],
      ],
      ),
    );
  }
}
