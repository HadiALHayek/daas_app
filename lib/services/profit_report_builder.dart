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

String _currencyKey(String currency) => currency == 'USD' ? 'USD' : 'SYP';

CurrencyTotals _buildCurrencyTotals(
    double incoming, double collected, double uncollected, double outgoing) {
  return CurrencyTotals(
    incoming: incoming,
    collected: collected,
    uncollected: uncollected,
    outgoing: outgoing,
    profit: collected - outgoing,
  );
}

ProfitReport buildProfitReport({
  required String period,
  required int year,
  required int? month,
  required List<Bill> bills,
  required List<ExpensePayment> expenses,
}) {
  final range = _rangeFor(period, year, month);

  double incomingSyp = 0;
  double incomingUsd = 0;
  double collectedSyp = 0;
  double collectedUsd = 0;
  double uncollectedSyp = 0;
  double uncollectedUsd = 0;
  double outgoingSyp = 0;
  double outgoingUsd = 0;
  var billCount = 0;

  for (final bill in bills) {
    if (!_inRange(bill.createdAt, range)) continue;
    billCount++;
    if (_currencyKey(bill.currency) == 'USD') {
      incomingUsd += bill.total;
      collectedUsd += bill.amountPaid;
      uncollectedUsd += (bill.total - bill.amountPaid);
    } else {
      incomingSyp += bill.total;
      collectedSyp += bill.amountPaid;
      uncollectedSyp += (bill.total - bill.amountPaid);
    }
  }

  for (final expense in expenses) {
    if (!_inRange(expense.paymentDate, range)) continue;
    if (_currencyKey(expense.currency) == 'USD') {
      outgoingUsd += expense.amount;
    } else {
      outgoingSyp += expense.amount;
    }
  }

  final breakdown = <ProfitBreakdown>[];
  if (period == 'yearly') {
    for (var m = 1; m <= 12; m++) {
      final monthRange = _Range(DateTime(year, m), DateTime(year, m + 1));
      var monthBills = 0;
      var monthIncomingSyp = 0.0;
      var monthIncomingUsd = 0.0;
      var monthCollectedSyp = 0.0;
      var monthCollectedUsd = 0.0;
      var monthUncollectedSyp = 0.0;
      var monthUncollectedUsd = 0.0;
      var monthOutgoingSyp = 0.0;
      var monthOutgoingUsd = 0.0;

      for (final bill in bills) {
        if (!_inRange(bill.createdAt, monthRange)) continue;
        monthBills++;
        if (_currencyKey(bill.currency) == 'USD') {
          monthIncomingUsd += bill.total;
          monthCollectedUsd += bill.amountPaid;
          monthUncollectedUsd += (bill.total - bill.amountPaid);
        } else {
          monthIncomingSyp += bill.total;
          monthCollectedSyp += bill.amountPaid;
          monthUncollectedSyp += (bill.total - bill.amountPaid);
        }
      }

      for (final expense in expenses) {
        if (!_inRange(expense.paymentDate, monthRange)) continue;
        if (_currencyKey(expense.currency) == 'USD') {
          monthOutgoingUsd += expense.amount;
        } else {
          monthOutgoingSyp += expense.amount;
        }
      }

      breakdown.add(
        ProfitBreakdown(
          month: m,
          syp: _buildCurrencyTotals(monthIncomingSyp, monthCollectedSyp,
              monthUncollectedSyp, monthOutgoingSyp),
          usd: _buildCurrencyTotals(monthIncomingUsd, monthCollectedUsd,
              monthUncollectedUsd, monthOutgoingUsd),
          billCount: monthBills,
        ),
      );
    }
  }

  return ProfitReport(
    period: period,
    year: year,
    month: month,
    syp: _buildCurrencyTotals(
        incomingSyp, collectedSyp, uncollectedSyp, outgoingSyp),
    usd: _buildCurrencyTotals(
        incomingUsd, collectedUsd, uncollectedUsd, outgoingUsd),
    billCount: billCount,
    breakdown: breakdown,
  );
}
