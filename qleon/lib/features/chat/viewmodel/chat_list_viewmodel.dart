// lib/features/chat/viewmodel/chat_list_viewmodel.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Summary information for a chat shown in the chat list.
/// This maps to documents under: users/{uid}/chats/{chatId}
class ChatSummary {
  final String id;
  final String title;
  final bool isGroup;
  final String lastMessage;
  final Timestamp lastUpdated;
  final int unreadCount;
  final bool pinned;
  final bool archived;
  final String otherPublicId; // could be uid or public id (0x...)

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

/// Production-ready ViewModel for ChatList with robust dedupe logic.
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

  // message-listener subscriptions per conversation id
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _msgSubs = {};
  final Map<String, Map<String, dynamic>?> _convCache = {}; // conv metadata cache

  // For dedupe: cache publicId -> uid resolution
  final Map<String, String> _publicToUidCache = {};

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

  // -----------------------
  // Initialization / Listeners
  // -----------------------
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
      for (final s in _msgSubs.values) {
        await s.cancel();
      }
      _msgSubs.clear();
      _convCache.clear();
      _chatMap.clear();
      _cachedChats = [];
      _lastDoc = null;
      hasMore = true;

      // per-user chat summaries listener (this is primary persisted source)
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

      // NOTE: listener callback marked async so we can await dedupe helpers
      _sub = baseQuery.snapshots().listen((snap) async {
        _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
        hasMore = snap.docs.length >= pageSize;
        var changed = false;

        for (final change in snap.docChanges) {
          final id = change.doc.id;
          final data = change.doc.data();
          if (data == null) continue;

          if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
            final summary = ChatSummary.fromMap(id, data);

            // STRONG DEDUPE: if this summary represents a 1:1 with otherPublicId
            // and that other already exists under different id, merge instead of adding new.
            if (!summary.isGroup && summary.otherPublicId.isNotEmpty) {
              final existingByOther = await _findExistingByOtherIdAsync(summary.otherPublicId);
              if (existingByOther != null && existingByOther.id != id) {
                // Merge: prefer newest lastUpdated
                final chosenLastUpdated = summary.lastUpdated.millisecondsSinceEpoch > existingByOther.lastUpdated.millisecondsSinceEpoch
                    ? summary.lastUpdated
                    : existingByOther.lastUpdated;
                final merged = existingByOther.copyWith(
                  lastMessage: summary.lastMessage.isNotEmpty ? summary.lastMessage : existingByOther.lastMessage,
                  lastUpdated: chosenLastUpdated,
                );
                _chatMap[existingByOther.id] = merged;
                // remove duplicate per-user doc (best-effort)
                try {
                  await _firestore.collection('users').doc(uid).collection('chats').doc(id).delete();
                } catch (_) {}
                changed = true;
                continue; // skip adding this doc as separate entry
              }
            }

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

      // Also listen to conversations collection for realtime last-message (to cover cases where
      // server-side fan-out to users/{uid}/chats isn't in place)
      _conversationsSub = _firestore.collection('conversations').where('members', arrayContains: uid).snapshots().listen((snap) {
        for (final change in snap.docChanges) {
          final doc = change.doc;
          final convId = doc.id;
          final convData = doc.data();
          _convCache[convId] = convData;
          if (change.type == DocumentChangeType.removed) {
            _cancelMessageListener(convId);
            if (_chatMap.containsKey(convId)) {
              _chatMap.remove(convId);
              _rebuildSortedListAndNotify();
            }
          } else {
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

  // -----------------------
  // Conversation -> last message listener helpers
  // -----------------------
  void _ensureMessageListener(String convId, Map<String, dynamic>? convData) {
    if (_msgSubs.containsKey(convId)) return;

    final msgsRef = _firestore.collection('conversations').doc(convId).collection('messages');
    final sub = msgsRef.orderBy('createdAt', descending: true).limit(1).snapshots().listen((snap) async {
      if (snap.docs.isEmpty) {
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

  /// MAIN MERGE / DEDUP LOGIC
  Future<void> _mergeAndPersistSummaryFromConv(
      String convId, Map<String, dynamic>? convData, QueryDocumentSnapshot<Map<String, dynamic>>? mdoc) async {
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

      // IMPORTANT: If the summary is archived and the view does NOT include archived,
      // do not add it to the local map / UI. Still persist to users/{uid}/chats to keep server consistent.
      if (summary.archived && !_includeArchived) {
        // persist merged summary for this user (merge) but do not add to _chatMap
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
          debugPrint('[ChatListVM] failed to persist archived users chat $convId: $e');
        }

        // remove from local map if present (strict prevention)
        if (_chatMap.containsKey(convId)) {
          _chatMap.remove(convId);
          _rebuildSortedListAndNotify();
        }

        return;
      }

      // STRONG DEDUPE: if another existing chat represents the same other user, merge into it
      if (!isGroup && otherId.isNotEmpty) {
        final existingByOther = await _findExistingByOtherIdAsync(otherId);
        if (existingByOther != null && existingByOther.id != convId) {
          final existingId = existingByOther.id;
          final existing = existingByOther;
          final chosenLastUpdated = lastMessageTs.millisecondsSinceEpoch > existing.lastUpdated.millisecondsSinceEpoch
              ? lastMessageTs
              : existing.lastUpdated;
          final merged = existing.copyWith(
            lastMessage: lastMessageText.isNotEmpty ? lastMessageText : existing.lastMessage,
            lastUpdated: chosenLastUpdated,
          );

          _chatMap[existingId] = merged;
          _rebuildSortedListAndNotify();

          // persist merged to users/{uid}/chats/{existingId}
          try {
            await _firestore.collection('users').doc(uid).collection('chats').doc(existingId).set({
              'title': merged.title,
              'isGroup': merged.isGroup,
              'lastMessage': merged.lastMessage,
              'lastUpdated': merged.lastUpdated,
              'unreadCount': merged.unreadCount,
              'pinned': merged.pinned,
              'archived': merged.archived,
              'otherPublicId': merged.otherPublicId,
            }, SetOptions(merge: true));
          } catch (e) {
            debugPrint('[ChatListVM] failed to persist merged users chat $existingId: $e');
          }

          // Best-effort delete duplicate per-user doc
          try {
            await _firestore.collection('users').doc(uid).collection('chats').doc(convId).delete();
          } catch (_) {}

          return; // merged; stop
        }
      }

      // Normal path: add/replace convId entry
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

  // -----------------------
  // Dedup helpers: try to find existing ChatSummary for same otherId
  // -----------------------
  Future<ChatSummary?> _findExistingByOtherIdAsync(String otherId) async {
    // quick pass: exact match on otherPublicId in cache
    for (final s in _chatMap.values) {
      if (!s.isGroup && s.otherPublicId.isNotEmpty && s.otherPublicId == otherId) return s;
    }

    // if otherId looks like publicId (0x...), try to resolve to uid and compare
    if (otherId.startsWith('0x')) {
      final resolvedUid = await _resolvePublicToUidCached(otherId);
      if (resolvedUid != null) {
        for (final s in _chatMap.values) {
          if (!s.isGroup) {
            // compare s.otherPublicId to resolvedUid or to publicId
            if (s.otherPublicId == resolvedUid || s.otherPublicId == otherId) return s;
          }
        }
      }
    } else {
      // otherId is likely a uid; sometimes stored otherPublicId may be a publicId -> resolve and compare
      for (final s in _chatMap.values) {
        if (!s.isGroup) {
          if (s.otherPublicId == otherId) return s;
          if (s.otherPublicId.startsWith('0x')) {
            final resolved = await _resolvePublicToUidCached(s.otherPublicId);
            if (resolved != null && resolved == otherId) return s;
          }
        }
      }
    }

    return null;
  }

  Future<String?> _resolvePublicToUidCached(String publicId) async {
    if (_publicToUidCache.containsKey(publicId)) return _publicToUidCache[publicId];
    try {
      final q = await _firestore.collection('users').where('name', isEqualTo: publicId).limit(1).get();
      if (q.docs.isNotEmpty) {
        final d = q.docs.first.data();
        final uid = (d['uid'] as String?) ?? q.docs.first.id;
        _publicToUidCache[publicId] = uid;
        return uid;
      }
      // cache negative result to avoid repeated queries
      _publicToUidCache[publicId] = '';
      return null;
    } catch (e) {
      debugPrint('[ChatListVM] _resolvePublicToUidCached error: $e');
      return null;
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

  // -----------------------
  // Selection / CRUD helpers (unchanged, except local map maintenance)
  // -----------------------
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
    if (_includeArchived == include) return;
    _includeArchived = include;
    await refresh();
  }

  ChatSummary? findById(String id) => _chatMap[id];

  void mergeIncomingChatSummary(ChatSummary summary) {
    // Enforce strict prevention: if incoming summary archived and we don't include archived, skip it
    if (summary.archived && !_includeArchived) {
      if (_chatMap.containsKey(summary.id)) {
        _chatMap.remove(summary.id);
        _rebuildSortedListAndNotify();
      }
      return;
    }

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
