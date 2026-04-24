import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../services/admin_service.dart';

class AdminProvider extends ChangeNotifier {
  List<BookingModel> _bookings = [];
  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic> _stats = {};
  int _pendingCount = 0;
  bool _isLoading = false;
  String? _errorMessage;

  List<BookingModel> get bookings => _bookings;
  List<Map<String, dynamic>> get users => _users;
  Map<String, dynamic> get stats => _stats;
  int get pendingCount => _pendingCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Stats getters
  int get totalBookings =>
      _stats['total_bookings'] as int? ?? 0;
  int get confirmedCount =>
      (_stats['bookings'] as Map<String, dynamic>?)?['confirmed'] as int? ??
      0;
  int get totalRooms =>
      _stats['total_rooms'] as int? ?? 0;

  // ─── Stats ─────────────────────────────────────────────────────────────────

  Future<void> loadStats() async {
    try {
      _stats = await AdminService.getStats();
      _pendingCount =
          (_stats['bookings'] as Map<String, dynamic>?)?['pending'] as int? ??
              0;
      notifyListeners();
    } catch (e) {
      _errorMessage = _extractError(e);
      notifyListeners();
    }
  }

  // ─── Bookings ──────────────────────────────────────────────────────────────

  /// Load bookings. Pass status=null for all, or "pending"/"confirmed"/"rejected".
  Future<void> loadBookings({String? status}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await AdminService.getAdminBookings(status: status);
      _bookings = data
          .map((e) => BookingModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _errorMessage = _extractError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> approveBooking(String id) async {
    try {
      await AdminService.approveBooking(id);
      await Future.wait([loadBookings(), loadStats()]);
      return true;
    } catch (e) {
      _errorMessage = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectBooking(String id, String reason) async {
    try {
      await AdminService.rejectBooking(id, reason);
      await Future.wait([loadBookings(), loadStats()]);
      return true;
    } catch (e) {
      _errorMessage = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeBooking(String id) async {
    try {
      await AdminService.completeBooking(id);
      await loadBookings();
      return true;
    } catch (e) {
      _errorMessage = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelBooking(String id) async {
    try {
      await AdminService.cancelBooking(id);
      await loadBookings();
      return true;
    } catch (e) {
      _errorMessage = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  // ─── Users ─────────────────────────────────────────────────────────────────

  Future<void> loadUsers({String? role, String? search}) async {
    _isLoading = true;
    notifyListeners();
    try {
      _users = await AdminService.getUsers(role: role, search: search);
    } catch (e) {
      _errorMessage = _extractError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> changeUserRole(String id, String role) async {
    try {
      await AdminService.changeUserRole(id, role);
      await loadUsers();
      return true;
    } catch (e) {
      _errorMessage = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteUser(String id) async {
    try {
      await AdminService.deleteUser(id);
      await loadUsers();
      return true;
    } catch (e) {
      _errorMessage = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _extractError(dynamic e) {
    if (e is DioException) {
      final msg = e.response?.data?['error'] as String?;
      return msg ?? e.message ?? e.toString();
    }
    return e.toString();
  }
}
