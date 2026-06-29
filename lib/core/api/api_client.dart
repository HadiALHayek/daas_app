import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_config.dart';

const _tokenKey = 'access_token';
const _refreshKey = 'refresh_token';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.read(secureStorageProvider));
});

class ApiClient {
  ApiClient(this._storage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: _tokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          if (e.response?.statusCode == 401) {
            final refreshToken = await getRefreshToken();
            if (refreshToken != null) {
              try {
                // Try to refresh the token
                final refreshResponse = await Dio(BaseOptions(baseUrl: ApiConfig.baseUrl))
                    .post('/api/auth/refresh', data: {
                  'refresh_token': refreshToken,
                });
                
                final newAccessToken = refreshResponse.data['access_token'];
                final newRefreshToken = refreshResponse.data['refresh_token'];
                
                await saveSession(
                  accessToken: newAccessToken,
                  refreshToken: newRefreshToken,
                );
                
                // Retry the original request with the new token
                final options = e.requestOptions;
                options.headers['Authorization'] = 'Bearer $newAccessToken';
                
                // Use a fresh Dio instance to avoid interceptor recursion
                final retryDio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
                final response = await retryDio.fetch(options);
                return handler.resolve(response);
              } catch (refreshError) {
                // Refresh failed (e.g., refresh token revoked), clear and force login
                await clearToken();
                return handler.reject(e);
              }
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  late final Dio _dio;
  final FlutterSecureStorage _storage;

  Dio get dio => _dio;

  Future<bool> hasValidSession() async {
    final token = await _storage.read(key: _tokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _tokenKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshKey);
  }

  Future<String?> getToken() => _storage.read(key: _tokenKey);
  Future<String?> getRefreshToken() => _storage.read(key: _refreshKey);
}
