// chat_room_viewmodel.dart
// Robust ChatRoomViewModel: resolves conversation docId, optimistic UI, safer parsing.
// Features:
//  - resolve publicId (0x...) -> uid by querying users collection
//  - normalize to canonical uidA_uidB when possible
//  - listen to canonical and legacy conversation docs and merge messages in-memory
//  - optimistic UI and safe parsing

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ChatMessage {
  final String id;
  final String text;
  final String senderId;
  final Timestamp createdAt;
  final String? replyToMessageId;
  final bool isDeleted;
  final bool isLocal;

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.createdAt,
    this.replyToMessageId,
    this.isDeleted = false,
    this.isLocal = false,
  });

  factory ChatMessage.fromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
    final rawCreatedAt = data['createdAt'];
    final createdAt = (rawCreatedAt is Timestamp) ? rawCreatedAt : Timestamp.now();
    final isLocal = rawCreatedAt == null;
    return ChatMessage(
      id: doc.id,
      text: (data['text'] ?? '').toString(),
      senderId: (data['senderId'] ?? 'unknown').toString(),
      createdAt: createdAt,
      replyToMessageId: data['replyToMessageId']?.toString(),
      isDeleted: (data['isDeleted'] as bool?) ?? false,
      isLocal: isLocal,
    );
  }

  Map<String, dynamic> toMapForSend() {
    return {
      'text': text,
      'senderId': senderId,
      'createdAt': FieldValue.serverTimestamp(),
      'replyToMessageId': replyToMessageId,
      'isDeleted': isDeleted,
    };
  }
}

class ChatRoomViewModel extends ChangeNotifier {
  String conversationId; // may be adjusted to canonical uid-based id during init
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot>? _sub; // canonical listener
  StreamSubscription<QuerySnapshot>? _legacySub; // legacy doc listener (if any)

  // exposed
  List<ChatMessage> messages = [];
  Set<String> selectedMessageIds = {};

  bool isLoading = true;
  bool isSending = false;
  String? errorMessage;

  // internal map to merge messages from multiple listeners, key = msgId
  final Map<String, ChatMessage> _messagesMap = {};

  ChatRoomViewModel({required this.conversationId});

