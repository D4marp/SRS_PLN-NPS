import 'package:flutter/material.dart';
import 'dart:async';
import '../models/room_model.dart';
import '../services/api_room_service.dart';
import '../services/websocket_service.dart';

class RoomProvider extends ChangeNotifier {
  List<RoomModel> _rooms = [];
  List<RoomModel> _filteredRooms = [];
  List<String> _cities = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Filter properties
  String _searchQuery = '';
  String? _selectedCity;
  bool? _hasACFilter;

  // Stream subscription management
  StreamSubscription<List<RoomModel>>? _roomsSubscription;

  // Getters
  List<RoomModel> get rooms => _filteredRooms;
  List<RoomModel> get allRooms => _rooms;
  List<String> get cities => _cities;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String? get selectedCity => _selectedCity;
  bool? get hasACFilter => _hasACFilter;

  RoomProvider() {
    _loadInitialData();
  }

  // Load initial data
  Future<void> _loadInitialData() async {
    await loadRooms();
  }

  /// Load all rooms with real-time updates via WebSocket
  Future<void> loadRooms() async {
    try {
      _setLoading(true);
      _clearError();

      // Cancel previous subscription if any
      _roomsSubscription?.cancel();

      bool firstEvent = true;

      // Subscribe to WebSocket stream for real-time updates
      _roomsSubscription = WebSocketService.watchRooms().listen(
        (rooms) {
          debugPrint('🔄 Rooms updated via WebSocket: ${rooms.length} rooms');
          _rooms = rooms;
          _applyFilters();
          if (firstEvent) {
            firstEvent = false;
            _isLoading = false;
          }
          notifyListeners();
        },
        onError: (error) {
          debugPrint('❌ Error in rooms WebSocket: $error');
          _setError('Error updating rooms: $error');
          _isLoading = false;
          notifyListeners();
        },
      );

      // Safety timeout: clear loading even if first message is delayed
      Future.delayed(const Duration(seconds: 10), () {
        if (_isLoading) {
          _isLoading = false;
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('❌ Error loading rooms: $e');
      _setError(e.toString());
      _setLoading(false);
      _rooms = [];
      notifyListeners();
    }
  }

  // Derive unique cities from the loaded room list
  Future<void> loadCities() async {
    _cities = _rooms.map((r) => r.city).toSet().toList()..sort();
    notifyListeners();
  }

  // Search rooms using local filter (data comes from WebSocket)
  Future<void> searchRooms(String query) async {
    _searchQuery = query;
    _applyFilters();
  }

  // Filter rooms by city
  void filterByCity(String? city) {
    _selectedCity = city;
    _applyFilters();
  }

  // Filter rooms by AC
  void filterByAC(bool? hasAC) {
    _hasACFilter = hasAC;
    _applyFilters();
  }



  // Apply all filters
  void _applyFilters() {
    // Refresh city list from current rooms
    _cities = _rooms.map((r) => r.city).toSet().toList()..sort();

    List<RoomModel> filtered = List.from(_rooms);

    // Apply city filter
    if (_selectedCity != null && _selectedCity!.isNotEmpty) {
      filtered = filtered
          .where(
              (room) => room.city.toLowerCase() == _selectedCity!.toLowerCase())
          .toList();
    }

    // Apply AC filter
    if (_hasACFilter != null) {
      filtered = filtered.where((room) => room.hasAC == _hasACFilter).toList();
    }

    // Apply search query filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((room) =>
              room.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              room.location
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              room.city.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    _filteredRooms = filtered;
    notifyListeners();
  }

  // Clear all filters
  void clearFilters() {
    _searchQuery = '';
    _selectedCity = null;
    _hasACFilter = null;
    _applyFilters();
  }

  // Get room by ID — try cache first, fall back to API
  Future<RoomModel?> getRoomById(String roomId) async {
    try {
      final cached = _rooms.where((r) => r.id == roomId).firstOrNull;
      if (cached != null) return cached;
      return await ApiRoomService.getRoom(roomId);
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  // Check room availability — uses the isAvailable flag from the API
  Future<bool> checkRoomAvailability(
      String roomId, DateTime bookingDate) async {
    try {
      final room = await ApiRoomService.getRoom(roomId);
      return room.isAvailable;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // Get rooms by city (for city-specific pages)
  Future<List<RoomModel>> getRoomsByCity(String city) async {
    try {
      _setLoading(true);
      _clearError();

      // Cancel previous subscription
      _roomsSubscription?.cancel();

      final completer = Completer<List<RoomModel>>();
      bool firstEvent = true;

      // Subscribe to city-filtered WebSocket stream
      _roomsSubscription = WebSocketService.watchRooms(city: city).listen(
        (rooms) {
          debugPrint('🔄 City rooms updated via WebSocket: $city (${rooms.length} rooms)');
          _rooms = rooms;
          _applyFilters();
          if (firstEvent) {
            firstEvent = false;
            _isLoading = false;
            if (!completer.isCompleted) completer.complete(rooms);
          }
          notifyListeners();
        },
        onError: (error) {
          debugPrint('❌ Error in city rooms WebSocket: $error');
          _setError('Error loading rooms for $city: $error');
          if (!completer.isCompleted) completer.complete([]);
        },
      );

      // Return first emission or empty list on timeout
      return await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _isLoading = false;
          return [];
        },
      );
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return [];
    }
  }

  // Refresh data
  Future<void> refresh() async {
    await _loadInitialData();
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

  // Get filtered room count
  int get filteredRoomCount => _filteredRooms.length;

  // Check if any filters are active
  bool get hasActiveFilters {
    return _searchQuery.isNotEmpty ||
        _selectedCity != null ||
        _hasACFilter != null;
  }

  // Get capacity range for filtering
  Map<String, int> get capacityRange {
    if (_rooms.isEmpty) return {'min': 0, 'max': 100};

    final capacities = _rooms.map((room) => room.maxGuests).toList();
    return {
      'min': capacities.reduce((a, b) => a < b ? a : b),
      'max': capacities.reduce((a, b) => a > b ? a : b),
    };
  }

  // Admin: Fetch all rooms
  Future<void> fetchRooms() async {
    await loadRooms();
  }

  // Admin: Add new room — returns created RoomModel (screen uses id to upload image)
  Future<RoomModel> addRoom(Map<String, dynamic> data) async {
    try {
      _setLoading(true);
      _clearError();
      return await ApiRoomService.createRoom(
        name: data['name'] as String,
        description: data['description'] as String,
        location: data['location'] as String,
        city: data['city'] as String,
        roomClass: data['roomClass'] as String,
        maxGuests: data['maxGuests'] as int,
        contactNumber: data['contactNumber'] as String,
        amenities: List<String>.from(data['amenities'] ?? []),
        hasAC: data['hasAC'] as bool? ?? false,
        isAvailable: data['isAvailable'] as bool? ?? true,
        floor: data['floor'] as String?,
        building: data['building'] as String?,
      );
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Admin: Update room
  Future<void> updateRoom(String roomId, Map<String, dynamic> data) async {
    try {
      _setLoading(true);
      _clearError();
      await ApiRoomService.updateRoom(
        roomId,
        name: data['name'] as String?,
        description: data['description'] as String?,
        location: data['location'] as String?,
        city: data['city'] as String?,
        roomClass: data['roomClass'] as String?,
        maxGuests: data['maxGuests'] as int?,
        contactNumber: data['contactNumber'] as String?,
        amenities: data['amenities'] != null
            ? List<String>.from(data['amenities'] as List)
            : null,
        hasAC: data['hasAC'] as bool?,
        isAvailable: data['isAvailable'] as bool?,
        floor: data['floor'] as String?,
        building: data['building'] as String?,
      );
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Admin: Delete room
  Future<void> deleteRoom(String roomId) async {
    try {
      _setLoading(true);
      _clearError();
      await ApiRoomService.deleteRoom(roomId);
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Admin: Toggle room availability
  Future<void> toggleRoomAvailability(String roomId, bool isAvailable) async {
    try {
      await ApiRoomService.updateRoom(roomId, isAvailable: isAvailable);
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  /// Cleanup subscriptions ketika provider di-dispose
  @override
  void dispose() {
    _roomsSubscription?.cancel();
    debugPrint('🛑 RoomProvider subscriptions cancelled');
    super.dispose();
  }
}
