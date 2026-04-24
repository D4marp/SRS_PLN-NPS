import 'package:dio/dio.dart';
import '../models/booking_model.dart';
import '../utils/api_config.dart';

/// HTTP service for all /api/bookings/* and /api/rooms/:id/bookings endpoints.
/// Replaces Firebase Firestore for booking mutations (create, cancel).
class ApiBookingService {
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

  // ─── User Bookings ──────────────────────────────────────────────────────────

  /// Create a new booking (JWT required). Status starts as `pending`.
  static Future<BookingModel> createBooking({
    required String roomId,
    required DateTime bookingDate,
    required String checkInTime,
    required String checkOutTime,
    required int numberOfGuests,
    String? purpose,
  }) async {
    final resp = await _dio().post('/api/bookings', data: {
      'roomId': roomId,
      'bookingDate': bookingDate.millisecondsSinceEpoch,
      'checkInTime': checkInTime,
      'checkOutTime': checkOutTime,
      'numberOfGuests': numberOfGuests,
      if (purpose != null && purpose.isNotEmpty) 'purpose': purpose,
    });
    return BookingModel.fromJson(
        Map<String, dynamic>.from(resp.data['data'] as Map));
  }

  /// Cancel a booking — user can cancel their own; admin can cancel any (JWT required).
  static Future<void> cancelBooking(String bookingId) async {
    await _dio().patch('/api/bookings/$bookingId/cancel');
  }

  /// Get a single booking by ID (JWT required).
  static Future<BookingModel> getBookingById(String bookingId) async {
    final resp = await _dio().get('/api/bookings/$bookingId');
    return BookingModel.fromJson(
        Map<String, dynamic>.from(resp.data['data'] as Map));
  }

  // ─── Room Schedule (public) ─────────────────────────────────────────────────

  /// Fetch pending+confirmed bookings for a room on an optional date
  /// (no auth required). Used for schedule/availability display.
  ///
  /// [date] format: `YYYY-MM-DD` derived from [DateTime.millisecondsSinceEpoch].
  static Future<List<BookingModel>> getRoomBookings(
    String roomId, {
    DateTime? date,
  }) async {
    final String? dateStr = date != null
        ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
        : null;
    final resp = await _dio().get(
      '/api/rooms/$roomId/bookings',
      queryParameters: {
        if (dateStr != null) 'date': dateStr,
      },
    );
    final list = resp.data['data'] as List<dynamic>;
    return list
        .map((e) => BookingModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
