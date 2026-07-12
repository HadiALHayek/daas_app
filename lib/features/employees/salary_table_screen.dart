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
import 'day_session_edit_dialog.dart';

class SalaryTableScreen extends ConsumerStatefulWidget {
  const SalaryTableScreen({super.key});

  @override
  ConsumerState<SalaryTableScreen> createState() => _SalaryTableScreenState();
}

class _SalaryTableScreenState extends ConsumerState<SalaryTableScreen> {
  // View mode: daily report first, weekly report behind a toggle.
  bool _weeklyView = false;

  // Weekly state.
  SalaryWeek? _week;
  bool _loading = true;
  String? _error;
  int _offset = 0;
  double? _rate;
  bool _paying = false;
  bool _weekLoadedOnce = false;

  // Daily state.
  late DateTime _day = _todayLocalDate();
  DailySalaryReport? _dailyReport;
  bool _dailyLoading = true;
  String? _dailyError;

  final _totalController = TextEditingController();
  final _numberFormat = NumberFormat('#,##0', 'ar');
  final _usdFormat = NumberFormat('#,##0.##', 'ar');
  final _dateFormat = DateFormat('yyyy/MM/dd', 'ar');
  final _dayLabelFormat = DateFormat('EEEE، yyyy/MM/dd', 'ar');
  final _timeFormat = DateFormat('hh:mm a', 'ar');

