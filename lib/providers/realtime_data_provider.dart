import 'package:flutter/material.dart';
import 'dart:async';
import '../models/room_model.dart';
import '../models/booking_model.dart';
import '../services/room_service.dart';
import '../services/booking_service.dart';

/// Real-time data provider yang mengelola stream data dari Firebase
/// Dengan proper subscription management dan error handling
class RealtimeDataProvider extends ChangeNotifier {
  // Streams
  late Stream<List<RoomModel>> _allRoomsStream;
  late Stream<List<BookingModel>> _userBookingsStream;

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

  /// Inisialisasi semua streams
  void _initializeStreams() {
    _allRoomsStream = RoomService.getAllRooms();
    _setupRoomsRealtime();
  }

  /// Setup realtime listener untuk rooms
  void _setupRoomsRealtime() {
    _setRoomsLoading(true);
    _clearError();

    _allRoomsSubscription = _allRoomsStream.listen(
      (rooms) {
        _rooms = rooms;
        _setRoomsLoading(false);
        notifyListeners();
        debugPrint('✅ Rooms updated realtime: ${rooms.length} rooms');
      },
      onError: (error) {
        debugPrint('❌ Error in rooms stream: $error');
        _setError('Error loading rooms: $error');
        _setRoomsLoading(false);
      },
    );
  }

  /// Setup realtime listener untuk user bookings
  void setupUserBookingsRealtime(String userId) {
    _setBookingsLoading(true);
    _clearError();

    // Cancel previous subscription if exists
    _userBookingsSubscription?.cancel();

    _userBookingsStream = BookingService.getUserBookings(userId);

    _userBookingsSubscription = _userBookingsStream.listen(
      (bookings) {
        _userBookings = bookings;
        _separateBookings();
        _setBookingsLoading(false);
        notifyListeners();
        debugPrint('✅ Bookings updated realtime: ${bookings.length} bookings');
      },
      onError: (error) {
        debugPrint('❌ Error in bookings stream: $error');
        _setError('Error loading bookings: $error');
        _setBookingsLoading(false);
      },
    );
  }

  /// Separate bookings into upcoming and past
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

  /// Get a specific room by ID
  Future<RoomModel?> getRoomById(String roomId) async {
    try {
      return await RoomService.getRoomById(roomId);
    } catch (e) {
      _setError('Error fetching room: $e');
      return null;
    }
  }

  /// Search rooms with realtime updates
  Future<void> searchRooms(String query) async {
    try {
      _setRoomsLoading(true);
      _clearError();

      final results = await RoomService.searchRooms(query);
      // Note: searchRooms returns Future, not Stream
      // For realtime search, consider implementing a stream-based search
      debugPrint('🔍 Search results: ${results.length} rooms found');
    } catch (e) {
      _setError('Error searching rooms: $e');
    } finally {
      _setRoomsLoading(false);
    }
  }

  /// Get rooms by city with realtime updates
  void getRoomsByCityRealtime(String city) {
    _setRoomsLoading(true);
    _clearError();

    // Cancel previous subscription and setup new one
    _allRoomsSubscription?.cancel();
    _allRoomsStream = RoomService.getRoomsByCity(city);

    _allRoomsSubscription = _allRoomsStream.listen(
      (rooms) {
        _rooms = rooms;
        _setRoomsLoading(false);
        notifyListeners();
        debugPrint('✅ City rooms updated realtime: $city (${rooms.length} rooms)');
      },
      onError: (error) {
        debugPrint('❌ Error in city rooms stream: $error');
        _setError('Error loading rooms for $city: $error');
        _setRoomsLoading(false);
      },
    );
  }

  /// Reset to all rooms
  void resetToAllRooms() {
    _allRoomsSubscription?.cancel();
    _setupRoomsRealtime();
  }

  /// Refresh all data manually
  Future<void> refreshAllData(String? userId) async {
    try {
      _setRoomsLoading(true);
      if (userId != null) {
        _setBookingsLoading(true);
      }
      _clearError();

      // Reset rooms stream
      resetToAllRooms();

      // Reset bookings if userId provided
      if (userId != null) {
        setupUserBookingsRealtime(userId);
      }

      debugPrint('🔄 All data refreshed');
    } catch (e) {
      _setError('Error refreshing data: $e');
    }
  }

  /// Cancel all active subscriptions
  void cancelAllSubscriptions() {
    _allRoomsSubscription?.cancel();
    _userBookingsSubscription?.cancel();
    debugPrint('🛑 All subscriptions cancelled');
  }

  // Private helper methods
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

  // Utility getters
  int get roomCount => _rooms.length;
  int get bookingCount => _userBookings.length;
  bool get hasActiveBookings => _upcomingBookings.isNotEmpty;

  @override
  void dispose() {
    cancelAllSubscriptions();
    super.dispose();
  }
}
