// lib/features/settings/viewmodel/security_viewmodel.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// SecurityViewModel
/// - Semua operasi Firebase auth terkait security.
/// - View hanya membaca isLoading / errorMessage / errorCode dan men-trigger UI (snackbars, dialogs, navigation).
class SecurityViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Public observable state
  bool isLoading = false;
  String? errorMessage;
  String? errorCode; // raw Firebase error code if needed

  SecurityViewModel();

  // -----------------------
  // Helpers
  // -----------------------
  void _setLoading(bool v) {
    if (isLoading == v) return;
    isLoading = v;
    notifyListeners();
  }

  void _setError(String? message, [String? code]) {
    errorMessage = message;
    errorCode = code;
    notifyListeners();
  }

  void clearError() {
    if (errorMessage != null || errorCode != null) {
      errorMessage = null;
      errorCode = null;
      notifyListeners();
    }
  }

  String _friendlyMessageFromCode(String code, [String? fallback]) {
    switch (code) {
      case 'wrong-password':
        return 'Password salah';
      case 'user-not-found':
        return 'Pengguna tidak ditemukan';
      case 'invalid-email':
        return 'Format email tidak valid';
      case 'email-already-in-use':
        return 'Email sudah terdaftar';
      case 'requires-recent-login':
        return 'Aksi ini membutuhkan autentikasi ulang. Silakan masuk kembali lalu coba lagi.';
      case 'weak-password':
        return 'Password terlalu lemah';
      case 'network-request-failed':
        return 'Koneksi bermasalah. Periksa jaringan Anda.';
      case 'invalid-credential':
        return 'Kredensial tidak valid atau kedaluwarsa';
      case 'user-token-expired':
      case 'invalid-user-token':
        return 'Sesi kedaluwarsa. Silakan keluar dan masuk kembali.';
      default:
        return fallback ?? code;
    }
  }

  // -----------------------
  // Reauth helper
  // -----------------------
  /// Reauthenticate using current password.
  /// Returns true on success, false on failure (and sets errorMessage).
  Future<bool> reauthenticateWithPassword(String currentPassword) async {
    if (isLoading) return false;
    _setLoading(true);
    _setError(null);
    try {
      final user = _auth.currentUser;
      final email = user?.email;
      if (user == null || email == null) {
        _setError('User tidak terautentikasi');
        return false;
      }
      final cred = EmailAuthProvider.credential(email: email, password: currentPassword);
      await user.reauthenticateWithCredential(cred);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_friendlyMessageFromCode(e.code, e.message), e.code);
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // -----------------------
  // Email change
  // -----------------------
  /// Reauth dengan [currentPassword], lalu kirim verification ke [newEmail].
  ///
  /// Jika [signOutAfterEmailChange] = true (default), VM akan otomatis signOut
  /// setelah verification email dikirim — ini mencegah token lama tersisa yang
  /// sering menyebabkan error "credential expired".
  ///
  /// Returns true when verification email was successfully requested.
  Future<bool> changeEmailWithPassword({
    required String currentPassword,
    required String newEmail,
    bool signOutAfterEmailChange = true,
  }) async {
    if (isLoading) return false;
    _setLoading(true);
    _setError(null);

    try {
      final user = _auth.currentUser;
      final oldEmail = user?.email;
      if (user == null || oldEmail == null) {
        _setError('User tidak terautentikasi');
        return false;
      }

      // 1) reauthenticate
      final cred = EmailAuthProvider.credential(email: oldEmail, password: currentPassword);
      await user.reauthenticateWithCredential(cred);

      // 2) request verify-before-update (kirim email verifikasi ke newEmail)
      await user.verifyBeforeUpdateEmail(newEmail);

      // 3) optional: sign out to clear local auth state / tokens
      if (signOutAfterEmailChange) {
        await _auth.signOut();
      }

      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_friendlyMessageFromCode(e.code, e.message), e.code);
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Directly update email after reauth. Not recommended for many apps,
  /// prefer verifyBeforeUpdateEmail. Returns true when update succeeded.
  Future<bool> changeEmailDirectWithPassword({
    required String currentPassword,
    required String newEmail,
    bool signOutAfterUpdate = false,
  }) async {
    if (isLoading) return false;
    _setLoading(true);
    _setError(null);

    try {
      final user = _auth.currentUser;
      final oldEmail = user?.email;
      if (user == null || oldEmail == null) {
        _setError('User tidak terautentikasi');
        return false;
      }

      final cred = EmailAuthProvider.credential(email: oldEmail, password: currentPassword);
      await user.reauthenticateWithCredential(cred);

      // update immediately
      await user.updateEmail(newEmail);
      await user.reload();

      if (signOutAfterUpdate) {
        await _auth.signOut();
      }

      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_friendlyMessageFromCode(e.code, e.message), e.code);
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // -----------------------
  // Password change
  // -----------------------
  /// Change password: reauth + update password.
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    bool signOutAfterChange = false,
  }) async {
    if (isLoading) return false;
    _setLoading(true);
    _setError(null);

    try {
      final user = _auth.currentUser;
      final email = user?.email;
      if (user == null || email == null) {
        _setError('User tidak terautentikasi');
        return false;
      }

      final credential = EmailAuthProvider.credential(email: email, password: currentPassword);
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      await user.reload();

      if (signOutAfterChange) {
        await _auth.signOut();
      }

      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_friendlyMessageFromCode(e.code, e.message), e.code);
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // -----------------------
  // Password reset
  // -----------------------
  Future<bool> sendPasswordReset(String email) async {
    if (isLoading) return false;
    _setLoading(true);
    _setError(null);

    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_friendlyMessageFromCode(e.code, e.message), e.code);
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // -----------------------
  // Force sign out helper
  // -----------------------
  /// Forcefully sign out current user. Useful when you need to clear state after email change.
  Future<void> forceSignOut() async {
    try {
      await _auth.signOut();
    } catch (_) {
      // ignore errors here; view can show message if needed
    } finally {
      notifyListeners();
    }
  }

  // -----------------------
  // Useful getters
  // -----------------------
  User? get currentUser => _auth.currentUser;
  String? get currentUserEmail => _auth.currentUser?.email;
}
