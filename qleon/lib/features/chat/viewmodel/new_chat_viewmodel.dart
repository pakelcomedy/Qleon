// new_chat_viewmodel.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Simple contact model used by NewChatView & AddContactView
class ChatContact {
  final String publicId; // unique public identity (e.g. other user's uid)
  final String displayName; // local alias
  final String publicStatus; // e.g. "Online" or "Last seen ..."
  final bool isOnline;

  ChatContact({
    required this.publicId,
    required this.displayName,
    required this.publicStatus,
    required this.isOnline,
  });

  /// compatibility: some UI code expects `.id`
  String get id => publicId;

  Map<String, dynamic> toMap() => {
        'publicId': publicId,
        'displayName': displayName,
        'publicStatus': publicStatus,
        'isOnline': isOnline,
      };

  factory ChatContact.fromMap(Map<String, dynamic> m) {
    return ChatContact(
      publicId: (m['publicId'] as String?) ?? '',
      displayName: (m['displayName'] as String?) ?? '',
      publicStatus: (m['publicStatus'] as String?) ?? '',
      isOnline: (m['isOnline'] as bool?) ?? false,
    );
  }

  factory ChatContact.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ChatContact(
      publicId: (data['publicId'] as String?) ?? doc.id,
      displayName: (data['displayName'] as String?) ?? '',
      publicStatus: (data['publicStatus'] as String?) ?? '',
      isOnline: (data['isOnline'] as bool?) ?? false,
    );
  }
}

/// ViewModel for NewChatView
class NewChatViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  List<ChatContact> contacts = [];
  bool isLoading = true;
  String? errorMessage;

  NewChatViewModel() {
    _init();
  }

  String? get currentUid => _auth.currentUser?.uid;

  /// Firestore collection path: users/{currentUid}/contacts
  CollectionReference<Map<String, dynamic>> _contactsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('contacts');

  void _init() {
    final uid = currentUid;
    if (uid == null) {
      // user not logged in — keep empty list
      isLoading = false;
      notifyListeners();
      return;
    }

    // Listen realtime to contacts subcollection
    _sub = _contactsRef(uid).orderBy('displayName').snapshots().listen(
      (snap) {
        contacts = snap.docs.map((d) => ChatContact.fromDoc(d)).toList();
        isLoading = false;
        errorMessage = null;
        notifyListeners();
      },
      onError: (e, st) {
        errorMessage = e.toString();
        isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Add contact to Firestore. Uses publicId as document id to avoid duplicates.
  Future<void> addContact(ChatContact contact) async {
    final uid = currentUid;
    if (uid == null) throw Exception('User not logged in');

    final docRef = _contactsRef(uid).doc(contact.publicId);

    try {
      await docRef.set(contact.toMap());
      // local updates will be reflected by the listener; but optimistic update is okay:
      final existsIndex = contacts.indexWhere((c) => c.publicId == contact.publicId);
      if (existsIndex == -1) {
        contacts.insert(0, contact);
        notifyListeners();
      }
    } on FirebaseException catch (e) {
      debugPrint('[NewChatVM] addContact error: ${e.code} ${e.message}');
      throw e;
    } catch (e) {
      debugPrint('[NewChatVM] addContact unknown error: $e');
      rethrow;
    }
  }

  Future<void> removeContact(String publicId) async {
    final uid = currentUid;
    if (uid == null) throw Exception('User not logged in');

    try {
      await _contactsRef(uid).doc(publicId).delete();
    } catch (e) {
      debugPrint('[NewChatVM] removeContact error: $e');
      rethrow;
    }
  }

  /// Helper: deterministic conversation id so same pair -> same id
  /// Order UIDs lexicographically so A_B == B_A.
  String _makeConversationId(String a, String b) {
    final list = [a, b]..sort();
    return '${list[0]}_${list[1]}';
  }

  /// Find existing conversation between current user and a contact (by contact.publicId).
  /// If none exists, create a new conversation document and return its id.
  ///
  /// IMPORTANT: this uses a deterministic conversation id (uidA_uidB) so both sides point to the same doc.
  Future<String> openOrCreateConversation(ChatContact contact) async {
    final uid = currentUid;
    if (uid == null) throw Exception('User not logged in');

    if (contact.publicId.isEmpty) throw ArgumentError('contact.publicId must not be empty');

    final otherId = contact.publicId;

    // Build canonical conversation id (deterministic)
    final conversationId = _makeConversationId(uid, otherId);
    final convRef = _firestore.collection('conversations').doc(conversationId);

    try {
      // 1) Check canonical doc existence first (fast)
      final doc = await convRef.get();
      if (doc.exists) {
        return conversationId;
      }

      // 2) If canonical not present, search for any conversation that includes both members
      // (useful if older conversations used random ids).
      final query = await _firestore
          .collection('conversations')
          .where('members', arrayContains: uid)
          .limit(50)
          .get();

      for (final d in query.docs) {
        final data = d.data();
        final members = (data['members'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];
        if (members.contains(otherId)) {
          // found existing conversation that includes the contact
          return d.id;
        }
      }

      // 3) Not found -> create conversation using the deterministic id so both sides point here.
      final createdAt = FieldValue.serverTimestamp();
      final payload = {
        'members': [uid, otherId],
        'isGroup': false,
        'createdAt': createdAt,
        'lastUpdated': createdAt,
      };

      // Use merge: true to be safe if doc gets created between get() and set()
      await convRef.set(payload, SetOptions(merge: true));

      // 4) create per-user chat summary for current user (and attempt for other user)
      final myChatRef = _firestore.collection('users').doc(uid).collection('chats').doc(conversationId);
      await myChatRef.set({
        'title': contact.displayName,
        'lastMessage': '',
        'lastUpdated': FieldValue.serverTimestamp(),
        'otherPublicId': contact.publicId,
        'isGroup': false,
        'pinned': false,
        'archived': false,
      }, SetOptions(merge: true));

      // Trying to write to the other user's chat summary may be blocked by rules.
      // Wrap in try/catch and ignore failure (server-side should handle fan-out ideally).
      try {
        final otherChatRef = _firestore.collection('users').doc(otherId).collection('chats').doc(conversationId);
        await otherChatRef.set({
          'title': (contact.displayName.isNotEmpty) ? contact.displayName : uid,
          'lastMessage': '',
          'lastUpdated': FieldValue.serverTimestamp(),
          'otherPublicId': uid,
          'isGroup': false,
          'pinned': false,
          'archived': false,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[NewChatVM] unable to write other user chat summary (may be expected): $e');
      }

      return conversationId;
    } catch (e) {
      debugPrint('[NewChatVM] openOrCreateConversation error: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
