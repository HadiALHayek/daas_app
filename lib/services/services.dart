import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_errors.dart';
import '../models/bill.dart';
import '../models/customer.dart';
import '../models/expense_payment.dart';
import '../models/item.dart';
import '../models/profit_report.dart';
import 'profit_report_builder.dart';

class AuthService {
  AuthService(this._client);
  final ApiClient _client;

  Future<void> login(String email, String password) async {
    try {
      final response = await _client.dio.post('/api/auth/login', data: {
        'email': email,
        'password': password,
      });
      final accessToken = response.data['access_token'] as String;
      final refreshToken = response.data['refresh_token'] as String;
      await _client.saveSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(
          'تعذر الاتصال بالخادم. تأكد أن الـ API يعمل وأن عنوان API_BASE_URL صحيح.',
        );
      }
      final data = e.response?.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error'] as String);
      }
      throw Exception('بيانات الدخول غير صحيحة');
    }
  }

  Future<void> logout() => _client.clearToken();

  Future<bool> isLoggedIn() => _client.hasValidSession();
}

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.read(apiClientProvider)),
);

class ItemsService {
  ItemsService(this._client);
  final ApiClient _client;

  Future<List<CatalogItem>> getItems() async {
    final response = await _client.dio.get('/api/items');
    return (response.data as List)
        .map((e) => CatalogItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CatalogItem> createItem(CatalogItem item) async {
    final response = await _client.dio.post('/api/items', data: item.toJson());
    return CatalogItem.fromJson(response.data as Map<String, dynamic>);
  }

  Future<CatalogItem> updateItem(String id, CatalogItem item) async {
    final response =
        await _client.dio.put('/api/items/$id', data: item.toJson());
    return CatalogItem.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteItem(String id) async {
    await _client.dio.delete('/api/items/$id');
  }
}

final itemsServiceProvider = Provider<ItemsService>(
  (ref) => ItemsService(ref.read(apiClientProvider)),
);

class ExchangeRateService {
  ExchangeRateService(this._client);
  final ApiClient _client;

  Future<double> getRate() async {
    final response = await _client.dio.get('/api/settings/exchange-rate');
    return (response.data['usd_to_syp'] as num).toDouble();
  }

  Future<double> updateRate(double rate) async {
    final response = await _client.dio.put(
      '/api/settings/exchange-rate',
      data: {'usd_to_syp': rate},
    );
    return (response.data['usd_to_syp'] as num).toDouble();
  }
}

final exchangeRateServiceProvider = Provider<ExchangeRateService>(
  (ref) => ExchangeRateService(ref.read(apiClientProvider)),
);

class CustomersService {
  CustomersService(this._client);
  final ApiClient _client;

  Future<List<Customer>> getCustomers() async {
    try {
      final response = await _client.dio.get('/api/customers');
      return (response.data as List)
          .map((e) => Customer.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(extractApiError(e));
    }
  }

  Future<Customer> createCustomer(Customer customer) async {
    try {
      final response =
          await _client.dio.post('/api/customers', data: customer.toJson());
      return Customer.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(extractApiError(e));
    }
  }

  Future<Customer> updateCustomer(String id, Customer customer) async {
    try {
      final response = await _client.dio.put(
        '/api/customers',
        queryParameters: {'id': id},
        data: customer.toJson(),
      );
      return Customer.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(extractApiError(e));
    }
  }

  Future<void> deleteCustomer(String id) async {
    try {
      await _client.dio.delete(
        '/api/customers',
        queryParameters: {'id': id},
      );
    } on DioException catch (e) {
      throw Exception(extractApiError(e));
    }
  }

  Future<List<Bill>> getCustomerBills(String customerId) async {
    try {
      final response =
          await _client.dio.get('/api/customers/$customerId/bills');
      return (response.data as List)
          .map((e) => Bill.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(extractApiError(e));
    }
  }
}

final customersServiceProvider = Provider<CustomersService>(
  (ref) => CustomersService(ref.read(apiClientProvider)),
);

class BillsService {
  BillsService(this._client);
  final ApiClient _client;

  Future<Bill> createBill({
    required String currency,
    required List<BillItem> items,
    String? customerId,
    String? manualCustomerName,
    String? manualCustomerPhone,
    double discount = 0,
    double? initialPayment,
  }) async {
    try {
      final payload = {
        'customer_id': customerId,
        'manual_customer_name': manualCustomerName,
        'manual_customer_phone': manualCustomerPhone,
        'currency': currency,
        'seller_signature': 'manual',
        'discount': discount,
        'items': items.map((i) => i.toCreateJson()).toList(),
        if (initialPayment != null) 'initial_payment': initialPayment,
      };
      final response = await _client.dio.post('/api/bills', data: payload);
      return Bill.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(extractApiError(e));
    }
  }

  Future<Bill> updateBill({
    required String billId,
    double? discount,
    List<BillItem>? items,
  }) async {
    try {
      final payload = <String, dynamic>{
        if (discount != null) 'discount': discount,
        if (items != null)
          'items': items.map((i) => i.toUpdateJson()).toList(),
      };
      final response = await _client.dio.put('/api/bills/$billId', data: payload);
      return Bill.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(extractApiError(e));
    }
  }

  Future<Bill> getBill(String id) async {
    try {
      final response = await _client.dio.get('/api/bills/$id');
      return Bill.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(extractApiError(e));
    }
  }

  Future<BillPayment> addBillPayment({
    required String billId,
    required double amount,
    String? notes,
  }) async {
    try {
      final response = await _client.dio.post(
        '/api/bills/$billId/payments',
        data: {
          'amount': amount,
          if (notes != null) 'notes': notes,
        },
      );
      return BillPayment.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(extractApiError(e));
    }
  }

  Future<void> deleteBill(String id) async {
    try {
      await _client.dio.delete('/api/bills/$id');
    } on DioException catch (e) {
      throw Exception(extractApiError(e));
    }
  }
}

final billsServiceProvider = Provider<BillsService>(
  (ref) => BillsService(ref.read(apiClientProvider)),
);

class ExpensesService {
  ExpensesService(this._client);
  final ApiClient _client;

  Future<List<ExpensePayment>> getExpenses() async {
    try {
      final response = await _client.dio.get('/api/expenses');
      return (response.data as List)
          .map((e) => ExpensePayment.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(extractApiError(e));
    }
  }

  Future<ExpensePayment> createExpense(ExpensePayment expense) async {
    try {
      final response = await _client.dio.post(
        '/api/expenses',
        data: expense.toJson(),
      );
      return ExpensePayment.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(extractApiError(e));
    }
  }

  Future<ExpensePayment> updateExpense(String id, ExpensePayment expense) async {
    try {
      final response = await _client.dio.put(
        '/api/expenses/$id',
        data: expense.toJson(),
      );
      return ExpensePayment.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(extractApiError(e));
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      await _client.dio.delete('/api/expenses/$id');
    } on DioException catch (e) {
      throw Exception(extractApiError(e));
    }
  }
}

final expensesServiceProvider = Provider<ExpensesService>(
  (ref) => ExpensesService(ref.read(apiClientProvider)),
);

class ReportsService {
  ReportsService(this._client);
  final ApiClient _client;

  Future<ProfitReport> getProfits({
    required String period,
    required int year,
    int? month,
  }) async {
    try {
      final response = await _client.dio.get(
        '/api/reports/profits',
        queryParameters: {
          'period': period,
          'year': year,
          if (month != null) 'month': month,
        },
      );
      final data = response.data as Map<String, dynamic>;

      if (data['report'] is Map) {
        return ProfitReport.fromJson(data);
      }

      return _buildProfitsLocally(period: period, year: year, month: month);
    } on DioException catch (e) {
      throw Exception(extractApiError(e));
    }
  }

  Future<ProfitReport> _buildProfitsLocally({
    required String period,
    required int year,
    int? month,
  }) async {
    final rateResponse = await _client.dio.get('/api/settings/exchange-rate');
    final exchangeRate = (rateResponse.data['usd_to_syp'] as num).toDouble();

    final expensesResponse = await _client.dio.get('/api/expenses');
    final expenses = (expensesResponse.data as List)
        .map((e) => ExpensePayment.fromJson(e as Map<String, dynamic>))
        .toList();

    final customersResponse = await _client.dio.get('/api/customers');
    final customers = customersResponse.data as List;

    final bills = <Bill>[];
    for (final customer in customers) {
      final id = (customer as Map<String, dynamic>)['id'] as String;
      final billsResponse = await _client.dio.get('/api/customers/$id/bills');
      for (final raw in billsResponse.data as List) {
        bills.add(Bill.fromJson(raw as Map<String, dynamic>));
      }
    }

    return buildProfitReport(
      period: period,
      year: year,
      month: month,
      bills: bills,
      expenses: expenses,
      exchangeRate: exchangeRate,
    );
  }
}

final reportsServiceProvider = Provider<ReportsService>(
  (ref) => ReportsService(ref.read(apiClientProvider)),
);
