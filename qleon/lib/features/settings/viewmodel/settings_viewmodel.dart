// lib/features/settings/viewmodel/settings_viewmodel.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Minimal SettingsViewModel used by SettingsView (focus: logout + simple loading/error state).
class SettingsViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Public state used by the view
  bool isLoading = false;
  bool isLoggingOut = false;
  String? errorMessage;

  SettingsViewModel();

  /// Initialize viewmodel (kept minimal).
  /// If later you need to preload remote data, do it here.
  Future<void> init() async {
    // Example: placeholder for possible future initialization
    _setLoading(true);
    try {
      // if you need to fetch initial data, do it here
      // e.g., await fetchProfile();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // ----------------------------
  // Public helpers for view
  // ----------------------------
  /// Clear error after the view showed it
  void clearError() {
    if (errorMessage != null) {
      errorMessage = null;
      notifyListeners();
    }
  }

  /// Public setter for error (view can set custom messages)
  void setError(String? msg) {
    errorMessage = msg;
    notifyListeners();
  }

  // ----------------------------
  // Logout
  // ----------------------------
  /// Sign out from Firebase. View should call this and then navigate.
  Future<void> logout() async {
    if (isLoggingOut) return;
    _setLoggingOut(true);
    setError(null);

    try {
      await _auth.signOut();
      // After signOut, view handles navigation to login screen
    } catch (e) {
      setError(e.toString());
      rethrow;
    } finally {
      _setLoggingOut(false);
    }
  }

  // ----------------------------
  // Internal helpers
  // ----------------------------
  void _setLoading(bool v) {
    isLoading = v;
    notifyListeners();
  }

  void _setLoggingOut(bool v) {
    isLoggingOut = v;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}