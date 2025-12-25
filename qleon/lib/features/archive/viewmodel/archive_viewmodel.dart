// lib/features/archive/viewmodel/archive_viewmodel.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Local model representing the per-user persisted chat summary stored under:
/// users/{uid}/chats/{convId}
class ArchivedChat {
  final String id;
  final String title;
  final String lastMessage;
  final Timestamp lastUpdated;
  final int unreadCount;
  final bool pinned;
  final bool archived;
  final bool isGroup;
  final String otherPublicId;

  ArchivedChat({
    required this.id,
    required this.title,
    required this.lastMessage,
    required this.lastUpdated,
    required this.unreadCount,
    required this.pinned,
    required this.archived,
    required this.isGroup,
    required this.otherPublicId,
  });

  factory ArchivedChat.fromMap(String id, Map<String, dynamic> m) {
    Timestamp lastUpdated;
    final dynamic lu = m['lastUpdated'];
    if (lu is Timestamp) {
      lastUpdated = lu;
    } else if (lu is int) {
      lastUpdated = Timestamp.fromMillisecondsSinceEpoch(lu);
    } else if (lu is String) {
      try {
        lastUpdated = Timestamp.fromDate(DateTime.parse(lu));
      } catch (_) {
        lastUpdated = Timestamp.now();
      }
    } else {
      lastUpdated = Timestamp.now();
    }

    return ArchivedChat(
      id: id,
      title: (m['title'] as String?) ?? '',
      lastMessage: (m['lastMessage'] as String?) ?? '',
      lastUpdated: lastUpdated,
      unreadCount: (m['unreadCount'] as int?) ?? 0,
      pinned: (m['pinned'] as bool?) ?? false,
      // STRICT: default archived=false if missing — only treat as archived when explicit true
      archived: (m['archived'] as bool?) ?? false,
      isGroup: (m['isGroup'] as bool?) ?? false,
      otherPublicId: (m['otherPublicId'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'lastMessage': lastMessage,
        'lastUpdated': lastUpdated,
        'unreadCount': unreadCount,
        'pinned': pinned,
        'archived': archived,
        'isGroup': isGroup,
        'otherPublicId': otherPublicId,
      };

  ArchivedChat copyWith({
    String? title,
    String? lastMessage,
    Timestamp? lastUpdated,
    int? unreadCount,
    bool? pinned,
    bool? archived,
    bool? isGroup,
    String? otherPublicId,
  }) {
    return ArchivedChat(
      id: id,
      title: title ?? this.title,
      lastMessage: lastMessage ?? this.lastMessage,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      unreadCount: unreadCount ?? this.unreadCount,
      pinned: pinned ?? this.pinned,
      archived: archived ?? this.archived,
      isGroup: isGroup ?? this.isGroup,
      otherPublicId: otherPublicId ?? this.otherPublicId,
    );
  }
}

/// ViewModel for the Archive feature (shows archived chats for current user)
class ArchiveViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Subscription to user's archived chats (users/{uid}/chats where archived==true)
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  // Master map + cached ordered list
  final Map<String, ArchivedChat> _map = {};
  List<ArchivedChat> _list = [];

  // selection set for UI
  final Set<String> selectedIds = {};

  // Pagination
  static const int defaultPageSize = 30;
  int pageSize = defaultPageSize;
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool hasMore = true;
  bool isPaginating = false;

  // UI state
  bool isLoading = true;
  bool isBusy = false;
  String? errorMessage;

  // Undo support (stores last unarchived ids and their previous snapshot data)
  List<String>? _lastUnarchivedIds;
  final Map<String, Map<String, dynamic>> _lastUnarchiveBackup = {};

  ArchiveViewModel() {
    _init();
  }

  String? get currentUid => _auth.currentUser?.uid;

  /// Exposed list of archived chats (ordered by lastUpdated desc)
  List<ArchivedChat> get archivedChats => List.unmodifiable(_list);

  bool get selectionMode => selectedIds.isNotEmpty;

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
      _map.clear();
      _list = [];
      _lastDoc = null;
      hasMore = true;

      Query<Map<String, dynamic>> q = _firestore
          .collection('users')
          .doc(uid)
          .collection('chats')
          .where('archived', isEqualTo: true)
          .orderBy('lastUpdated', descending: true)
          .limit(pageSize);

      // REBUILD approach: when snapshot arrives, rebuild local map from snapshot.docs
      _sub = q.snapshots().listen((snap) {
        try {
          // Rebuild map from the authoritative snapshot to avoid duplicates/race conditions
          final Map<String, ArchivedChat> newMap = {};
          for (final doc in snap.docs) {
            final data = doc.data();
            if (data == null) continue;
            // DEFENSIVE BUT STRICT: include only when field explicitly true
            final archivedField = (data['archived'] as bool?) ?? false;
            if (!archivedField) continue;
            final item = ArchivedChat.fromMap(doc.id, data);
            newMap[doc.id] = item;
          }

          // replace master map and rebuild list once
          _map
            ..clear()
            ..addAll(newMap);

          _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
          hasMore = snap.docs.length >= pageSize;

          _rebuildListAndNotify();
          isLoading = false;
          errorMessage = null;
        } catch (e) {
          debugPrint('[ArchiveVM] snapshot rebuild error: $e');
          isLoading = false;
          errorMessage = e.toString();
          notifyListeners();
        }
      }, onError: (e) {
        isLoading = false;
        errorMessage = e.toString();
        notifyListeners();
      });
    } catch (e) {
      isLoading = false;
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  bool _isDifferent(ArchivedChat a, ArchivedChat b) {
    return a.title != b.title ||
        a.lastMessage != b.lastMessage ||
        a.unreadCount != b.unreadCount ||
        a.pinned != b.pinned ||
        a.archived != b.archived ||
        a.lastUpdated.millisecondsSinceEpoch != b.lastUpdated.millisecondsSinceEpoch;
  }

  void _rebuildListAndNotify() {
    final list = _map.values.toList();
    list.sort((a, b) => b.lastUpdated.millisecondsSinceEpoch.compareTo(a.lastUpdated.millisecondsSinceEpoch));
    _list = list;
    notifyListeners();
  }

  /// Manual refresh
  Future<void> refresh() async {
    await _sub?.cancel();
    _map.clear();
    _list = [];
    _lastDoc = null;
    hasMore = true;
    isLoading = true;
    notifyListeners();
    await _init();
  }

  /// Pagination: load next page of archived chat summaries
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
          .where('archived', isEqualTo: true)
          .orderBy('lastUpdated', descending: true)
          .startAfterDocument(_lastDoc!)
          .limit(pageSize);

      final next = await q.get();
      for (final doc in next.docs) {
        final data = doc.data();
        if (data == null) continue;
        // Defensive: ensure archived flag true
        final archivedField = (data['archived'] as bool?) ?? false;
        if (!archivedField) continue;
        final item = ArchivedChat.fromMap(doc.id, data);
        final existing = _map[doc.id];
        if (existing == null || _isDifferent(existing, item)) {
          _map[doc.id] = item;
        }
      }
      _lastDoc = next.docs.isNotEmpty ? next.docs.last : _lastDoc;
      hasMore = next.docs.length >= pageSize;
      _rebuildListAndNotify();
      errorMessage = null;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    } finally {
      isPaginating = false;
      notifyListeners();
    }
  }

