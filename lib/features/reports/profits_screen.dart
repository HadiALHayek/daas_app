import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  final _numberFormat = NumberFormat('#,##0.##', 'ar');

  static const _monthNames = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

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

  String _syp(double amount) =>
      '${_numberFormat.format(amount)} ${StringsAr.syp}';

  String _usd(double amount) =>
      '${_numberFormat.format(amount)} ${StringsAr.usd}';

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
                          decoration: const InputDecoration(labelText: StringsAr.year),
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
                            decoration: const InputDecoration(labelText: StringsAr.month),
                            items: List.generate(12, (i) {
                              return DropdownMenuItem(
                                value: i + 1,
                                child: Text(_monthNames[i]),
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

  Widget _buildDualMetric({
    required String title,
    required CurrencyTotals syp,
    required CurrencyTotals usd,
    required IconData icon,
    required Color color,
    required double Function(CurrencyTotals) pick,
    Color? backgroundColor,
  }) {
    return StatMetricCard(
      title: title,
      value: _syp(pick(syp)),
      secondaryValue: _usd(pick(usd)),
      icon: icon,
      color: color,
      backgroundColor: backgroundColor,
    );
  }

  Widget _buildReport(ProfitReport report) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDualMetric(
          title: 'إجمالي المبيعات (فواتير)',
          syp: report.syp,
          usd: report.usd,
          icon: Icons.receipt_long_rounded,
          color: AppColors.primary,
          pick: (t) => t.incoming,
        ),
        const SizedBox(height: 12),
        _buildDualMetric(
          title: 'التحصيل النقدي (دفعات)',
          syp: report.syp,
          usd: report.usd,
          icon: Icons.payments_rounded,
          color: AppColors.success,
          backgroundColor: AppColors.successSoft,
          pick: (t) => t.collected,
        ),
        const SizedBox(height: 12),
        _buildDualMetric(
          title: 'المبالغ المتبقية (ديون)',
          syp: report.syp,
          usd: report.usd,
          icon: Icons.pending_actions_rounded,
          color: AppColors.warning,
          backgroundColor: AppColors.accentSoft,
          pick: (t) => t.uncollected,
        ),
        const SizedBox(height: 12),
        _buildDualMetric(
          title: StringsAr.outgoing,
          syp: report.syp,
          usd: report.usd,
          icon: Icons.trending_down_rounded,
          color: AppColors.error,
          backgroundColor: AppColors.errorSoft,
          pick: (t) => t.outgoing,
        ),
        const SizedBox(height: 12),
        _buildDualMetric(
          title: StringsAr.profit,
          syp: report.syp,
          usd: report.usd,
          icon: Icons.account_balance_wallet_rounded,
          color: AppColors.info,
          pick: (t) => t.profit,
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
            if (row.billCount == 0 && row.syp.collected == 0 && row.usd.collected == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ListItemCard(
                title: _monthNames[row.month - 1],
                subtitle:
                    'التحصيل: ${_syp(row.syp.collected)} / ${_usd(row.usd.collected)}\n'
                    'المتبقي: ${_syp(row.syp.uncollected)} / ${_usd(row.usd.uncollected)}\n'
                    'الأرباح: ${_syp(row.syp.profit)} / ${_usd(row.usd.profit)}',
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
    );
  }
}
