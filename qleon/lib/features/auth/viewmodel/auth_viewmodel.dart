import 'package:flutter/material.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthViewModel extends ChangeNotifier {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String _generateAutoName() {
    const chars = '0123456789ABCDEF';
    final rand = Random.secure();
    return '0x' +
        List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> register() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      debugPrint("Email / password kosong");
      return;
    }

    isLoading = true;
    notifyListeners();

    final autoName = _generateAutoName();

    try {
      // 🔥 Firebase Register
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      // Optional — simpan profile user ke Firestore
      await _firestore.collection("users").doc(uid).set({
        "uid": uid,
        "email": email,
        "name": autoName,
        "createdAt": FieldValue.serverTimestamp(),
      });

      debugPrint('REGISTER SUCCESS: $autoName');
    } on FirebaseAuthException catch (e) {
      debugPrint('REGISTER ERROR: ${e.code}');
    } catch (e) {
      debugPrint('REGISTER ERROR: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