  // ---------------------------
  // Selection helpers
  // ---------------------------
  void startSelection(String id) {
    selectedIds.add(id);
    notifyListeners();
  }

  void toggleSelection(String id) {
    if (selectedIds.contains(id)) selectedIds.remove(id);
    else selectedIds.add(id);
    notifyListeners();
  }

  void clearSelection() {
    selectedIds.clear();
    notifyListeners();
  }

  // ---------------------------
  // Unarchive operations
  // ---------------------------

  /// Unarchive a single chat
  Future<void> unarchive(String convId) async {
    return unarchiveMultiple([convId]);
  }

  /// Unarchive multiple chats (optimistic). Stores backup for undo.
  Future<void> unarchiveMultiple(List<String> convIds) async {
    final uid = currentUid;
    if (uid == null) throw StateError('Not authenticated');

    if (convIds.isEmpty) return;

    isBusy = true;
    errorMessage = null;
    notifyListeners();

    // backup previous user chat docs to allow undo
    _lastUnarchivedIds = List<String>.from(convIds);
    _lastUnarchiveBackup.clear();

    try {
      // read existing docs (batched) to backup
      final futures = convIds.map((id) => _firestore.collection('users').doc(uid).collection('chats').doc(id).get()).toList();
      final snaps = await Future.wait(futures);

      for (var i = 0; i < convIds.length; i++) {
        final id = convIds[i];
        final snap = snaps[i];
        _lastUnarchiveBackup[id] = snap.exists ? (snap.data() ?? <String, dynamic>{}) : <String, dynamic>{};
      }

      // OPTIMISTIC: remove from local archived map immediately (so UI won't show duplicates)
      for (final id in convIds) {
        if (_map.containsKey(id)) {
          _map.remove(id);
        }
      }
      _rebuildListAndNotify();

      // write batch to Firestore to set archived=false and update lastUpdated
      final batch = _firestore.batch();
      for (final id in convIds) {
        final docRef = _firestore.collection('users').doc(uid).collection('chats').doc(id);
        batch.set(docRef, {'archived': false, 'lastUpdated': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      }
      await batch.commit();

      // VERIFY: ensure server doc archived field actually false; if not, retry a couple times
      for (final id in convIds) {
        final docRef = _firestore.collection('users').doc(uid).collection('chats').doc(id);
        var tries = 0;
        while (tries < 3) {
          tries++;
          try {
            final snap = await docRef.get();
            final serverArchived = (snap.data()?['archived'] as bool?) ?? false;
            if (!serverArchived) {
              // ok: confirmed archived=false
              break;
            } else {
              debugPrint('[ArchiveVM] post-commit check: archived still true for $id, retrying (attempt $tries)');
              // try to force update
              try {
                await docRef.update({'archived': false, 'lastUpdated': FieldValue.serverTimestamp()});
              } catch (e) {
                debugPrint('[ArchiveVM] force update failed for $id: $e');
              }
              // small delay before next check (awaitable)
              await Future.delayed(const Duration(milliseconds: 300));
            }
          } catch (e) {
            debugPrint('[ArchiveVM] error reading $id during verify: $e');
            await Future.delayed(const Duration(milliseconds: 300));
          }
        }
      }

      // final cleanup: ensure local map doesn't contain these ids (in case snapshot still hasn't reflected)
      for (final id in convIds) {
        _map.remove(id);
      }
      _rebuildListAndNotify();

      // If some doc still exists server-side as archived=true after retries, force a refresh subscription to re-sync
      // (this is defensive: rare)
      bool anyStillArchived = false;
      for (final id in convIds) {
        final doc = await _firestore.collection('users').doc(uid).collection('chats').doc(id).get();
        final serverArchived = (doc.data()?['archived'] as bool?) ?? false;
        if (serverArchived) {
          anyStillArchived = true;
          debugPrint('[ArchiveVM] after retries $id still archived on server');
        }
      }
      if (anyStillArchived) {
        await refresh();
      }

      // success
      isBusy = false;
      notifyListeners();
    } catch (e) {
      // rollback local optimistic update by restoring backup if possible
      for (final id in convIds) {
        final backup = _lastUnarchiveBackup[id];
        if (backup != null && backup.isNotEmpty) {
          _map[id] = ArchivedChat.fromMap(id, backup);
        } else {
          _map.remove(id);
        }
      }
      _rebuildListAndNotify();

      isBusy = false;
      errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Undo the last unarchive operation (if available)
  Future<void> undoLastUnarchive() async {
    final uid = currentUid;
    if (uid == null) return;
    final ids = _lastUnarchivedIds;
    if (ids == null || ids.isEmpty) return;

    isBusy = true;
    notifyListeners();

    try {
      final batch = _firestore.batch();
      for (final id in ids) {
        final backup = _lastUnarchiveBackup[id];
        if (backup != null && backup.isNotEmpty) {
          // restore full backup
          final docRef = _firestore.collection('users').doc(uid).collection('chats').doc(id);
          batch.set(docRef, backup, SetOptions(merge: true));
          // update local map
          _map[id] = ArchivedChat.fromMap(id, backup);
        } else {
          // if there was no backup doc, set archived=true to restore
          final docRef = _firestore.collection('users').doc(uid).collection('chats').doc(id);
          batch.set(docRef, {'archived': true, 'lastUpdated': FieldValue.serverTimestamp()}, SetOptions(merge: true));
          // local: we cannot reconstruct full item, it's safer to leave removed until snapshot repopulates
        }
      }
      await batch.commit();

      // clear undo cache
      _lastUnarchivedIds = null;
      _lastUnarchiveBackup.clear();

      _rebuildListAndNotify();
      isBusy = false;
      notifyListeners();
    } catch (e) {
      isBusy = false;
      errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Convenience: unarchive all currently selected items
  Future<void> unarchiveSelected() async {
    if (selectedIds.isEmpty) return;
    final ids = selectedIds.toList();
    await unarchiveMultiple(ids);
    selectedIds.clear();
    notifyListeners();
  }

  // ---------------------------
  // Utilities
  // ---------------------------
  ArchivedChat? findById(String id) => _map[id];

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
