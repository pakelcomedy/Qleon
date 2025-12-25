// lib/features/archive/viewmodel/archive_viewmodel.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Local model representing the per-user persisted chat summary stored under:
/// users/{uid}/chats/{convId} (but for archive we persist locally in Hive)
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
    } else if (lu is int || lu is double || lu is num) {
      // heuristic: allow seconds or milliseconds
      final n = (lu as num).toInt();
      if (n < 100000000000) {
        lastUpdated = Timestamp.fromMillisecondsSinceEpoch(n * 1000);
      } else {
        lastUpdated = Timestamp.fromMillisecondsSinceEpoch(n);
      }
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
      // For archive semantics we keep archived=true when stored locally
      archived: (m['archived'] as bool?) ?? true,
      isGroup: (m['isGroup'] as bool?) ?? false,
      otherPublicId: (m['otherPublicId'] as String?) ?? '',
    );
  }

  /// For writing back to Firestore (preserve Timestamp)
  Map<String, dynamic> toMapForFirestore() => {
        'title': title,
        'lastMessage': lastMessage,
        'lastUpdated': lastUpdated,
        'unreadCount': unreadCount,
        'pinned': pinned,
        'archived': archived,
        'isGroup': isGroup,
        'otherPublicId': otherPublicId,
      };

  /// For storing in Hive: convert lastUpdated -> int (ms)
  Map<String, dynamic> toMapForHive() => {
        'title': title,
        'lastMessage': lastMessage,
        'lastUpdated': lastUpdated.millisecondsSinceEpoch,
        'unreadCount': unreadCount,
        'pinned': pinned,
        'archived': archived,
        'isGroup': isGroup,
        'otherPublicId': otherPublicId,
      };

  factory ArchivedChat.fromHiveMap(String id, Map m) {
    final dynamic lu = m['lastUpdated'];
    Timestamp lastUpdated;
    if (lu is int || lu is double || lu is num) {
      final n = (lu as num).toInt();
      if (n < 100000000000) {
        lastUpdated = Timestamp.fromMillisecondsSinceEpoch(n * 1000);
      } else {
        lastUpdated = Timestamp.fromMillisecondsSinceEpoch(n);
      }
    } else if (lu is Timestamp) {
      lastUpdated = lu;
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
      archived: (m['archived'] as bool?) ?? true,
      isGroup: (m['isGroup'] as bool?) ?? false,
      otherPublicId: (m['otherPublicId'] as String?) ?? '',
    );
  }

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

