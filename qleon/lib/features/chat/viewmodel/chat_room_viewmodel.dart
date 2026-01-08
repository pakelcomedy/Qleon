// lib/features/chat/viewmodel/chat_room_viewmodel.dart
// Offline-first ChatRoomViewModel with media & location support.
// - SQLite local source-of-truth (messages table extended for media/location)
// - Firestore as transient queue (message metadata + inline media stored here OR chunked in subcollection)
// - optimistic send, pending queue, retries, ACK+DELETE handling
// - media are written to local cache on receive to avoid storing big blobs in DB

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';

/// -----------------------------
/// Data model
/// -----------------------------
/// type: 'text' | 'image' | 'file' | 'location'
class ChatMessage {
  final String id;
  final String conversationId;
  final String type;
  final String? text; // for text messages or captions
  final String? localPath; // local file path when available (for images/files)
  final String? remoteUrl; // legacy field (unused when storing inline media)
  final String? remoteData; // base64 inline media payload when stored in Firestore (may be removed after saving locally)
  final String? mimeType;
  final String? fileName;
  final int? fileSize;
  final double? latitude;
  final double? longitude;
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
    this.type = 'text',
    this.text,
    this.localPath,
    this.remoteUrl,
    this.remoteData,
    this.mimeType,
    this.fileName,
    this.fileSize,
    this.latitude,
    this.longitude,
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

