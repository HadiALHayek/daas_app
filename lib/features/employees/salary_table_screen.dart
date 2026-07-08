import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_errors.dart';
import '../../core/constants/strings_ar.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/employee.dart';
import '../../services/services.dart';

class SalaryTableScreen extends ConsumerStatefulWidget {
  const SalaryTableScreen({super.key});

  @override
  ConsumerState<SalaryTableScreen> createState() => _SalaryTableScreenState();
}

class _SalaryTableScreenState extends ConsumerState<SalaryTableScreen> {
  SalaryWeek? _week;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  int _offset = 0;

  final _numberFormat = NumberFormat('#,##0', 'ar');
  final _rateFormat = NumberFormat('#,##0.##', 'ar');
  final _dateFormat = DateFormat('yyyy/MM/dd', 'ar');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final week = await ref
          .read(employeesServiceProvider)
          .getSalaryTable(weekOffset: _offset);
      if (!mounted) return;
      setState(() => _week = week);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = StringsAr.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeWeek(int delta) {
    setState(() => _offset += delta);
    _load();
  }

  Future<void> _payWeek() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(StringsAr.paySalaries),
        content: const Text(StringsAr.confirmPaySalaries),
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
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(employeesServiceProvider)
          .payWeekSalaries(weekOffset: _offset);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(StringsAr.salariesPaid)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatAppError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _undoWeek() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(StringsAr.undoPay),
        content: const Text(StringsAr.confirmDelete),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(StringsAr.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(StringsAr.undoPay),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(employeesServiceProvider)
          .unpayWeekSalaries(weekOffset: _offset);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatAppError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _weekLabel() {
    if (_offset == 0) return StringsAr.currentWeek;
    if (_offset == -1) return StringsAr.previousWeek;
    return '${StringsAr.week} ($_offset)';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: StringsAr.salaryTable,
      body: Column(
        children: [
          _buildWeekHeader(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _loading
                  ? const AppLoading(
                      key: ValueKey('loading'), message: StringsAr.loading)
                  : KeyedSubtree(
                      key: const ValueKey('content'),
                      child: _error != null
                          ? EmptyState(
                              icon: Icons.error_outline,
                              title: _error!,
                              action: FilledButton(
                                onPressed: _load,
                                child: const Text(StringsAr.retry),
                              ),
                            )
                          : (_week == null || _week!.rows.isEmpty)
                              ? EmptyState(
                                  icon: Icons.table_chart_outlined,
                                  title: StringsAr.noEmployees,
                                )
                              : _buildTable(),
                    ),
            ),
          ),
          _buildPayBar(),
        ],
      ),
    );
  }

  Widget _buildPayBar() {
    final week = _week;
    if (_loading || week == null || week.rows.isEmpty) {
      return const SizedBox.shrink();
    }
    final unpaid = week.unpaidPayableCount;
    final anyPaid = week.rows.any((r) => r.paid);

    if (unpaid == 0 && !anyPaid) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            if (anyPaid)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _undoWeek,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text(StringsAr.undoPay),
                ),
              ),
            if (anyPaid && unpaid > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: (_busy || unpaid == 0) ? null : _payWeek,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.payments_rounded),
                label: Text(
                  unpaid == 0
                      ? StringsAr.allSalariesPaid
                      : '${StringsAr.paySalaries} ($unpaid)',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekHeader() {
    final week = _week;
    return Container(
      color: AppColors.primary.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          IconButton(
            tooltip: StringsAr.previousWeek,
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => _changeWeek(-1),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  _weekLabel(),
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (week != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${_dateFormat.format(week.weekStart.toLocal())} - ${_dateFormat.format(week.weekEnd.toLocal().subtract(const Duration(days: 1)))}',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: StringsAr.nextWeek,
            // Disable navigating into the future beyond the current week.
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: _offset >= 0 ? null : () => _changeWeek(1),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    final rows = _week!.rows;
    final totalRegular = rows.fold<double>(0, (s, r) => s + r.regularPay);
    final totalOvertime = rows.fold<double>(0, (s, r) => s + r.overtimePay);
    final totalLoans = rows.fold<double>(0, (s, r) => s + r.loans);
    final totalNet = rows.fold<double>(0, (s, r) => s + r.net);

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(12),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              AppColors.primary.withValues(alpha: 0.08),
            ),
            columnSpacing: 22,
            columns: const [
              DataColumn(label: Text(StringsAr.name)),
              DataColumn(label: Text(StringsAr.regularMinutes), numeric: true),
              DataColumn(label: Text(StringsAr.overtimeMinutes), numeric: true),
              DataColumn(label: Text(StringsAr.perMinuteRate), numeric: true),
              DataColumn(label: Text(StringsAr.regularPay), numeric: true),
              DataColumn(label: Text(StringsAr.overtimePay), numeric: true),
              DataColumn(label: Text(StringsAr.loans), numeric: true),
              DataColumn(label: Text(StringsAr.netSalary), numeric: true),
            ],
            rows: [
              ...rows.map(_dataRow),
              _totalsRow(totalRegular, totalOvertime, totalLoans, totalNet),
            ],
          ),
        ),
      ),
    );
  }

  DataRow _dataRow(SalaryRow row) {
    final negative = row.net < 0;
    return DataRow(cells: [
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (row.paid) ...[
            const Icon(Icons.check_circle_rounded,
                size: 16, color: AppColors.success),
            const SizedBox(width: 4),
          ],
          Text(
            row.name,
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
          ),
        ],
      )),
      DataCell(Text(_numberFormat.format(row.regularMin))),
      DataCell(Text(_numberFormat.format(row.overtimeMin))),
      DataCell(Text(_rateFormat.format(row.perMinute))),
      DataCell(Text(_numberFormat.format(row.regularPay))),
      DataCell(Text(_numberFormat.format(row.overtimePay))),
      DataCell(Text(
        _numberFormat.format(row.loans),
        style: TextStyle(
          color: row.loans > 0 ? AppColors.warning : AppColors.textSecondary,
        ),
      )),
      DataCell(Text(
        _numberFormat.format(row.net),
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: negative ? AppColors.error : AppColors.success,
        ),
      )),
    ]);
  }

  DataRow _totalsRow(
    double regular,
    double overtime,
    double loans,
    double net,
  ) {
    Widget bold(String text, {Color? color}) => Text(
          text,
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.w800,
            color: color ?? AppColors.textPrimary,
          ),
        );
    return DataRow(
      color: WidgetStateProperty.all(AppColors.primary.withValues(alpha: 0.05)),
      cells: [
        DataCell(bold(StringsAr.total)),
        const DataCell(Text('')),
        const DataCell(Text('')),
        const DataCell(Text('')),
        DataCell(bold(_numberFormat.format(regular))),
        DataCell(bold(_numberFormat.format(overtime))),
        DataCell(bold(_numberFormat.format(loans), color: AppColors.warning)),
        DataCell(bold(
          _numberFormat.format(net),
          color: net < 0 ? AppColors.error : AppColors.success,
        )),
      ],
    );
  }
}
