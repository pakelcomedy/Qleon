// lib/features/chat/viewmodel/chat_room_viewmodel.dart
// Offline-first ChatRoomViewModel (local-first like WhatsApp) with:
// - SQLite local source-of-truth
// - Firestore as temporary queue + TTL (3 days)
// - optimistic send, pending queue, retries, ACK handling
// Dependencies:
//   sqflite: ^2.2.8
//   path_provider: ^2.0.14

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// -----------------------------
/// Data model
/// -----------------------------
class ChatMessage {
  final String id;
  final String conversationId;
  final String text;
  final String senderId;
  final Timestamp createdAt;
  final String? replyToMessageId;
  final bool isDeleted;
  final bool isLocal; // optimistic/local-only indicator
  final bool delivered; // server delivered flag
  final Timestamp? deliveredAt;
  final Timestamp? expiresAt;

  /// sendState: 'pending' | 'sending' | 'sent' | 'failed'
  final String sendState;
  final int sendAttempts;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.text,
    required this.senderId,
    required this.createdAt,
    this.replyToMessageId,
    this.isDeleted = false,
    this.isLocal = false,
    this.delivered = false,
    this.deliveredAt,
    this.expiresAt,
    this.sendState = 'sent',
    this.sendAttempts = 0,
  });

  /// Safe factory from Firestore document snapshot (server copy)
  factory ChatMessage.fromDoc(QueryDocumentSnapshot doc, {String? conversationIdOverride}) {
    final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
    final rawCreatedAt = data['createdAt'];
    final createdAt = (rawCreatedAt is Timestamp) ? rawCreatedAt : Timestamp.now();
    final delivered = (data['delivered'] as bool?) ?? false;
    final deliveredAt = (data['deliveredAt'] is Timestamp) ? data['deliveredAt'] as Timestamp : null;
    final expiresAt = (data['expiresAt'] is Timestamp) ? data['expiresAt'] as Timestamp : null;

    // server copy is considered not local; sendState defaults to 'sent'
    return ChatMessage(
      id: doc.id,
      conversationId: conversationIdOverride ?? (data['conversationId']?.toString() ?? ''),
      text: (data['text'] ?? '').toString(),
      senderId: (data['senderId'] ?? 'unknown').toString(),
      createdAt: createdAt,
      replyToMessageId: data['replyToMessageId']?.toString(),
      isDeleted: (data['isDeleted'] as bool?) ?? false,
      isLocal: false,
      delivered: delivered,
      deliveredAt: deliveredAt,
      expiresAt: expiresAt,
      sendState: 'sent',
      sendAttempts: 0,
    );
  }

  /// Map used to send to Firestore (serverTimestamp for createdAt)
  Map<String, dynamic> toMapForSend({Duration? ttl}) {
    final Map<String, dynamic> m = {
      'text': text,
      'senderId': senderId,
      'createdAt': FieldValue.serverTimestamp(),
      'replyToMessageId': replyToMessageId,
      'isDeleted': isDeleted,
      'delivered': false,
      'conversationId': conversationId,
    };
    if (ttl != null) {
      final expiry = DateTime.now().toUtc().add(ttl);
      m['expiresAt'] = Timestamp.fromDate(expiry);
    }
    return m;
  }

  /// Map for local DB upsert
  Map<String, Object?> toLocalMap() {
    return {
      'id': id,
      'conversationId': conversationId,
      'text': text,
      'senderId': senderId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'replyToMessageId': replyToMessageId,
      'isDeleted': isDeleted ? 1 : 0,
      'isLocal': isLocal ? 1 : 0,
      'delivered': delivered ? 1 : 0,
      'deliveredAt': deliveredAt?.millisecondsSinceEpoch,
      'expiresAt': expiresAt?.millisecondsSinceEpoch,
      'sendState': sendState,
      'sendAttempts': sendAttempts,
    };
  }

  /// Create ChatMessage from local DB row
  factory ChatMessage.fromLocal(Map<String, Object?> row) {
    final createdAtMillis = (row['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch;
    final deliveredAtMillis = (row['deliveredAt'] as int?);
    final expiresAtMillis = (row['expiresAt'] as int?);
    return ChatMessage(
      id: (row['id'] as String),
      conversationId: (row['conversationId'] as String),
      text: (row['text'] as String),
      senderId: (row['senderId'] as String),
      createdAt: Timestamp.fromMillisecondsSinceEpoch(createdAtMillis),
      replyToMessageId: (row['replyToMessageId'] as String?),
      isDeleted: ((row['isDeleted'] as int?) ?? 0) == 1,
      isLocal: ((row['isLocal'] as int?) ?? 0) == 1,
      delivered: ((row['delivered'] as int?) ?? 0) == 1,
      deliveredAt: deliveredAtMillis != null ? Timestamp.fromMillisecondsSinceEpoch(deliveredAtMillis) : null,
      expiresAt: expiresAtMillis != null ? Timestamp.fromMillisecondsSinceEpoch(expiresAtMillis) : null,
      sendState: (row['sendState'] as String?) ?? 'sent',
      sendAttempts: (row['sendAttempts'] as int?) ?? 0,
    );
  }

  ChatMessage copyWith({
    String? sendState,
    int? sendAttempts,
    bool? delivered,
    Timestamp? deliveredAt,
    bool? isLocal,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      text: text,
      senderId: senderId,
      createdAt: createdAt,
      replyToMessageId: replyToMessageId,
      isDeleted: isDeleted,
      isLocal: isLocal ?? this.isLocal,
      delivered: delivered ?? this.delivered,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      expiresAt: expiresAt,
      sendState: sendState ?? this.sendState,
      sendAttempts: sendAttempts ?? this.sendAttempts,
    );
  }
}

/// -----------------------------
/// Local DB helper (sqflite)
/// -----------------------------
class LocalChatDb {
  static const _dbName = 'qleon_chat_local.db';
  static const _dbVersion = 2; // bumped because we add columns
  static Database? _db;

  static Future<void> init() async {
    if (_db != null) return;
    final Directory documentsDirectory = await getApplicationDocumentsDirectory();
    final path = p.join(documentsDirectory.path, _dbName);
    _db = await openDatabase(path, version: _dbVersion, onCreate: (db, ver) async {
      await db.execute('''
        CREATE TABLE messages (
          id TEXT PRIMARY KEY,
          conversationId TEXT,
          text TEXT,
          senderId TEXT,
          createdAt INTEGER,
          replyToMessageId TEXT,
          isDeleted INTEGER DEFAULT 0,
          isLocal INTEGER DEFAULT 0,
          delivered INTEGER DEFAULT 0,
          deliveredAt INTEGER,
          expiresAt INTEGER,
          sendState TEXT DEFAULT 'sent',
          sendAttempts INTEGER DEFAULT 0
        );
      ''');
      await db.execute('CREATE INDEX idx_conv_createdAt ON messages(conversationId, createdAt);');
      await db.execute('CREATE INDEX idx_conv_sendState ON messages(conversationId, sendState);');
    }, onUpgrade: (db, oldV, newV) async {
      // simple migration: if upgrading from v1 -> v2, add columns
      if (oldV < 2) {
        try {
          await db.execute("ALTER TABLE messages ADD COLUMN sendState TEXT DEFAULT 'sent';");
          await db.execute("ALTER TABLE messages ADD COLUMN sendAttempts INTEGER DEFAULT 0;");
          await db.execute('CREATE INDEX IF NOT EXISTS idx_conv_sendState ON messages(conversationId, sendState);');
        } catch (e) {
          debugPrint('[LocalChatDb] migration v1->v2 failed: $e');
        }
      }
    });
  }

  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  static Database get db {
    if (_db == null) throw StateError('Local DB not initialized. Call LocalChatDb.init() first.');
    return _db!;
  }

  static Future<void> upsertMessage(ChatMessage m) async {
    await db.insert(
      'messages',
      m.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<ChatMessage>> getMessagesForConversation(String conversationId) async {
    final rows = await db.query(
      'messages',
      where: 'conversationId = ?',
      whereArgs: [conversationId],
      orderBy: 'createdAt ASC',
    );
    return rows.map((r) => ChatMessage.fromLocal(r)).toList();
  }

  static Future<List<ChatMessage>> getPendingMessages(String conversationId, {int maxAttempts = 10}) async {
    final rows = await db.query(
      'messages',
      where: 'conversationId = ? AND sendState IN (?, ?) AND sendAttempts < ?',
      whereArgs: [conversationId, 'pending', 'failed', maxAttempts],
      orderBy: 'createdAt ASC',
    );
    return rows.map((r) => ChatMessage.fromLocal(r)).toList();
  }

  static Future<void> updateSendState(String conversationId, String messageId, String sendState, {int? sendAttempts}) async {
    final map = <String, Object?>{'sendState': sendState};
    if (sendAttempts != null) map['sendAttempts'] = sendAttempts;
    await db.update('messages', map, where: 'id = ? AND conversationId = ?', whereArgs: [messageId, conversationId]);
  }

  static Future<void> markDelivered(String conversationId, String messageId, {Timestamp? deliveredAt}) async {
    final map = <String, Object?>{'delivered': 1};
    if (deliveredAt != null) map['deliveredAt'] = deliveredAt.millisecondsSinceEpoch;
    await db.update('messages', map, where: 'id = ? AND conversationId = ?', whereArgs: [messageId, conversationId]);
  }

  static Future<void> deleteExpiredMessages(String conversationId, int beforeMillis) async {
    await db.delete('messages', where: 'conversationId = ? AND expiresAt IS NOT NULL AND expiresAt < ?', whereArgs: [conversationId, beforeMillis]);
  }
}

/// -----------------------------
/// ChatRoomViewModel
/// -----------------------------
class ChatRoomViewModel extends ChangeNotifier {
  String conversationId; // may be canonicalized
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot>? _sub; // canonical listener
  StreamSubscription<QuerySnapshot>? _legacySub; // legacy listener

  // exposed
  List<ChatMessage> messages = [];
  Set<String> selectedMessageIds = {};

  bool isLoading = true;
  bool isSending = false;
  String? errorMessage;

  // internal maps for merging/dedupe
  final Map<String, ChatMessage> _messagesMap = {}; // docId -> ChatMessage
  final Map<String, String> _fingerprintIndex = {}; // fingerprint -> docId
  final Map<String, String> _idToFingerprint = {};
  final Map<String, int> _legacyDuplicateCounter = {};

  // config: default TTL for messages in Firestore (client sets expiresAt as now + ttl)
  final Duration messageTTL;

  // internal guard to prevent reentrant ACK loops
  final Set<String> _ackInProgress = {};

  ChatRoomViewModel({required this.conversationId, this.messageTTL = const Duration(days: 3)});

  // ---------------- lifecycle ----------------
  Future<void> init() async {
    if (_sub != null || _legacySub != null) return;
    await LocalChatDb.init();

    final originalConversationId = conversationId;
    debugPrint('[ChatVM] init() start conversationId=$conversationId');

    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;

      if (currentUid != null) {
        final parts = conversationId.split('_');
        final looksCanonical = parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty;

        if (looksCanonical) {
          final resolvedA = await _resolveToUidIfNeeded(parts[0]);
          final resolvedB = await _resolveToUidIfNeeded(parts[1]);

          if (resolvedA != null && resolvedB != null) {
            final sorted = [resolvedA, resolvedB]..sort();
            final canonical = '${sorted[0]}_${sorted[1]}';
            if (canonical != conversationId) {
              debugPrint('[ChatVM] resolved canonical (from parts) -> $canonical (was $conversationId)');
              conversationId = canonical;
              await _firestore.collection('conversations').doc(conversationId).set({
                'members': [sorted[0], sorted[1]],
                'isGroup': false,
                'lastUpdated': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            }
          } else {
            if (parts.contains(currentUid)) {
              final otherCandidate = (parts[0] == currentUid) ? parts[1] : parts[0];
              final found = await _findConversationWithMembers(currentUid, otherCandidate);
              if (found != null) {
                debugPrint('[ChatVM] found conversation by members -> $found (legacy source: $conversationId)');
                conversationId = found;
              } else {
                debugPrint('[ChatVM] keeping legacy conversationId=$conversationId (not resolvable to uid pair)');
              }
            }
          }
        } else {
          final otherResolved = await _resolveToUidIfNeeded(conversationId);
          if (otherResolved != null) {
            final sorted = [currentUid, otherResolved]..sort();
            final canonical = '${sorted[0]}_${sorted[1]}';
            final canonicalSnap = await _firestore.collection('conversations').doc(canonical).get();
            if (canonicalSnap.exists) {
              debugPrint('[ChatVM] canonical found $canonical (from otherResolved)');
              conversationId = canonical;
            } else {
              debugPrint('[ChatVM] creating canonical $canonical (from otherResolved)');
              conversationId = canonical;
              await _firestore.collection('conversations').doc(conversationId).set({
                'members': [sorted[0], sorted[1]],
                'isGroup': false,
                'createdAt': FieldValue.serverTimestamp(),
                'lastUpdated': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            }
          } else {
            debugPrint('[ChatVM] otherId ${conversationId} could not be resolved to uid - keeping as legacy id');
          }
        }
      } else {
        debugPrint('[ChatVM] currentUser null during init(), will listen to provided conversationId as-is');
      }

      // Start listeners: canonical + legacy (if original differs)
      await _startListeners(canonicalId: conversationId, legacyId: (originalConversationId == conversationId) ? null : originalConversationId);

      // Load local messages to show immediately
      await _loadLocalMessages();

      // cleanup expired local messages for this conversation (best-effort)
      try {
        final beforeMillis = DateTime.now().toUtc().millisecondsSinceEpoch;
        await LocalChatDb.deleteExpiredMessages(conversationId, beforeMillis);
      } catch (e) {
        debugPrint('[ChatVM] local cleanup expired failed: $e');
      }

      // Try to sync pending messages (upload queue) on init
      unawaited(_syncPendingMessages());

      isLoading = false;
      notifyListeners();
    } catch (e, st) {
      errorMessage = e.toString();
      isLoading = false;
      notifyListeners();
      debugPrint('[ChatVM] init error: $e\n$st');
    }
  }

  Future<void> _loadLocalMessages() async {
    try {
      final local = await LocalChatDb.getMessagesForConversation(conversationId);
      // merge into map and rebuild
      for (final m in local) {
        _messagesMap[m.id] = m;
        final fp = _makeFingerprint(m);
        _fingerprintIndex.putIfAbsent(fp, () => m.id);
        _idToFingerprint[m.id] = fp;
      }
      _rebuildMessagesFromMap();
    } catch (e) {
      debugPrint('[ChatVM] error loading local messages: $e');
    }
  }

  Future<void> _startListeners({required String canonicalId, String? legacyId}) async {
    // clear in-memory caches for a fresh start (do not delete local DB)
    _fingerprintIndex.clear();
    _idToFingerprint.clear();
    _legacyDuplicateCounter.clear();

    // canonical listener
    final collRef = _firestore.collection('conversations').doc(canonicalId).collection('messages');
    _sub = collRef.orderBy('createdAt', descending: false).snapshots().listen((snap) {
      _applySnapshotToMap(snap, convId: canonicalId, isLegacy: false);
    }, onError: (e, st) {
      errorMessage = e.toString();
      notifyListeners();
      debugPrint('[ChatVM] canonical listener error: $e\n$st');
    });

    // legacy listener only if provided & different
    if (legacyId != null && legacyId.isNotEmpty && legacyId != canonicalId) {
      final legacyRef = _firestore.collection('conversations').doc(legacyId).collection('messages');
      _legacySub = legacyRef.orderBy('createdAt', descending: false).snapshots().listen((snap) {
        _applySnapshotToMap(snap, convId: legacyId, isLegacy: true);
      }, onError: (e, st) {
        debugPrint('[ChatVM] legacy listener error for $legacyId: $e');
      });
      debugPrint('[ChatVM] listening to legacy doc $legacyId and canonical $canonicalId');
    } else {
      debugPrint('[ChatVM] listening only to canonical doc $canonicalId');
    }
  }

  /// Apply snapshot into local in-memory map, persist novel messages to local DB,
  /// and send ACK for messages received by this device.
  void _applySnapshotToMap(QuerySnapshot snap, {required String convId, required bool isLegacy}) {
    var changed = false;
    var novelFound = false;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    for (final doc in snap.docs) {
      // safe parsing: wrap in try/catch per doc
      ChatMessage cm;
      try {
        cm = ChatMessage.fromDoc(doc, conversationIdOverride: convId);
      } catch (e) {
        debugPrint('[ChatVM] parse error for doc ${doc.id}: $e');
        continue;
      }

      final fp = _makeFingerprint(cm);

      // If we already have a message with same doc id -> update it
      if (_messagesMap.containsKey(cm.id)) {
        final prev = _messagesMap[cm.id]!;
        final prevFp = _idToFingerprint[cm.id];
        if (prev.createdAt.millisecondsSinceEpoch != cm.createdAt.millisecondsSinceEpoch ||
            prev.text != cm.text ||
            prev.isDeleted != cm.isDeleted ||
            prev.delivered != cm.delivered) {
          _messagesMap[cm.id] = cm;
          changed = true;
        }
        if (prevFp != fp) {
          if (prevFp != null) _fingerprintIndex.remove(prevFp);
          _fingerprintIndex[fp] = cm.id;
          _idToFingerprint[cm.id] = fp;
        }
        // persist latest into local DB (upsert) - this will replace optimistic entry if id matches
        _persistToLocal(cm);
        // maybe ACK if needed
        _maybeAcknowledgeIfNeeded(cm, convId: convId, currentUid: currentUid);
        continue;
      }

      // If fingerprint already mapped => treat as duplicate message (different doc id)
      if (_fingerprintIndex.containsKey(fp)) {
        final existingId = _fingerprintIndex[fp]!;
        final existing = _messagesMap[existingId];
        if (existing == null) {
          // stale mapping: replace mapping with this doc
          _messagesMap[cm.id] = cm;
          _fingerprintIndex[fp] = cm.id;
          _idToFingerprint[cm.id] = fp;
          changed = true;
          novelFound = true;
          _persistToLocal(cm);
          _maybeAcknowledgeIfNeeded(cm, convId: convId, currentUid: currentUid);
          continue;
        }

        // Decide whether to replace existing entry content (prefer newer createdAt)
        final shouldReplace =
            cm.createdAt.millisecondsSinceEpoch > existing.createdAt.millisecondsSinceEpoch ||
                cm.text != existing.text ||
                cm.isDeleted != existing.isDeleted;
        if (shouldReplace) {
          _messagesMap[existingId] = cm;
          _idToFingerprint[existingId] = fp;
          changed = true;
        }
        // Persist latest to local DB and ACK if needed
        _persistToLocal(cm);
        _maybeAcknowledgeIfNeeded(cm, convId: convId, currentUid: currentUid);
        continue;
      }

      // New message (fingerprint + docId)
      _messagesMap[cm.id] = cm;
      _fingerprintIndex[fp] = cm.id;
      _idToFingerprint[cm.id] = fp;
      changed = true;
      novelFound = true;

      _persistToLocal(cm);
      _maybeAcknowledgeIfNeeded(cm, convId: convId, currentUid: currentUid);
    }

    // Heuristic: if legacy only produces duplicates repeatedly, cancel it
    if (isLegacy) {
      final cnt = _legacyDuplicateCounter[convId] ?? 0;
      if (!novelFound) {
        final next = cnt + 1;
        _legacyDuplicateCounter[convId] = next;
        if (next >= 2) {
          debugPrint('[ChatVM] legacy listener $convId produced only duplicates $next times - cancelling legacy listener');
          _cancelLegacyListener(convId);
        }
      } else {
        _legacyDuplicateCounter[convId] = 0;
      }
    }

    if (changed) {
      _rebuildMessagesFromMap();
      isLoading = false;
      notifyListeners();
    } else {
      if (isLoading) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Persist message to local DB (upsert). Runs best-effort (non-blocking for UI).
  void _persistToLocal(ChatMessage m) {
    LocalChatDb.upsertMessage(m).catchError((e) {
      debugPrint('[ChatVM] local persist failed for ${m.id}: $e');
    });
  }

  /// Acknowledge message: if we are the recipient and message not yet delivered, set delivered true.
  void _maybeAcknowledgeIfNeeded(ChatMessage m, {required String convId, String? currentUid}) {
    try {
      currentUid ??= FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null) return;
      // don't ACK our own messages
      if (m.senderId == currentUid) return;
      if (m.isDeleted) return;
      if (m.delivered) return; // already delivered according to server

      // avoid duplicate ACK attempts for same doc
      final ackKey = '$convId::${m.id}';
      if (_ackInProgress.contains(ackKey)) return;

      _ackInProgress.add(ackKey);

      // mark delivered on server (idempotent update)
      _firestore
          .collection('conversations')
          .doc(convId)
          .collection('messages')
          .doc(m.id)
          .set({
            'delivered': true,
            'deliveredAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .then((_) async {
            // reflect delivered flag in local DB
            final nowTs = Timestamp.now();
            await LocalChatDb.markDelivered(convId, m.id, deliveredAt: nowTs);
          })
          .catchError((e) {
            debugPrint('[ChatVM] ACK failed for ${m.id}: $e');
          })
          .whenComplete(() {
            _ackInProgress.remove(ackKey);
          });
    } catch (e) {
      debugPrint('[ChatVM] _maybeAcknowledgeIfNeeded error: $e');
    }
  }

  String _makeFingerprint(ChatMessage m) {
    // fingerprint uses normalized (trimmed, collapsed whitespace) text + sender + createdAt
    final normalizedText = _normalizeWhitespace(m.text);
    return '${m.senderId}_${m.createdAt.millisecondsSinceEpoch}_$normalizedText';
  }

  String _normalizeWhitespace(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  Future<void> _cancelLegacyListener(String legacyConvId) async {
    if (_legacySub == null) return;
    try {
      await _legacySub!.cancel();
    } catch (_) {}
    _legacySub = null;
    _legacyDuplicateCounter.remove(legacyConvId);
    debugPrint('[ChatVM] legacy listener cancelled for $legacyConvId');
    // intentionally DO NOT remove messages from in-memory map or local DB
  }

  /// Try to resolve possibly publicId (like "0xABCD") to uid.
  Future<String?> _resolveToUidIfNeeded(String part) async {
    try {
      if (part.isEmpty) return null;
      // quick check: if user doc exists with id == part, treat as uid
      final doc = await _firestore.collection('users').doc(part).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey('uid')) return (data['uid'] as String?) ?? doc.id;
        return doc.id;
      }

      if (part.startsWith('0x')) {
        final q = await _firestore.collection('users').where('name', isEqualTo: part).limit(1).get();
        if (q.docs.isNotEmpty) {
          final d = q.docs.first.data();
          if (d.containsKey('uid')) return (d['uid'] as String?) ?? q.docs.first.id;
          return q.docs.first.id;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[ChatVM] _resolveToUidIfNeeded error for $part: $e');
      return null;
    }
  }

  Future<String?> _findConversationWithMembers(String currentUid, String otherCandidate) async {
    try {
      final q = await _firestore.collection('conversations').where('members', arrayContains: currentUid).limit(200).get();
      for (final d in q.docs) {
        final members = (d.data()['members'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        if (members.contains(currentUid) && members.contains(otherCandidate)) {
          return d.id;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[ChatVM] _findConversationWithMembers error: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _legacySub?.cancel();
    _sub = null;
    _legacySub = null;
    super.dispose();
  }

  // ---------------- messaging ----------------

  /// Generate a reasonably-unique local id (safe without external uuid package)
  String _generateLocalId(String senderUid) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rnd = Random().nextInt(1 << 31);
    final short = senderUid.isNotEmpty ? senderUid.substring(0, min(6, senderUid.length)) : 'anon';
    return 'loc_${short}_$now\_$rnd';
  }

  /// Send message: local-first (save to local DB, optimistic UI), then upload to Firestore using the SAME id.
  /// If upload fails, mark sendState 'failed' and increment attempts; pending messages are retried by _syncPendingMessages().
  Future<void> sendTextMessage(String text, {String? replyToMessageId}) async {
    final user = FirebaseAuth.instance.currentUser;
    final senderUid = user?.uid;
    if (senderUid == null) throw StateError('User not authenticated');

    isSending = true;
    notifyListeners();

    // ensure conversation canonicalization for publicId parts
    final parts = conversationId.split('_');
    if (parts.length == 2 && (parts[0].startsWith('0x') || parts[1].startsWith('0x'))) {
      final r0 = await _resolveToUidIfNeeded(parts[0]) ?? parts[0];
      final r1 = await _resolveToUidIfNeeded(parts[1]) ?? parts[1];
      final sorted = [r0, r1]..sort();
      final canonical = '${sorted[0]}_${sorted[1]}';
      if (canonical != conversationId) {
        conversationId = canonical;
      }
    }

    // create local id and local ChatMessage (include expiresAt), mark sendState = 'pending'
    final localId = _generateLocalId(senderUid);
    final expiresTs = Timestamp.fromDate(DateTime.now().toUtc().add(messageTTL));
    final localMsg = ChatMessage(
      id: localId,
      conversationId: conversationId,
      text: text,
      senderId: senderUid,
      createdAt: Timestamp.now(),
      replyToMessageId: replyToMessageId,
      isLocal: true,
      delivered: false,
      expiresAt: expiresTs,
      sendState: 'pending',
      sendAttempts: 0,
    );

    // optimistic: insert into in-memory map + persist local DB + UI
    final fp = _makeFingerprint(localMsg);
    _messagesMap[localMsg.id] = localMsg;
    _fingerprintIndex[fp] = localMsg.id;
    _idToFingerprint[localMsg.id] = fp;
    _rebuildMessagesFromMap();

    await LocalChatDb.upsertMessage(localMsg); // persist before attempting upload
    notifyListeners();

    try {
      // ensure conversation doc members updated (best-effort)
      final convRef = _firestore.collection('conversations').doc(conversationId);
      final parts2 = conversationId.split('_');
      if (parts2.length == 2 && parts2[0].isNotEmpty && parts2[1].isNotEmpty) {
        var other = (parts2[0] == senderUid) ? parts2[1] : parts2[0];
        if (other.startsWith('0x')) {
          final r = await _resolveToUidIfNeeded(other);
          if (r != null) other = r;
        }
        await convRef.set({
          'members': FieldValue.arrayUnion([senderUid, other]),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await convRef.set({
          'members': FieldValue.arrayUnion([senderUid]),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // attempt immediate upload (idempotent set)
      final msgRef = convRef.collection('messages').doc(localMsg.id);
      await msgRef.set(localMsg.toMapForSend(ttl: messageTTL));
      // note: snapshot will replace the local placeholder with server copy (same id)
      // update local sendState to 'sending' (best-effort) - actual 'sent' will be via snapshot/server-existence
      await LocalChatDb.updateSendState(conversationId, localMsg.id, 'sending', sendAttempts: 1);
    } catch (e, st) {
      // mark failed & increment attempts (do not remove local placeholder)
      final failedAttempts = localMsg.sendAttempts + 1;
      await LocalChatDb.updateSendState(conversationId, localMsg.id, 'failed', sendAttempts: failedAttempts);
      // update in-memory map too
      final updatedLocal = localMsg.copyWith(sendState: 'failed', sendAttempts: failedAttempts);
      _messagesMap[localMsg.id] = updatedLocal;
      _rebuildMessagesFromMap();
      errorMessage = e.toString();
      debugPrint('[ChatVM] sendTextMessage error: $e\n$st');
      // do not rethrow: keep UI responsive and rely on sync queue
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  /// Attempts to upload pending/failed messages from local DB.
  /// Call on init, on app resume, or on connectivity regained.
  Future<void> _syncPendingMessages({int maxAttempts = 5}) async {
    try {
      final pending = await LocalChatDb.getPendingMessages(conversationId, maxAttempts: maxAttempts);
      if (pending.isEmpty) return;

      debugPrint('[ChatVM] syncing ${pending.length} pending messages for $conversationId');

      for (final m in pending) {
        // optimistic update sendState -> 'sending'
        await LocalChatDb.updateSendState(conversationId, m.id, 'sending', sendAttempts: m.sendAttempts + 1);
        final convRef = _firestore.collection('conversations').doc(conversationId);
        final msgRef = convRef.collection('messages').doc(m.id);
        try {
          await msgRef.set(m.toMapForSend(ttl: messageTTL));
          // best-effort: mark as 'sending' (server snapshot will mark 'sent')
          // local DB will be updated by snapshot/upsert; still mark sendState to 'sending' here:
          await LocalChatDb.updateSendState(conversationId, m.id, 'sending', sendAttempts: m.sendAttempts + 1);
        } catch (e) {
          // mark failed, will be retried later
          final attempts = m.sendAttempts + 1;
          final newState = attempts >= maxAttempts ? 'failed' : 'failed';
          await LocalChatDb.updateSendState(conversationId, m.id, newState, sendAttempts: attempts);
          debugPrint('[ChatVM] _syncPendingMessages upload failed for ${m.id}: $e');
        }
      }

      // reload local messages into memory to reflect state changes
      await _loadLocalMessages();
      notifyListeners();
    } catch (e) {
      debugPrint('[ChatVM] _syncPendingMessages error: $e');
    }
  }

  /// Public method you can call from app lifecycle hooks (e.g. onResume) or connectivity listener
  Future<void> syncPendingMessages() async => _syncPendingMessages();

  void _rebuildMessagesFromMap() {
    final list = _messagesMap.values.toList()
      ..sort((a, b) => a.createdAt.millisecondsSinceEpoch.compareTo(b.createdAt.millisecondsSinceEpoch));
    messages = list;
    notifyListeners();
  }

  Future<void> softDeleteMessage(String messageId) async {
    try {
      await _firestore.collection('conversations').doc(conversationId).collection('messages').doc(messageId).set({'isDeleted': true, 'lastUpdated': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      // optimistic local update
      final local = _messagesMap[messageId];
      if (local != null) {
        final updated = local.copyWith(isLocal: local.isLocal, sendState: local.sendState);
        final replaced = ChatMessage(
          id: local.id,
          conversationId: local.conversationId,
          text: local.text,
          senderId: local.senderId,
          createdAt: local.createdAt,
          replyToMessageId: local.replyToMessageId,
          isDeleted: true,
          isLocal: local.isLocal,
          delivered: local.delivered,
          deliveredAt: local.deliveredAt,
          expiresAt: local.expiresAt,
          sendState: local.sendState,
          sendAttempts: local.sendAttempts,
        );
        _messagesMap[messageId] = replaced;
        LocalChatDb.upsertMessage(replaced).catchError((e) => debugPrint('[ChatVM] local soft-delete failed $e'));
        _rebuildMessagesFromMap();
      }
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // selection helpers
  void startSelection(String messageId) {
    selectedMessageIds = {messageId};
    notifyListeners();
  }

  void toggleSelection(String messageId) {
    if (selectedMessageIds.contains(messageId)) selectedMessageIds.remove(messageId);
    else selectedMessageIds.add(messageId);
    notifyListeners();
  }

  void clearSelection() {
    if (selectedMessageIds.isNotEmpty) {
      selectedMessageIds.clear();
      notifyListeners();
    }
  }

  ChatMessage? findMessageById(String id) {
    return _messagesMap[id];
  }

  /// Return a Firestore-backed stream (if needed elsewhere). Note: prefer local DB for UI.
  Stream<List<ChatMessage>> messagesStream() {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ChatMessage.fromDoc(d, conversationIdOverride: conversationId)).toList());
  }
}
