/// Chat List ViewModel
/// ------------------------------------------------------------
/// Manages chat list state
/// - Stream user chats
/// - Handle loading & error state
/// ------------------------------------------------------------

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/models/chat_model.dart';
import '../../../data/repositories/chat_repository.dart';

class ChatListViewModel extends ChangeNotifier {
  ChatListViewModel(this._chatRepository);

  final ChatRepository _chatRepository;

  /// -------------------------------
  /// STATE
  /// -------------------------------

  List<ChatModel> _chats = [];
  bool _isLoading = false;
  String? _error;

  List<ChatModel> get chats => _chats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  StreamSubscription<List<ChatModel>>? _chatSub;

  /// -------------------------------
  /// INIT
  /// -------------------------------

  void init(String userId) {
    _setLoading(true);
    _chatSub = _chatRepository.streamUserChats(userId).listen(
      (chatList) {
        _chats = chatList;
        _setLoading(false);
      },
      onError: (_) {
        _setError('Failed to load chats');
        _setLoading(false);
      },
    );
  }

  /// -------------------------------
  /// REFRESH
  /// -------------------------------

  Future<void> refresh(String userId) async {
    _chatSub?.cancel();
    init(userId);
  }

  /// -------------------------------
  /// HELPERS
  /// -------------------------------

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    super.dispose();
  }
}
