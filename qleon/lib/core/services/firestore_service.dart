/// Firestore Service
/// ------------------------------------------------------------
/// Centralized Firestore access layer for Qleon
/// - Typed collection/document helpers
/// - Common query & batch utilities
/// - NO business logic here
/// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/firebase_constants.dart';

class FirestoreService {
  FirestoreService(this._firestore);

  final FirebaseFirestore _firestore;

  /// -------------------------------
  /// CORE INSTANCE
  /// -------------------------------

  FirebaseFirestore get instance => _firestore;

  /// -------------------------------
  /// COLLECTION HELPERS
  /// -------------------------------

  CollectionReference<Map<String, dynamic>> users() {
    return _firestore.collection(FirebaseCollections.users);
  }

  CollectionReference<Map<String, dynamic>> chats() {
    return _firestore.collection(FirebaseCollections.chats);
  }

  CollectionReference<Map<String, dynamic>> messages(String chatId) {
    return chats().doc(chatId).collection(FirebaseCollections.messages);
  }

  /// -------------------------------
  /// DOCUMENT HELPERS
  /// -------------------------------

  DocumentReference<Map<String, dynamic>> userDoc(String userId) {
    return users().doc(userId);
  }

  DocumentReference<Map<String, dynamic>> chatDoc(String chatId) {
    return chats().doc(chatId);
  }

  /// -------------------------------
  /// UTILITIES
  /// -------------------------------

  Future<void> setWithMerge({
    required DocumentReference<Map<String, dynamic>> ref,
    required Map<String, dynamic> data,
  }) async {
    await ref.set(data, SetOptions(merge: true));
  }

  WriteBatch batch() => _firestore.batch();

  FieldValue serverTimestamp() => FieldValue.serverTimestamp();
}