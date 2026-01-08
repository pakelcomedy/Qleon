// add_contact_viewmodel.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'new_chat_viewmodel.dart'; // ChatContact model

class AddContactViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // MobileScanner controller (used by camera and optionally analyzeImage)
  final MobileScannerController cameraController = MobileScannerController();

  bool isProcessing = false;
  String? errorMessage;

  // parsing lengths - MUST match generator in ProfileViewModel
  static const int kNameLen = 10; // e.g. "0xA94F32C1"
  static const int kTempLen = 6; // e.g. "9fhh9i"

  // prefix expected in QR payload (optional)
  static const String kPrefix = 'qleon://user/';

  // last found/created conversation id (helpful for caller to navigate)
  String? lastConversationId;
  bool lastConversationExists = false;

  // last scanned uid extracted from QR (useful so UI/caller doesn't need to re-parse)
  String? lastScannedUid;

  // cache publicId -> uid resolution
  final Map<String, String?> _publicToUidCache = {};

  AddContactViewModel();

  /// Process raw scanned string.
  /// Returns a ChatContact if successful, otherwise throws.
  Future<ChatContact> processScannedPayload(String raw) async {
    isProcessing = true;
    errorMessage = null;
    notifyListeners();

    try {
      // Allow either raw payload or with prefix
      String payload = raw.trim();
      if (payload.startsWith(kPrefix)) {
        payload = payload.replaceFirst(kPrefix, '');
      }

      // minimal length check
      if (payload.length <= kNameLen + kTempLen) {
        throw FormatException('Payload too short');
      }

      final name = payload.substring(0, kNameLen);
      payload.substring(kNameLen, kNameLen + kTempLen);
      final uid = payload.substring(kNameLen + kTempLen);

      // sanity checks
      if (!name.startsWith('0x') || uid.isEmpty) {
        throw FormatException('Invalid payload format');
      }

      // store scanned uid for caller convenience
      lastScannedUid = uid;

      // Try to fetch user doc to enrich displayName/status
      final userDoc = await _firestore.collection('users').doc(uid).get();

      String displayName = name; // fallback to name as display alias
      String publicStatus = 'New contact';
      bool isOnline = false;

      if (userDoc.exists) {
        final data = userDoc.data()!;
        // The 'name' field in users doc is already the public identity (0x..)
        displayName = (data['name'] as String?) ?? displayName;
        // If you have additional profile fields like displayName/publicStatus/isOnline, map them here
        if (data.containsKey('displayName')) {
          displayName = (data['displayName'] as String?) ?? displayName;
        }
        if (data.containsKey('publicStatus')) {
          publicStatus = (data['publicStatus'] as String?) ?? publicStatus;
        }
        // if you track presence in users doc:
        if (data.containsKey('isOnline')) {
          isOnline = (data['isOnline'] as bool?) ?? false;
        }
      } else {
        // user doc not found — still create contact with minimal info
        displayName = name;
        publicStatus = 'No profile found';
      }

      final contact = ChatContact(
        publicId: name,
        displayName: displayName,
        publicStatus: publicStatus,
        isOnline: isOnline,
      );

      // reset last conversation info — caller should call createOrGetConversationId if needed
      lastConversationId = null;
      lastConversationExists = false;

      isProcessing = false;
      notifyListeners();
      return contact;
    } on FirebaseException catch (e) {
      isProcessing = false;
      errorMessage = e.message ?? e.code;
      notifyListeners();
      rethrow;
    } catch (e) {
      isProcessing = false;
      errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Create or return existing conversation id for current user and [otherUid].
  ///
  /// Improvements:
  ///  - Accepts optional otherPublicId (public identity like "0x...") to detect duplicates
  ///  - Checks users/{me}/chats for existing per-user summary first (fast)
  ///  - If per-user summary is archived, will unarchive it and return that id (avoid creating new)
  ///  - Searches conversations membership as fallback
  ///  - Creates canonical conversation doc using a transaction to avoid races creating duplicates
  Future<String> createOrGetConversationId(String otherUid, {String? otherPublicId, bool createIfMissing = true}) async {
    isProcessing = true;
    errorMessage = null;
    notifyListeners();

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      isProcessing = false;
      notifyListeners();
      throw StateError('No authenticated user');
    }
    final myUid = currentUser.uid;
    if (otherUid.isEmpty) {
      isProcessing = false;
      notifyListeners();
      throw ArgumentError('otherUid must not be empty');
    }
    if (otherUid == myUid) {
      isProcessing = false;
      notifyListeners();
      throw ArgumentError('Cannot create conversation with self');
    }

    // Normalize: if caller passed a publicId instead of uid, try resolve it
    String resolvedOtherUid = otherUid;
    if (otherUid.startsWith('0x')) {
      final r = await _resolvePublicToUidCached(otherUid);
      if (r != null && r.isNotEmpty) resolvedOtherUid = r;
    }

    // if otherPublicId not provided, derive a candidate public id from otherUid (if user doc exists)
    String? resolvedOtherPublicId = otherPublicId;
    if (resolvedOtherPublicId == null && !resolvedOtherUid.startsWith('0x')) {
      try {
        final snap = await _firestore.collection('users').doc(resolvedOtherUid).get();
        if (snap.exists) {
          resolvedOtherPublicId = (snap.data()?['name'] as String?) ?? resolvedOtherPublicId;
        }
      } catch (_) {}
    }

    // deterministic canonical id
    final conversationId = _makeConversationId(myUid, resolvedOtherUid);
    final convRef = _firestore.collection('conversations').doc(conversationId);

    try {
      // 1) Quick: check canonical per-user chat doc under users/{me}/chats/{conversationId}
      final myChatDocRef = _firestore.collection('users').doc(myUid).collection('chats').doc(conversationId);
      final myChatSnap = await myChatDocRef.get();
      if (myChatSnap.exists) {
        // if archived -> unarchive (user expects to resume chat with scanned contact)
        final data = myChatSnap.data();
        final archived = (data?['archived'] as bool?) ?? false;
        if (archived) {
          try {
            await myChatDocRef.update({'archived': false, 'lastUpdated': FieldValue.serverTimestamp()});
          } catch (_) {}
        }
        lastConversationId = conversationId;
        lastConversationExists = true;
        isProcessing = false;
        notifyListeners();
        return conversationId;
      }

      // 2) Strong dedupe: check users/{my}/chats for any doc that references otherPublicId or otherUid
      // prefer query by exact otherPublicId if we have it
      if (resolvedOtherPublicId != null && resolvedOtherPublicId.isNotEmpty) {
        final q = await _firestore
            .collection('users')
            .doc(myUid)
            .collection('chats')
            .where('otherPublicId', isEqualTo: resolvedOtherPublicId)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          final doc = q.docs.first;
          // if archived -> unarchive
          final d = doc.data();
          final archived = (d['archived'] as bool?) ?? false;
          if (archived) {
            try {
              await doc.reference.update({'archived': false, 'lastUpdated': FieldValue.serverTimestamp()});
            } catch (_) {}
          }
          lastConversationId = doc.id;
          lastConversationExists = true;
          isProcessing = false;
          notifyListeners();
          return doc.id;
        }
      }

      // also try by otherPublicId == resolvedOtherUid (sometimes otherPublicId stored as uid)
      final q2 = await _firestore
          .collection('users')
          .doc(myUid)
          .collection('chats')
          .where('otherPublicId', isEqualTo: resolvedOtherUid)
          .limit(1)
          .get();
      if (q2.docs.isNotEmpty) {
        final doc = q2.docs.first;
        final d = doc.data();
        final archived = (d['archived'] as bool?) ?? false;
        if (archived) {
          try {
            await doc.reference.update({'archived': false, 'lastUpdated': FieldValue.serverTimestamp()});
          } catch (_) {}
        }
        lastConversationId = doc.id;
        lastConversationExists = true;
        isProcessing = false;
        notifyListeners();
        return doc.id;
      }

      // 3) Fallback: search conversations collection for any doc that contains both members (cheap limit)
      // This is fallback and limits results to avoid large scans.
      final qConv = await _firestore.collection('conversations').where('members', arrayContains: myUid).limit(50).get();
      for (final d in qConv.docs) {
        final members = (d.data()['members'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        if (members.contains(myUid) && members.contains(resolvedOtherUid)) {
          lastConversationId = d.id;
          lastConversationExists = true;
          isProcessing = false;
          notifyListeners();
          return d.id;
        }
      }

      if (!createIfMissing) {
        lastConversationId = null;
        lastConversationExists = false;
        isProcessing = false;
        notifyListeners();
        throw StateError('Conversation does not exist and createIfMissing is false');
      }

      // 4) Create canonical conversation using a transaction (atomic) to prevent race duplicates
      final createdId = await _firestore.runTransaction<String?>((tx) async {
        final fresh = await tx.get(convRef);
        if (fresh.exists) {
          // already created by other client in the meantime
          return convRef.id;
        }

        // prepare conversation data
        final now = FieldValue.serverTimestamp();
        final conversationData = <String, dynamic>{
          'members': [myUid, resolvedOtherUid],
          'isGroup': false,
          'createdAt': now,
          'lastUpdated': now,
        };

        tx.set(convRef, conversationData, SetOptions(merge: true));
        return convRef.id;
      }, timeout: const Duration(seconds: 15)).catchError((e) => null);

      if (createdId != null) {
        lastConversationId = createdId;
        lastConversationExists = true;

        // Also try to ensure users/{my}/chats summary exists (best-effort)
        try {
          await _firestore.collection('users').doc(myUid).collection('chats').doc(createdId).set({
            'title': (resolvedOtherPublicId ?? resolvedOtherUid),
            'isGroup': false,
            'lastMessage': null,
            'lastUpdated': FieldValue.serverTimestamp(),
            'unreadCount': 0,
            'pinned': false,
            'archived': false,
            'otherPublicId': resolvedOtherPublicId ?? resolvedOtherUid,
          }, SetOptions(merge: true));
        } catch (_) {
          // ignore per-user write failure (rules might prevent it)
        }

        isProcessing = false;
        notifyListeners();
        return createdId;
      } else {
        // transaction failure fallback: try to re-check canonical doc once more
        final finalSnap = await convRef.get();
        if (finalSnap.exists) {
          lastConversationId = convRef.id;
          lastConversationExists = true;
          isProcessing = false;
          notifyListeners();
          return convRef.id;
        }
        throw StateError('Failed to create conversation');
      }
    } on FirebaseException catch (e) {
      lastConversationId = null;
      lastConversationExists = false;
      isProcessing = false;
      errorMessage = e.message ?? e.code;
      notifyListeners();
      rethrow;
    } catch (e) {
      lastConversationId = null;
      lastConversationExists = false;
      isProcessing = false;
      errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Helper: deterministic conversation id (so same pair => same id)
  String _makeConversationId(String a, String b) {
    final list = [a, b]..sort();
    return '${list[0]}_${list[1]}';
  }

  /// Try to decode QR from picked image path using MobileScannerController.analyzeImage
  Future<String?> decodeQrFromImage(String imagePath) async {
    try {
      final result = await cameraController.analyzeImage(imagePath);
      if (result == null) return null;

      try {
        final dynamic r = result;
        if (r is String) return r;
        if (r is Iterable && r.isNotEmpty) {
          final first = r.first;
          if (first is String) return first;
          if (first?.rawValue != null) return first.rawValue as String?;
        }
        if (r.rawValue != null) return r.rawValue as String?;
        if (r.barcodes != null && r.barcodes.isNotEmpty) {
          final barcode = r.barcodes.first;
          return barcode.rawValue as String?;
        }
      } catch (_) {
        return result.toString();
      }
      return result.toString();
    } catch (e) {
      debugPrint('[AddContactVM] decodeQrFromImage failed: $e');
      return null;
    }
  }

  /// Resolve a public identity (0x...) to uid with cache.
  /// Returns null if not resolvable.
  Future<String?> _resolvePublicToUidCached(String publicId) async {
    if (_publicToUidCache.containsKey(publicId)) {
      return _publicToUidCache[publicId] == '' ? null : _publicToUidCache[publicId];
    }
    try {
      final q = await _firestore.collection('users').where('name', isEqualTo: publicId).limit(1).get();
      if (q.docs.isNotEmpty) {
        final doc = q.docs.first;
        final uid = (doc.data()['uid'] as String?) ?? doc.id;
        _publicToUidCache[publicId] = uid;
        return uid;
      } else {
        _publicToUidCache[publicId] = '';
        return null;
      }
    } catch (e) {
      debugPrint('[AddContactVM] _resolvePublicToUidCached error: $e');
      _publicToUidCache[publicId] = '';
      return null;
    }
  }

  @override
  void dispose() {
    try {
      cameraController.dispose();
    } catch (_) {}
    super.dispose();
  }
}
