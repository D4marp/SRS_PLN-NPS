import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/api_auth_service.dart';
import '../utils/api_config.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _initializeAuth();
  }

  // Initialize auth state listener
  void _initializeAuth() {
    AuthService.authStateChanges.listen((User? user) async {
      _user = user;
      if (user != null) {
        await _loadUserModel();
      } else {
        _userModel = null;
      }
      notifyListeners();
    });
  }

  // Load user model from Firestore
  Future<void> _loadUserModel() async {
    if (_user == null) return;

    try {
      _userModel = await AuthService.getUserDocument(_user!.uid);
    } catch (e) {
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  // Sign up with email and password
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      await AuthService.signUpWithEmail(
        email: email,
        password: password,
        name: name,
      );

      // Register in Go backend and store JWT for API calls
      final token = await ApiAuthService.register(email, password, name);
      ApiConfig.setToken(token);

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

      await AuthService.signInWithEmail(
        email: email,
        password: password,
      );

      // Obtain Go backend JWT for protected API calls
      final token = await ApiAuthService.login(email, password);
      ApiConfig.setToken(token);

      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      _setLoading(true);
      _clearError();

      await AuthService.signInWithGoogle();
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
      await AuthService.signOut();
      ApiConfig.setToken(null); // clear Go backend JWT
      _user = null;
      _userModel = null;
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    try {
      _setLoading(true);
      _clearError();

      await AuthService.resetPassword(email);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Update user profile
  Future<bool> updateUserProfile(UserModel updatedUser) async {
    try {
      _setLoading(true);
      _clearError();

      await AuthService.updateUserDocument(updatedUser);
      _userModel = updatedUser;

      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Delete account
  Future<bool> deleteAccount() async {
    try {
      _setLoading(true);
      _clearError();

      await AuthService.deleteAccount();
      _user = null;
      _userModel = null;

      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Send email verification
  Future<bool> sendEmailVerification() async {
    try {
      _setLoading(true);
      _clearError();

      await AuthService.sendEmailVerification();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Reload user
  Future<void> reloadUser() async {
    try {
      await AuthService.reloadUser();
      await _loadUserModel();
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Set user role
  Future<void> setUserRole(String roleString) async {
    if (_user == null) return;

    try {
      final userDoc = await AuthService.getUserDocument(_user!.uid);
      if (userDoc != null) {
        final role = roleString == 'superadmin'
            ? UserRole.superadmin
            : roleString == 'admin'
            ? UserRole.admin
            : roleString == 'booking'
            ? UserRole.booking
            : UserRole.user;
        final updatedUser = userDoc.copyWith(role: role);
        await AuthService.updateUserDocument(updatedUser);
        _userModel = updatedUser;
        notifyListeners();
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Update user location
  Future<void> updateUserLocation(String city) async {
    if (_user == null || _userModel == null) return;

    try {
      final updatedUser = _userModel!.copyWith(city: city);
      await AuthService.updateUserDocument(updatedUser);
      _userModel = updatedUser;
      notifyListeners();
    } catch (e) {
      print('Error updating location: $e');
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
    notifyListeners();
  }

  void clearError() => _clearError();

  // Check if email is verified
  bool get isEmailVerified => AuthService.isEmailVerified;
}
