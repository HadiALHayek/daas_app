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
    this.priceOverride = false,
  });

  final String? id;
  final String? itemId;
  final String itemName;
  final double quantity;
  final double unitSellPrice;
  final double totalSell;
  final bool priceOverride;

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
        if (priceOverride) 'unit_sell_price': unitSellPrice,
      };

  Map<String, dynamic> toUpdateJson() => {
        'id': id,
        'unit_sell_price': unitSellPrice,
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
    this.discount = 0,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
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
  final double discount;
  final double total;
  final String sellerSignature;
  final DateTime createdAt;
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  final List<BillItem> items;
  final List<BillPayment> payments;
  final double amountPaid;
  final double amountRemaining;

  factory Bill.fromJson(Map<String, dynamic> json) {
    final customer = json['customers'];
    
    // Aggressively find payments in the JSON
    final rawPayments = json['payments'] as List? ?? 
                        json['bill_payments'] as List? ?? 
                        json['billPayments'] as List? ?? 
                        [];
                        
    final paymentsList = rawPayments
        .map((e) => BillPayment.fromJson(e as Map<String, dynamic>))
        .toList();

    // Sum from list to ensure accuracy
    final sumOfPayments = paymentsList.fold<double>(0, (sum, p) => sum + p.amount);
    
    // Check multiple possible field names for amount_paid
    final amountPaidField = (json['amount_paid'] as num? ?? 
                             json['amountPaid'] as num? ?? 
                             0).toDouble();
                             
    // The final amount paid is either what the field says or the sum of payments, whichever is greater.
    final finalAmountPaid = sumOfPayments > amountPaidField ? sumOfPayments : amountPaidField;

    final totalValue = (json['total'] as num? ?? 0).toDouble();

    return Bill(
      id: json['id'] as String,
      billNumber: (json['bill_number'] as num? ?? 0).toInt(),
      currency: json['currency'] as String? ?? 'SYP',
      usdToSypRate: (json['usd_to_syp_rate'] as num? ?? 1).toDouble(),
      subtotal: (json['subtotal'] as num? ?? 0).toDouble(),
      discount: (json['discount'] as num? ?? 0).toDouble(),
      total: totalValue,
      sellerSignature: json['seller_signature'] as String? ?? '',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
      customerId: customer is Map ? customer['id'] as String? : json['customer_id'] as String?,
      customerName: customer is Map ? customer['name'] as String? : null,
      customerPhone: customer is Map ? customer['phone'] as String? : null,
      customerAddress: customer is Map ? customer['address'] as String? : null,
      items: (json['items'] as List? ?? json['bill_items'] as List? ?? [])
          .map((e) => BillItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      payments: paymentsList,
      amountPaid: finalAmountPaid,
      amountRemaining: (totalValue - finalAmountPaid).clamp(0, double.infinity),
    );
  }

  String get currencyLabel => currency == 'SYP' ? 'ل.س' : r'$';

  bool get isFullyPaid => amountRemaining <= 0.05;
}
