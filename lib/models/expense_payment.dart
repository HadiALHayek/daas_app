class ExpensePayment {
  const ExpensePayment({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.currency,
    required this.paymentDate,
    this.notes,
    this.usdToSypRate,
  });

  final String id;
  final String title;
  final String category;
  final double amount;
  final String currency;
  final DateTime paymentDate;
  final String? notes;
  final double? usdToSypRate;

  factory ExpensePayment.fromJson(Map<String, dynamic> json) {
    return ExpensePayment(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      paymentDate: DateTime.parse(json['payment_date'] as String),
      notes: json['notes'] as String?,
      usdToSypRate: json['usd_to_syp_rate'] != null
          ? (json['usd_to_syp_rate'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'category': category,
        'amount': amount,
        'currency': currency,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };

  String get currencyLabel => currency == 'SYP' ? 'ل.س' : r'$';

  /// Value of this expense in USD. SYP expenses are converted using the rate
  /// recorded on the day they were paid (falling back to a default only for
  /// legacy rows that have no stored rate).
  double get usdValue {
    if (currency == 'USD') return amount;
    final rate = (usdToSypRate ?? 0) > 0 ? usdToSypRate! : 15000;
    return amount / rate;
  }
}
