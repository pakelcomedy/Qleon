/// Chat Room ViewModel
/// ------------------------------------------------------------
/// Manages single chat room state
/// - Stream messages
/// - Send text / encrypted messages
/// - Handle loading & error state
/// ------------------------------------------------------------

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/models/message_model.dart';
import '../../../data/repositories/message_repository.dart';

class ChatRoomViewModel extends ChangeNotifier {
  ChatRoomViewModel(this._messageRepository);

  final MessageRepository _messageRepository;

  /// -------------------------------
  /// STATE
  /// -------------------------------

  List<MessageModel> _messages = [];
  bool _isSending = false;
  String? _error;

  List<MessageModel> get messages => _messages;
  bool get isSending => _isSending;
  String? get error => _error;

  StreamSubscription<List<MessageModel>>? _messageSub;

  /// -------------------------------
  /// INIT
  /// -------------------------------

  void init(String chatId) {
    _messageSub = _messageRepository.streamMessages(chatId).listen(
      (messageList) {
        _messages = messageList;
        notifyListeners();
      },
      onError: (_) {
        _setError('Failed to load messages');
      },
    );
  }

  /// -------------------------------
  /// SEND MESSAGE
  /// -------------------------------

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String plainText,
  }) async {
    if (plainText.trim().isEmpty) return;

    _setSending(true);
    _clearError();

    try {
      await _messageRepository.sendMessage(
        chatId: chatId,
        senderId: senderId,
        text: plainText,
      );
    } catch (e) {
      _setError('Failed to send message');
    } finally {
      _setSending(false);
    }
  }

  /// -------------------------------
  /// HELPERS
  /// -------------------------------

  void _setSending(bool value) {
    _isSending = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    super.dispose();
  }
}
