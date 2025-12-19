/// Message Repository
/// ------------------------------------------------------------
/// Acts as abstraction layer between ViewModel & DataSource
/// - Handles errors
/// - Exposes clean API
/// - No UI / Firestore logic
/// ------------------------------------------------------------

import '../datasources/remote/message_remote_ds.dart';
import '../models/message_model.dart';

class MessageRepository {
  MessageRepository(this._remoteDataSource);

  final MessageRemoteDataSource _remoteDataSource;

  /// -------------------------------
  /// SEND MESSAGE
  /// -------------------------------

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String message,
    required String recipientPublicKey,
  }) async {
    try {
      await _remoteDataSource.sendMessage(
        chatId: chatId,
        senderId: senderId,
        plainText: message,
        recipientPublicKey: recipientPublicKey,
      );
    } catch (e) {
      throw Exception('Failed to send message');
    }
  }

  /// -------------------------------
  /// STREAM MESSAGES
  /// -------------------------------

  Stream<List<MessageModel>> streamMessages(String chatId) {
    try {
      return _remoteDataSource.streamMessages(chatId);
    } catch (e) {
      throw Exception('Failed to load messages');
    }
  }
}
