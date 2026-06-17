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
      final token = resp.data['data']?['token'] as String?;
      if (token == null) {
        throw 'Login failed: No token received from server';
      }
      return token;
    } on DioException catch (e) {
      // Handle network/server errors
      if (e.response != null) {
        final errorMsg = e.response?.data['error'] ?? e.response?.data['message'] ?? 'Login failed';
        throw 'Login error: $errorMsg';
      } else if (e.type == DioExceptionType.connectionTimeout) {
        throw 'Connection timeout - server not responding. Check if VPS is online.';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw 'Receive timeout - server response too slow';
      } else {
        throw 'Network error: ${e.message}';
      }
    } catch (e) {
      print('Login error: $e');
      rethrow;
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
      final token = resp.data['data']?['token'] as String?;
      if (token == null) {
        throw 'Register failed: No token received from server';
      }
      return token;
    } on DioException catch (e) {
      // Handle network/server errors
      if (e.response != null) {
        final errorMsg = e.response?.data['error'] ?? e.response?.data['message'] ?? 'Register failed';
        throw 'Register error: $errorMsg';
      } else if (e.type == DioExceptionType.connectionTimeout) {
        throw 'Connection timeout - server not responding. Check if VPS is online.';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw 'Receive timeout - server response too slow';
      } else {
        throw 'Network error: ${e.message}';
      }
    } catch (e) {
      print('Register error: $e');
      rethrow;
    }
  }
}
