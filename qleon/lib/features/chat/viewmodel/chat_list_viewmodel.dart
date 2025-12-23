// chat_list_viewmodel.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Summary information for a chat shown in the chat list.
/// This maps to documents under: users/{uid}/chats/{chatId}
class ChatSummary {
  final String id;
  final String title; // display name or group title
  final bool isGroup;
  final String lastMessage;
  final Timestamp lastUpdated;
  final int unreadCount;
  final bool pinned;
  final bool archived;
  final String otherPublicId; // optional: public identity of the other user

  ChatSummary({
    required this.id,
    required this.title,
    required this.isGroup,
    required this.lastMessage,
    required this.lastUpdated,
    required this.unreadCount,
    required this.pinned,
    required this.archived,
    required this.otherPublicId,
  });

  factory ChatSummary.fromMap(String id, Map<String, dynamic> m) {
    Timestamp lastUpdated;
    final dynamic lu = m['lastUpdated'];
    if (lu is Timestamp) {
      lastUpdated = lu;
    } else if (lu is int) {
      lastUpdated = Timestamp.fromMillisecondsSinceEpoch(lu);
    } else if (lu is String) {
      // ISO string fallback
      try {
        final dt = DateTime.parse(lu);
        lastUpdated = Timestamp.fromDate(dt);
      } catch (_) {
        lastUpdated = Timestamp.now();
      }
    } else {
      lastUpdated = Timestamp.now();
    }

    return ChatSummary(
      id: id,
      title: (m['title'] as String?) ?? '',
      isGroup: (m['isGroup'] as bool?) ?? false,
      lastMessage: (m['lastMessage'] as String?) ?? '',
      lastUpdated: lastUpdated,
      unreadCount: (m['unreadCount'] as int?) ?? 0,
      pinned: (m['pinned'] as bool?) ?? false,
      archived: (m['archived'] as bool?) ?? false,
      otherPublicId: (m['otherPublicId'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'isGroup': isGroup,
        'lastMessage': lastMessage,
        'lastUpdated': lastUpdated,
        'unreadCount': unreadCount,
        'pinned': pinned,
        'archived': archived,
        'otherPublicId': otherPublicId,
      };

  ChatSummary copyWith({
    String? id,
    String? title,
    bool? isGroup,
    String? lastMessage,
    Timestamp? lastUpdated,
    int? unreadCount,
    bool? pinned,
    bool? archived,
    String? otherPublicId,
  }) {
    return ChatSummary(
      id: id ?? this.id,
      title: title ?? this.title,
      isGroup: isGroup ?? this.isGroup,
      lastMessage: lastMessage ?? this.lastMessage,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      unreadCount: unreadCount ?? this.unreadCount,
      pinned: pinned ?? this.pinned,
      archived: archived ?? this.archived,
      otherPublicId: otherPublicId ?? this.otherPublicId,
    );
  }
}

/// Production-ready ViewModel for ChatList
/// - listens to users/{uid}/chats (persisted per-user summaries)
/// - ALSO listens to conversations where current user is a member and attaches
///   *one message listener per conversation* to receive realtime last-message updates.
class ChatListViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub; // users/{uid}/chats
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _conversationsSub; // conversations where member

  final Map<String, ChatSummary> _chatMap = {};
  List<ChatSummary> _cachedChats = [];

  final Set<String> selectedIds = {};

  bool isLoading = true;
  bool isBusy = false;
  String? errorMessage;

  static const int defaultPageSize = 30;
  int pageSize = defaultPageSize;
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool hasMore = true;
  bool isPaginating = false;

  String _query = '';
  bool _includeArchived = false;
  final Map<String, String> _userDisplayCache = {};

  // helper caches & subscriptions per conversation to track last message realtime
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _msgSubs = {};
  final Map<String, Map<String, dynamic>?> _convCache = {}; // allow nullable convo data

  ChatListViewModel() {
    _init();
  }

  String? get currentUid => _auth.currentUser?.uid;

  List<ChatSummary> get chats {
    if (_query.isEmpty) return List.unmodifiable(_cachedChats);
    final q = _query.toLowerCase();
    return List.unmodifiable(_cachedChats.where((c) {
      return c.title.toLowerCase().contains(q) || c.lastMessage.toLowerCase().contains(q);
    }).toList());
  }

  bool get selectionMode => selectedIds.isNotEmpty;
  bool get hasSelection => selectedIds.isNotEmpty;

  Future<void> _init() async {
    final uid = currentUid;
    if (uid == null) {
      isLoading = false;
      errorMessage = 'User not logged in';
      notifyListeners();
      return;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _sub?.cancel();
      await _conversationsSub?.cancel();
      // cancel all message subs
      for (final s in _msgSubs.values) {
        await s.cancel();
      }
      _msgSubs.clear();
      _convCache.clear();
      _chatMap.clear();
      _cachedChats = [];
      _lastDoc = null;
      hasMore = true;

      // listen to per-user chat summaries (existing persisted view)
      Query<Map<String, dynamic>> baseQuery = _firestore
          .collection('users')
          .doc(uid)
          .collection('chats')
          .orderBy('pinned', descending: true)
          .orderBy('lastUpdated', descending: true)
          .limit(pageSize);

      if (!_includeArchived) {
        baseQuery = baseQuery.where('archived', isEqualTo: false);
      }

      _sub = baseQuery.snapshots().listen((snap) {
        _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
        hasMore = snap.docs.length >= pageSize;
        var changed = false;

        for (final change in snap.docChanges) {
          final id = change.doc.id;
          final data = change.doc.data();
          if (data == null) continue;
          if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
            final summary = ChatSummary.fromMap(id, data);
            final existing = _chatMap[id];
            if (existing == null || _isDifferent(existing, summary)) {
              _chatMap[id] = summary;
              changed = true;
            }
          } else if (change.type == DocumentChangeType.removed) {
            if (_chatMap.containsKey(id)) {
              _chatMap.remove(id);
              changed = true;
            }
          }
        }

        if (changed) {
          _rebuildSortedListAndNotify();
        } else {
          if (isLoading) notifyListeners();
        }
        isLoading = false;
        errorMessage = null;
      }, onError: (e) {
        isLoading = false;
        errorMessage = e.toString();
        notifyListeners();
      });

      // Listen to conversations that include current user (no orderBy to avoid index issues)
      _conversationsSub = _firestore.collection('conversations').where('members', arrayContains: uid).snapshots().listen((snap) {
        for (final change in snap.docChanges) {
          final doc = change.doc;
          final convId = doc.id;
          final convData = doc.data();
          // cache conv metadata (note: doc.data() may be null)
          _convCache[convId] = convData;
          if (change.type == DocumentChangeType.removed) {
            // cancel message listener + remove from map
            _cancelMessageListener(convId);
            if (_chatMap.containsKey(convId)) {
              _chatMap.remove(convId);
              _rebuildSortedListAndNotify();
            }
          } else {
            // On added/modified: ensure we have a message listener for this conversation,
            // and let message listener drive the lastMessage updates (realtime).
            _ensureMessageListener(convId, convData);
          }
        }
      }, onError: (e) {
        debugPrint('[ChatListVM] conversations listener error: $e');
      });
    } catch (e) {
      isLoading = false;
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  bool _isDifferent(ChatSummary a, ChatSummary b) {
    return a.title != b.title ||
        a.isGroup != b.isGroup ||
        a.lastMessage != b.lastMessage ||
        a.unreadCount != b.unreadCount ||
        a.pinned != b.pinned ||
        a.archived != b.archived ||
        a.otherPublicId != b.otherPublicId ||
        a.lastUpdated.millisecondsSinceEpoch != b.lastUpdated.millisecondsSinceEpoch;
  }

  void _rebuildSortedListAndNotify() {
    final list = _chatMap.values.toList();
    list.sort(_chatComparator);
    _cachedChats = list;
    notifyListeners();
  }

  int _chatComparator(ChatSummary a, ChatSummary b) {
    if (a.pinned && !b.pinned) return -1;
    if (!a.pinned && b.pinned) return 1;
    final aMillis = a.lastUpdated.millisecondsSinceEpoch;
    final bMillis = b.lastUpdated.millisecondsSinceEpoch;
    return bMillis.compareTo(aMillis);
  }

  Future<void> refresh() async {
    await _sub?.cancel();
    await _conversationsSub?.cancel();
    for (final s in _msgSubs.values) {
      await s.cancel();
    }
    _msgSubs.clear();
    _convCache.clear();
    _lastDoc = null;
    hasMore = true;
    isLoading = true;
    _chatMap.clear();
    _cachedChats = [];
    notifyListeners();
    await _init();
  }

  Future<void> loadMore() async {
    if (isPaginating || !hasMore) return;
    final uid = currentUid;
    if (uid == null) return;
    if (_lastDoc == null) return;

    isPaginating = true;
    notifyListeners();

    try {
      Query<Map<String, dynamic>> q = _firestore
          .collection('users')
          .doc(uid)
          .collection('chats')
          .orderBy('pinned', descending: true)
          .orderBy('lastUpdated', descending: true)
          .startAfterDocument(_lastDoc!)
          .limit(pageSize);

      if (!_includeArchived) q = q.where('archived', isEqualTo: false);

      final nextSnap = await q.get();
      for (final doc in nextSnap.docs) {
        final id = doc.id;
        final summary = ChatSummary.fromMap(id, doc.data());
        final existing = _chatMap[id];
        if (existing == null || _isDifferent(existing, summary)) {
          _chatMap[id] = summary;
        }
      }
      _lastDoc = nextSnap.docs.isNotEmpty ? nextSnap.docs.last : _lastDoc;
      hasMore = nextSnap.docs.length >= pageSize;
      _rebuildSortedListAndNotify();
      errorMessage = null;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isPaginating = false;
      notifyListeners();
    }
  }

  // Ensure there's a single listener for the last message of convId
  void _ensureMessageListener(String convId, Map<String, dynamic>? convData) {
    if (_msgSubs.containsKey(convId)) {
      // already listening
      return;
    }

    final msgsRef = _firestore.collection('conversations').doc(convId).collection('messages');
    final sub = msgsRef.orderBy('createdAt', descending: true).limit(1).snapshots().listen((snap) async {
      if (snap.docs.isEmpty) {
        // no messages yet -> still create summary from convData
        await _mergeAndPersistSummaryFromConv(convId, convData, null);
        return;
      }
      final mdoc = snap.docs.first;
      await _mergeAndPersistSummaryFromConv(convId, convData, mdoc);
    }, onError: (e) {
      debugPrint('[ChatListVM] message listener error for $convId: $e');
    });

    _msgSubs[convId] = sub;
  }

  Future<void> _cancelMessageListener(String convId) async {
    final s = _msgSubs.remove(convId);
    if (s != null) {
      await s.cancel();
    }
    _convCache.remove(convId);
  }

  Future<void> _mergeAndPersistSummaryFromConv(String convId, Map<String, dynamic>? convData, QueryDocumentSnapshot<Map<String, dynamic>>? mdoc) async {
    final uid = currentUid;
    if (uid == null) return;

    try {
      final members = (convData?['members'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      final isGroup = (convData?['isGroup'] as bool?) ?? false;

      String otherId = '';
      if (!isGroup) {
        otherId = members.firstWhere((m) => m != uid, orElse: () => '');
      }

      String lastMessageText = '';
      Timestamp lastMessageTs = convData?['lastUpdated'] as Timestamp? ?? Timestamp.now();
      if (mdoc != null) {
        final mdata = mdoc.data();
        lastMessageText = (mdata['text'] as String?) ?? '';
        final rawTs = mdata['createdAt'];
        if (rawTs is Timestamp) lastMessageTs = rawTs;
      }

      String displayName = otherId;
      if (otherId.isNotEmpty) {
        displayName = await _getUserDisplayName(otherId) ?? otherId;
      } else if (isGroup) {
        displayName = (convData?['title'] as String?) ?? 'Group';
      } else {
        displayName = convId;
      }

      // preserve per-user prefs if present
      final userChatRef = _firestore.collection('users').doc(uid).collection('chats').doc(convId);
      int unreadCount = 0;
      bool pinned = false;
      bool archived = false;
      String otherPublicId = otherId;
      String titleToWrite = displayName;

      try {
        final userChatSnap = await userChatRef.get();
        if (userChatSnap.exists) {
          final d = userChatSnap.data()!;
          unreadCount = (d['unreadCount'] as int?) ?? unreadCount;
          pinned = (d['pinned'] as bool?) ?? pinned;
          archived = (d['archived'] as bool?) ?? archived;
          otherPublicId = (d['otherPublicId'] as String?) ?? otherPublicId;
          titleToWrite = (d['title'] as String?) ?? titleToWrite;
        }
      } catch (e) {
        debugPrint('[ChatListVM] unable to read users chat doc for $convId: $e');
      }

      final summary = ChatSummary(
        id: convId,
        title: titleToWrite,
        isGroup: isGroup,
        lastMessage: lastMessageText,
        lastUpdated: lastMessageTs,
        unreadCount: unreadCount,
        pinned: pinned,
        archived: archived,
        otherPublicId: otherPublicId,
      );

      final existing = _chatMap[convId];
      if (existing == null || _isDifferent(existing, summary)) {
        _chatMap[convId] = summary;
        _rebuildSortedListAndNotify();
      }

      // persist summary for this user (merge)
      try {
        await userChatRef.set({
          'title': summary.title,
          'isGroup': summary.isGroup,
          'lastMessage': summary.lastMessage,
          'lastUpdated': summary.lastUpdated,
          'unreadCount': summary.unreadCount,
          'pinned': summary.pinned,
          'archived': summary.archived,
          'otherPublicId': summary.otherPublicId,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[ChatListVM] failed to persist users chat summary $convId: $e');
      }
    } catch (e) {
      debugPrint('[ChatListVM] merge error for $convId: $e');
    }
  }

  Future<String?> _getUserDisplayName(String uid) async {
    if (_userDisplayCache.containsKey(uid)) return _userDisplayCache[uid];
    try {
      final snap = await _firestore.collection('users').doc(uid).get();
      if (snap.exists) {
        final data = snap.data();
        final name = (data?['displayName'] as String?) ?? (data?['name'] as String?) ?? uid;
        _userDisplayCache[uid] = name;
        return name;
      }
      return null;
    } catch (e) {
      debugPrint('[ChatListVM] _getUserDisplayName error for $uid: $e');
      return null;
    }
  }

  // Selection helpers and rest kept same as before...
  void startSelection(String chatId) {
    selectedIds.add(chatId);
    notifyListeners();
  }

  void toggleSelection(String chatId) {
    if (selectedIds.contains(chatId)) {
      selectedIds.remove(chatId);
    } else {
      selectedIds.add(chatId);
    }
    notifyListeners();
  }

  void clearSelection() {
    selectedIds.clear();
    notifyListeners();
  }

  Future<void> togglePin(String chatId) async {
    final uid = currentUid;
    if (uid == null) throw Exception('Not logged in');

    final docRef = _firestore.collection('users').doc(uid).collection('chats').doc(chatId);

    isBusy = true;
    notifyListeners();

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) {
          tx.set(docRef, {
            'pinned': true,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          return;
        }
        final currentPinned = (snap.data()?['pinned'] as bool?) ?? false;
        tx.update(docRef, {
          'pinned': !currentPinned,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      });

      final idx = _cachedChats.indexWhere((c) => c.id == chatId);
      if (idx >= 0) {
        final old = _cachedChats[idx];
        final updated = old.copyWith(pinned: !old.pinned, lastUpdated: Timestamp.now());
        _chatMap[chatId] = updated;
        _rebuildSortedListAndNotify();
      }
      selectedIds.clear();
      errorMessage = null;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> archiveChats({List<String>? chatIds}) async {
    final uid = currentUid;
    if (uid == null) throw Exception('Not logged in');

    final ids = chatIds ?? selectedIds.toList();
    if (ids.isEmpty) return;

    isBusy = true;
    notifyListeners();

    final batch = _firestore.batch();
    try {
      for (final id in ids) {
        final docRef = _firestore.collection('users').doc(uid).collection('chats').doc(id);
        batch.update(docRef, {'archived': true, 'lastUpdated': FieldValue.serverTimestamp()});
      }
      await batch.commit();

      for (final id in ids) {
        final existing = _chatMap[id];
        if (existing != null) {
          final updated = existing.copyWith(archived: true, lastUpdated: Timestamp.now());
          _chatMap[id] = updated;
          if (!_includeArchived) _chatMap.remove(id);
        }
      }
      _rebuildSortedListAndNotify();
      selectedIds.removeAll(ids);
      errorMessage = null;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> deleteChats({List<String>? chatIds}) async {
    final uid = currentUid;
    if (uid == null) throw Exception('Not logged in');

    final ids = chatIds ?? selectedIds.toList();
    if (ids.isEmpty) return;

    isBusy = true;
    notifyListeners();

    final batch = _firestore.batch();
    try {
      for (final id in ids) {
        final docRef = _firestore.collection('users').doc(uid).collection('chats').doc(id);
        batch.delete(docRef);
      }
      await batch.commit();

      for (final id in ids) {
        _chatMap.remove(id);
      }
      _rebuildSortedListAndNotify();
      selectedIds.removeAll(ids);
      errorMessage = null;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String chatId) async {
    final uid = currentUid;
    if (uid == null) throw Exception('Not logged in');

    final docRef = _firestore.collection('users').doc(uid).collection('chats').doc(chatId);

    try {
      await docRef.update({'unreadCount': 0});
      final idx = _cachedChats.indexWhere((c) => c.id == chatId);
      if (idx >= 0) {
        final updated = _cachedChats[idx].copyWith(unreadCount: 0);
        _chatMap[chatId] = updated;
        _rebuildSortedListAndNotify();
      }
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  void setQuery(String q) {
    _query = q.trim();
    notifyListeners();
  }

  Future<void> setIncludeArchived(bool include) async {
    if (_includeArchived == include) {
      return;
    }
    _includeArchived = include;
    await refresh();
  }

  ChatSummary? findById(String id) => _chatMap[id];

  void mergeIncomingChatSummary(ChatSummary summary) {
    final existing = _chatMap[summary.id];
    if (existing == null || _isDifferent(existing, summary)) {
      _chatMap[summary.id] = summary;
      _rebuildSortedListAndNotify();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _conversationsSub?.cancel();
    for (final s in _msgSubs.values) {
      s.cancel();
    }
    _msgSubs.clear();
    super.dispose();
  }
}
