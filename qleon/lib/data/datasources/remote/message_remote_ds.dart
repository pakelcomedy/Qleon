/// Message Remote Data Source
/// ------------------------------------------------------------
/// Handles encrypted message transmission via Firestore
/// - Send encrypted payload
/// - Stream encrypted messages
/// - No decryption here (CryptoService only)
/// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firebase_constants.dart';
import '../../../core/encryption/crypto_service.dart';
import '../../models/message_model.dart';

class MessageRemoteDataSource {
  MessageRemoteDataSource(
    this._firestore,
    this._cryptoService,
  );

  final FirebaseFirestore _firestore;
  final CryptoService _cryptoService;

  CollectionReference<Map<String, dynamic>> _messageCollection(String chatId) =>
      _firestore
          .collection(FirebaseCollections.chats)
          .doc(chatId)
          .collection(FirebaseCollections.messages);

  /// -------------------------------
  /// SEND MESSAGE
  /// -------------------------------

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String plainText,
    required String recipientPublicKey,
  }) async {
    final encryptedPayload = await _cryptoService.encryptMessage(
      chatId: chatId,
      plainText: plainText,
      recipientPublicKey: recipientPublicKey,
    );

    await _messageCollection(chatId).add({
      'senderId': senderId,
      'payload': encryptedPayload,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update chat activity timestamp
    await _firestore
        .collection(FirebaseCollections.chats)
        .doc(chatId)
        .update({'updatedAt': FieldValue.serverTimestamp()});
  }

  /// -------------------------------
  /// STREAM MESSAGES
  /// -------------------------------

  Stream<List<MessageModel>> streamMessages(String chatId) {
    return _messageCollection(chatId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final messages = <MessageModel>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final decryptedText = await _cryptoService.decryptMessage(
          chatId: chatId,
          payload: Map<String, dynamic>.from(data['payload']),
        );

        messages.add(
          MessageModel(
            id: doc.id,
            senderId: data['senderId'],
            text: decryptedText,
            createdAt: data['createdAt'],
          ),
        );
      }

      return messages;
    });
  }
}