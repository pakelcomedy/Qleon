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
/// - ALSO listens to conversations where current user is a member and updates list
///   when new messages arrive (useful when server-side fan-out is not present)
class ChatListViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// internal subscription to user's chat summaries
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  /// subscription to conversations that include current user
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _conversationsSub;

  /// master map of chats (prevents duplicates and allows O(1) updates)
  final Map<String, ChatSummary> _chatMap = {};

  /// derived ordered list (cached)
  List<ChatSummary> _chats = [];

  /// selection set for UI (by id)
  final Set<String> selectedIds = {};

  bool isLoading = true;
  bool isBusy = false; // general in-flight flag for operations
  String? errorMessage;

  // pagination
  static const int defaultPageSize = 30;
  int pageSize = defaultPageSize;
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool hasMore = true;
  bool isPaginating = false;

  // search query (client-side)
  String _query = '';

  // whether to include archived chats in the list
  bool _includeArchived = false;

  // small cache for user display names to reduce reads
  final Map<String, String> _userDisplayCache = {};

  ChatListViewModel() {
    _init();
  }

  String? get currentUid => _auth.currentUser?.uid;

  /// Public accessor: filtered & ordered list of chats (unmodifiable)
  List<ChatSummary> get chats {
    if (_query.isEmpty) return List.unmodifiable(_chats);
    final q = _query.toLowerCase();
    return List.unmodifiable(_chats.where((c) {
      return c.title.toLowerCase().contains(q) || c.lastMessage.toLowerCase().contains(q);
    }).toList());
  }

  bool get selectionMode => selectedIds.isNotEmpty;
  bool get hasSelection => selectedIds.isNotEmpty;

  // ============================================================
  // Initialization: subscribe to snapshot for first page (realtime)
  // Also subscribe to conversations for incoming messages so UI updates.
  // ============================================================
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
      // cancel existing
      await _sub?.cancel();
      await _conversationsSub?.cancel();
      _chatMap.clear();
      _chats = [];
      _lastDoc = null;
      hasMore = true;

      // build base query for per-user chat summaries
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

      // Listen to per-user chat summaries (existing behavior)
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
          _rebuildSortedList();
          notifyListeners();
        } else {
          // still notify loading state if this was first arrival
          if (isLoading) notifyListeners();
        }

        isLoading = false;
        errorMessage = null;
      }, onError: (e) {
        isLoading = false;
        errorMessage = e.toString();
        notifyListeners();
      });

      // ALSO: listen to conversations where current user is a member.
      // This ensures UI updates when someone sends a message even if users/{uid}/chats is not updated.
      _conversationsSub = _firestore
          .collection('conversations')
          .where('members', arrayContains: uid)
          .orderBy('lastUpdated', descending: true)
          .snapshots()
          .listen((snap) {
        // For each conversation doc changed, update our local chat summary (merge).
        for (final change in snap.docChanges) {
          final doc = change.doc;
          _updateSummaryFromConversation(doc.id, doc.data()).catchError((e) {
            debugPrint('[ChatListVM] _updateSummaryFromConversation error: $e');
          });
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

  // Helper: decide if two summaries differ (to avoid unnecessary rebuilds)
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

  // Rebuilds _chats sorted from _chatMap
  void _rebuildSortedList() {
    final list = _chatMap.values.toList();
    list.sort(_chatComparator);
    _chats = list;
  }

  // Comparator: pinned (true first) then lastUpdated desc (null safe)
  int _chatComparator(ChatSummary a, ChatSummary b) {
    if (a.pinned && !b.pinned) return -1;
    if (!a.pinned && b.pinned) return 1;
    final aMillis = a.lastUpdated.millisecondsSinceEpoch;
    final bMillis = b.lastUpdated.millisecondsSinceEpoch;
    return bMillis.compareTo(aMillis); // descending
  }

  /// Manual refresh (re-run initial query)
  Future<void> refresh() async {
    await _sub?.cancel();
    await _conversationsSub?.cancel();
    _lastDoc = null;
    hasMore = true;
    isLoading = true;
    _chatMap.clear();
    _chats = [];
    notifyListeners();
    await _init();
  }

  /// pagination: load next page once user scrolls
  Future<void> loadMore() async {
    if (isPaginating || !hasMore) return;
    final uid = currentUid;
    if (uid == null) return;

    // If we don't have a lastDoc (e.g. no results) then nothing to paginate
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
      _rebuildSortedList();
      errorMessage = null;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isPaginating = false;
      notifyListeners();
    }
  }

  // ============================================================
  // When a conversation document changes, build or update a ChatSummary.
  // We fetch the most recent message (messages subcollection) to show lastMessage.
  // We also try to resolve the "other" member's display name (cached).
  // ============================================================
  Future<void> _updateSummaryFromConversation(String convId, Map<String, dynamic>? convData) async {
    final uid = currentUid;
    if (uid == null || convData == null) return;

    try {
      final members = (convData['members'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      final isGroup = (convData['isGroup'] as bool?) ?? false;
      final lastUpdatedFromConv = convData['lastUpdated'] as Timestamp?;
      Timestamp lastUpdated = lastUpdatedFromConv ?? Timestamp.now();

      // determine other member(s)
      String otherId = '';
      if (!isGroup) {
        otherId = members.firstWhere((m) => m != uid, orElse: () => '');
      }

      // find last message (messages subcollection, orderBy createdAt desc limit 1)
      String lastMessageText = '';
      Timestamp? lastMessageTs;
      try {
        final msgsSnap = await _firestore
            .collection('conversations')
            .doc(convId)
            .collection('messages')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();
        if (msgsSnap.docs.isNotEmpty) {
          final mdoc = msgsSnap.docs.first;
          final mdata = mdoc.data();
          lastMessageText = (mdata['text'] as String?) ?? '';
          lastMessageTs = (mdata['createdAt'] is Timestamp) ? mdata['createdAt'] as Timestamp : null;
        }
      } catch (e) {
        debugPrint('[ChatListVM] failed to get last message for $convId: $e');
      }

      if (lastMessageTs != null) lastUpdated = lastMessageTs;

      // resolve other display name (cache)
      String displayName = otherId;
      if (otherId.isNotEmpty) {
        displayName = await _getUserDisplayName(otherId) ?? otherId;
      } else if (isGroup) {
        // try to get title from conversation metadata if present
        displayName = (convData['title'] as String?) ?? 'Group';
      } else {
        displayName = convId;
      }

      // preserve pinned/archived/unreadCount if exists in users/{uid}/chats/{convId}
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
        lastUpdated: lastUpdated,
        unreadCount: unreadCount,
        pinned: pinned,
        archived: archived,
        otherPublicId: otherPublicId,
      );

      // merge into local map and persist to users/{uid}/chats for this user
      final existing = _chatMap[convId];
      if (existing == null || _isDifferent(existing, summary)) {
        _chatMap[convId] = summary;
        _rebuildSortedList();
        notifyListeners();
      }

      // persist summary for this user under users/{uid}/chats/{convId} so it's available on reload
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
        // ignore write errors (rules may prevent writing to other user's docs)
        debugPrint('[ChatListVM] failed to persist users chat summary $convId: $e');
      }
    } catch (e) {
      debugPrint('[ChatListVM] _updateSummaryFromConversation general error: $e');
    }
  }

  // Lightweight resolver for display name (caching)
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

  // ============================================================
  // Selection helpers
  // ============================================================
  void startSelection(String chatId) {
    selectedIds.add(chatId);
    notifyListeners();
  }

  void toggleSelection(String chatId) {
    if (selectedIds.contains(chatId))
      selectedIds.remove(chatId);
    else
      selectedIds.add(chatId);
    notifyListeners();
  }

  void clearSelection() {
    selectedIds.clear();
    notifyListeners();
  }

  // ============================================================
  // Pin / Unpin (atomic using transaction on user's chat doc)
  // ============================================================
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

      // optimistic local update - reflect pinned flip and update lastUpdated locally
      final idx = _chats.indexWhere((c) => c.id == chatId);
      if (idx >= 0) {
        final old = _chats[idx];
        final updated = old.copyWith(pinned: !old.pinned, lastUpdated: Timestamp.now());
        _chatMap[chatId] = updated;
        _rebuildSortedList();
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

  // ============================================================
  // Archive selected or single chat (per-user)
  // ============================================================
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

      // local update: remove from map if we're not showing archived
      for (final id in ids) {
        final existing = _chatMap[id];
        if (existing != null) {
          final updated = existing.copyWith(archived: true, lastUpdated: Timestamp.now());
          _chatMap[id] = updated;
          if (!_includeArchived) _chatMap.remove(id);
        }
      }
      _rebuildSortedList();
      selectedIds.removeAll(ids);
      errorMessage = null;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  // ============================================================
  // Delete chats (local-only documents under users/{uid}/chats),
  // This does NOT delete the conversation document itself (server-level).
  // ============================================================
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
      _rebuildSortedList();
      selectedIds.removeAll(ids);
      errorMessage = null;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  // ============================================================
  // Mark chat as read (set unreadCount=0 for this user's chat doc)
  // ============================================================
  Future<void> markAsRead(String chatId) async {
    final uid = currentUid;
    if (uid == null) throw Exception('Not logged in');

    final docRef = _firestore.collection('users').doc(uid).collection('chats').doc(chatId);

    try {
      await docRef.update({'unreadCount': 0});
      // local update
      final idx = _chats.indexWhere((c) => c.id == chatId);
      if (idx >= 0) {
        final updated = _chats[idx].copyWith(unreadCount: 0);
        _chatMap[chatId] = updated;
        _rebuildSortedList();
        notifyListeners();
      }
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ============================================================
  // Search (client-side). For large scale, push to server-side search.
  // ============================================================
  void setQuery(String q) {
    _query = q.trim();
    notifyListeners();
  }

  // Toggle whether archived chats are included in the list and re-init stream
  Future<void> setIncludeArchived(bool include) async {
    if (_includeArchived == include) return;
    _includeArchived = include;
    await refresh();
  }

  // ============================================================
  // Utility: find ChatSummary by id
  // ============================================================
  ChatSummary? findById(String id) {
    return _chatMap[id];
  }

  // ============================================================
  // Optionally allow external code to push updates (e.g., when new message arrives)
  // This will merge and reorder the local list appropriately.
  // ============================================================
  void mergeIncomingChatSummary(ChatSummary summary) {
    final existing = _chatMap[summary.id];
    if (existing == null || _isDifferent(existing, summary)) {
      _chatMap[summary.id] = summary;
      _rebuildSortedList();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _conversationsSub?.cancel();
    super.dispose();
  }
}
