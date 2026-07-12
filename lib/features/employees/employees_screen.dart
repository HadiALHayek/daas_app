import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_errors.dart';
import '../../core/constants/strings_ar.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/employee.dart';
import '../../services/services.dart';
import 'add_loan_dialog.dart';
import 'employee_form_dialog.dart';
import 'employee_loans_dialog.dart';

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  List<Employee>? _employees;
  bool _loading = true;
  String? _error;
  Timer? _ticker;

  final _numberFormat = NumberFormat('#,##0.##', 'ar');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker() {
    final anyRunning = _employees?.any((e) => e.isRunning) ?? false;
    if (anyRunning && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!anyRunning && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final employees = await ref.read(employeesServiceProvider).getEmployees();
      if (!mounted) return;
      setState(() => _employees = employees);
      _syncTicker();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = StringsAr.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Reload employees without showing the full-screen loading state.
  Future<void> _refreshSilently() async {
    try {
      final employees = await ref.read(employeesServiceProvider).getEmployees();
      if (!mounted) return;
      setState(() => _employees = employees);
      _syncTicker();
    } catch (_) {
      // Keep whatever is on screen; a manual pull-to-refresh can retry.
    }
  }

  Future<void> _toggleTimer(Employee employee) async {
    final service = ref.read(employeesServiceProvider);
    final wasRunning = employee.isRunning;

    // Optimistically flip the card so the timer starts/stops instantly
    // without a loading screen.
    setState(() {
      _employees = _employees!
          .map((e) => e.id != employee.id
              ? e
              : Employee(
                  id: e.id,
                  name: e.name,
                  weeklySalary: e.weeklySalary,
                  currency: e.currency,
                  activeSessionStart: wasRunning ? null : DateTime.now(),
                  weekLoans: e.weekLoans,
                ))
          .toList();
    });
    _syncTicker();

    try {
      if (wasRunning) {
        await service.stopTimer(employee.id);
      } else {
        await service.startTimer(employee.id);
      }
      // Reconcile the exact server start time quietly in the background.
      await _refreshSilently();
    } catch (e) {
      await _refreshSilently();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatAppError(e))),
        );
      }
    }
  }

  /// Lets the user pick a manual arrival (start) time, then starts the timer
  /// backdated to that moment — or, if the timer is already running, edits its
  /// start time. Elapsed time is then computed from the picked time up to now.
  Future<void> _setArrival(Employee employee) async {
    final now = DateTime.now();
    final initial = employee.activeSessionStart ?? now;

    final date = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now,
      helpText: StringsAr.arrivalTime,
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: StringsAr.arrivalTime,
    );
    if (time == null || !mounted) return;

    final picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);

    if (picked.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(StringsAr.arrivalInFuture)),
      );
      return;
    }

    // Optimistically show the backdated timer immediately.
    setState(() {
      _employees = _employees!
          .map((e) => e.id != employee.id
              ? e
              : Employee(
                  id: e.id,
                  name: e.name,
                  weeklySalary: e.weeklySalary,
                  currency: e.currency,
                  activeSessionStart: picked,
                  weekLoans: e.weekLoans,
                ))
          .toList();
    });
    _syncTicker();

    try {
      await ref
          .read(employeesServiceProvider)
          .startTimer(employee.id, startAt: picked);
      await _refreshSilently();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(StringsAr.arrivalSet)),
        );
      }
    } catch (e) {
      await _refreshSilently();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatAppError(e))),
        );
      }
    }
  }

  /// Lets the admin pick a manual departure (end) time, then stops the timer
  /// closing the session at that moment instead of now.
  Future<void> _setDeparture(Employee employee) async {
    final start = employee.activeSessionStart;
    if (start == null) return;
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(start.year, start.month, start.day),
      lastDate: now,
      helpText: StringsAr.departureTime,
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
      helpText: StringsAr.departureTime,
    );
    if (time == null || !mounted) return;

    final picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);

    if (picked.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(StringsAr.departureInFuture)),
      );
      return;
    }
    if (!picked.isAfter(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(StringsAr.departureBeforeArrival)),
      );
      return;
    }

    // Optimistically stop the card.
    setState(() {
      _employees = _employees!
          .map((e) => e.id != employee.id
              ? e
              : Employee(
                  id: e.id,
                  name: e.name,
                  weeklySalary: e.weeklySalary,
                  currency: e.currency,
                  activeSessionStart: null,
                  weekLoans: e.weekLoans,
                ))
          .toList();
    });
    _syncTicker();

    try {
      await ref
          .read(employeesServiceProvider)
          .stopTimer(employee.id, endAt: picked);
      await _refreshSilently();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(StringsAr.departureSet)),
        );
      }
    } catch (e) {
      await _refreshSilently();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatAppError(e))),
        );
      }
    }
  }

  /// Stops the timer at 17:00 (end of the work day) of the day the session
  /// started — for when the admin forgot to stop at closing time.
  Future<void> _stopAtEndOfDay(Employee employee) async {
    final start = employee.activeSessionStart;
    if (start == null) return;
    final localStart = start.toLocal();
    final endOfDay =
        DateTime(localStart.year, localStart.month, localStart.day, 17, 0);

    if (!endOfDay.isAfter(localStart)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(StringsAr.departureBeforeArrival)),
      );
      return;
    }
    if (endOfDay.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(StringsAr.departureInFuture)),
      );
      return;
    }

    // Optimistically stop the card.
    setState(() {
      _employees = _employees!
          .map((e) => e.id != employee.id
              ? e
              : Employee(
                  id: e.id,
                  name: e.name,
                  weeklySalary: e.weeklySalary,
                  currency: e.currency,
                  activeSessionStart: null,
                  weekLoans: e.weekLoans,
                ))
          .toList();
    });
    _syncTicker();

    try {
      await ref
          .read(employeesServiceProvider)
          .stopTimer(employee.id, endAt: endOfDay);
      await _refreshSilently();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(StringsAr.departureSet)),
        );
      }
    } catch (e) {
      await _refreshSilently();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatAppError(e))),
        );
      }
    }
  }

  Future<void> _addEmployee() async {
    final result = await showEmployeeFormDialog(context);
    if (result == null) return;
    try {
      await ref.read(employeesServiceProvider).createEmployee(
            name: result.name,
            weeklySalary: result.weeklySalary,
          );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatAppError(e))),
        );
      }
    }
  }

  Future<void> _editEmployee(Employee employee) async {
    final result = await showEmployeeFormDialog(context, employee: employee);
    if (result == null) return;
    try {
      await ref.read(employeesServiceProvider).updateEmployee(
            id: employee.id,
            name: result.name,
            weeklySalary: result.weeklySalary,
          );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatAppError(e))),
        );
      }
    }
  }

  Future<void> _deleteEmployee(Employee employee) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          StringsAr.confirmDelete,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text('حذف "${employee.name}"؟'),
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
      await ref.read(employeesServiceProvider).deleteEmployee(employee.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatAppError(e))),
        );
      }
    }
  }

  Future<void> _addLoan(Employee employee) async {
    final result = await showAddLoanDialog(context);
    if (result == null) return;
    try {
      await ref.read(employeesServiceProvider).addLoan(
            employeeId: employee.id,
            amount: result.amount,
            note: result.note,
          );
      await _refreshSilently();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت إضافة القرض')),
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

  Future<void> _manageLoans(Employee employee) async {
    final changed = await showEmployeeLoansDialog(context, employee);
    if (changed == true) await _refreshSilently();
  }

  String _formatElapsed(DateTime start) {
    final d = DateTime.now().difference(start);
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: StringsAr.employees,
      actions: [
        IconButton(
          tooltip: StringsAr.salaryTable,
          icon: const Icon(Icons.table_chart_rounded),
          onPressed: () => context.push('/employees/salary'),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEmployee,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text(StringsAr.addEmployee),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _loading
            ? const AppLoading(key: ValueKey('loading'), message: StringsAr.loading)
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
                    : (_employees == null || _employees!.isEmpty)
                        ? EmptyState(
                            icon: Icons.groups_rounded,
                            title: StringsAr.noEmployees,
                            subtitle: 'أضف موظفاً لتتبع الدوام والرواتب',
                            action: FilledButton.icon(
                              onPressed: _addEmployee,
                              icon: const Icon(Icons.add),
                              label: const Text(StringsAr.addEmployee),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                              itemCount: _employees!.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) =>
                                  _buildCard(_employees![index]),
                            ),
                          ),
              ),
      ),
    );
  }

  Widget _buildCard(Employee employee) {
    final running = employee.isRunning;
    final accent = running ? AppColors.success : AppColors.primary;
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.person_rounded, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.name,
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${StringsAr.weeklySalary}: ${_numberFormat.format(employee.weeklySalary)} ${StringsAr.syp}',
                      style: GoogleFonts.cairo(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (employee.weekLoans > 0) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.request_quote_outlined,
                            size: 13,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${StringsAr.loansThisWeek}: ${_numberFormat.format(employee.weekLoans)} ${StringsAr.syp}',
                            style: GoogleFonts.cairo(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) {
                  switch (value) {
                    case 'arrival':
                      _setArrival(employee);
                      break;
                    case 'departure':
                      _setDeparture(employee);
                      break;
                    case 'loan':
                      _addLoan(employee);
                      break;
                    case 'loans':
                      _manageLoans(employee);
                      break;
                    case 'edit':
                      _editEmployee(employee);
                      break;
                    case 'delete':
                      _deleteEmployee(employee);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'arrival',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.more_time_rounded),
                      title: Text(
                        running
                            ? StringsAr.editArrivalTime
                            : StringsAr.setArrivalTime,
                      ),
                    ),
                  ),
                  if (running)
                    const PopupMenuItem(
                      value: 'departure',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.timer_off_outlined),
                        title: Text(StringsAr.setDepartureTime),
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'loan',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.request_quote_outlined),
                      title: Text(StringsAr.addLoan),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'loans',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.account_balance_wallet_outlined),
                      title: Text(StringsAr.manageLoans),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined),
                      title: Text(StringsAr.edit),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline, color: AppColors.error),
                      title: Text(StringsAr.delete),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: running
                        ? AppColors.successSoft
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        running ? StringsAr.working : '—',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: running
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        running
                            ? _formatElapsed(employee.activeSessionStart!)
                            : '00:00:00',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontFeatures: const [FontFeature.tabularFigures()],
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: running
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (running) ...[
                Tooltip(
                  message: StringsAr.stopAtEndOfDay,
                  child: IconButton.filledTonal(
                    onPressed: () => _stopAtEndOfDay(employee),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.accentSoft,
                      foregroundColor: AppColors.warning,
                      padding: const EdgeInsets.all(14),
                    ),
                    icon: const Icon(Icons.wb_twilight_rounded),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      running ? AppColors.error : AppColors.success,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
                onPressed: () => _toggleTimer(employee),
                onLongPress: () =>
                    running ? _setDeparture(employee) : _setArrival(employee),
                icon: Icon(
                  running ? Icons.stop_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(running ? StringsAr.stopWork : StringsAr.startWork),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
