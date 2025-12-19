/// Auth Service
/// ------------------------------------------------------------
/// Handles authentication logic for Qleon
/// Firebase Auth wrapper (Email/Password)
/// ------------------------------------------------------------

import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  /// -------------------------------
  /// STREAM
  /// -------------------------------

  Stream<User?> authStateChanges() {
    return _firebaseAuth.authStateChanges();
  }

  /// -------------------------------
  /// AUTH ACTIONS
  /// -------------------------------

  Future<User> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (credential.user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'User not found',
      );
    }

    return credential.user!;
  }

  Future<User> register({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (credential.user == null) {
      throw FirebaseAuthException(
        code: 'registration-failed',
        message: 'Failed to register user',
      );
    }

    return credential.user!;
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  /// -------------------------------
  /// UTILITIES
  /// -------------------------------

  User? get currentUser => _firebaseAuth.currentUser;

  String? get currentUserId => _firebaseAuth.currentUser?.uid;

  bool get isAuthenticated => _firebaseAuth.currentUser != null;
}