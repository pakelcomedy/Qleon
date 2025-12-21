import 'package:flutter/material.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthViewModel extends ChangeNotifier {
  static FirebaseAuth get firebaseAuth => FirebaseAuth.instance;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;

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

  bool get isLoggedIn => _auth.currentUser != null;

  Future<User?> currentUser() async {
    try {
      await _auth.currentUser?.reload();
    } catch (_) {}
    return _auth.currentUser;
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
      debugPrint('[AuthVM] USER LOGOUT SUCCESS');
    } catch (e) {
      debugPrint('[AuthVM] LOGOUT ERROR: $e');
      errorMessage = 'Gagal logout. Coba lagi.';
      notifyListeners();
    }
  }

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

      final uid = credential.user?.uid;
      debugPrint('[AuthVM] createUser returned uid=$uid');

      if (uid != null) {
        await _firestore.collection("users").doc(uid).set({
          "uid": uid,
          "email": email,
          "name": autoName,
          "createdAt": FieldValue.serverTimestamp(),
        });
      }

      try {
        await _auth.currentUser?.reload();
        final u = _auth.currentUser;
        final token = u != null ? await u.getIdToken() : null;
        debugPrint('[AuthVM] after register current=${u?.uid} token=${token != null ? token.substring(0,20) + "..." : null}');
      } catch (e) {
        debugPrint('[AuthVM] reload/getIdToken after register failed: $e');
      }

      isRegisteredSuccess = true;
      isLoginSuccess = _auth.currentUser != null;
      debugPrint('[AuthVM] REGISTER SUCCESS uid=${_auth.currentUser?.uid}');
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthVM] REGISTER ERROR code=${e.code} message=${e.message}');
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
      debugPrint('[AuthVM] REGISTER ERROR: $e');
      errorMessage = 'Terjadi kesalahan. Coba lagi.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

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

      final uid = credential.user?.uid;
      debugPrint('[AuthVM] signIn returned uid=$uid');

      try {
        await _auth.currentUser?.reload();
        final u = _auth.currentUser;
        final token = u != null ? await u.getIdToken() : null;
        debugPrint('[AuthVM] after login current=${u?.uid} token=${token != null ? token.substring(0,20) + "..." : null}');
      } catch (e) {
        debugPrint('[AuthVM] reload/getIdToken after login failed: $e');
      }

      isLoginSuccess = _auth.currentUser != null;
      if (isLoginSuccess) {
        debugPrint('[AuthVM] LOGIN SUCCESS uid=${_auth.currentUser?.uid}');
      } else {
        debugPrint('[AuthVM] LOGIN finished but currentUser is null');
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthVM] LOGIN ERROR code=${e.code} message=${e.message}');
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
      debugPrint('[AuthVM] LOGIN ERROR: $e');
      errorMessage = 'Terjadi kesalahan. Coba lagi.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

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
      debugPrint('[AuthVM] PASSWORD RESET EMAIL SENT: $email');
      isPasswordResetSuccess = true;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthVM] PASSWORD RESET ERROR code=${e.code} message=${e.message}');
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
      debugPrint('[AuthVM] PASSWORD RESET ERROR: $e');
      errorMessage = 'Terjadi kesalahan. Coba lagi.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void resetRegistrationState() {
    isRegisteredSuccess = false;
    errorMessage = null;
    notifyListeners();
  }

  void resetLoginState() {
    isLoginSuccess = false;
    errorMessage = null;
    notifyListeners();
  }

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
