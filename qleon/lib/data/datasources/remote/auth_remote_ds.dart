/// Auth Remote Data Source
/// ------------------------------------------------------------
/// Bridges AuthRepository with AuthService (Firebase Auth)
/// No UI logic, no state management
/// ------------------------------------------------------------

import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/auth_service.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._authService);

  final AuthService _authService;

  /// -------------------------------
  /// STREAM
  /// -------------------------------

  Stream<User?> authStateChanges() {
    return _authService.authStateChanges();
  }

  /// -------------------------------
  /// AUTH ACTIONS
  /// -------------------------------

  Future<User> signIn({
    required String email,
    required String password,
  }) async {
    return _authService.signIn(
      email: email,
      password: password,
    );
  }

  Future<User> register({
    required String email,
    required String password,
  }) async {
    return _authService.register(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  /// -------------------------------
  /// UTILITIES
  /// -------------------------------

  User? get currentUser => _authService.currentUser;

  String? get currentUserId => _authService.currentUserId;
}