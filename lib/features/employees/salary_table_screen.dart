import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String? _error;
  int _offset = 0;
  double? _rate;
  bool _paying = false;

  final _totalController = TextEditingController();
  final _numberFormat = NumberFormat('#,##0', 'ar');
  final _usdFormat = NumberFormat('#,##0.##', 'ar');
  final _dateFormat = DateFormat('yyyy/MM/dd', 'ar');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _totalController.dispose();
    super.dispose();
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
      // Pre-fill the editable total with the computed payable sum.
      _totalController.text = _defaultTotal(week).round().toString();
      _loadRate();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = StringsAr.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRate() async {
    try {
      final rate = await ref.read(exchangeRateServiceProvider).getRate();
      if (mounted) setState(() => _rate = rate);
    } catch (_) {
      // Rate is only used to show the USD equivalent; ignore failures.
    }
  }

  /// Sum of net pay for rows that are payable and not yet paid.
  double _defaultTotal(SalaryWeek week) => week.rows
      .where((r) => !r.paid && r.net > 0)
      .fold<double>(0, (s, r) => s + r.net);

  String _normalizeDigits(String input) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    final buffer = StringBuffer();
    for (final ch in input.split('')) {
      final ai = arabic.indexOf(ch);
      final fi = persian.indexOf(ch);
      if (ai != -1) {
        buffer.write(ai);
      } else if (fi != -1) {
        buffer.write(fi);
      } else {
        buffer.write(ch);
      }
    }
    return buffer.toString();
  }

  double? _parseAmount() {
    final raw = _normalizeDigits(_totalController.text)
        .replaceAll(',', '')
        .replaceAll('٬', '')
        .trim();
    final value = double.tryParse(raw);
    if (value == null || value < 0) return null;
    return value;
  }

  Future<void> _confirmPay() async {
    final amount = _parseAmount();
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(StringsAr.invalidAmount)),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          StringsAr.recordSalaries,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          '${StringsAr.confirmRecordSalaries}\n\n'
          '${_numberFormat.format(amount)} ${StringsAr.syp}',
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
    if (confirm != true) return;

    setState(() => _paying = true);
    try {
      await ref
          .read(employeesServiceProvider)
          .payWeekSalaries(weekOffset: _offset, amount: amount);
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
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _undoPay() async {
    setState(() => _paying = true);
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
      if (mounted) setState(() => _paying = false);
    }
  }

  void _changeWeek(int delta) {
    setState(() => _offset += delta);
    _load();
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
          if (!_loading && _error == null) _buildPayoutBar(),
        ],
      ),
    );
  }

  Widget _buildPayoutBar() {
    final week = _week;
    if (week == null || week.rows.isEmpty) return const SizedBox.shrink();

    final defaultTotal = _defaultTotal(week);
    final anyPaid = week.rows.any((r) => r.paid);

    // Everything payable is already recorded — show a paid banner + undo.
    if (week.unpaidPayableCount == 0) {
      if (!anyPaid) return const SizedBox.shrink();
      return _barContainer(
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                StringsAr.salariesPaid,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w800,
                  color: AppColors.success,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _paying ? null : _undoPay,
              icon: const Icon(Icons.undo_rounded, size: 18),
              label: const Text(StringsAr.undoPay),
            ),
          ],
        ),
      );
    }

    final amount = _parseAmount();
    final usd = (_rate != null && _rate! > 0 && amount != null)
        ? amount / _rate!
        : null;

    return _barContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                StringsAr.totalSalaries,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '${_numberFormat.format(defaultTotal)} ${StringsAr.syp}',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _totalController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[0-9٠-٩۰-۹.,]'),
                    ),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: StringsAr.amountToRecord,
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: _paying ? null : _confirmPay,
                  icon: _paying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text(StringsAr.recordSalaries),
                ),
              ),
            ],
          ),
          if (usd != null) ...[
            const SizedBox(height: 8),
            Text(
              '${StringsAr.usdEquivalent}: ${_usdFormat.format(usd)} ${StringsAr.usd}',
              style: GoogleFonts.cairo(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _barContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(top: false, child: child),
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
