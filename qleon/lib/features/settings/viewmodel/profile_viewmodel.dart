// profile_viewmodel.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  String? uid;
  String? name; // public id (name field in users/{uid})
  String? temp;
  String get qrData => _generateQrData(); // name + temp + uid, no spaces

  bool isLoading = false;
  bool isUpdatingTemp = false;
  String? errorMessage;

  ProfileViewModel() {
    _init();
  }

  Future<void> _init() async {
    isLoading = true;
    notifyListeners();

    final user = _auth.currentUser;
    if (user == null) {
      // user not logged in yet
      isLoading = false;
      errorMessage = 'User not logged in';
      notifyListeners();
      return;
    }

    uid = user.uid;

    // start listening to users/{uid} doc
    final userRef = _firestore.collection('users').doc(uid);
    try {
      _sub = userRef.snapshots().listen((snap) {
        if (snap.exists) {
          final data = snap.data();

          // update fields safely
          name = data?['name'] as String?;
          temp = data?['temp'] as String?;
          errorMessage = null;
        } else {
          // doc missing
          name = null;
          temp = null;
        }
        isLoading = false;
        notifyListeners(); // auto refresh UI (QR will change because qrData getter uses name/temp/uid)
      }, onError: (e) {
        debugPrint('[ProfileVM] snapshot error: $e');
        errorMessage = e.toString();
        isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('[ProfileVM] init error: $e');
      errorMessage = e.toString();
      isLoading = false;
      notifyListeners();
    }
  }

  // generate qrData as name + temp + uid, no spaces; returns empty string if missing
  String _generateQrData() {
    final n = name ?? '';
    final t = temp ?? '';
    final u = uid ?? '';
    if (n.isEmpty || t.isEmpty || u.isEmpty) return '';
    return '$n$t$u';
  }

  // generate a new temp value (alphanumeric)
  String _generateTempCandidate({int length = 6}) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  // Change QR code by updating 'temp' field in users/{uid}
  Future<void> changeTemp({int tempLength = 6}) async {
    if (uid == null) {
      errorMessage = 'User not initialized';
      notifyListeners();
      return;
    }

    isUpdatingTemp = true;
    notifyListeners();

    final newTemp = _generateTempCandidate(length: tempLength);

    try {
      final userRef = _firestore.collection('users').doc(uid);
      await userRef.update({
        'temp': newTemp,
      });

      // The snapshot listener will pick the change and update local temp -> qrData.
      // But as an optimistic UX, set local temp now so UI reflects immediately:
      temp = newTemp;
      errorMessage = null;
    } on FirebaseException catch (e) {
      debugPrint('[ProfileVM] Failed to update temp: ${e.code} ${e.message}');
      errorMessage = 'Gagal mengubah QR code: ${e.message ?? e.code}';
    } catch (e) {
      debugPrint('[ProfileVM] changeTemp error: $e');
      errorMessage = 'Terjadi kesalahan saat mengubah QR code.';
    } finally {
      isUpdatingTemp = false;
      notifyListeners();
    }
  }

  // Force refresh (fetch once)
  Future<void> reloadProfile() async {
    if (uid == null) return;
    isLoading = true;
    notifyListeners();
    try {
      final snap = await _firestore.collection('users').doc(uid).get();
      if (snap.exists) {
        final data = snap.data();
        name = data?['name'] as String?;
        temp = data?['temp'] as String?;
      }
      errorMessage = null;
    } catch (e) {
      debugPrint('[ProfileVM] reload error: $e');
      errorMessage = 'Gagal memuat profil';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
