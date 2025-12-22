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

  AddContactViewModel();

  /// Process raw scanned string.
  /// Returns a ChatContact if successful, otherwise throws.
  ///
  /// NOTE: This method only parses the QR and enriches contact from `users` doc.
  /// To get or create a conversation id between current user and scanned user,
  /// call `createOrGetConversationId(lastScannedUid!)` afterwards (or pass uid directly).
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
      final temp = payload.substring(kNameLen, kNameLen + kTempLen);
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
  /// Strategy:
  /// - Determine a deterministic conversation id by lexicographically sorting the two UIDs
  ///   and joining them with an underscore. This prevents duplicate conversations for the same pair.
  /// - Check if a conversation doc with that id exists. If not and [createIfMissing] is true,
  ///   search for an existing conversation document that contains both members (to avoid duplicates),
  ///   otherwise create a minimal conversation doc.
  ///
  /// Returns the conversation id (string).
  Future<String> createOrGetConversationId(String otherUid, {bool createIfMissing = true}) async {
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

    // make canonical conversation id (lexicographically sorted: "a_b")
    final conversationId = _makeConversationId(myUid, otherUid);
    final convRef = _firestore.collection('conversations').doc(conversationId);

    try {
      // quick check canonical doc
      final doc = await convRef.get();
      if (doc.exists) {
        lastConversationId = conversationId;
        lastConversationExists = true;
        isProcessing = false;
        notifyListeners();
        return conversationId;
      }

      // If canonical doc not found, search for any conversation doc that has both members in 'members' array
      final q = await _firestore.collection('conversations').where('members', arrayContains: myUid).get();
      for (final d in q.docs) {
        final members = (d.data()['members'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        if (members.contains(myUid) && members.contains(otherUid)) {
          // found existing doc with both members
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

      // create minimal conversation doc (merge so we don't overwrite random fields)
      final now = FieldValue.serverTimestamp();
      final conversationData = <String, dynamic>{
        // store canonical id in doc if you like; doc.id already is canonical
        'members': [myUid, otherUid],
        'createdAt': now,
        'lastMessage': null,
        'lastUpdated': now,
      };

      // Use set with merge to be safe if doc appears between the earlier check and this set
      await convRef.set(conversationData, SetOptions(merge: true));

      lastConversationId = conversationId;
      lastConversationExists = true;
      isProcessing = false;
      notifyListeners();
      return conversationId;
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
  /// Order UIDs lexicographically so A_B == B_A.
  String _makeConversationId(String a, String b) {
    final list = [a, b]..sort();
    return '${list[0]}_${list[1]}';
  }

  /// Try to decode QR from picked image path using MobileScannerController.analyzeImage
  /// Not all versions/platforms support analyzeImage; wrap in try/catch.
  Future<String?> decodeQrFromImage(String imagePath) async {
    try {
      // analyzeImage is available on some versions of mobile_scanner; this
      // call may throw/no-op if not available — keep defensive.
      final result = await cameraController.analyzeImage(imagePath);
      if (result == null) return null;

      // If result has barcodes property:
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
        // fallback try toString()
        return result.toString();
      }
      return result.toString();
    } catch (e) {
      // analyzeImage may not be implemented; return null so UI can show message
      debugPrint('[AddContactVM] decodeQrFromImage failed: $e');
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
