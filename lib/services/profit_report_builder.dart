import '../models/bill.dart';
import '../models/expense_payment.dart';
import '../models/profit_report.dart';

class _Range {
  const _Range(this.start, this.end);
  final DateTime start;
  final DateTime end;
}

bool _inRange(DateTime date, _Range range) {
  return !date.isBefore(range.start) && date.isBefore(range.end);
}

_Range _rangeFor(String period, int year, int? month) {
  if (period == 'monthly' && month != null) {
    return _Range(DateTime(year, month), DateTime(year, month + 1));
  }
  return _Range(DateTime(year), DateTime(year + 1));
}

CurrencyTotals _calculateTotals({
  required List<Bill> bills,
  required List<ExpensePayment> expenses,
  required double exchangeRate,
  required _Range range,
}) {
  double incomingUsd = 0;
  double collectedUsd = 0;
  double uncollectedUsd = 0;
  double uncollectedSyp = 0;
  double outgoingUsd = 0;

  for (final bill in bills) {
    if (!_inRange(bill.createdAt, range)) continue;

    final billRate = bill.usdToSypRate > 0 ? bill.usdToSypRate : exchangeRate;
    final total = bill.total;
    
    // Incoming uses the bill's creation rate
    incomingUsd += bill.currency == 'USD' ? total : total / billRate;

    double totalPaidInOriginalCurrency = 0;
    for (final p in bill.payments) {
      final paymentAmount = p.amount;
      final paymentRate = (p.usdToSypRate ?? 0) > 0 ? p.usdToSypRate! : billRate;
      
      totalPaidInOriginalCurrency += paymentAmount;

      // Collected uses the historical rate of the payment
      collectedUsd += bill.currency == 'USD' ? paymentAmount : paymentAmount / paymentRate;
    }

    final debt = (total - totalPaidInOriginalCurrency).clamp(0.0, double.infinity);
    if (bill.currency == 'USD') {
      uncollectedUsd += debt;
    } else {
      uncollectedSyp += debt;
    }
  }

  for (final exp in expenses) {
    if (!_inRange(exp.paymentDate, range)) continue;
    final expRate = (exp.usdToSypRate ?? 0) > 0 ? exp.usdToSypRate! : exchangeRate;
    outgoingUsd +=
        exp.currency == 'USD' ? exp.amount : exp.amount / expRate;
  }

  return CurrencyTotals(
    incoming: incomingUsd,
    collected: collectedUsd,
    uncollectedUsd: uncollectedUsd,
    uncollectedSyp: uncollectedSyp,
    outgoing: outgoingUsd,
    profit: collectedUsd - outgoingUsd,
  );
}

ProfitReport buildProfitReport({
  required String period,
  required int year,
  required int? month,
  required List<Bill> bills,
  required List<ExpensePayment> expenses,
  double exchangeRate = 15000,
}) {
  final range = _rangeFor(period, year, month);

  final totalReport = _calculateTotals(
    bills: bills,
    expenses: expenses,
    exchangeRate: exchangeRate,
    range: range,
  );

  var billCount = 0;
  for (final bill in bills) {
    if (_inRange(bill.createdAt, range)) billCount++;
  }

  final breakdown = <ProfitBreakdown>[];
  if (period == 'yearly') {
    for (var m = 1; m <= 12; m++) {
      final monthRange = _Range(DateTime(year, m), DateTime(year, m + 1));
      var monthBillCount = 0;
      for (final bill in bills) {
        if (_inRange(bill.createdAt, monthRange)) monthBillCount++;
      }

      breakdown.add(
        ProfitBreakdown(
          month: m,
          report: _calculateTotals(
            bills: bills,
            expenses: expenses,
            exchangeRate: exchangeRate,
            range: monthRange,
          ),
          billCount: monthBillCount,
        ),
      );
    }
  }

  return ProfitReport(
    period: period,
    year: year,
    month: month,
    report: totalReport,
    billCount: billCount,
    breakdown: breakdown,
  );
}
