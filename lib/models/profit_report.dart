class CurrencyTotals {
  const CurrencyTotals({
    required this.incoming,
    required this.collected,
    required this.uncollectedUsd,
    required this.uncollectedSyp,
    required this.outgoing,
    required this.profit,
  });

  final double incoming;
  final double collected;
  final double uncollectedUsd;
  final double uncollectedSyp;
  final double outgoing;
  final double profit;

  factory CurrencyTotals.fromJson(Map<String, dynamic> json) {
    return CurrencyTotals(
      incoming: (json['incoming'] as num).toDouble(),
      collected: (json['collected'] as num).toDouble(),
      uncollectedUsd: (json['uncollected_usd'] as num? ?? 0).toDouble(),
      uncollectedSyp: (json['uncollected_syp'] as num? ?? 0).toDouble(),
      outgoing: (json['outgoing'] as num).toDouble(),
      profit: (json['profit'] as num).toDouble(),
    );
  }

  static const zero = CurrencyTotals(
    incoming: 0,
    collected: 0,
    uncollectedUsd: 0,
    uncollectedSyp: 0,
    outgoing: 0,
    profit: 0,
  );
}

class ProfitBreakdown {
  const ProfitBreakdown({
    required this.month,
    required this.report,
    required this.billCount,
  });

  final int month;
  final CurrencyTotals report;
  final int billCount;

  factory ProfitBreakdown.fromJson(Map<String, dynamic> json) {
    return ProfitBreakdown(
      month: json['month'] as int,
      report: CurrencyTotals.fromJson(json['report'] as Map<String, dynamic>),
      billCount: json['bill_count'] as int,
    );
  }
}

class ProfitReport {
  const ProfitReport({
    required this.period,
    required this.year,
    required this.report,
    required this.billCount,
    required this.breakdown,
    this.month,
  });

  final String period;
  final int year;
  final int? month;
  final CurrencyTotals report;
  final int billCount;
  final List<ProfitBreakdown> breakdown;

  factory ProfitReport.fromJson(Map<String, dynamic> json) {
    return ProfitReport(
      period: json['period'] as String,
      year: json['year'] as int,
      month: json['month'] as int?,
      report: CurrencyTotals.fromJson(json['report'] as Map<String, dynamic>),
      billCount: json['bill_count'] as int,
      breakdown: (json['breakdown'] as List? ?? [])
          .map((e) => ProfitBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