/// ViewModel for the Archive feature (LOCAL-HIVE based archive)
/// NOTE: archive is stored fully local in Hive box 'archived_chats'.
class ArchiveViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Master map + cached ordered list (source of truth for UI = Hive)
  final Map<String, ArchivedChat> _map = {};
  List<ArchivedChat> _list = [];

  // selection set for UI
  final Set<String> selectedIds = {};

  // Pagination (not used for Hive but kept for API compatibility)
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

  // Hive box
  Box? _archiveBox;

  ArchiveViewModel() {
    _init();
  }

  String? get currentUid => _auth.currentUser?.uid;

  /// Exposed list of archived chats (ordered by lastUpdated desc)
  List<ArchivedChat> get archivedChats => List.unmodifiable(_list);

  bool get selectionMode => selectedIds.isNotEmpty;

  Future<void> _init() async {
    final uid = currentUid;

    // initialize hive box (best effort)
    try {
      if (!Hive.isBoxOpen('archived_chats')) {
        await Hive.openBox('archived_chats');
      }
      _archiveBox = Hive.box('archived_chats');
    } catch (e) {
      debugPrint('[ArchiveVM] failed to open Hive box archived_chats: $e');
      _archiveBox = null;
    }

    // load local archive into memory
    await _loadFromHive();

    // set loading false
    isLoading = false;
    errorMessage = (uid == null) ? 'User not logged in' : null;
    notifyListeners();
  }

  Future<void> _loadFromHive() async {
    _map.clear();
    _list = [];
    try {
      if (_archiveBox != null && _archiveBox!.isOpen) {
        for (final key in _archiveBox!.keys) {
          final v = _archiveBox!.get(key);
          if (v is Map) {
            final item = ArchivedChat.fromHiveMap(key.toString(), v);
            _map[item.id] = item;
          }
        }
      }
      _rebuildListAndNotify();
    } catch (e) {
      debugPrint('[ArchiveVM] loadFromHive failed: $e');
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  void _rebuildListAndNotify() {
    final list = _map.values.toList();
    list.sort((a, b) => b.lastUpdated.millisecondsSinceEpoch.compareTo(a.lastUpdated.millisecondsSinceEpoch));
    _list = list;
    notifyListeners();
  }

  /// Manual refresh (reload from Hive)
  Future<void> refresh() async {
    isLoading = true;
    notifyListeners();
    await _loadFromHive();
    isLoading = false;
    notifyListeners();
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
  // Archive operations (LOCAL)
  // ---------------------------

  /// Archive multiple chats: move from Firestore -> Hive and delete server doc (best-effort).
  Future<void> archiveMultiple(List<String> convIds) async {
    final uid = currentUid;
    if (uid == null) throw StateError('Not authenticated');
    if (convIds.isEmpty) return;

    isBusy = true;
    errorMessage = null;
    notifyListeners();

    try {
      for (final id in convIds) {
        try {
          final snap = await _firestore.collection('users').doc(uid).collection('chats').doc(id).get();
          if (snap.exists && snap.data() != null) {
            final data = snap.data()!;
            // ensure archived flag true locally
            final mapToStore = Map<String, dynamic>.from(data);
            mapToStore['archived'] = true;
            // convert lastUpdated to ms if Timestamp present
            if (mapToStore['lastUpdated'] is Timestamp) {
              mapToStore['lastUpdated'] = (mapToStore['lastUpdated'] as Timestamp).millisecondsSinceEpoch;
            }
            if (_archiveBox != null) {
              await _archiveBox!.put(id, mapToStore);
            }
            // update local map
            final archived = ArchivedChat.fromHiveMap(id, mapToStore);
            _map[id] = archived;
          } else {
            // if no server doc, create a minimal archived entry locally
            final fallback = ArchivedChat(
              id: id,
              title: '',
              lastMessage: '',
              lastUpdated: Timestamp.now(),
              unreadCount: 0,
              pinned: false,
              archived: true,
              isGroup: false,
              otherPublicId: '',
            );
            if (_archiveBox != null) {
              await _archiveBox!.put(id, fallback.toMapForHive());
            }
            _map[id] = fallback;
          }

          // best-effort delete server doc to avoid duplicates
          try {
            await _firestore.collection('users').doc(uid).collection('chats').doc(id).delete();
          } catch (_) {}
        } catch (e) {
          debugPrint('[ArchiveVM] archiveMultiple: failed to archive $id: $e');
        }
      }

      _rebuildListAndNotify();
      errorMessage = null;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  /// Unarchive multiple chats: move from Hive -> Firestore (write back) and remove from Hive.
  /// Stores backup for undo.
  Future<void> unarchiveMultiple(List<String> convIds) async {
    final uid = currentUid;
    if (uid == null) throw StateError('Not authenticated');
    if (convIds.isEmpty) return;

    isBusy = true;
    errorMessage = null;
    notifyListeners();

    // backup hive data for undo
    _lastUnarchivedIds = List<String>.from(convIds);
    _lastUnarchiveBackup.clear();

    try {
      for (final id in convIds) {
        final raw = _archiveBox?.get(id);
        if (raw is Map) {
          // store backup
          _lastUnarchiveBackup[id] = Map<String, dynamic>.from(raw);

          // convert to model
          final s = ArchivedChat.fromHiveMap(id, raw);

          // write back to Firestore (merge) and mark archived=false
          final docRef = _firestore.collection('users').doc(uid).collection('chats').doc(id);
          final toWrite = s.toMapForFirestore();
          toWrite['archived'] = false;
          toWrite['lastUpdated'] = FieldValue.serverTimestamp();

          try {
            await docRef.set(toWrite, SetOptions(merge: true));
          } catch (e) {
            debugPrint('[ArchiveVM] unarchiveMultiple: failed to write $id to server: $e');
            // if write failed, keep backup and continue to next
            continue;
          }

          // remove from hive
          try {
            if (_archiveBox != null) await _archiveBox!.delete(id);
          } catch (e) {
            debugPrint('[ArchiveVM] unarchiveMultiple: failed to delete $id from hive: $e');
          }

          // remove from local map
          _map.remove(id);
        } else {
          // no hive entry - nothing to do
          debugPrint('[ArchiveVM] unarchiveMultiple: no hive entry for $id');
        }
      }

      _rebuildListAndNotify();

      // success
      isBusy = false;
      notifyListeners();
    } catch (e) {
      // restore local entries from backup in case of failure
      for (final id in convIds) {
        final backup = _lastUnarchiveBackup[id];
        if (backup != null) {
          _map[id] = ArchivedChat.fromHiveMap(id, backup);
          try {
            if (_archiveBox != null) await _archiveBox!.put(id, backup);
          } catch (_) {}
        }
      }
      _rebuildListAndNotify();

      isBusy = false;
      errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Undo the last unarchive operation: restore backed-up hive entries and delete server docs written by unarchive
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
          // restore to hive
          try {
            if (_archiveBox != null) await _archiveBox!.put(id, backup);
            _map[id] = ArchivedChat.fromHiveMap(id, backup);
          } catch (e) {
            debugPrint('[ArchiveVM] undoLastUnarchive: failed to restore hive for $id: $e');
          }
          // remove server doc (best-effort) to undo the unarchive
          final docRef = _firestore.collection('users').doc(uid).collection('chats').doc(id);
          batch.delete(docRef);
        } else {
          // nothing to restore locally; as a fallback set archived=true on server
          final docRef = _firestore.collection('users').doc(uid).collection('chats').doc(id);
          batch.set(docRef, {'archived': true, 'lastUpdated': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        }
      }
      try {
        await batch.commit();
      } catch (e) {
        debugPrint('[ArchiveVM] undoLastUnarchive: batch commit failed: $e');
      }

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

  /// Unarchive single chat (helper for UI compatibility)
Future<void> unarchive(String convId) async {
  await unarchiveMultiple([convId]);
}

  /// Convenience: unarchive all currently selected items
  Future<void> unarchiveSelected() async {
    if (selectedIds.isEmpty) return;
    final ids = selectedIds.toList();
    await unarchiveMultiple(ids);
    selectedIds.clear();
    notifyListeners();
  }

  /// Return archived chats from local Hive (sorted)
  Future<List<ArchivedChat>> getArchivedChats() async {
    final list = <ArchivedChat>[];
    try {
      if (_archiveBox != null && _archiveBox!.isOpen) {
        for (final key in _archiveBox!.keys) {
          final v = _archiveBox!.get(key);
          if (v is Map) {
            list.add(ArchivedChat.fromHiveMap(key.toString(), v));
          }
        }
      }
    } catch (e) {
      debugPrint('[ArchiveVM] getArchivedChats failed: $e');
    }
    list.sort((a, b) => b.lastUpdated.millisecondsSinceEpoch.compareTo(a.lastUpdated.millisecondsSinceEpoch));
    return list;
  }

  /// Remove archived entries locally (and optionally try to delete server doc)
  Future<void> deleteArchived({List<String>? ids}) async {
    final uids = ids ?? selectedIds.toList();
    if (uids.isEmpty) return;

    isBusy = true;
    notifyListeners();

    try {
      final uid = currentUid;
      for (final id in uids) {
        try {
          if (_archiveBox != null) await _archiveBox!.delete(id);
        } catch (e) {
          debugPrint('[ArchiveVM] deleteArchived: hive delete failed for $id: $e');
        }
        _map.remove(id);

        // optional: try to remove server doc as well (best-effort)
        if (uid != null) {
          try {
            await _firestore.collection('users').doc(uid).collection('chats').doc(id).delete();
          } catch (_) {}
        }
      }
      _rebuildListAndNotify();
      selectedIds.removeAll(uids);
      errorMessage = null;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  ArchivedChat? findById(String id) => _map[id];

  @override
  void dispose() {
    // nothing to cancel (no firestore snapshot for archived list)
    super.dispose();
  }
}
