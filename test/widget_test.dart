import 'package:flutter_test/flutter_test.dart';

import 'package:daas_app/core/constants/strings_ar.dart';
import 'package:daas_app/models/bill.dart';

void main() {
  test('Arabic strings are defined', () {
    expect(StringsAr.appTitle, 'إدارة مصنع الأثاث');
    expect(StringsAr.profits, isNotEmpty);
  });

  test('Bill currency label for SYP and USD', () {
    final sypBill = Bill(
      id: '1',
      billNumber: 1,
      currency: 'SYP',
      usdToSypRate: 15000,
      subtotal: 100,
      total: 100,
      sellerSignature: '',
      createdAt: DateTime(2026, 1, 1),
    );
    expect(sypBill.currencyLabel, 'ل.س');

    final usdBill = Bill(
      id: '2',
      billNumber: 2,
      currency: 'USD',
      usdToSypRate: 15000,
      subtotal: 50,
      total: 50,
      sellerSignature: '',
      createdAt: DateTime(2026, 1, 1),
    );
    expect(usdBill.currencyLabel, r'$');
  });
}
