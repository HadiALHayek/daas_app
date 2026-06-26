import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

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

  final _numberFormat = NumberFormat('#,##0', 'ar');

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
    setState(() => _loading = true);
    try {
      final report = await ref.read(reportsServiceProvider).getProfits(
            period: _period,
            year: _year,
            month: _period == 'monthly' ? _month : null,
          );
      setState(() => _report = report);
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

  Widget _buildReport(ProfitReport report) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StatMetricCard(
          title: StringsAr.incoming,
          value: '${_numberFormat.format(report.incoming)} ${StringsAr.syp}',
          icon: Icons.trending_up_rounded,
          color: AppColors.success,
          backgroundColor: AppColors.successSoft,
        ),
        const SizedBox(height: 12),
        StatMetricCard(
          title: StringsAr.outgoing,
          value: '${_numberFormat.format(report.outgoing)} ${StringsAr.syp}',
          icon: Icons.trending_down_rounded,
          color: AppColors.error,
          backgroundColor: AppColors.errorSoft,
        ),
        const SizedBox(height: 12),
        StatMetricCard(
          title: StringsAr.profit,
          value: '${_numberFormat.format(report.profit)} ${StringsAr.syp}',
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
            if (row.billCount == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ListItemCard(
                title: _monthNames[row.month - 1],
                subtitle:
                    '${StringsAr.incoming}: ${_numberFormat.format(row.incoming)}  •  '
                    '${StringsAr.profit}: ${_numberFormat.format(row.profit)}',
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
