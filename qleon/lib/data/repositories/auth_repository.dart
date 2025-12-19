/// Auth Repository
/// ------------------------------------------------------------
/// Domain-level authentication logic for Qleon
/// - Wraps AuthRemoteDataSource
/// - Handles logout side-effects (security cleanup)
/// - Exposes clean API for ViewModels
/// ------------------------------------------------------------

import 'package:firebase_auth/firebase_auth.dart';

import '../datasources/remote/auth_remote_ds.dart';
import '../datasources/local/secure_storage_ds.dart';

class AuthRepository {
  AuthRepository({
    required AuthRemoteDataSource remote,
    required SecureStorageDataSource secureStorage,
  })  : _remote = remote,
        _secureStorage = secureStorage;

  final AuthRemoteDataSource _remote;
  final SecureStorageDataSource _secureStorage;

  /// -------------------------------
  /// STREAM
  /// -------------------------------

  Stream<User?> authStateChanges() {
    return _remote.authStateChanges();
  }

  /// -------------------------------
  /// AUTH ACTIONS
  /// -------------------------------

  Future<User> signIn({
    required String email,
    required String password,
  }) async {
    return _remote.signIn(
      email: email,
      password: password,
    );
  }

  Future<User> register({
    required String email,
    required String password,
  }) async {
    return _remote.register(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    /// Security-critical cleanup
    await _secureStorage.clearAll();
    await _remote.signOut();
  }

  /// -------------------------------
  /// UTILITIES
  /// -------------------------------

  User? get currentUser => _remote.currentUser;

  String? get currentUserId => _remote.currentUserId;

  bool get isAuthenticated => currentUser != null;
}