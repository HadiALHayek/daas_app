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

  Future<void> _toggleTimer(Employee employee) async {
    try {
      final service = ref.read(employeesServiceProvider);
      if (employee.isRunning) {
        await service.stopTimer(employee.id);
      } else {
        await service.startTimer(employee.id);
      }
      await _load();
    } catch (e) {
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
                    Text(
                      '${StringsAr.perMinuteRate}: ${_numberFormat.format(employee.perMinute)} ${StringsAr.syp}',
                      style: GoogleFonts.cairo(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) {
                  switch (value) {
                    case 'loan':
                      _addLoan(employee);
                      break;
                    case 'edit':
                      _editEmployee(employee);
                      break;
                    case 'delete':
                      _deleteEmployee(employee);
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'loan',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.request_quote_outlined),
                      title: Text(StringsAr.addLoan),
                    ),
                  ),
                  PopupMenuItem(
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
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      running ? AppColors.error : AppColors.success,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
                onPressed: () => _toggleTimer(employee),
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
