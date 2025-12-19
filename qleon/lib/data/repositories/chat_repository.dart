/// Chat Repository
/// ------------------------------------------------------------
/// Provides chat-level operations
/// - Create / fetch chats
/// - Stream chat list
/// - Abstracts Firestore implementation
/// ------------------------------------------------------------

import '../datasources/remote/chat_remote_ds.dart';
import '../models/chat_model.dart';

class ChatRepository {
  ChatRepository(this._remoteDataSource);

  final ChatRemoteDataSource _remoteDataSource;

  /// -------------------------------
  /// CREATE OR GET CHAT
  /// -------------------------------

  Future<ChatModel> createOrGetChat({
    required String currentUserId,
    required String peerUserId,
  }) async {
    try {
      return await _remoteDataSource.createOrGetChat(
        currentUserId: currentUserId,
        peerUserId: peerUserId,
      );
    } catch (e) {
      throw Exception('Failed to create or fetch chat');
    }
  }

  /// -------------------------------
  /// STREAM USER CHATS
  /// -------------------------------

  Stream<List<ChatModel>> streamUserChats(String userId) {
    try {
      return _remoteDataSource.streamUserChats(userId);
    } catch (e) {
      throw Exception('Failed to load chats');
    }
  }
}
