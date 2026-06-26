class ExpensePayment {
  const ExpensePayment({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.currency,
    required this.paymentDate,
    this.notes,
  });

  final String id;
  final String title;
  final String category;
  final double amount;
  final String currency;
  final DateTime paymentDate;
  final String? notes;

  factory ExpensePayment.fromJson(Map<String, dynamic> json) {
    return ExpensePayment(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      paymentDate: DateTime.parse(json['payment_date'] as String),
      notes: json['notes'] as String?,
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
}
