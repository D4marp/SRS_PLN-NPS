import 'package:dio/dio.dart';
import '../utils/api_config.dart';

/// Minimal HTTP client for Go backend auth endpoints.
/// Used alongside Firebase Auth to obtain a Go JWT for protected API calls.
class ApiAuthService {
  static Dio _dio() {
    return Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
  }

  /// Login to Go backend and return the JWT token.
  /// Returns `null` if the request fails (e.g. user not yet in Go DB).
  static Future<String?> login(String email, String password) async {
    try {
      final resp = await _dio().post('/api/auth/login', data: {
        'email': email,
        'password': password,
      });
      return resp.data['data']?['token'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Register in Go backend and return the JWT token.
  /// Returns `null` if the request fails (e.g. email already taken in Go DB).
  static Future<String?> register(String email, String password, String name) async {
    try {
      final resp = await _dio().post('/api/auth/register', data: {
        'email': email,
        'password': password,
        'name': name,
      });
      return resp.data['data']?['token'] as String?;
    } catch (_) {
      return null;
    }
  }
}
