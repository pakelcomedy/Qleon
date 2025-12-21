// lib/features/settings/viewmodel/security_viewmodel.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// SecurityViewModel
/// - Single responsibility: semua operasi Firebase auth terkait security.
/// - View hanya observe isLoading / errorMessage / errorCode dan men-trigger UI (snackbars, dialogs).
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
      default:
        return fallback ?? code;
    }
  }

  /// Reauthenticate (reauth) helper — returns true on success.
  /// Use this if you want to ask user for password in a dialog and then call this separately.
  Future<bool> reauthenticateWithPassword(String currentPassword) async {
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

  /// Change email by first reauthenticating with [currentPassword],
  /// then calling verifyBeforeUpdateEmail(newEmail).
  /// This sends a verification link to the NEW email. The actual account
  /// email will be changed only after the user clicks that verification link.
  ///
  /// Returns true on success (verification email sent). On failure sets errorMessage and returns false.
  Future<bool> changeEmailWithPassword({
    required String currentPassword,
    required String newEmail,
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

      // 2) request verify-before-update (recommended flow):
      //    this sends a verification email to newEmail and will apply the change
      //    only after the user verifies that new address.
      await user.verifyBeforeUpdateEmail(newEmail);

      // success: verification email sent
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

  /// (Optional) Directly update email after reauth (if you want immediate update).
  /// Note: some Firebase projects / rules might require verification or disallow direct update.
  /// Prefer verifyBeforeUpdateEmail in most apps.
  Future<bool> changeEmailDirectWithPassword({
    required String currentPassword,
    required String newEmail,
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
  // Useful getters
  // -----------------------
  User? get currentUser => _auth.currentUser;
  String? get currentUserEmail => _auth.currentUser?.email;
}