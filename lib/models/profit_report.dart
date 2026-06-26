class ProfitBreakdown {
  const ProfitBreakdown({
    required this.month,
    required this.incoming,
    required this.outgoing,
    required this.profit,
    required this.billCount,
  });

  final int month;
  final double incoming;
  final double outgoing;
  final double profit;
  final int billCount;

  factory ProfitBreakdown.fromJson(Map<String, dynamic> json) {
    return ProfitBreakdown(
      month: json['month'] as int,
      incoming: (json['incoming'] as num).toDouble(),
      outgoing: (json['outgoing'] as num).toDouble(),
      profit: (json['profit'] as num).toDouble(),
      billCount: json['bill_count'] as int,
    );
  }
}

class ProfitReport {
  const ProfitReport({
    required this.period,
    required this.year,
    required this.currency,
    required this.incoming,
    required this.outgoing,
    required this.profit,
    required this.billCount,
    required this.breakdown,
    this.month,
  });

  final String period;
  final int year;
  final int? month;
  final String currency;
  final double incoming;
  final double outgoing;
  final double profit;
  final int billCount;
  final List<ProfitBreakdown> breakdown;

  factory ProfitReport.fromJson(Map<String, dynamic> json) {
    return ProfitReport(
      period: json['period'] as String,
      year: json['year'] as int,
      month: json['month'] as int?,
      currency: json['currency'] as String,
      incoming: (json['incoming'] as num).toDouble(),
      outgoing: (json['outgoing'] as num).toDouble(),
      profit: (json['profit'] as num).toDouble(),
      billCount: json['bill_count'] as int,
      breakdown: (json['breakdown'] as List? ?? [])
          .map((e) => ProfitBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
