// auth_viewmodel.dart
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

  // Generate candidate name like 0xA9F3C21B
  String _generateAutoNameCandidate() {
    const chars = '0123456789ABCDEF';
    final rand = Random.secure();
    return '0x' +
        List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  // temp generator (alphanumeric, length 6)
  String _generateTempValue({int length = 6}) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
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

  // Helper: check if a name exists in users collection
  Future<bool> _nameExists(String name) async {
    final snap = await _firestore
        .collection('users')
        .where('name', isEqualTo: name)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  // Helper: cleanup auth user (delete) and optionally user doc
  Future<void> _cleanupAuthAndDoc({String? uid}) async {
    try {
      // delete users doc if exist
      if (uid != null) {
        try {
          await _firestore.collection('users').doc(uid).delete();
          debugPrint('[AuthVM] Deleted users/$uid doc during cleanup');
        } catch (e) {
          debugPrint('[AuthVM] Failed to delete users doc during cleanup: $e');
        }
      }

      // delete the currently signed-in Auth user (if any)
      try {
        final u = _auth.currentUser;
        if (u != null) {
          await u.delete();
          debugPrint('[AuthVM] Deleted Auth user during cleanup');
        }
      } catch (e) {
        debugPrint('[AuthVM] Failed to delete Auth user during cleanup: $e');
      }
    } catch (e) {
      debugPrint('[AuthVM] cleanup error: $e');
    }
  }

  // Main register: create auth user, then write users/{uid} with unique name + temp
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

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user?.uid;
      debugPrint('[AuthVM] createUser returned uid=$uid');

      if (uid == null) {
        throw Exception('UID kosong setelah createUser');
      }

      // We'll attempt to reserve a unique name by:
      // 1) generate candidate
      // 2) query for existing docs with that name
      // 3) if none, write users/{uid}
      // 4) after write, re-check how many docs have that name:
      //    - if 1 => success
      //    - if >1 => collision (concurrent writer), delete our doc and retry
      //
      // NOTE: This is not strictly atomic (no separate unique-index collection),
      // but with retries and collision-check-after-write we minimize duplicates.
      final int maxAttempts = 8;
      bool stored = false;
      String? finalName;
      String? finalTemp;

      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        final candidate = _generateAutoNameCandidate();
        final temp = _generateTempValue();

        // quick existence check
        final exists = await _nameExists(candidate);
        if (exists) {
          debugPrint('[AuthVM] name collision (pre-check) for $candidate — retrying');
          continue;
        }

        // attempt to write user doc
        final userRef = _firestore.collection('users').doc(uid);

        try {
          await userRef.set({
            'uid': uid,
            'email': email,
            'name': candidate,
            'temp': temp,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // after write, verify there is exactly one doc with that name
          final recheck = await _firestore
              .collection('users')
              .where('name', isEqualTo: candidate)
              .get();

          if (recheck.docs.length == 1) {
            // success
            stored = true;
            finalName = candidate;
            finalTemp = temp;
            debugPrint('[AuthVM] Stored users/$uid with unique name $candidate');
            break;
          } else {
            // collision happened concurrently; remove our document and retry
            debugPrint('[AuthVM] Collision detected after write for $candidate (count=${recheck.docs.length}). Removing our doc and retrying.');
            try {
              await userRef.delete();
              debugPrint('[AuthVM] Deleted users/$uid doc due to collision');
            } catch (delErr) {
              debugPrint('[AuthVM] Failed to delete users doc after collision: $delErr');
            }
            // continue loop to try another candidate
            continue;
          }
        } catch (writeErr) {
          // writing failed (permission/network). Try cleanup and rethrow to outer handler
          debugPrint('[AuthVM] Failed to write users/$uid: $writeErr');
          // attempt to delete the auth user to avoid orphaned auth account
          try {
            await credential.user?.delete();
            debugPrint('[AuthVM] Deleted auth user due to write failure');
          } catch (delErr) {
            debugPrint('[AuthVM] Failed to delete auth user after write failure: $delErr');
          }
          rethrow;
        }
      } // end attempts loop

      if (!stored) {
        // Could not secure a unique name after retries -> cleanup and error
        debugPrint('[AuthVM] Unable to acquire unique name after $maxAttempts attempts. Cleaning up auth user.');
        await _cleanupAuthAndDoc(uid: uid);
        errorMessage = 'Gagal membuat akun (nama tidak tersedia). Coba lagi.';
        isRegisteredSuccess = false;
        isLoginSuccess = false;
        isLoading = false;
        notifyListeners();
        return;
      }

      // optional: reload auth user and debug token
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
      debugPrint('[AuthVM] REGISTER SUCCESS uid=${_auth.currentUser?.uid} name=$finalName temp=$finalTemp');
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
      // If an auth user exists and we hit a crash, attempt cleanup
      try {
        final u = _auth.currentUser;
        if (u != null) {
          final uid = u.uid;
          await _cleanupAuthAndDoc(uid: uid);
        }
      } catch (cleanupErr) {
        debugPrint('[AuthVM] cleanup after exception failed: $cleanupErr');
      }

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
