import 'package:flutter/material.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthViewModel extends ChangeNotifier {
  // Expose a static FirebaseAuth instance so other parts (AuthGate) can reuse it
  static FirebaseAuth get firebaseAuth => FirebaseAuth.instance;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;

  // registration / login / reset flags
  bool isRegisteredSuccess = false;
  bool isLoginSuccess = false;
  bool isPasswordResetSuccess = false;
  String? errorMessage;

  final _auth = firebaseAuth;
  final _firestore = FirebaseFirestore.instance;

  String _generateAutoName() {
    const chars = '0123456789ABCDEF';
    final rand = Random.secure();
    return '0x' +
        List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Convenience getter to check immediately if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  /// Logout: sign out from Firebase
  Future<void> logout() async {
    try {
      await _auth.signOut();
      debugPrint('USER LOGOUT SUCCESS');
    } catch (e) {
      debugPrint('LOGOUT ERROR: $e');
      errorMessage = 'Gagal logout. Coba lagi.';
      notifyListeners();
    }
  }

  /// Register user. VM does NOT navigate or show UI.
  Future<void> register() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      errorMessage = "Email atau password tidak boleh kosong";
      notifyListeners();
      return;
    }

    isLoading = true;
    errorMessage = null;
    isRegisteredSuccess = false;
    notifyListeners();

    final autoName = _generateAutoName();

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      await _firestore.collection("users").doc(uid).set({
        "uid": uid,
        "email": email,
        "name": autoName,
        "createdAt": FieldValue.serverTimestamp(),
      });

      debugPrint('REGISTER SUCCESS: $autoName');
      isRegisteredSuccess = true;
    } on FirebaseAuthException catch (e) {
      debugPrint('REGISTER ERROR: ${e.code}');
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'Password terlalu lemah';
          break;
        case 'email-already-in-use':
          errorMessage = 'Email sudah terdaftar';
          break;
        case 'invalid-email':
          errorMessage = 'Format email tidak valid';
          break;
        default:
          errorMessage = 'Gagal mendaftar: ${e.message ?? e.code}';
      }
    } catch (e) {
      debugPrint('REGISTER ERROR: $e');
      errorMessage = 'Terjadi kesalahan. Coba lagi.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Login user. VM only updates state; View handles navigation/snackbars.
  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      errorMessage = "Email atau password tidak boleh kosong";
      notifyListeners();
      return;
    }

    isLoading = true;
    errorMessage = null;
    isLoginSuccess = false;
    notifyListeners();

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;
      debugPrint('LOGIN SUCCESS: $uid');
      isLoginSuccess = true;
    } on FirebaseAuthException catch (e) {
      debugPrint('LOGIN ERROR: ${e.code}');
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Pengguna tidak ditemukan';
          break;
        case 'wrong-password':
          errorMessage = 'Password salah';
          break;
        case 'invalid-email':
          errorMessage = 'Format email tidak valid';
          break;
        case 'user-disabled':
          errorMessage = 'Akun dinonaktifkan';
          break;
        default:
          errorMessage = 'Gagal login: ${e.message ?? e.code}';
      }
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');
      errorMessage = 'Terjadi kesalahan. Coba lagi.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Forgot password: kirim email reset
  Future<void> sendPasswordResetEmail() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      errorMessage = "Masukkan email untuk menerima link reset";
      notifyListeners();
      return;
    }

    isLoading = true;
    errorMessage = null;
    isPasswordResetSuccess = false;
    notifyListeners();

    try {
      await _auth.sendPasswordResetEmail(email: email);
      debugPrint('PASSWORD RESET EMAIL SENT: $email');
      isPasswordResetSuccess = true;
    } on FirebaseAuthException catch (e) {
      debugPrint('PASSWORD RESET ERROR: ${e.code}');
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Pengguna tidak ditemukan';
          break;
        case 'invalid-email':
          errorMessage = 'Format email tidak valid';
          break;
        default:
          errorMessage = 'Gagal mengirim link: ${e.message ?? e.code}';
      }
    } catch (e) {
      debugPrint('PASSWORD RESET ERROR: $e');
      errorMessage = 'Terjadi kesalahan. Coba lagi.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Reset registration flags after view handled navigation / snackbar.
  void resetRegistrationState() {
    isRegisteredSuccess = false;
    errorMessage = null;
    notifyListeners();
  }

  /// Reset login flags after view handled navigation / snackbar.
  void resetLoginState() {
    isLoginSuccess = false;
    errorMessage = null;
    notifyListeners();
  }

  /// Reset password-reset flags after view handled navigation / snackbar.
  void resetPasswordState() {
    isPasswordResetSuccess = false;
    errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
