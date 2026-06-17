import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/booking_model.dart';
import '../services/api_booking_service.dart';
import '../services/websocket_service.dart';
import '../utils/api_config.dart';

class BookingProvider extends ChangeNotifier {
  // Booking features are available on every platform that can reach the API.
  final bool _enabled = true;

  bool get isEnabled => _enabled;

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

  // Cache of active stream controllers per room (for force refresh).
  // Keep this field name distinct from the previous single-controller cache so
  // Flutter web hot reload does not reuse a stale Map<String, StreamController>.
  final Map<String, Set<StreamController<List<BookingModel>>>>
      _roomStreamControllerSets = {};

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
    if (!_enabled) {
      debugPrint('BookingProvider: loadUserBookings skipped (disabled)');
      return;
    }
    try {
      _clearError();

      // Cancel previous subscription if any
      _userBookingsSubscription?.cancel();

      // Subscribe to WebSocket stream for real-time updates
      _userBookingsSubscription = WebSocketService.watchBookings().listen(
        (bookings) {
          debugPrint(
              '✅ Bookings loaded via WebSocket: ${bookings.length} bookings');
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
    String? bookedForName,
    String? bookedForCompany,
    String? pihak1,
    String? pihak2,
    String? purpose,
  }) async {
    if (!_enabled) {
      debugPrint('BookingProvider: createBooking skipped (disabled)');
      return null;
    }
    try {
      _setLoading(true);
      _clearError();

      final booking = await ApiBookingService.createBooking(
        roomId: roomId,
        bookingDate: bookingDate,
        checkInTime: checkInTime,
        checkOutTime: checkOutTime,
        numberOfGuests: numberOfGuests,
        bookedForName: bookedForName,
        bookedForCompany: bookedForCompany,
        pihak1: pihak1,
        pihak2: pihak2,
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
    if (!_enabled) {
      debugPrint('BookingProvider: cancelBooking skipped (disabled)');
      return false;
    }
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
    if (!_enabled) {
      debugPrint('BookingProvider: getBookingById skipped (disabled)');
      return null;
    }
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
    if (!_enabled) {
      debugPrint('BookingProvider: getBookingsByRoomId skipped (disabled)');
      return [];
    }
    try {
      return await ApiBookingService.getRoomBookings(roomId);
    } catch (e) {
      debugPrint('Error fetching bookings for room $roomId: $e');
      return [];
    }
  }

  // Get bookings for a room as a one-shot stream (schedule/availability display)
  Stream<List<BookingModel>> getBookingsByRoomIdStream(String roomId) {
    if (!_enabled) {
      return Stream.value(<BookingModel>[]);
    }
    return Stream.fromFuture(ApiBookingService.getRoomBookings(roomId));
  }

  /// Real-time stream of bookings for a specific room.
  /// **PRIORITY: API-first architecture**
  /// 1. Fetch bookings from API immediately (reliable, stable)
  /// 2. Merge with WebSocket real-time updates (for live changes)
  /// 3. Fallback to periodic API polling if WebSocket unavailable
  ///
  /// This ensures room schedules always display data even if WebSocket disconnects.
  Stream<List<BookingModel>> watchBookingsByRoomIdStream(String roomId) {
    if (!_enabled) {
      return Stream.value(<BookingModel>[]);
    }

    final controller = StreamController<List<BookingModel>>.broadcast();
    List<BookingModel> currentData = [];
    StreamSubscription<List<BookingModel>>? wsSubscription;
    StreamSubscription<List<BookingModel>>? pollingSubscription;
    bool disposed = false;

    // Register every controller so force refresh updates all room widgets.
    _roomStreamControllerSets
        .putIfAbsent(roomId, () => <StreamController<List<BookingModel>>>{})
        .add(controller);

    /// Merge API data with WebSocket updates (dedup by booking ID)
    void mergeBookings(List<BookingModel> wsBookings) {
      final wsFiltered = wsBookings.where((b) => b.roomId == roomId).toList();
      final wsIds = wsFiltered.map((b) => b.id).toSet();

      // Keep API data for IDs not in WebSocket, add WebSocket data
      final merged = [
        ...currentData.where((b) => !wsIds.contains(b.id)),
        ...wsFiltered,
      ];
      merged.sort((a, b) => a.checkInTime.compareTo(b.checkInTime));

      currentData = merged;
      if (!controller.isClosed) controller.add(currentData);
    }

    /// Fetch initial data from API
    Future<void> fetchInitialData() async {
      try {
        final bookings = await ApiBookingService.getRoomBookings(roomId);
        if (!disposed && !controller.isClosed) {
          currentData = bookings;
          controller.add(currentData);
          debugPrint(
              '📡 [API] Initial bookings loaded: ${currentData.length} for room $roomId');
        }
      } catch (e) {
        debugPrint('❌ [API] Failed to load initial bookings: $e');
      }
    }

    /// Fallback: poll API every 3s when WebSocket is unavailable (faster updates for kiosk)
    void setupPollingFallback() {
      if (disposed || pollingSubscription != null) return;

      debugPrint('⏱️ [Polling] Starting API poll every 3s for room $roomId');
      pollingSubscription =
          Stream.periodic(const Duration(seconds: 3)).asyncMap((_) async {
        try {
          return await ApiBookingService.getRoomBookings(roomId);
        } catch (e) {
          debugPrint('❌ [Polling] Error: $e');
          return currentData;
        }
      }).listen(
        (bookings) {
          if (!disposed && !controller.isClosed) {
            currentData = bookings;
            controller.add(currentData);
            debugPrint('🔄 [Polling] Updated: ${currentData.length} bookings');
          }
        },
      );
    }

    /// Subscribe to WebSocket for real-time updates (if token available)
    void subscribeToWebSocket() {
      if (ApiConfig.token == null || ApiConfig.token!.isEmpty) {
        debugPrint(
            '⚠️ No JWT token, WebSocket disabled. Using API polling fallback.');
        setupPollingFallback();
        return;
      }

      wsSubscription = WebSocketService.watchBookings().listen(
        (wsBookings) {
          debugPrint(
              '🔄 [WebSocket] Received ${wsBookings.length} bookings, filtering for room $roomId');
          mergeBookings(wsBookings);
        },
        onError: (error) {
          debugPrint(
              '⚠️ [WebSocket] Error: $error — falling back to API polling');
          wsSubscription?.cancel();
          wsSubscription = null;
          setupPollingFallback();
        },
        onDone: () {
          debugPrint('⚠️ [WebSocket] Closed — falling back to API polling');
          wsSubscription = null;
          setupPollingFallback();
        },
      );
    }

    controller.onListen = () {
      debugPrint(
          '👂 watchBookingsByRoomIdStream listener attached for room $roomId');
      fetchInitialData().then((_) => subscribeToWebSocket());
    };

    controller.onCancel = () {
      disposed = true;
      wsSubscription?.cancel();
      pollingSubscription?.cancel();
      final controllers = _roomStreamControllerSets[roomId];
      controllers?.remove(controller);
      if (controllers == null || controllers.isEmpty) {
        _roomStreamControllerSets.remove(roomId);
      }
      debugPrint(
          '🔌 watchBookingsByRoomIdStream listener cancelled for room $roomId');
    };

    return controller.stream;
  }

  // Refresh bookings
  Future<void> refreshBookings(String userId) async {
    if (!_enabled) return;
    loadUserBookings(userId);
  }

  /// Force refresh room bookings (for immediate updates after check-in/check-out)
  Future<List<BookingModel>> forceRefreshRoomBookings(String roomId) async {
    if (!_enabled) return [];
    try {
      final bookings = await ApiBookingService.getRoomBookings(roomId);

      // Emit to cached stream controller if listener is active
      final controllers = _roomStreamControllerSets[roomId];
      if (controllers != null && controllers.isNotEmpty) {
        for (final controller in List.of(controllers)) {
          if (controller.isClosed) {
            controllers.remove(controller);
            continue;
          }
          controller.add(bookings);
        }
        debugPrint(
            '✨ [Force Refresh] Emitted ${bookings.length} bookings to ${controllers.length} stream(s) for room $roomId');
      }

      debugPrint(
          '🔄 [Force Refresh] Room $roomId: ${bookings.length} bookings updated');
      return bookings;
    } catch (e) {
      debugPrint('❌ [Force Refresh] Failed: $e');
      return [];
    }
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

  /// Submit feedback for a completed booking
  Future<bool> submitFeedback({
    required String bookingId,
    required String satisfaction,
    required String reason,
  }) async {
    if (!_enabled) {
      debugPrint('BookingProvider: submitFeedback skipped (disabled)');
      return false;
    }
    try {
      _setLoading(true);
      _clearError();

      final updatedBooking = await ApiBookingService.submitFeedback(
        bookingId: bookingId,
        satisfaction: satisfaction,
        reason: reason,
      );

      // Update the booking in the local list
      final index = _userBookings.indexWhere((b) => b.id == bookingId);
      if (index != -1) {
        _userBookings[index] = updatedBooking;
        _separateBookings();
      }

      debugPrint('✅ Feedback submitted for booking: $bookingId');
      return true;
    } catch (e) {
      debugPrint('❌ Error submitting feedback: $e');
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Submit early check-in/check-out times for a booking
  Future<bool> submitCheckInCheckOut({
    required String bookingId,
    String? actualCheckInTime,
    String? actualCheckOutTime,
    bool markComplete = false,
  }) async {
    if (!_enabled) {
      debugPrint('BookingProvider: submitCheckInCheckOut skipped (disabled)');
      return false;
    }
    try {
      _setLoading(true);
      _clearError();

      final updatedBooking = await ApiBookingService.submitCheckInCheckOut(
        bookingId: bookingId,
        actualCheckInTime: actualCheckInTime,
        actualCheckOutTime: actualCheckOutTime,
        markComplete: markComplete,
      );
      // Update the booking in the local list
      final index = _userBookings.indexWhere((b) => b.id == bookingId);
      if (index != -1) {
        _userBookings[index] = updatedBooking;
        _separateBookings();
      }

      debugPrint(
          '✅ Check-in/Check-out times submitted for booking: $bookingId');
      return true;
    } catch (e) {
      debugPrint('❌ Error submitting check-in/check-out: $e');
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Cleanup subscriptions ketika provider di-dispose
  @override
  void dispose() {
    _userBookingsSubscription?.cancel();
    debugPrint('🛑 BookingProvider subscriptions cancelled');
    super.dispose();
  }
}
