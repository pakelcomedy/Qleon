/// Settings ViewModel
/// ------------------------------------------------------------
/// Manages application settings
/// - Theme mode
/// - Notifications toggle
/// - Security preferences
/// ------------------------------------------------------------

import 'package:flutter/foundation.dart';

import '../../../core/services/connectivity_service.dart';
import '../../../core/services/auth_service.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel(
    this._authService,
    this._connectivityService,
  );

  final AuthService _authService;
  final ConnectivityService _connectivityService;

  /// -------------------------------
  /// STATE
  /// -------------------------------

  bool _notificationsEnabled = true;
  bool _isOnline = true;
  bool _isLoading = false;
  String? _error;

  bool get notificationsEnabled => _notificationsEnabled;
  bool get isOnline => _isOnline;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// -------------------------------
  /// INIT
  /// -------------------------------

  void init() {
    _connectivityService.onConnectivityChanged.listen((status) {
      _isOnline = status;
      notifyListeners();
    });
  }

  /// -------------------------------
  /// NOTIFICATIONS
  /// -------------------------------

  Future<void> toggleNotifications(bool enabled) async {
    _setLoading(true);
    _clearError();

    try {
      // Persist preference if needed (Firestore / Local storage)
      _notificationsEnabled = enabled;
    } catch (e) {
      _setError('Failed to update notification settings');
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
    } catch (e) {
      _setError('Failed to logout');
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
}
