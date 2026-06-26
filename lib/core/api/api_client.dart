import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_config.dart';

const _tokenKey = 'access_token';
const _lastActiveKey = 'session_last_active_ms';

/// Session ends after this much time without app use.
const sessionInactivityTimeout = Duration(hours: 1);

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
          final isLogin = options.path.contains('/api/auth/login');

          if (!isLogin) {
            final valid = await hasValidSession();
            if (!valid) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  response: Response(
                    requestOptions: options,
                    statusCode: 401,
                    data: {
                      'error':
                          'انتهت الجلسة بعد ساعة من عدم الاستخدام. سجّل الدخول مرة أخرى.',
                    },
                  ),
                ),
              );
            }
            await recordSessionActivity();
          }

          final token = await _storage.read(key: _tokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  late final Dio _dio;
  final FlutterSecureStorage _storage;
  DateTime? _lastActivityWrite;

  Dio get dio => _dio;

  Future<bool> hasValidSession() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null || token.isEmpty) return false;

    final lastActiveRaw = await _storage.read(key: _lastActiveKey);
    if (lastActiveRaw == null) {
      await recordSessionActivity(force: true);
      return true;
    }

    final lastActiveMs = int.tryParse(lastActiveRaw);
    if (lastActiveMs == null) {
      await clearToken();
      return false;
    }

    final idleFor = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(lastActiveMs),
    );
    if (idleFor >= sessionInactivityTimeout) {
      await clearToken();
      return false;
    }

    return true;
  }

  Future<void> recordSessionActivity({bool force = false}) async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null || token.isEmpty) return;

    final now = DateTime.now();
    if (!force &&
        _lastActivityWrite != null &&
        now.difference(_lastActivityWrite!) < const Duration(seconds: 30)) {
      return;
    }

    _lastActivityWrite = now;
    await _storage.write(
      key: _lastActiveKey,
      value: now.millisecondsSinceEpoch.toString(),
    );
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
    await recordSessionActivity(force: true);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _lastActiveKey);
    _lastActivityWrite = null;
  }

  Future<String?> getToken() => _storage.read(key: _tokenKey);
}
