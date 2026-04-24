import 'package:dio/dio.dart';
import '../utils/api_config.dart';

/// Pure Go backend auth client (no Firebase)
class ApiAuthService {
  static Dio _dio() {
    return Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
  }

  /// Login to Go backend and return JWT token
  static Future<String?> login(String email, String password) async {
    try {
      final resp = await _dio().post('/api/auth/login', data: {
        'email': email,
        'password': password,
      });
      return resp.data['data']?['token'] as String?;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  /// Register in Go backend and return JWT token
  static Future<String?> register(
    String email,
    String password,
    String name, {
    String? phone,
    String? company,
    String? city,
  }) async {
    try {
      final resp = await _dio().post('/api/auth/register', data: {
        'email': email,
        'password': password,
        'name': name,
        'phone': phone ?? '',
        'company': company ?? '',
        'city': city ?? '',
      });
      return resp.data['data']?['token'] as String?;
    } catch (e) {
      print('Register error: $e');
      return null;
    }
  }
}
