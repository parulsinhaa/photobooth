// lib/features/auth/repo/auth_repo.dart
import 'package:dio/dio.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/constants/app_constants.dart';

class AuthRepo {
  final Dio _dio;

  AuthRepo(this._dio);

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final token = LocalStorage.getString(AppConstants.tokenKey);
    if (token == null || token.isEmpty) return null;

    try {
      final response = await _dio.get('/auth/me');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<void> sendOtp({required String phone, required String countryCode}) async {
    await _dio.post('/auth/send-otp', data: {
      'phone': phone,
      'country_code': countryCode,
    });
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final response = await _dio.post('/auth/verify-otp', data: {
      'phone': phone,
      'otp': otp,
    });

    final data = response.data as Map<String, dynamic>;
    final token = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String;

    await LocalStorage.setString(AppConstants.tokenKey, token);
    await LocalStorage.setString(AppConstants.refreshTokenKey, refreshToken);

    final user = data['user'] as Map<String, dynamic>;
    await LocalStorage.setString('user_id', user['id'] as String);
    await LocalStorage.setString('user_name', user['username'] as String);

    return user;
  }

  Future<void> register({
    required String username,
    required String phone,
    String? email,
  }) async {
    await _dio.post('/auth/register', data: {
      'username': username,
      'phone': phone,
      'email': email,
    });
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {}
    await LocalStorage.remove(AppConstants.tokenKey);
    await LocalStorage.remove(AppConstants.refreshTokenKey);
    await LocalStorage.remove('user_id');
    await LocalStorage.remove('user_name');
  }
}

// lib/core/network/dio_client.dart
class DioClient {
  static late Dio _instance;

  static Dio get instance {
    _instance = Dio(BaseOptions(
      baseUrl: '${AppConstants.baseUrl}/api/v1',
      connectTimeout: const Duration(seconds: AppConstants.apiTimeoutSeconds),
      receiveTimeout: const Duration(seconds: AppConstants.apiTimeoutSeconds),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Auth interceptor
    _instance.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = LocalStorage.getString(AppConstants.tokenKey);
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Try to refresh token
          try {
            final refreshToken = LocalStorage.getString(AppConstants.refreshTokenKey);
            if (refreshToken != null) {
              final response = await Dio().post(
                '${AppConstants.baseUrl}/api/v1/auth/refresh',
                data: {'refresh_token': refreshToken},
              );
              final newToken = response.data['access_token'] as String;
              await LocalStorage.setString(AppConstants.tokenKey, newToken);

              // Retry original request
              error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
              final retryResponse = await _instance.fetch(error.requestOptions);
              return handler.resolve(retryResponse);
            }
          } catch (_) {
            // Clear tokens and force logout
            await LocalStorage.remove(AppConstants.tokenKey);
            await LocalStorage.remove(AppConstants.refreshTokenKey);
          }
        }
        handler.next(error);
      },
    ));

    return _instance;
  }
}
