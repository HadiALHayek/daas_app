class BillPayment {
  const BillPayment({
    required this.id,
    required this.amount,
    required this.paymentDate,
    this.notes,
    this.usdToSypRate,
  });

  final String id;
  final double amount;
  final DateTime paymentDate;
  final String? notes;
  final double? usdToSypRate;

  factory BillPayment.fromJson(Map<String, dynamic> json) {
    return BillPayment(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      paymentDate: DateTime.parse(json['payment_date'] as String),
      notes: json['notes'] as String?,
      usdToSypRate: json['usd_to_syp_rate'] != null
          ? (json['usd_to_syp_rate'] as num).toDouble()
          : null,
    );
  }
}

class OutstandingBill {
  const OutstandingBill({
    required this.id,
    required this.billNumber,
    required this.total,
    required this.amountRemaining,
    required this.currency,
  });

  final String id;
  final int billNumber;
  final double total;
  final double amountRemaining;
  final String currency;

  factory OutstandingBill.fromJson(Map<String, dynamic> json) {
    return OutstandingBill(
      id: json['id'] as String,
      billNumber: (json['bill_number'] as num).toInt(),
      total: (json['total'] as num).toDouble(),
      amountRemaining: (json['amount_remaining'] as num).toDouble(),
      currency: json['currency'] as String,
    );
  }

  String get currencyLabel => currency == 'SYP' ? 'ل.س' : r'$';
}

/// Payment recorded against an older bill while creating a new one.
class CrossBillPayment {
  const CrossBillPayment({
    required this.billNumber,
    required this.amount,
    required this.currency,
    this.notes,
  });

  final int billNumber;
  final double amount;
  final String currency;
  final String? notes;

  String get currencyLabel => currency == 'SYP' ? 'ل.س' : r'$';
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
    this.manualCustomerName,
    this.manualCustomerPhone,
    this.items = const [],
    this.payments = const [],
    this.outstandingBills = const [],
    this.crossBillPayments = const [],
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
  final String? manualCustomerName;
  final String? manualCustomerPhone;
  final List<BillItem> items;
  final List<BillPayment> payments;
  final List<OutstandingBill> outstandingBills;
  final List<CrossBillPayment> crossBillPayments;
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

    final manualName = json['manual_customer_name'] as String?;
    final manualPhone = json['manual_customer_phone'] as String?;

    final outstanding = (json['outstanding_bills'] as List? ?? [])
        .map((e) => OutstandingBill.fromJson(e as Map<String, dynamic>))
        .toList();

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
      customerName: customer is Map ? customer['name'] as String? : manualName,
      customerPhone: customer is Map ? customer['phone'] as String? : manualPhone,
      customerAddress: customer is Map ? customer['address'] as String? : null,
      manualCustomerName: manualName,
      manualCustomerPhone: manualPhone,
      items: (json['items'] as List? ?? json['bill_items'] as List? ?? [])
          .map((e) => BillItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      payments: paymentsList,
      outstandingBills: outstanding,
      crossBillPayments: const [],
      amountPaid: finalAmountPaid,
      amountRemaining: (totalValue - finalAmountPaid).clamp(0, double.infinity),
    );
  }

  String get currencyLabel => currency == 'SYP' ? 'ل.س' : r'$';

  bool get isFullyPaid => amountRemaining <= 0.05;

  Bill withCrossBillPayments(List<CrossBillPayment> crossBillPayments) {
    return Bill(
      id: id,
      billNumber: billNumber,
      currency: currency,
      usdToSypRate: usdToSypRate,
      subtotal: subtotal,
      total: total,
      discount: discount,
      sellerSignature: sellerSignature,
      createdAt: createdAt,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      manualCustomerName: manualCustomerName,
      manualCustomerPhone: manualCustomerPhone,
      items: items,
      payments: payments,
      outstandingBills: outstandingBills,
      crossBillPayments: crossBillPayments,
      amountPaid: amountPaid,
      amountRemaining: amountRemaining,
    );
  }

  Bill withPayment(BillPayment payment) {
    if (payments.any((p) => p.id == payment.id)) return this;
    final newPayments = [...payments, payment];
    final paid = amountPaid + payment.amount;
    return Bill(
      id: id,
      billNumber: billNumber,
      currency: currency,
      usdToSypRate: usdToSypRate,
      subtotal: subtotal,
      total: total,
      discount: discount,
      sellerSignature: sellerSignature,
      createdAt: createdAt,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      manualCustomerName: manualCustomerName,
      manualCustomerPhone: manualCustomerPhone,
      items: items,
      payments: newPayments,
      outstandingBills: outstandingBills,
      crossBillPayments: crossBillPayments,
      amountPaid: paid,
      amountRemaining: (total - paid).clamp(0, double.infinity),
    );
  }

  /// Keeps previous-bill balances when an API response omits them.
  Bill preservingOutstandingFrom(Bill? previous) {
    if (previous == null ||
        outstandingBills.isNotEmpty ||
        previous.outstandingBills.isEmpty) {
      return this;
    }
    return Bill(
      id: id,
      billNumber: billNumber,
      currency: currency,
      usdToSypRate: usdToSypRate,
      subtotal: subtotal,
      total: total,
      discount: discount,
      sellerSignature: sellerSignature,
      createdAt: createdAt,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      manualCustomerName: manualCustomerName,
      manualCustomerPhone: manualCustomerPhone,
      items: items,
      payments: payments,
      outstandingBills: previous.outstandingBills,
      crossBillPayments: crossBillPayments,
      amountPaid: amountPaid,
      amountRemaining: amountRemaining,
    );
  }
}
