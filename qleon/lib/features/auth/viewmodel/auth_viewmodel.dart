/// Auth ViewModel
/// ------------------------------------------------------------
/// Handles authentication state & actions
/// - Login
/// - Register
/// - Logout
/// - Auth state stream
/// ------------------------------------------------------------

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/auth_service.dart';
import '../../../data/models/user_model.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._authService);

  final AuthService _authService;

  /// -------------------------------
  /// STATE
  /// -------------------------------

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;

  StreamSubscription<UserModel?>? _authSub;

  /// -------------------------------
  /// INIT
  /// -------------------------------

  void init() {
    _authSub = _authService.userStream.listen((user) {
      _currentUser = user;
      notifyListeners();
    });
  }

  /// -------------------------------
  /// LOGIN
  /// -------------------------------

  Future<void> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      _currentUser = await _authService.login(
        email: email,
        password: password,
      );
    } catch (e) {
      _setError('Login failed');
    } finally {
      _setLoading(false);
    }
  }

  /// -------------------------------
  /// REGISTER
  /// -------------------------------

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      _currentUser = await _authService.register(
        email: email,
        password: password,
        displayName: displayName,
      );
    } catch (e) {
      _setError('Registration failed');
    } finally {
      _setLoading(false);
    }
  }

  /// -------------------------------
  /// LOGOUT
  /// -------------------------------

  Future<void> logout() async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.logout();
      _currentUser = null;
    } catch (e) {
      _setError('Logout failed');
    } finally {
      _setLoading(false);
    }
  }

  /// -------------------------------
  /// HELPERS
  /// -------------------------------

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
