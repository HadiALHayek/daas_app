class CurrencyTotals {
  const CurrencyTotals({
    required this.incoming,
    required this.collected,
    required this.outgoing,
    required this.profit,
  });

  final double incoming;
  final double collected;
  final double outgoing;
  final double profit;

  factory CurrencyTotals.fromJson(Map<String, dynamic> json) {
    return CurrencyTotals(
      incoming: (json['incoming'] as num).toDouble(),
      collected: (json['collected'] as num?)?.toDouble() ?? 
                 (json['incoming'] as num).toDouble(), // fallback to incoming if missing
      outgoing: (json['outgoing'] as num).toDouble(),
      profit: (json['profit'] as num).toDouble(),
    );
  }

  static const zero = CurrencyTotals(incoming: 0, collected: 0, outgoing: 0, profit: 0);
}

class ProfitBreakdown {
  const ProfitBreakdown({
    required this.month,
    required this.syp,
    required this.usd,
    required this.billCount,
  });

  final int month;
  final CurrencyTotals syp;
  final CurrencyTotals usd;
  final int billCount;

  factory ProfitBreakdown.fromJson(Map<String, dynamic> json) {
    return ProfitBreakdown(
      month: json['month'] as int,
      syp: CurrencyTotals.fromJson(json['syp'] as Map<String, dynamic>),
      usd: CurrencyTotals.fromJson(json['usd'] as Map<String, dynamic>),
      billCount: json['bill_count'] as int,
    );
  }
}

class ProfitReport {
  const ProfitReport({
    required this.period,
    required this.year,
    required this.syp,
    required this.usd,
    required this.billCount,
    required this.breakdown,
    this.month,
  });

  final String period;
  final int year;
  final int? month;
  final CurrencyTotals syp;
  final CurrencyTotals usd;
  final int billCount;
  final List<ProfitBreakdown> breakdown;

  factory ProfitReport.fromJson(Map<String, dynamic> json) {
    return ProfitReport(
      period: json['period'] as String,
      year: json['year'] as int,
      month: json['month'] as int?,
      syp: CurrencyTotals.fromJson(json['syp'] as Map<String, dynamic>),
      usd: CurrencyTotals.fromJson(json['usd'] as Map<String, dynamic>),
      billCount: json['bill_count'] as int,
      breakdown: (json['breakdown'] as List? ?? [])
          .map((e) => ProfitBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