  static DateTime _todayLocalDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _loadDaily();
  }

  @override
  void dispose() {
    _totalController.dispose();
    super.dispose();
  }

  Future<void> _loadDaily() async {
    if (!mounted) return;
    setState(() {
      _dailyLoading = true;
      _dailyError = null;
    });
    try {
      final report =
          await ref.read(employeesServiceProvider).getDailyReport(_day);
      if (!mounted) return;
      setState(() => _dailyReport = report);
    } catch (e) {
      if (!mounted) return;
      setState(() => _dailyError = StringsAr.error);
    } finally {
      if (mounted) setState(() => _dailyLoading = false);
    }
  }

  void _changeDay(int deltaDays) {
    setState(() => _day = _day.add(Duration(days: deltaDays)));
    _loadDaily();
  }

  bool get _isToday {
    final t = _todayLocalDate();
    return _day.year == t.year && _day.month == t.month && _day.day == t.day;
  }

  String _dayLabel() {
    if (_isToday) return StringsAr.today;
    return _dayLabelFormat.format(_day);
  }

  Future<void> _editDay(DailySalaryRow row) async {
    final result = await showDaySessionEditDialog(
      context,
      employeeName: row.name,
      day: _day,
      initialStart: row.start != null
          ? TimeOfDay.fromDateTime(row.start!.toLocal())
          : null,
      initialEnd:
          row.end != null ? TimeOfDay.fromDateTime(row.end!.toLocal()) : null,
    );
    if (result == null) return;

    DateTime? start;
    DateTime? end;
    if (!result.cleared) {
      start = DateTime(_day.year, _day.month, _day.day, result.start!.hour,
          result.start!.minute);
      end = DateTime(_day.year, _day.month, _day.day, result.end!.hour,
          result.end!.minute);
    }

    try {
      await ref.read(employeesServiceProvider).updateDaySession(
            employeeId: row.employeeId,
            date: _day,
            start: start,
            end: end,
          );
      // Edits change the underlying sessions, so the weekly report must reload
      // next time it is shown.
      _weekLoadedOnce = false;
      await _loadDaily();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(StringsAr.dayUpdated)),
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

  Future<void> _editDaySalary(DailySalaryRow row) async {
    final controller =
        TextEditingController(text: row.pay.round().toString());
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '${StringsAr.editDailySalary} - ${row.name}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹.,]')),
          ],
          decoration: const InputDecoration(
            labelText: StringsAr.dailySalary,
            suffixText: StringsAr.syp,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(StringsAr.cancel),
          ),
          FilledButton(
            onPressed: () {
              final raw = _normalizeDigits(controller.text)
                  .replaceAll(',', '')
                  .replaceAll('٬', '')
                  .trim();
              final v = double.tryParse(raw);
              if (v == null || v < 0) return;
              Navigator.pop(ctx, v);
            },
            child: const Text(StringsAr.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;

    try {
      await ref.read(employeesServiceProvider).setDailySalary(
            employeeId: row.employeeId,
            date: _day,
            amount: result,
          );
      _weekLoadedOnce = false;
      await _loadDaily();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(StringsAr.dayUpdated)),
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

  Future<void> _revertDaySalary(DailySalaryRow row) async {
    try {
      await ref.read(employeesServiceProvider).clearDailySalary(
            employeeId: row.employeeId,
            date: _day,
          );
      _weekLoadedOnce = false;
      await _loadDaily();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatAppError(e))),
        );
      }
    }
  }

  void _switchToWeekly() {
    setState(() => _weeklyView = true);
    if (!_weekLoadedOnce) _load();
  }

  void _switchToDaily() {
    setState(() => _weeklyView = false);
    _loadDaily();
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
      setState(() {
        _week = week;
        _weekLoadedOnce = true;
      });
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
          _buildModeToggle(),
          Expanded(
            child: _weeklyView ? _buildWeeklyBody() : _buildDailyBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    Widget tab(String label, IconData icon, bool selected, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 18,
                    color: selected ? Colors.white : AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          tab(StringsAr.dailyReport, Icons.today_rounded, !_weeklyView,
              _switchToDaily),
          tab(StringsAr.weeklyReport, Icons.calendar_month_rounded, _weeklyView,
              _switchToWeekly),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Daily view
  // ---------------------------------------------------------------------------

  Widget _buildDailyBody() {
    return Column(
      children: [
        _buildDayHeader(),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _dailyLoading
                ? const AppLoading(
                    key: ValueKey('daily-loading'), message: StringsAr.loading)
                : KeyedSubtree(
                    key: const ValueKey('daily-content'),
                    child: _dailyError != null
                        ? EmptyState(
                            icon: Icons.error_outline,
                            title: _dailyError!,
                            action: FilledButton(
                              onPressed: _loadDaily,
                              child: const Text(StringsAr.retry),
                            ),
                          )
                        : (_dailyReport == null || _dailyReport!.rows.isEmpty)
                            ? EmptyState(
                                icon: Icons.event_busy_outlined,
                                title: StringsAr.noEmployees,
                              )
                            : _buildDailyList(),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayHeader() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: StringsAr.previousDay,
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => _changeDay(-1),
          ),
          Expanded(
            child: Text(
              _dayLabel(),
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            tooltip: StringsAr.nextDay,
            icon: const Icon(Icons.chevron_left_rounded),
            // Don't navigate into the future.
            onPressed: _isToday ? null : () => _changeDay(1),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyList() {
    final rows = _dailyReport!.rows;
    return RefreshIndicator(
      onRefresh: _loadDaily,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _buildDailyCard(rows[index]),
      ),
    );
  }

  Widget _buildDailyCard(DailySalaryRow row) {
    final hasSession = row.hasSession;
    final h = row.totalMin ~/ 60;
    final m = row.totalMin % 60;

    return SectionCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (hasSession ? AppColors.success : AppColors.textMuted)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              hasSession ? Icons.person_rounded : Icons.person_off_outlined,
              color: hasSession ? AppColors.success : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      '${StringsAr.dailySalary}: ${_numberFormat.format(row.pay)} ${StringsAr.syp}',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.success,
                      ),
                    ),
                    if (row.isOverride) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          StringsAr.edited,
                          style: GoogleFonts.cairo(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                if (hasSession)
                  Text(
                    '${_timeFormat.format(row.start!.toLocal())}  ←  '
                    '${row.end != null ? _timeFormat.format(row.end!.toLocal()) : StringsAr.working}',
                    style: GoogleFonts.cairo(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  Text(
                    StringsAr.absent,
                    style: GoogleFonts.cairo(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                if (hasSession && row.end != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${StringsAr.hoursWorked}: ${_numberFormat.format(h)}س ${_numberFormat.format(m)}د'
                    '${row.overtimeMin > 0 ? '  •  ${StringsAr.overtimeMinutes} ${_numberFormat.format(row.overtimeMin)}' : ''}',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: row.overtimeMin > 0
                          ? AppColors.warning
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              switch (value) {
                case 'time':
                  _editDay(row);
                  break;
                case 'salary':
                  _editDaySalary(row);
                  break;
                case 'revert':
                  _revertDaySalary(row);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'time',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.schedule_outlined),
                  title: Text(StringsAr.editDay),
                ),
              ),
              const PopupMenuItem(
                value: 'salary',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.payments_outlined),
                  title: Text(StringsAr.editDailySalary),
                ),
              ),
              if (row.isOverride)
                const PopupMenuItem(
                  value: 'revert',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.restart_alt_rounded),
                    title: Text(StringsAr.revertToComputed),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Weekly view
  // ---------------------------------------------------------------------------

  Widget _buildWeeklyBody() {
    return Column(
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
