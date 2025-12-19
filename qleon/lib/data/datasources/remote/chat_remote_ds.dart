/// Chat Remote Data Source
/// ------------------------------------------------------------
/// Handles chat-related Firestore operations
/// - Fetch chat list
/// - Create private & group chats
/// - Stream chat metadata
/// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firebase_constants.dart';
import '../../models/chat_model.dart';

class ChatRemoteDataSource {
  ChatRemoteDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _chatCollection =>
      _firestore.collection(FirebaseCollections.chats);

  /// -------------------------------
  /// FETCH CHAT LIST
  /// -------------------------------

  Stream<List<ChatModel>> streamUserChats(String userId) {
    return _chatCollection
        .where('members', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatModel.fromFirestore(doc))
            .toList());
  }

  /// -------------------------------
  /// CREATE PRIVATE CHAT
  /// -------------------------------

  Future<String> createPrivateChat({
    required String currentUserId,
    required String peerUserId,
  }) async {
    final doc = await _chatCollection.add({
      'type': 'private',
      'members': [currentUserId, peerUserId],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  /// -------------------------------
  /// CREATE GROUP CHAT
  /// -------------------------------

  Future<String> createGroupChat({
    required String name,
    required List<String> memberIds,
  }) async {
    final doc = await _chatCollection.add({
      'type': 'group',
      'name': name,
      'members': memberIds,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  /// -------------------------------
  /// UPDATE LAST ACTIVITY
  /// -------------------------------

  Future<void> updateChatTimestamp(String chatId) async {
    await _chatCollection.doc(chatId).update({
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}