  // ===== lifecycle =====
  Future<void> init() async {
    if (_sub != null || _legacySub != null) return; // already listening

    final originalConversationId = conversationId;
    debugPrint('[ChatVM] init() start conversationId=$conversationId');

    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;

      if (currentUid != null) {
        // Resolve incoming id:
        // Cases:
        //  - incoming is canonical (uidA_uidB or maybe publicId_publicId)
        //  - incoming is single otherUid/publicId -> treat as other and compute canonical
        final parts = conversationId.split('_');
        final looksCanonical = parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty;

        if (looksCanonical) {
          // Try resolving both parts to uids (if either is a publicId like 0x...)
          final resolvedA = await _resolveToUidIfNeeded(parts[0]);
          final resolvedB = await _resolveToUidIfNeeded(parts[1]);

          if (resolvedA != null && resolvedB != null) {
            final sorted = [resolvedA, resolvedB]..sort();
            final canonical = '${sorted[0]}_${sorted[1]}';
            if (canonical != conversationId) {
              debugPrint('[ChatVM] resolved canonical (from parts) -> $canonical (was $conversationId)');
              conversationId = canonical;
              // ensure canonical doc exists and has proper members
              await _firestore.collection('conversations').doc(conversationId).set({
                'members': [sorted[0], sorted[1]],
                'isGroup': false,
                'lastUpdated': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            }
          } else {
            // Could not resolve both parts to uids; fallback: if one part is currentUid, try to find a conversation doc that has both
            if (parts.contains(currentUid)) {
              final otherCandidate = (parts[0] == currentUid) ? parts[1] : parts[0];
              final found = await _findConversationWithMembers(currentUid, otherCandidate);
              if (found != null) {
                debugPrint('[ChatVM] found conversation by members -> $found (legacy source: $conversationId)');
                conversationId = found;
              } else {
                // leave conversationId as-is (legacy doc). We'll still listen to it and attempt to canonicalize later.
                debugPrint('[ChatVM] keeping legacy conversationId=$conversationId (not resolvable to uid pair)');
              }
            }
          }
        } else {
          // treat conversationId as otherUid/publicId
          final otherResolved = await _resolveToUidIfNeeded(conversationId);
          if (otherResolved != null) {
            final sorted = [currentUid, otherResolved]..sort();
            final canonical = '${sorted[0]}_${sorted[1]}';
            // if canonical exists use it otherwise create it (merge)
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
            // cannot resolve other -> leave as provided (likely a legacy id)
            debugPrint('[ChatVM] otherId ${conversationId} could not be resolved to uid - keeping as legacy id');
          }
        }
      } else {
        debugPrint('[ChatVM] currentUser null during init(), will listen to provided conversationId as-is');
      }

      // At this point: conversationId may have changed to canonical uid pair.
      // We'll listen to canonical doc and ALSO listen to originalConversationId if different (legacy).
      await _startListeners(canonicalId: conversationId, legacyId: (originalConversationId == conversationId) ? null : originalConversationId);
    } catch (e, st) {
      errorMessage = e.toString();
      isLoading = false;
      notifyListeners();
      debugPrint('[ChatVM] init error: $e\n$st');
    }
  }

  Future<void> _startListeners({required String canonicalId, String? legacyId}) async {
    // clear previous map & messages
    _messagesMap.clear();
    messages = [];
    isLoading = true;
    notifyListeners();

    // canonical listener
    final collRef = _firestore.collection('conversations').doc(canonicalId).collection('messages');
    _sub = collRef.orderBy('createdAt', descending: false).snapshots().listen((snap) {
      _applySnapshotToMap(snap);
    }, onError: (e, st) {
      errorMessage = e.toString();
      isLoading = false;
      notifyListeners();
      debugPrint('[ChatVM] canonical listener error: $e\n$st');
    });

    // legacy listener (only if provided and different from canonical)
    if (legacyId != null && legacyId.isNotEmpty && legacyId != canonicalId) {
      final legacyRef = _firestore.collection('conversations').doc(legacyId).collection('messages');
      _legacySub = legacyRef.orderBy('createdAt', descending: false).snapshots().listen((snap) {
        _applySnapshotToMap(snap);
      }, onError: (e, st) {
        // non-fatal: legacy may not exist
        debugPrint('[ChatVM] legacy listener error for $legacyId: $e');
      });
      debugPrint('[ChatVM] listening to legacy doc $legacyId and canonical $canonicalId');
    } else {
      debugPrint('[ChatVM] listening only to canonical doc $canonicalId');
    }
  }

  void _applySnapshotToMap(QuerySnapshot snap) {
    var changed = false;
    for (final doc in snap.docs) {
      final cm = ChatMessage.fromDoc(doc);
      final prev = _messagesMap[cm.id];
      // replace or insert
      if (prev == null || prev.createdAt.millisecondsSinceEpoch != cm.createdAt.millisecondsSinceEpoch || prev.text != cm.text || prev.isDeleted != cm.isDeleted) {
        _messagesMap[cm.id] = cm;
        changed = true;
      }
    }
    if (changed) {
      // rebuild list sorted by createdAt ascending
      final list = _messagesMap.values.toList()
        ..sort((a, b) => a.createdAt.toDate().millisecondsSinceEpoch.compareTo(b.createdAt.toDate().millisecondsSinceEpoch));
      messages = list;
      isLoading = false;
      notifyListeners();
    } else {
      if (isLoading) {
        // first empty snapshot case
        isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Try to resolve possibly publicId (like "0xABCD") to uid.
  /// If `part` already looks like a uid (exists as users doc id) returns it.
  /// If `part` looks like a public id (startsWith "0x") tries to query users where name == part.
  /// Returns null if cannot resolve.
  Future<String?> _resolveToUidIfNeeded(String part) async {
    try {
      if (part.isEmpty) return null;
      // quick check: if user doc exists with id == part, treat it as uid
      final doc = await _firestore.collection('users').doc(part).get();
      if (doc.exists) {
        // doc may contain 'uid' field or doc.id is uid
        final data = doc.data();
        if (data != null && data.containsKey('uid')) return (data['uid'] as String?) ?? doc.id;
        return doc.id;
      }

      // if looks like publicId (0x...) try to query by name field
      if (part.startsWith('0x')) {
        final q = await _firestore.collection('users').where('name', isEqualTo: part).limit(1).get();
        if (q.docs.isNotEmpty) {
          final d = q.docs.first.data();
          if (d.containsKey('uid')) return (d['uid'] as String?) ?? q.docs.first.id;
          return q.docs.first.id;
        }
      }

      // Not resolved
      return null;
    } catch (e) {
      debugPrint('[ChatVM] _resolveToUidIfNeeded error for $part: $e');
      return null;
    }
  }

  /// Try to find a conversation doc id that has both members (currentUid & otherCandidate)
  /// Returns doc.id if found, otherwise null.
  Future<String?> _findConversationWithMembers(String currentUid, String otherCandidate) async {
    try {
      final q = await _firestore
          .collection('conversations')
          .where('members', arrayContains: currentUid)
          .limit(200)
          .get();

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

  // ===== messaging =====
  /// Send message and ensure conversation doc exists (merge). SenderId is UID (no fallback).
  Future<void> sendTextMessage(String text, {String? replyToMessageId}) async {
    final user = FirebaseAuth.instance.currentUser;
    final senderUid = user?.uid;
    if (senderUid == null) {
      throw StateError('User not authenticated');
    }
    final senderId = senderUid; // force using uid

    isSending = true;
    notifyListeners();

    final convRef = _firestore.collection('conversations').doc(conversationId);
    final msgRef = convRef.collection('messages').doc();

    // local optimistic message
    final local = ChatMessage(
      id: msgRef.id,
      text: text,
      senderId: senderId,
      createdAt: Timestamp.now(),
      replyToMessageId: replyToMessageId,
      isLocal: true,
    );

    // put into internal map & rebuild messages
    _messagesMap[local.id] = local;
    _rebuildMessagesFromMap();

    try {
      // Ensure conversation exists: add both members when possible.
      final parts = conversationId.split('_');
      if (parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        final other = (parts[0] == senderUid) ? parts[1] : parts[0];
        // If other looks like publicId, try to resolve it to uid before writing members
        String otherResolved = other;
        if (other.startsWith('0x')) {
          final r = await _resolveToUidIfNeeded(other);
          if (r != null) otherResolved = r;
        }
        await convRef.set({
          'members': FieldValue.arrayUnion([senderUid, otherResolved]),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        // unknown id format: ensure sender is at least recorded
        await convRef.set({
          'members': FieldValue.arrayUnion([senderUid]),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await msgRef.set(local.toMapForSend());
      // server copy will come through snapshots and replace local placeholder (same id)
    } catch (e) {
      // remove optimistic local message on failure
      _messagesMap.remove(local.id);
      _rebuildMessagesFromMap();
      errorMessage = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  void _rebuildMessagesFromMap() {
    final list = _messagesMap.values.toList()
      ..sort((a, b) => a.createdAt.toDate().millisecondsSinceEpoch.compareTo(b.createdAt.toDate().millisecondsSinceEpoch));
    messages = list;
    notifyListeners();
  }

  Future<void> softDeleteMessage(String messageId) async {
    try {
      await _firestore.collection('conversations').doc(conversationId).collection('messages').doc(messageId).update({'isDeleted': true});
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
    try {
      return messages.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  Stream<List<ChatMessage>> messagesStream() {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(ChatMessage.fromDoc).toList());
  }
}