  /// From Firestore server doc
  factory ChatMessage.fromDoc(QueryDocumentSnapshot doc, {String? conversationIdOverride}) {
    final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
    final rawCreatedAt = data['createdAt'];
    final createdAt = (rawCreatedAt is Timestamp) ? rawCreatedAt : Timestamp.now();
    final delivered = (data['delivered'] as bool?) ?? false;
    final deliveredAt = (data['deliveredAt'] is Timestamp) ? data['deliveredAt'] as Timestamp : null;
    final expiresAt = (data['expiresAt'] is Timestamp) ? data['expiresAt'] as Timestamp : null;
    final type = (data['type'] as String?) ?? 'text';
    final media = (data['media'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final lat = (data['latitude'] is num) ? (data['latitude'] as num).toDouble() : null;
    final lng = (data['longitude'] is num) ? (data['longitude'] as num).toDouble() : null;

    // safe fileSize extraction
    int? fileSize;
    if (media.containsKey('size')) {
      final s = media['size'];
      if (s is int) fileSize = s;
      else if (s is num) fileSize = s.toInt();
    }

    final remoteData = media['data'] is String ? media['data'] as String : null;
    return ChatMessage(
      id: doc.id,
      conversationId: conversationIdOverride ?? (data['conversationId']?.toString() ?? ''),
      type: type,
      text: (data['text'] as String?) ?? '',
      localPath: null,
      remoteUrl: media['url']?.toString(),
      remoteData: remoteData,
      mimeType: media['mime']?.toString(),
      fileName: media['name']?.toString(),
      fileSize: fileSize,
      latitude: lat,
      longitude: lng,
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
  Map<String, dynamic> toMapForSend({Duration? ttl, String? inlineBase64, bool chunked = false, int? chunksCount}) {
    final Map<String, dynamic> m = {
      'type': type,
      'text': text ?? '',
      'senderId': senderId,
      'createdAt': FieldValue.serverTimestamp(),
      'replyToMessageId': replyToMessageId,
      'isDeleted': isDeleted,
      'delivered': false,
      'conversationId': conversationId,
    };
    if (chunked) {
      // chunk metadata only
      m['media'] = {
        'chunked': true,
        'mime': mimeType ?? '',
        'name': fileName ?? '',
        'size': fileSize ?? 0,
        'chunksCount': chunksCount ?? 0,
      };
    } else if (inlineBase64 != null && inlineBase64.isNotEmpty) {
      m['media'] = {
        'data': inlineBase64,
        'mime': mimeType ?? '',
        'name': fileName ?? '',
        'size': fileSize ?? 0,
      };
    } else if (remoteUrl != null && remoteUrl!.isNotEmpty) {
      m['media'] = {
        'url': remoteUrl,
        'mime': mimeType,
        'name': fileName,
        'size': fileSize,
      };
    }
    if (latitude != null && longitude != null) {
      m['latitude'] = latitude;
      m['longitude'] = longitude;
    }
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
      'type': type,
      'text': text,
      'localPath': localPath,
      'remoteUrl': remoteUrl,
      'remoteData': remoteData,
      'mimeType': mimeType,
      'fileName': fileName,
      'fileSize': fileSize,
      'latitude': latitude,
      'longitude': longitude,
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
      type: (row['type'] as String?) ?? 'text',
      text: (row['text'] as String?),
      localPath: (row['localPath'] as String?),
      remoteUrl: (row['remoteUrl'] as String?),
      remoteData: (row['remoteData'] as String?),
      mimeType: (row['mimeType'] as String?),
      fileName: (row['fileName'] as String?),
      fileSize: (row['fileSize'] as int?),
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
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
    bool? isDeleted,
    String? remoteUrl,
    String? localPath,
    String? remoteData,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      type: type,
      text: text,
      localPath: localPath ?? this.localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      remoteData: remoteData ?? this.remoteData,
      mimeType: mimeType,
      fileName: fileName,
      fileSize: fileSize,
      latitude: latitude,
      longitude: longitude,
      senderId: senderId,
      createdAt: createdAt,
      replyToMessageId: replyToMessageId,
      isDeleted: isDeleted ?? this.isDeleted,
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
  // bumped to 5 to ensure remoteData column exists (if migrating)
  static const _dbVersion = 5;
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
          type TEXT DEFAULT 'text',
          text TEXT,
          localPath TEXT,
          remoteUrl TEXT,
          remoteData TEXT,
          mimeType TEXT,
          fileName TEXT,
          fileSize INTEGER,
          latitude REAL,
          longitude REAL,
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
      if (oldV < 2) {
        try {
          await db.execute("ALTER TABLE messages ADD COLUMN sendState TEXT DEFAULT 'sent';");
          await db.execute("ALTER TABLE messages ADD COLUMN sendAttempts INTEGER DEFAULT 0;");
          await db.execute('CREATE INDEX IF NOT EXISTS idx_conv_sendState ON messages(conversationId, sendState);');
        } catch (e) {
          debugPrint('[LocalChatDb] migration v1->v2 failed: $e');
        }
      }
      if (oldV < 3) {
        try {
          await db.execute("ALTER TABLE messages ADD COLUMN type TEXT DEFAULT 'text';");
          await db.execute("ALTER TABLE messages ADD COLUMN localPath TEXT;");
          await db.execute("ALTER TABLE messages ADD COLUMN remoteUrl TEXT;");
          await db.execute("ALTER TABLE messages ADD COLUMN mimeType TEXT;");
          await db.execute("ALTER TABLE messages ADD COLUMN fileName TEXT;");
          await db.execute("ALTER TABLE messages ADD COLUMN fileSize INTEGER;");
          await db.execute("ALTER TABLE messages ADD COLUMN latitude REAL;");
          await db.execute("ALTER TABLE messages ADD COLUMN longitude REAL;");
        } catch (e) {
          debugPrint('[LocalChatDb] migration to v3 failed: $e');
        }
      }
      if (oldV < 4) {
        try {
          await db.execute("ALTER TABLE messages ADD COLUMN remoteData TEXT;");
        } catch (e) {
          debugPrint('[LocalChatDb] migration to v4 failed: $e');
        }
      }
      if (oldV < 5) {
        // nothing extra, keep for future
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

  static Future<List<ChatMessage>> getUndeliveredMessages(String conversationId, String excludeSenderId, {int limit = 100}) async {
    final rows = await db.query(
      'messages',
      where: 'conversationId = ? AND delivered = 0 AND senderId != ?',
      whereArgs: [conversationId, excludeSenderId],
      orderBy: 'createdAt ASC',
      limit: limit,
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

  static Future<void> deleteMessage(String conversationId, String messageId) async {
    await db.delete('messages', where: 'conversationId = ? AND id = ?', whereArgs: [conversationId, messageId]);
  }

  static Future<void> clearConversation(String conversationId) async {
    await db.delete('messages', where: 'conversationId = ?', whereArgs: [conversationId]);
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

  // small local helper to intentionally run a future without awaiting it
  void _unawaited(Future<void> f) {
    f.catchError((e) {
      debugPrint('[ChatVM] unawaited error: $e');
    });
  }

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

      // Load local messages to show immediately (UI must read only from local DB)
      await _loadLocalMessages();

      // cleanup expired local messages for this conversation (best-effort)
      try {
        final beforeMillis = DateTime.now().toUtc().millisecondsSinceEpoch;
        await LocalChatDb.deleteExpiredMessages(conversationId, beforeMillis);
      } catch (e) {
        debugPrint('[ChatVM] local cleanup expired failed: $e');
      }

      // Try to sync pending messages (upload queue) on init (fire-and-forget)
      _unawaited(_syncPendingMessages());

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
      // reset in-memory map and rebuild from local DB (local is source-of-truth for UI)
      _messagesMap.clear();
      _fingerprintIndex.clear();
      _idToFingerprint.clear();
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
    _sub = collRef.orderBy('createdAt', descending: false).snapshots().listen((snap) async {
      await _applySnapshotToMap(snap, convId: canonicalId, isLegacy: false);
    }, onError: (e, st) {
      errorMessage = e.toString();
      notifyListeners();
      debugPrint('[ChatVM] canonical listener error: $e\n$st');
    });

    // legacy listener only if provided & different
    if (legacyId != null && legacyId.isNotEmpty && legacyId != canonicalId) {
      final legacyRef = _firestore.collection('conversations').doc(legacyId).collection('messages');
      _legacySub = legacyRef.orderBy('createdAt', descending: false).snapshots().listen((snap) async {
        await _applySnapshotToMap(snap, convId: legacyId, isLegacy: true);
      }, onError: (e, st) {
        debugPrint('[ChatVM] legacy listener error for $legacyId: $e');
      });
      debugPrint('[ChatVM] listening to legacy doc $legacyId and canonical $canonicalId');
    } else {
      debugPrint('[ChatVM] listening only to canonical doc $canonicalId');
    }
  }

  Future<void> _applySnapshotToMap(QuerySnapshot snap, {required String convId, required bool isLegacy}) async {
    var changed = false;
    var novelFound = false;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    for (final doc in snap.docs) {
      ChatMessage cm;
      try {
        cm = ChatMessage.fromDoc(doc, conversationIdOverride: convId);
      } catch (e) {
        debugPrint('[ChatVM] parse error for doc ${doc.id}: $e');
        continue;
      }

      final fp = _makeFingerprint(cm);

      // Dedup: if fingerprint exists and points to same content, skip heavy work.
      if (_fingerprintIndex.containsKey(fp)) {
        final existingId = _fingerprintIndex[fp]!;
        final existing = _messagesMap[existingId];
        if (existing != null) {
          // heuristics: if server copy isn't newer or different, skip
          final shouldReplace = cm.createdAt.millisecondsSinceEpoch > existing.createdAt.millisecondsSinceEpoch ||
              cm.text != existing.text ||
              cm.isDeleted != existing.isDeleted ||
              cm.remoteUrl != existing.remoteUrl ||
              cm.remoteData != existing.remoteData;
          if (!shouldReplace) {
            // still attempt to ACK+DELETE if needed (in case server still holds a copy)
            await _ackAndDeleteIfNeeded(cm, convId: convId, currentUid: currentUid);
            continue;
          }
        }
      }

      // If chunked message -> try assemble chunks first
      final docData = doc.data() as Map<String, dynamic>? ?? {};
      final media = (docData['media'] as Map<String, dynamic>?) ?? {};
      final isChunked = (media['chunked'] as bool?) ?? false;
      if (isChunked) {
        final chunksCount = (media['chunksCount'] is int) ? media['chunksCount'] as int : (media['chunksCount'] is num ? (media['chunksCount'] as num).toInt() : null);
        if (chunksCount == null || chunksCount <= 0) {
          // malformed chunked message — skip
          debugPrint('[ChatVM] chunked message ${doc.id} missing chunksCount — skipping until available');
          continue;
        }
        // fetch chunks
        try {
          final chunksSnap = await _firestore.collection('conversations').doc(convId).collection('messages').doc(doc.id).collection('chunks').orderBy('seq').get();
          if (chunksSnap.docs.length < chunksCount) {
            debugPrint('[ChatVM] chunks for ${doc.id} not complete yet (${chunksSnap.docs.length}/$chunksCount) — skipping for now');
            continue; // wait until all chunks present
          }
          final sb = StringBuffer();
          for (final c in chunksSnap.docs) {
            final cdata = c.data();
            if (cdata.containsKey('data') && cdata['data'] is String) sb.write(cdata['data'] as String);
            else {
              debugPrint('[ChatVM] chunk ${c.id} missing data, abort assemble');
              sb.clear();
              break;
            }
          }
          final assembledBase64 = sb.isEmpty ? null : sb.toString();
          if (assembledBase64 != null && assembledBase64.isNotEmpty) {
            // attach assembled base64 to cm.remoteData so persisting & local save will occur
            cm = cm.copyWith(remoteData: assembledBase64);
          } else {
            debugPrint('[ChatVM] assembled base64 empty for ${doc.id}');
            continue;
          }
        } catch (e) {
          debugPrint('[ChatVM] error fetching chunks for ${doc.id}: $e');
          continue;
        }
      }

      // Persist server message into local DB FIRST (critical: local-first)
      try {
        await _persistToLocal(cm);
        novelFound = true;
      } catch (e) {
        debugPrint('[ChatVM] failed to persist server msg ${cm.id} locally: $e');
        // do not ACK or DELETE if local persist failed
        continue;
      }

      // If message has inline media (remoteData), save to disk and update local record
      if (cm.remoteData != null && (cm.localPath == null || cm.localPath!.isEmpty)) {
        try {
          await _saveMediaLocallyIfNeeded(cm);
        } catch (e) {
          debugPrint('[ChatVM] saving media locally failed for ${cm.id}: $e');
        }
      }

      // After local persistence succeeded, attempt ACK and DELETE on server (also delete chunks subcollection if present)
      await _ackAndDeleteIfNeeded(cm, convId: convId, currentUid: currentUid);

      // update fingerprint/index to avoid reprocessing
      _fingerprintIndex[fp] = cm.id;
      _idToFingerprint[cm.id] = fp;
      _messagesMap[cm.id] = cm; // keep a transient mapping (final state will come from local DB load)
      changed = true;
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

    // Important: UI should read from local DB (source-of-truth). Reload local messages if something novel changed.
    if (changed || novelFound) {
      await _loadLocalMessages();
      isLoading = false;
      notifyListeners();
    } else {
      if (isLoading) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _persistToLocal(ChatMessage m) async {
    try {
      await LocalChatDb.upsertMessage(m);
    } catch (e) {
      debugPrint('[ChatVM] local persist failed for ${m.id}: $e');
      rethrow;
    }
  }

  /// Save inline base64 media to app cache and update local DB with localPath.
  /// After successful write, remoteData in DB is cleared to avoid DB bloat.
  Future<void> _saveMediaLocallyIfNeeded(ChatMessage m) async {
    if (m.remoteData == null || m.remoteData!.isEmpty) return;
    try {
      final bytes = base64Decode(m.remoteData!);
      final cacheDir = await getTemporaryDirectory();
      final convDir = Directory(p.join(cacheDir.path, 'conversations', conversationId));
      if (!await convDir.exists()) await convDir.create(recursive: true);

      // create safe filename using message id + original name or mime
      final safeName = (m.fileName != null && m.fileName!.isNotEmpty)
          ? '${m.id}_${m.fileName}'
          : '${m.id}.${_extensionFromMime(m.mimeType)}';
      final filePath = p.join(convDir.path, safeName);

      final f = File(filePath);
      await f.writeAsBytes(bytes, flush: true);

      // Update local DB: set localPath and clear remoteData (to avoid big DB entry)
      final updated = m.copyWith(localPath: filePath, remoteData: null);
      await LocalChatDb.upsertMessage(updated);

      // update in-memory map as well
      _messagesMap[m.id] = updated;
      debugPrint('[ChatVM] saved media locally for ${m.id} -> $filePath');
    } catch (e) {
      debugPrint('[ChatVM] _saveMediaLocallyIfNeeded error for ${m.id}: $e');
      rethrow;
    }
  }

  String _extensionFromMime(String? mime) {
    if (mime == null || mime.isEmpty) return 'bin';
    final parts = mime.split('/');
    if (parts.length == 2) {
      final subtype = parts[1].split('+').first;
      return subtype.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    }
    return 'bin';
  }

  Future<void> _ackAndDeleteIfNeeded(ChatMessage m, {required String convId, String? currentUid}) async {
    try {
      currentUid ??= FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null) return;
      // don't ACK our own messages
      if (m.senderId == currentUid) return;
      if (m.isDeleted) return;

      final ackKey = '$convId::${m.id}';
      if (_ackInProgress.contains(ackKey)) return;
      _ackInProgress.add(ackKey);

      final docRef = _firestore.collection('conversations').doc(convId).collection('messages').doc(m.id);

      try {
        // 1) mark delivered state (idempotent)
        await docRef.set({
          'delivered': true,
          'deliveredAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 2) if chunked -> delete chunks subcollection first
        try {
          final docSnap = await docRef.get();
          if (docSnap.exists) {
            final data = docSnap.data() as Map<String, dynamic>? ?? {};
            final media = (data['media'] as Map<String, dynamic>?) ?? {};
            final isChunked = (media['chunked'] as bool?) ?? false;
            if (isChunked) {
              final chunksColl = docRef.collection('chunks');
              final chunksSnap = await chunksColl.get();
              final batch = _firestore.batch();
              for (final ch in chunksSnap.docs) {
                batch.delete(ch.reference);
              }
              await batch.commit();
            }
          }
        } catch (e) {
          debugPrint('[ChatVM] warning deleting chunks for ${m.id}: $e');
          // continue to try deleting doc anyway
        }

        // 3) delete the server copy (transient queue)
        await docRef.delete();

        // 4) mark local DB as delivered
        await LocalChatDb.markDelivered(convId, m.id, deliveredAt: Timestamp.now());
        debugPrint('[ChatVM] ACK+DELETE success for ${m.id}');
      } catch (e) {
        debugPrint('[ChatVM] ACK+DELETE failed for ${m.id}: $e');
      } finally {
        _ackInProgress.remove(ackKey);
      }
    } catch (e) {
      debugPrint('[ChatVM] _ackAndDeleteIfNeeded error: $e');
    }
  }

  // ----------------- MEDIA / LOCATION SEND API -----------------

  /// Generic media sender. type: 'image' or 'file'
  /// Steps:
  /// 1) create local optimistic message with localPath set, sendState 'pending'
  /// 2) persist local
  /// 3) read file bytes, if small -> inline base64 to message doc; if large -> chunk and store chunks subcollection
  /// 4) write Firestore metadata doc (serverTimestamp)
  /// 5) mark local sendState 'sent' or 'failed'
  Future<void> sendMediaMessage(File file, {required String type, String? mimeType, String? fileName, String? replyToMessageId}) async {
    final user = FirebaseAuth.instance.currentUser;
    final senderUid = user?.uid;
    if (senderUid == null) throw StateError('User not authenticated');

    isSending = true;
    notifyListeners();

    final localId = _generateLocalId(senderUid);
    final createdAt = Timestamp.now();
    final expiresTs = Timestamp.fromDate(DateTime.now().toUtc().add(messageTTL));

    final fn = fileName ?? p.basename(file.path);
    final fSize = await file.length().catchError((_) => 0);

    // optimistic local message
    final localMsg = ChatMessage(
      id: localId,
      conversationId: conversationId,
      type: type,
      text: null,
      localPath: file.path,
      remoteUrl: null,
      remoteData: null,
      mimeType: mimeType,
      fileName: fn,
      fileSize: fSize,
      latitude: null,
      longitude: null,
      senderId: senderUid,
      createdAt: createdAt,
      replyToMessageId: replyToMessageId,
      isLocal: true,
      delivered: false,
      expiresAt: expiresTs,
      sendState: 'pending',
      sendAttempts: 0,
    );

    // persist local optimistic
    final fp = _makeFingerprint(localMsg);
    _messagesMap[localMsg.id] = localMsg;
    _fingerprintIndex[fp] = localMsg.id;
    _idToFingerprint[localMsg.id] = fp;
    _rebuildMessagesFromMap();
    await LocalChatDb.upsertMessage(localMsg);
    notifyListeners();

    try {
      final bytes = await file.readAsBytes();

      // Firestore single-doc limit ~1 MiB; base64 expands ~33%. Use safe thresholds.
      const safeLimitBytes = 750 * 1024; // ~750KB raw
      if (bytes.length <= safeLimitBytes) {
        // inline small file
        final base64Data = base64Encode(bytes);

        final convRef = _firestore.collection('conversations').doc(conversationId);
        final msgRef = convRef.collection('messages').doc(localId);

        final metadata = {
          'data': base64Data,
          'mime': mimeType ?? '',
          'name': fn,
          'size': fSize,
        };

        final Map<String, dynamic> toWrite = {
          'type': type,
          'media': metadata,
          'senderId': senderUid,
          'conversationId': conversationId,
          'replyToMessageId': replyToMessageId,
          'createdAt': FieldValue.serverTimestamp(),
          'delivered': false,
        };
        if (messageTTL != Duration.zero) {
          final expiry = DateTime.now().toUtc().add(messageTTL);
          toWrite['expiresAt'] = Timestamp.fromDate(expiry);
        }

        // ensure conversation doc members updated (best-effort)
        try {
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
        } catch (_) {}

        await msgRef.set(toWrite);

        // update local message with remoteData (we keep remoteData briefly so local save step will work in receiver)
        final updatedLocal = localMsg.copyWith(
          sendState: 'sent',
          sendAttempts: localMsg.sendAttempts + 1,
          isLocal: false,
          remoteData: base64Data,
        );
        await LocalChatDb.upsertMessage(updatedLocal);
        _messagesMap[localId] = updatedLocal;
        _rebuildMessagesFromMap();
        notifyListeners();
      } else {
        // chunk large file
        final chunkSize = 256 * 1024; // 256KB per chunk (tunable)
        final chunks = <String>[];
        for (var i = 0; i < bytes.length; i += chunkSize) {
          final end = min(i + chunkSize, bytes.length);
          final slice = bytes.sublist(i, end);
          chunks.add(base64Encode(slice));
        }
        final chunksCount = chunks.length;

        final convRef = _firestore.collection('conversations').doc(conversationId);
        final msgRef = convRef.collection('messages').doc(localId);

        // create message doc with chunk metadata
        final Map<String, dynamic> toWrite = {
          'type': type,
          'media': {
            'chunked': true,
            'mime': mimeType ?? '',
            'name': fn,
            'size': fSize,
            'chunksCount': chunksCount,
          },
          'senderId': senderUid,
          'conversationId': conversationId,
          'replyToMessageId': replyToMessageId,
          'createdAt': FieldValue.serverTimestamp(),
          'delivered': false,
        };
        if (messageTTL != Duration.zero) {
          final expiry = DateTime.now().toUtc().add(messageTTL);
          toWrite['expiresAt'] = Timestamp.fromDate(expiry);
        }

        await msgRef.set(toWrite);

        // write chunks subcollection
        final batch = _firestore.batch();
        // we write each chunk as a doc with id '0','1',... to allow ordered fetch
        for (var i = 0; i < chunks.length; i++) {
          final chRef = msgRef.collection('chunks').doc(i.toString());
          batch.set(chRef, {'seq': i, 'data': chunks[i]});
        }
        await batch.commit();

        // update local with marker that remote is chunked (we keep remoteData null; receiver will assemble)
        final updatedLocal = localMsg.copyWith(sendState: 'sent', sendAttempts: localMsg.sendAttempts + 1, isLocal: false);
        await LocalChatDb.upsertMessage(updatedLocal);
        _messagesMap[localId] = updatedLocal;
        _rebuildMessagesFromMap();
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('[ChatVM] sendMediaMessage error: $e\n$st');
      // mark failed & increment attempts
      final failedAttempts = (localMsg.sendAttempts) + 1;
      await LocalChatDb.updateSendState(conversationId, localMsg.id, 'failed', sendAttempts: failedAttempts);
      final updatedLocal = localMsg.copyWith(sendState: 'failed', sendAttempts: failedAttempts);
      _messagesMap[localMsg.id] = updatedLocal;
      _rebuildMessagesFromMap();
      errorMessage = e.toString();
      notifyListeners();
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  /// Convenience wrappers:
  Future<void> sendImage(File file, {String? mimeType, String? fileName, String? replyToMessageId}) =>
      sendMediaMessage(file, type: 'image', mimeType: mimeType, fileName: fileName, replyToMessageId: replyToMessageId);

  Future<void> sendDocument(File file, {String? mimeType, String? fileName, String? replyToMessageId}) =>
      sendMediaMessage(file, type: 'file', mimeType: mimeType, fileName: fileName, replyToMessageId: replyToMessageId);

  /// Send location message (no binary). local-first, then write Firestore metadata.
  Future<void> sendLocationMessage(double lat, double lng, {String? address, String? replyToMessageId}) async {
    final user = FirebaseAuth.instance.currentUser;
    final senderUid = user?.uid;
    if (senderUid == null) throw StateError('User not authenticated');

    isSending = true;
    notifyListeners();

    final localId = _generateLocalId(senderUid);
    final createdAt = Timestamp.now();
    final expiresTs = Timestamp.fromDate(DateTime.now().toUtc().add(messageTTL));

    final localMsg = ChatMessage(
      id: localId,
      conversationId: conversationId,
      type: 'location',
      text: address,
      localPath: null,
      remoteUrl: null,
      remoteData: null,
      mimeType: null,
      fileName: null,
      fileSize: null,
      latitude: lat,
      longitude: lng,
      senderId: senderUid,
      createdAt: createdAt,
      replyToMessageId: replyToMessageId,
      isLocal: true,
      delivered: false,
      expiresAt: expiresTs,
      sendState: 'pending',
      sendAttempts: 0,
    );

    // persist local optimistic
    final fp = _makeFingerprint(localMsg);
    _messagesMap[localMsg.id] = localMsg;
    _fingerprintIndex[fp] = localMsg.id;
    _idToFingerprint[localMsg.id] = fp;
    _rebuildMessagesFromMap();
    await LocalChatDb.upsertMessage(localMsg);
    notifyListeners();

    try {
      final convRef = _firestore.collection('conversations').doc(conversationId);
      final msgRef = convRef.collection('messages').doc(localId);
      final data = {
        'type': 'location',
        'text': address ?? '',
        'latitude': lat,
        'longitude': lng,
        'senderId': senderUid,
        'conversationId': conversationId,
        'replyToMessageId': replyToMessageId,
        'createdAt': FieldValue.serverTimestamp(),
        'delivered': false,
      };
      if (messageTTL != Duration.zero) {
        final expiry = DateTime.now().toUtc().add(messageTTL);
        data['expiresAt'] = Timestamp.fromDate(expiry);
      }
      await msgRef.set(data);

      // mark local sent
      await LocalChatDb.updateSendState(conversationId, localMsg.id, 'sent', sendAttempts: 1);
      final updatedLocal = localMsg.copyWith(sendState: 'sent', sendAttempts: 1, isLocal: false);
      _messagesMap[localMsg.id] = updatedLocal;
      await LocalChatDb.upsertMessage(updatedLocal);
      _rebuildMessagesFromMap();
      notifyListeners();
    } catch (e, st) {
      debugPrint('[ChatVM] sendLocationMessage error: $e\n$st');
      final failedAttempts = localMsg.sendAttempts + 1;
      await LocalChatDb.updateSendState(conversationId, localMsg.id, 'failed', sendAttempts: failedAttempts);
      final updatedLocal = localMsg.copyWith(sendState: 'failed', sendAttempts: failedAttempts);
      _messagesMap[localMsg.id] = updatedLocal;
      _rebuildMessagesFromMap();
      errorMessage = e.toString();
      notifyListeners();
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  /// Attempts to upload pending/failed (text/media/location) messages from local DB.
  Future<void> _syncPendingMessages({int maxAttempts = 5}) async {
    try {
      final pending = await LocalChatDb.getPendingMessages(conversationId, maxAttempts: maxAttempts);
      if (pending.isEmpty) return;

      debugPrint('[ChatVM] syncing ${pending.length} pending messages for $conversationId');

      for (final m in pending) {
        // if it's a media message that still has localPath and no remoteData, attempt upload (inline / chunk)
        if ((m.type == 'image' || m.type == 'file') && (m.remoteData == null || m.remoteData!.isEmpty) && (m.localPath != null && m.localPath!.isNotEmpty)) {
          // try uploading (inline or chunk) - reuse sendMediaMessage logic by creating File and calling sendMediaMessage
          try {
            final file = File(m.localPath!);
            if (await file.exists()) {
              await sendMediaMessage(file, type: m.type, mimeType: m.mimeType, fileName: m.fileName, replyToMessageId: m.replyToMessageId);
              continue;
            } else {
              // local file missing -> mark failed
              await LocalChatDb.updateSendState(conversationId, m.id, 'failed', sendAttempts: m.sendAttempts + 1);
              continue;
            }
          } catch (e) {
            debugPrint('[ChatVM] _syncPendingMessages upload failed for ${m.id}: $e');
            final attempts = m.sendAttempts + 1;
            await LocalChatDb.updateSendState(conversationId, m.id, 'failed', sendAttempts: attempts);
            continue;
          }
        }

        // otherwise treat as text/location (send metadata only)
        try {
          await LocalChatDb.updateSendState(conversationId, m.id, 'sending', sendAttempts: m.sendAttempts + 1);
          final convRef = _firestore.collection('conversations').doc(conversationId);
          final msgRef = convRef.collection('messages').doc(m.id);
          await msgRef.set(m.toMapForSend(ttl: messageTTL, inlineBase64: m.remoteData));
          await LocalChatDb.updateSendState(conversationId, m.id, 'sent', sendAttempts: m.sendAttempts + 1);
        } catch (e) {
          final attempts = m.sendAttempts + 1;
          await LocalChatDb.updateSendState(conversationId, m.id, 'failed', sendAttempts: attempts);
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

  Future<void> syncPendingMessages() async => _syncPendingMessages();

  void _rebuildMessagesFromMap() {
    final list = _messagesMap.values.toList()
      ..sort((a, b) => a.createdAt.millisecondsSinceEpoch.compareTo(b.createdAt.millisecondsSinceEpoch));
    messages = list;
    notifyListeners();
  }

  /// Local-only delete method (keeps name `delete` as requested)
  Future<void> delete(String messageId) async {
    try {
      final local = _messagesMap[messageId];
      if (local == null) return;

      final tombstone = local.copyWith(isDeleted: true);
      _messagesMap[messageId] = tombstone;
      await LocalChatDb.upsertMessage(tombstone);
      selectedMessageIds.remove(messageId);
      _rebuildMessagesFromMap();
      notifyListeners();
    } catch (e, st) {
      debugPrint('[ChatVM] delete (local-only) failed: $e\n$st');
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> clear() async {
    try {
      await LocalChatDb.clearConversation(conversationId);
      _messagesMap.removeWhere((key, value) => value.conversationId == conversationId);
      _fingerprintIndex.removeWhere((k, v) => !_messagesMap.containsKey(v));
      _idToFingerprint.removeWhere((k, v) => !_messagesMap.containsKey(k));
      selectedMessageIds.clear();
      _rebuildMessagesFromMap();
      notifyListeners();
    } catch (e, st) {
      debugPrint('[ChatVM] clear (local-only) failed: $e\n$st');
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> softDeleteMessage(String messageId) async {
    try {
      final local = _messagesMap[messageId];
      if (local == null) return;

      final deleted = local.copyWith(isDeleted: true);
      _messagesMap[messageId] = deleted;
      await LocalChatDb.upsertMessage(deleted);
      selectedMessageIds.remove(messageId);
      _rebuildMessagesFromMap();
      notifyListeners();
    } catch (e, st) {
      debugPrint('[ChatVM] softDeleteMessage (local-only) failed: $e\n$st');
      errorMessage = e.toString();
      notifyListeners();
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

  String _makeFingerprint(ChatMessage m) {
    final normalizedText = _normalizeWhitespace(m.text ?? '');
    final urlSig = (m.remoteUrl ?? '').replaceAll(RegExp(r'https?://'), '');
    final dataSig = (m.remoteData ?? '').isNotEmpty ? '_d${(m.remoteData ?? '').length}' : '';
    return '${m.senderId}_${m.createdAt.millisecondsSinceEpoch}_${m.type}_${normalizedText}_$urlSig$dataSig';
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
  }

  Future<String?> _resolveToUidIfNeeded(String part) async {
    try {
      if (part.isEmpty) return null;
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

  String _generateLocalId(String senderUid) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rnd = Random().nextInt(1 << 31);
    final short = senderUid.isNotEmpty ? senderUid.substring(0, min(6, senderUid.length)) : 'anon';
    return 'loc_${short}_$now\_$rnd';
  }

  Future<void> sendTextMessage(String text, {String? replyToMessageId}) async {
    final user = FirebaseAuth.instance.currentUser;
    final senderUid = user?.uid;
    if (senderUid == null) throw StateError('User not authenticated');

    isSending = true;
    notifyListeners();

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

    final localId = _generateLocalId(senderUid);
    final expiresTs = Timestamp.fromDate(DateTime.now().toUtc().add(messageTTL));
    final localMsg = ChatMessage(
      id: localId,
      conversationId: conversationId,
      type: 'text',
      text: text,
      localPath: null,
      remoteUrl: null,
      remoteData: null,
      mimeType: null,
      fileName: null,
      fileSize: null,
      latitude: null,
      longitude: null,
      senderId: senderUid,
      createdAt: Timestamp.now(),
      replyToMessageId: replyToMessageId,
      isLocal: true,
      delivered: false,
      expiresAt: expiresTs,
      sendState: 'pending',
      sendAttempts: 0,
    );

    final fp = _makeFingerprint(localMsg);
    _messagesMap[localMsg.id] = localMsg;
    _fingerprintIndex[fp] = localMsg.id;
    _idToFingerprint[localMsg.id] = fp;
    _rebuildMessagesFromMap();

    await LocalChatDb.upsertMessage(localMsg);
    notifyListeners();

    try {
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

      final msgRef = convRef.collection('messages').doc(localMsg.id);
      await msgRef.set(localMsg.toMapForSend(ttl: messageTTL));

      await LocalChatDb.updateSendState(conversationId, localMsg.id, 'sent', sendAttempts: 1);
      final updatedLocal = localMsg.copyWith(sendState: 'sent', sendAttempts: 1, isLocal: false);
      _messagesMap[localMsg.id] = updatedLocal;
      await LocalChatDb.upsertMessage(updatedLocal);
      _rebuildMessagesFromMap();
    } catch (e, st) {
      final failedAttempts = localMsg.sendAttempts + 1;
      await LocalChatDb.updateSendState(conversationId, localMsg.id, 'failed', sendAttempts: failedAttempts);
      final updatedLocal = localMsg.copyWith(sendState: 'failed', sendAttempts: failedAttempts);
      _messagesMap[localMsg.id] = updatedLocal;
      _rebuildMessagesFromMap();
      errorMessage = e.toString();
      debugPrint('[ChatVM] sendTextMessage error: $e\n$st');
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  Stream<List<ChatMessage>> messagesStream() {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ChatMessage.fromDoc(d, conversationIdOverride: conversationId)).toList());
  }

  /// Opens lat,lng in external map application (Google Maps / Apple Maps)
  Future<void> openLocationInMaps(double lat, double lng, {String? label}) async {
    // prefer geo URI, fallback to google maps web URL
    final geoUri = Uri.parse('geo:$lat,$lng?q=${Uri.encodeComponent(lat.toString() + ',' + lng.toString() + (label != null ? "($label)" : ""))}');
    final gmaps = Uri.parse('https://www.google.com/maps/search/?api=1&query=${lat},${lng}');
    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri);
        return;
      }
      if (await canLaunchUrl(gmaps)) {
        await launchUrl(gmaps, mode: LaunchMode.externalApplication);
        return;
      }
      debugPrint('[ChatVM] cannot open maps for $lat,$lng');
    } catch (e) {
      debugPrint('[ChatVM] openLocationInMaps failed: $e');
    }
  }
}
