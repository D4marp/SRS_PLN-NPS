import 'package:flutter/material.dart';
import 'dart:async';
import '../models/room_model.dart';
import '../models/booking_model.dart';
import '../services/websocket_service.dart';
import '../services/api_room_service.dart';

/// Real-time data provider that manages streams from WebSocket (Go backend).
/// Replaces Firebase Firestore streams.
class RealtimeDataProvider extends ChangeNotifier {
  // Stream subscriptions
  StreamSubscription<List<RoomModel>>? _allRoomsSubscription;
  StreamSubscription<List<BookingModel>>? _userBookingsSubscription;

  // Data
  List<RoomModel> _rooms = [];
  List<BookingModel> _userBookings = [];
  List<BookingModel> _upcomingBookings = [];
  List<BookingModel> _pastBookings = [];

  // State
  bool _isLoadingRooms = false;
  bool _isLoadingBookings = false;
  String? _errorMessage;

  // Getters
  List<RoomModel> get rooms => _rooms;
  List<BookingModel> get userBookings => _userBookings;
  List<BookingModel> get upcomingBookings => _upcomingBookings;
  List<BookingModel> get pastBookings => _pastBookings;
  bool get isLoadingRooms => _isLoadingRooms;
  bool get isLoadingBookings => _isLoadingBookings;
  String? get errorMessage => _errorMessage;

  RealtimeDataProvider() {
    _initializeStreams();
  }

  void _initializeStreams() {
    _setupRoomsRealtime();
  }

  /// Setup realtime listener untuk rooms via WebSocket
  void _setupRoomsRealtime({String? city}) {
    _setRoomsLoading(true);
    _clearError();

    _allRoomsSubscription?.cancel();
    _allRoomsSubscription =
        WebSocketService.watchRooms(city: city).listen(
      (rooms) {
        _rooms = rooms;
        _setRoomsLoading(false);
        notifyListeners();
        debugPrint('✅ Rooms updated via WebSocket: ${rooms.length} rooms');
      },
      onError: (error) {
        debugPrint('❌ Error in rooms stream: $error');
        _setError('Error loading rooms: $error');
        _setRoomsLoading(false);
      },
    );
  }

  /// Setup realtime listener untuk user bookings via WebSocket
  void setupUserBookingsRealtime(String userId) {
    _setBookingsLoading(true);
    _clearError();

    _userBookingsSubscription?.cancel();
    _userBookingsSubscription =
        WebSocketService.watchBookings().listen(
      (bookings) {
        _userBookings = bookings;
        _separateBookings();
        _setBookingsLoading(false);
        notifyListeners();
        debugPrint('✅ Bookings updated via WebSocket: ${bookings.length} bookings');
      },
      onError: (error) {
        debugPrint('❌ Error in bookings stream: $error');
        _setError('Error loading bookings: $error');
        _setBookingsLoading(false);
      },
    );
  }

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
            booking.status == BookingStatus.completed ||
            booking.status == BookingStatus.rejected)
        .toList();
  }

  /// Get a specific room by ID — try local cache, fallback to API
  Future<RoomModel?> getRoomById(String roomId) async {
    try {
      final cached = _rooms.where((r) => r.id == roomId).firstOrNull;
      if (cached != null) return cached;
      return await ApiRoomService.getRoom(roomId);
    } catch (e) {
      _setError('Error fetching room: $e');
      return null;
    }
  }

  /// Search rooms — applies local filter on cached WebSocket data
  Future<void> searchRooms(String query) async {
    // Rooms are already in _rooms from WebSocket; local search is handled
    // by RoomProvider._applyFilters(). This method is a no-op here.
    debugPrint('🔍 searchRooms called with: $query (handled by RoomProvider)');
  }

  /// Get rooms by city with realtime updates via WebSocket
  void getRoomsByCityRealtime(String city) {
    _setupRoomsRealtime(city: city);
  }

  /// Reset to all rooms (no city filter)
  void resetToAllRooms() {
    _setupRoomsRealtime();
  }

  Future<void> refreshAllData(String? userId) async {
    try {
      _clearError();
      resetToAllRooms();
      if (userId != null) {
        setupUserBookingsRealtime(userId);
      }
      debugPrint('🔄 All data refreshed');
    } catch (e) {
      _setError('Error refreshing data: $e');
    }
  }

  void cancelAllSubscriptions() {
    _allRoomsSubscription?.cancel();
    _userBookingsSubscription?.cancel();
    debugPrint('🛑 All subscriptions cancelled');
  }

  void _setRoomsLoading(bool loading) {
    _isLoadingRooms = loading;
  }

  void _setBookingsLoading(bool loading) {
    _isLoadingBookings = loading;
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

  int get roomCount => _rooms.length;
  int get bookingCount => _userBookings.length;
  bool get hasActiveBookings => _upcomingBookings.isNotEmpty;

  @override
  void dispose() {
    cancelAllSubscriptions();
    super.dispose();
  }
}
