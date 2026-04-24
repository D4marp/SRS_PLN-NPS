import 'package:flutter/material.dart';
import 'dart:async';
import '../models/booking_model.dart';
import '../services/api_booking_service.dart';
import '../services/websocket_service.dart';

class BookingProvider extends ChangeNotifier {
  List<BookingModel> _userBookings = [];
  List<BookingModel> _upcomingBookings = [];
  List<BookingModel> _pastBookings = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Current booking being created
  BookingModel? _currentBooking;
  DateTime? _selectedBookingDate;
  int _numberOfGuests = 1;

  // Stream subscription management
  StreamSubscription<List<BookingModel>>? _userBookingsSubscription;

  // Getters
  List<BookingModel> get userBookings => _userBookings;
  List<BookingModel> get upcomingBookings => _upcomingBookings;
  List<BookingModel> get pastBookings => _pastBookings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  BookingModel? get currentBooking => _currentBooking;
  DateTime? get selectedBookingDate => _selectedBookingDate;
  int get numberOfGuests => _numberOfGuests;

  /// Load user bookings with real-time updates via WebSocket.
  /// The server filters bookings by the user's JWT token.
  void loadUserBookings(String userId) {
    try {
      _clearError();

      // Cancel previous subscription if any
      _userBookingsSubscription?.cancel();

      // Subscribe to WebSocket stream for real-time updates
      _userBookingsSubscription = WebSocketService.watchBookings().listen(
        (bookings) {
          debugPrint('✅ Bookings loaded via WebSocket: ${bookings.length} bookings');
          _userBookings = bookings;
          _separateBookings();
          notifyListeners();
        },
        onError: (error) {
          debugPrint('❌ Error in bookings WebSocket: $error');
          _setError('Error loading bookings: $error');
        },
      );
    } catch (e) {
      debugPrint('❌ Error setting up bookings WebSocket: $e');
      _setError(e.toString());
    }
  }

  // Separate bookings into upcoming and past
  void _separateBookings() {
    final now = DateTime.now();
    _upcomingBookings = _userBookings
        .where((booking) =>
            booking.bookingDate.isAfter(now) &&
            (booking.status == BookingStatus.pending ||
                booking.status == BookingStatus.confirmed))
        .toList();

    _pastBookings = _userBookings
        .where((booking) =>
            booking.bookingDate.isBefore(now) ||
            booking.status == BookingStatus.cancelled ||
            booking.status == BookingStatus.completed)
        .toList();
  }

  // Create a new booking
  Future<String?> createBooking({
    required String userId, // kept for API compatibility; JWT carries identity
    required String roomId,
    required DateTime bookingDate,
    required String checkInTime,
    required String checkOutTime,
    required int numberOfGuests,
    String? purpose,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final booking = await ApiBookingService.createBooking(
        roomId: roomId,
        bookingDate: bookingDate,
        checkInTime: checkInTime,
        checkOutTime: checkOutTime,
        numberOfGuests: numberOfGuests,
        purpose: purpose,
      );

      return booking.id;
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Cancel booking
  Future<bool> cancelBooking(String bookingId) async {
    try {
      _setLoading(true);
      _clearError();

      await ApiBookingService.cancelBooking(bookingId);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Get booking by ID — try local cache first, then API
  Future<BookingModel?> getBookingById(String bookingId) async {
    try {
      final cached = _userBookings.where((b) => b.id == bookingId).firstOrNull;
      if (cached != null) return cached;
      return await ApiBookingService.getBookingById(bookingId);
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  // Set booking date
  void setBookingDate(DateTime date) {
    _selectedBookingDate = date;
    notifyListeners();
  }

  // Set number of guests
  void setNumberOfGuests(int guests) {
    _numberOfGuests = guests;
    notifyListeners();
  }

  // Check if date is valid
  bool get isDateValid {
    return _selectedBookingDate != null;
  }

  // Clear booking data
  void clearBookingData() {
    _currentBooking = null;
    _selectedBookingDate = null;
    _numberOfGuests = 1;
    notifyListeners();
  }

  // Get upcoming bookings count
  int get upcomingBookingsCount => _upcomingBookings.length;

  // Get past bookings count
  int get pastBookingsCount => _pastBookings.length;

  // Get bookings by status
  List<BookingModel> getBookingsByStatus(BookingStatus status) {
    return _userBookings.where((booking) => booking.status == status).toList();
  }



  // Get bookings by room ID
  Future<List<BookingModel>> getBookingsByRoomId(String roomId) async {
    try {
      return await ApiBookingService.getRoomBookings(roomId);
    } catch (e) {
      debugPrint('Error fetching bookings for room $roomId: $e');
      return [];
    }
  }

  // Get bookings for a room as a one-shot stream (schedule/availability display)
  Stream<List<BookingModel>> getBookingsByRoomIdStream(String roomId) {
    return Stream.fromFuture(ApiBookingService.getRoomBookings(roomId));
  }

  // Refresh bookings
  Future<void> refreshBookings(String userId) async {
    loadUserBookings(userId);
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  // Validate booking date
  String? validateDate() {
    if (_selectedBookingDate == null) {
      return 'Please select booking date';
    }
    if (_selectedBookingDate!.isBefore(DateTime.now())) {
      return 'Booking date cannot be in the past';
    }
    return null;
  }

  // Get minimum selectable date (today)
  DateTime get minSelectableDate => DateTime.now();

  // Get maximum selectable date (1 year from now)
  DateTime get maxSelectableDate =>
      DateTime.now().add(const Duration(days: 365));

  /// Cleanup subscriptions ketika provider di-dispose
  @override
  void dispose() {
    _userBookingsSubscription?.cancel();
    debugPrint('🛑 BookingProvider subscriptions cancelled');
    super.dispose();
  }
}

