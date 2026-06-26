class BillPayment {
  const BillPayment({
    required this.id,
    required this.amount,
    required this.paymentDate,
    this.notes,
  });

  final String id;
  final double amount;
  final DateTime paymentDate;
  final String? notes;

  factory BillPayment.fromJson(Map<String, dynamic> json) {
    return BillPayment(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      paymentDate: DateTime.parse(json['payment_date'] as String),
      notes: json['notes'] as String?,
    );
  }
}

class BillItem {
  const BillItem({
    this.id,
    required this.itemName,
    required this.quantity,
    required this.unitSellPrice,
    required this.totalSell,
    this.itemId,
  });

  final String? id;
  final String? itemId;
  final String itemName;
  final double quantity;
  final double unitSellPrice;
  final double totalSell;

  factory BillItem.fromJson(Map<String, dynamic> json) {
    return BillItem(
      id: json['id'] as String?,
      itemId: json['item_id'] as String?,
      itemName: json['item_name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitSellPrice: (json['unit_sell_price'] as num).toDouble(),
      totalSell: (json['total_sell'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toCreateJson() => {
        if (itemId != null) 'item_id': itemId,
        'item_name': itemName,
        'quantity': quantity,
      };
}

class Bill {
  const Bill({
    required this.id,
    required this.billNumber,
    required this.currency,
    required this.usdToSypRate,
    required this.subtotal,
    required this.total,
    required this.sellerSignature,
    required this.createdAt,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.items = const [],
    this.payments = const [],
    this.amountPaid = 0,
    this.amountRemaining = 0,
  });

  final String id;
  final int billNumber;
  final String currency;
  final double usdToSypRate;
  final double subtotal;
  final double total;
  final String sellerSignature;
  final DateTime createdAt;
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  final List<BillItem> items;
  final List<BillPayment> payments;
  final double amountPaid;
  final double amountRemaining;

  factory Bill.fromJson(Map<String, dynamic> json) {
    final customer = json['customers'];
    final payments = (json['payments'] as List? ?? json['bill_payments'] as List? ?? [])
        .map((e) => BillPayment.fromJson(e as Map<String, dynamic>))
        .toList();

    final amountPaid = json['amount_paid'] != null
        ? (json['amount_paid'] as num).toDouble()
        : payments.fold<double>(0, (sum, p) => sum + p.amount);

    final total = (json['total'] as num).toDouble();

    return Bill(
      id: json['id'] as String,
      billNumber: (json['bill_number'] as num).toInt(),
      currency: json['currency'] as String,
      usdToSypRate: (json['usd_to_syp_rate'] as num).toDouble(),
      subtotal: (json['subtotal'] as num).toDouble(),
      total: total,
      sellerSignature: json['seller_signature'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      customerId: customer is Map ? customer['id'] as String? : json['customer_id'] as String?,
      customerName: customer is Map ? customer['name'] as String? : null,
      customerPhone: customer is Map ? customer['phone'] as String? : null,
      items: (json['items'] as List? ?? json['bill_items'] as List? ?? [])
          .map((e) => BillItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      payments: payments,
      amountPaid: amountPaid,
      amountRemaining: json['amount_remaining'] != null
          ? (json['amount_remaining'] as num).toDouble()
          : total - amountPaid,
    );
  }

  String get currencyLabel => currency == 'SYP' ? 'ل.س' : r'$';

  bool get isFullyPaid => amountRemaining <= 0.001;
}
