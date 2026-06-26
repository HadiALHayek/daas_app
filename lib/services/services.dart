import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/api_errors.dart';
import '../models/bill.dart';
import '../models/customer.dart';
import '../models/item.dart';
import '../models/profit_report.dart';

class AuthService {
  AuthService(this._client);
  final ApiClient _client;

  Future<void> login(String email, String password) async {
    try {
      final response = await _client.dio.post('/api/auth/login', data: {
        'email': email,
        'password': password,
      });
      final token = response.data['access_token'] as String;
      await _client.saveToken(token);
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

  Future<bool> isLoggedIn() async {
    final token = await _client.getToken();
    return token != null && token.isNotEmpty;
  }
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
    final response = await _client.dio.get('/api/customers');
    return (response.data as List)
        .map((e) => Customer.fromJson(e as Map<String, dynamic>))
        .toList();
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
        '/api/customers/$id',
        data: customer.toJson(),
      );
      return Customer.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(extractApiError(e));
    }
  }

  Future<void> deleteCustomer(String id) async {
    try {
      await _client.dio.delete('/api/customers/$id');
    } on DioException catch (e) {
      throw Exception(extractApiError(e));
    }
  }

  Future<List<Bill>> getCustomerBills(String customerId) async {
    final response =
        await _client.dio.get('/api/customers/$customerId/bills');
    return (response.data as List)
        .map((e) => Bill.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final customersServiceProvider = Provider<CustomersService>(
  (ref) => CustomersService(ref.read(apiClientProvider)),
);

class BillsService {
  BillsService(this._client);
  final ApiClient _client;

  Future<Bill> createBill({
    required String customerId,
    required String currency,
    required List<BillItem> items,
  }) async {
    try {
      final payload = {
        'customer_id': customerId,
        'currency': currency,
        // Non-empty so older API deployments don't reject empty signature
        'seller_signature': 'manual',
        'items': items.map((i) => i.toCreateJson()).toList(),
      };
      final response = await _client.dio.post('/api/bills', data: payload);
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
}

final billsServiceProvider = Provider<BillsService>(
  (ref) => BillsService(ref.read(apiClientProvider)),
);

class ReportsService {
  ReportsService(this._client);
  final ApiClient _client;

  Future<ProfitReport> getProfits({
    required String period,
    required int year,
    int? month,
  }) async {
    final response = await _client.dio.get(
      '/api/reports/profits',
      queryParameters: {
        'period': period,
        'year': year,
        if (month != null) 'month': month,
      },
    );
    return ProfitReport.fromJson(response.data as Map<String, dynamic>);
  }
}

final reportsServiceProvider = Provider<ReportsService>(
  (ref) => ReportsService(ref.read(apiClientProvider)),
);
