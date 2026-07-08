class Employee {
  const Employee({
    required this.id,
    required this.name,
    required this.weeklySalary,
    this.currency = 'SYP',
    this.activeSessionStart,
  });

  final String id;
  final String name;
  final double weeklySalary;
  final String currency;

  /// Start time of the currently running attendance session, or null if the
  /// timer is stopped.
  final DateTime? activeSessionStart;

  bool get isRunning => activeSessionStart != null;

  /// Per-minute pay rate: weekly salary / (9h x 6 days) = / 3240.
  double get perMinute => weeklySalary > 0 ? weeklySalary / 3240 : 0;

  factory Employee.fromJson(Map<String, dynamic> json) {
    final session = json['active_session'];
    return Employee(
      id: json['id'] as String,
      name: json['name'] as String,
      weeklySalary: (json['weekly_salary'] as num?)?.toDouble() ?? 0,
      currency: (json['currency'] as String?) ?? 'SYP',
      activeSessionStart: session is Map && session['start_at'] != null
          ? DateTime.parse(session['start_at'] as String)
          : null,
    );
  }
}

class EmployeeLoan {
  const EmployeeLoan({
    required this.id,
    required this.employeeId,
    required this.amount,
    this.note,
    required this.loanDate,
  });

  final String id;
  final String employeeId;
  final double amount;
  final String? note;
  final DateTime loanDate;

  factory EmployeeLoan.fromJson(Map<String, dynamic> json) {
    return EmployeeLoan(
      id: json['id'] as String,
      employeeId: json['employee_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      note: json['note'] as String?,
      loanDate: DateTime.parse(json['loan_date'] as String),
    );
  }
}

class SalaryRow {
  const SalaryRow({
    required this.employeeId,
    required this.name,
    required this.weeklySalary,
    required this.regularMin,
    required this.overtimeMin,
    required this.perMinute,
    required this.regularPay,
    required this.overtimePay,
    required this.gross,
    required this.loans,
    required this.net,
    this.paid = false,
  });

  final String employeeId;
  final String name;
  final double weeklySalary;
  final int regularMin;
  final int overtimeMin;
  final double perMinute;
  final double regularPay;
  final double overtimePay;
  final double gross;
  final double loans;
  final double net;

  /// Whether this week's salary has already been paid out (recorded as an
  /// expense in the profit report).
  final bool paid;

  factory SalaryRow.fromJson(Map<String, dynamic> json) {
    return SalaryRow(
      employeeId: json['employee_id'] as String,
      name: json['name'] as String,
      weeklySalary: (json['weekly_salary'] as num?)?.toDouble() ?? 0,
      regularMin: (json['regular_min'] as num?)?.toInt() ?? 0,
      overtimeMin: (json['overtime_min'] as num?)?.toInt() ?? 0,
      perMinute: (json['per_minute'] as num?)?.toDouble() ?? 0,
      regularPay: (json['regular_pay'] as num?)?.toDouble() ?? 0,
      overtimePay: (json['overtime_pay'] as num?)?.toDouble() ?? 0,
      gross: (json['gross'] as num?)?.toDouble() ?? 0,
      loans: (json['loans'] as num?)?.toDouble() ?? 0,
      net: (json['net'] as num?)?.toDouble() ?? 0,
      paid: (json['paid'] as bool?) ?? false,
    );
  }
}

class SalaryWeek {
  const SalaryWeek({
    required this.weekOffset,
    required this.weekStart,
    required this.weekEnd,
    required this.rows,
  });

  final int weekOffset;
  final DateTime weekStart;
  final DateTime weekEnd;
  final List<SalaryRow> rows;

  /// Employees with a positive net that still need to be paid this week.
  int get unpaidPayableCount =>
      rows.where((r) => !r.paid && r.net > 0).length;

  factory SalaryWeek.fromJson(Map<String, dynamic> json) {
    return SalaryWeek(
      weekOffset: (json['week_offset'] as num?)?.toInt() ?? 0,
      weekStart: DateTime.parse(json['week_start'] as String),
      weekEnd: DateTime.parse(json['week_end'] as String),
      rows: (json['rows'] as List)
          .map((e) => SalaryRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
