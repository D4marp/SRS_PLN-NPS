import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../services/api_auth_service.dart';
import '../utils/api_config.dart';

/// Pure Go backend authentication (no Firebase)
class AuthProvider extends ChangeNotifier {
  UserModel? _userModel;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _userModel != null && ApiConfig.token != null;

  AuthProvider() {
    _initializeAuth();
  }

  // Initialize auth state from local storage
  Future<void> _initializeAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final userJson = prefs.getString('user_model');

      if (token != null && userJson != null) {
        ApiConfig.setToken(token);
        final persistedUser = UserModel.fromJson(jsonDecode(userJson));
        final role = _roleFromJwt(token);
        final userId = _userIdFromJwt(token);
        _userModel = persistedUser.copyWith(
          role: role,
          id: userId ?? persistedUser.id,
        );
      }
    } catch (e) {
      print('Auth init error: $e');
    }
    notifyListeners();
  }

  // Register with email and password
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String company,
    required String city,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final token = await ApiAuthService.register(email, password, name);
      if (token == null) throw 'Registration failed';

      ApiConfig.setToken(token);

      final role = _roleFromJwt(token);
      final userId = _userIdFromJwt(token);

      final user = UserModel(
        id: userId ?? '',
        name: name,
        email: email,
        role: role,
        city: city,
        profileImage: null,
        createdAt: DateTime.now(),
      );

      _userModel = user;
      await _saveAuthState(token, user);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sign in with email and password
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final token = await ApiAuthService.login(email, password);
      if (token == null) throw 'Login failed - check email/password';

      ApiConfig.setToken(token);

      final role = _roleFromJwt(token);
      final userId = _userIdFromJwt(token);

      final user = UserModel(
        id: userId ?? '',
        name: email.split('@').first,
        email: email,
        role: role,
        city: null,
        profileImage: null,
        createdAt: DateTime.now(),
      );

      _userModel = user;
      await _saveAuthState(token, user);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      _setLoading(true);
      ApiConfig.setToken(null);
      _userModel = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('jwt_token');
      await prefs.remove('user_model');
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // Save auth state to local storage
  Future<void> _saveAuthState(String token, UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      await prefs.setString('user_model', jsonEncode(user.toJson()));
    } catch (e) {
      print('Error saving auth state: $e');
    }
  }

  // Update user city
  Future<void> updateUserCity(String city) async {
    if (_userModel == null) return;
    try {
      _userModel = _userModel!.copyWith(city: city);
      if (ApiConfig.token != null) {
        await _saveAuthState(ApiConfig.token!, _userModel!);
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Update user city (alias for backward compatibility)
  Future<void> updateUserLocation(String city) async {
    await updateUserCity(city);
  }

  // Reset password (placeholder - Go backend doesn't have this yet)
  Future<bool> resetPassword(String email) async {
    try {
      _setLoading(true);
      _clearError();
      // TODO: Implement password reset in Go backend
      _setError('Password reset coming soon');
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Get user ID (backward compatibility)
  String? get userId => _userModel?.id;

  // Helper methods
  UserRole _roleFromJwt(String token) {
    try {
      final payload = _jwtPayload(token);
      return UserRoleX.fromString(payload['role'] as String?);
    } catch (_) {
      return UserRole.user;
    }
  }

  String? _userIdFromJwt(String token) {
    try {
      final payload = _jwtPayload(token);
      return payload['user_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _jwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw FormatException('Invalid JWT token');
    }

    final payload = parts[1];
    final normalized = base64Url.normalize(payload);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final Map<String, dynamic> jsonPayload = jsonDecode(decoded);
    return jsonPayload;
  }

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

  void clearError() => _clearError();
}
