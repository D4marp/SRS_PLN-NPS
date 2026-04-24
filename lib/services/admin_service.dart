import 'package:dio/dio.dart';
import '../utils/api_config.dart';

/// HTTP service for all /api/admin/* and booking action endpoints.
/// Token must be set via ApiConfig.setToken() after Go backend login.
class AdminService {
  static Dio _dio() {
    final dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
    if (ApiConfig.token != null) {
      dio.options.headers['Authorization'] = 'Bearer ${ApiConfig.token}';
    }
    return dio;
  }

  // ─── Dashboard Stats ────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getStats() async {
    final resp = await _dio().get('/api/admin/stats');
    return Map<String, dynamic>.from(resp.data['data'] ?? {});
  }

  // ─── Booking Management ─────────────────────────────────────────────────────

  /// Fetch bookings with optional filters. status: null = all.
  static Future<List<Map<String, dynamic>>> getAdminBookings({
    String? status,
    String? roomId,
    String? fromDate,
    String? toDate,
  }) async {
    final resp = await _dio().get('/api/admin/bookings', queryParameters: {
      if (status != null) 'status': status,
      if (roomId != null) 'roomId': roomId,
      if (fromDate != null) 'fromDate': fromDate,
      if (toDate != null) 'toDate': toDate,
    });
    return List<Map<String, dynamic>>.from(resp.data['data'] ?? []);
  }

  static Future<void> approveBooking(String id, {String? note}) async {
    await _dio().post(
      '/api/bookings/$id/approve',
      data: note != null ? {'note': note} : {},
    );
  }

  static Future<void> rejectBooking(String id, String reason) async {
    await _dio().post('/api/bookings/$id/reject', data: {'reason': reason});
  }

  static Future<void> completeBooking(String id) async {
    await _dio().patch('/api/bookings/$id/complete');
  }

  static Future<void> cancelBooking(String id) async {
    await _dio().patch('/api/bookings/$id/cancel');
  }

  // ─── User Management (superadmin) ───────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getUsers({
    String? role,
    String? search,
  }) async {
    final resp = await _dio().get('/api/admin/users', queryParameters: {
      if (role != null && role.isNotEmpty) 'role': role,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return List<Map<String, dynamic>>.from(resp.data['data'] ?? []);
  }

  static Future<void> changeUserRole(String id, String role) async {
    await _dio().patch('/api/admin/users/$id/role', data: {'role': role});
  }

  static Future<void> deleteUser(String id) async {
    await _dio().delete('/api/admin/users/$id');
  }
}
