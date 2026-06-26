import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/strings_ar.dart';
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
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
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
    return Scaffold(
      appBar: AppBar(title: const Text(StringsAr.profits)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'monthly', label: Text(StringsAr.monthly)),
                    ButtonSegment(value: 'yearly', label: Text(StringsAr.yearly)),
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
                        value: _year,
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
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _month,
                          decoration:
                              const InputDecoration(labelText: StringsAr.month),
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
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _report == null
                    ? const Center(child: Text(StringsAr.noData))
                    : _buildReport(_report!),
          ),
        ],
      ),
    );
  }

  Widget _buildReport(ProfitReport report) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _SummaryCard(
          title: StringsAr.incoming,
          value: '${_numberFormat.format(report.incoming)} ${StringsAr.syp}',
          color: Colors.green.shade700,
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          title: StringsAr.outgoing,
          value: '${_numberFormat.format(report.outgoing)} ${StringsAr.syp}',
          color: Colors.red.shade700,
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          title: StringsAr.profit,
          value: '${_numberFormat.format(report.profit)} ${StringsAr.syp}',
          color: Colors.blue.shade700,
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            title: const Text(StringsAr.billCount),
            trailing: Text(
              report.billCount.toString(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        if (report.period == 'yearly' && report.breakdown.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'التفصيل الشهري',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...report.breakdown.map((row) {
            if (row.billCount == 0) return const SizedBox.shrink();
            return Card(
              child: ListTile(
                title: Text(_monthNames[row.month - 1]),
                subtitle: Text(
                  '${StringsAr.incoming}: ${_numberFormat.format(row.incoming)} | '
                  '${StringsAr.profit}: ${_numberFormat.format(row.profit)}',
                ),
                trailing: Text('${row.billCount} فاتورة'),
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
