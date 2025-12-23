// new_chat_viewmodel.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Simple contact model used by NewChatView & AddContactView
class ChatContact {
  final String publicId; // unique public identity (e.g. other user's uid or 0x..)
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

/// ViewModel for NewChatView with strong duplicate prevention.
class NewChatViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  List<ChatContact> contacts = [];
  bool isLoading = true;
  String? errorMessage;

  // cache publicId -> uid resolution to avoid repeated queries
  final Map<String, String?> _publicToUidCache = {};

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
      // local updates will be reflected by the listener; optimistic update too:
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
  /// Order identifiers lexicographically so A_B == B_A.
  String _makeConversationId(String a, String b) {
    final list = [a, b]..sort();
    return '${list[0]}_${list[1]}';
  }

  /// Resolve a public identity (0x...) to uid with cache.
  /// Returns null if not resolvable.
  Future<String?> _resolvePublicToUidCached(String publicId) async {
    if (_publicToUidCache.containsKey(publicId)) {
      final cached = _publicToUidCache[publicId];
      return (cached == '') ? null : cached;
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
      debugPrint('[NewChatVM] _resolvePublicToUidCached error: $e');
      _publicToUidCache[publicId] = '';
      return null;
    }
  }

  /// Find existing conversation between current user and a contact (by contact.publicId),
  /// or create a canonical one if none exists. Prevents duplicates aggressively:
  /// - checks users/{me}/chats for existing per-user summary (by conversationId or otherPublicId)
  /// - unarchives summary if archived
  /// - searches conversations collection for membership match
  /// - creates canonical conversation using transaction to avoid races
  Future<String> openOrCreateConversation(ChatContact contact) async {
    final uid = currentUid;
    if (uid == null) throw Exception('User not logged in');
    if (contact.publicId.isEmpty) throw ArgumentError('contact.publicId must not be empty');

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      // Resolve contact.publicId -> uid when necessary
      String resolvedOther = contact.publicId;
      if (contact.publicId.startsWith('0x')) {
        final r = await _resolvePublicToUidCached(contact.publicId);
        if (r != null && r.isNotEmpty) resolvedOther = r;
      }

      // Try to get a candidate public id for the other (useful when otherPublicId stored)
      String? otherPublicId = contact.publicId;
      if (!resolvedOther.startsWith('0x')) {
        try {
          final snap = await _firestore.collection('users').doc(resolvedOther).get();
          if (snap.exists) {
            otherPublicId = (snap.data()?['name'] as String?) ?? otherPublicId;
          }
        } catch (_) {}
      }

      // deterministic canonical conversation id
      final conversationId = _makeConversationId(uid, resolvedOther);
      final convRef = _firestore.collection('conversations').doc(conversationId);

      // 1) Check users/{me}/chats/{conversationId} first
      final myChatRef = _firestore.collection('users').doc(uid).collection('chats').doc(conversationId);
      final myChatSnap = await myChatRef.get();
      if (myChatSnap.exists) {
        // if archived -> unarchive (user expects to resume chat)
        final archived = (myChatSnap.data()?['archived'] as bool?) ?? false;
        if (archived) {
          try {
            await myChatRef.update({'archived': false, 'lastUpdated': FieldValue.serverTimestamp()});
          } catch (_) {}
        }
        isLoading = false;
        notifyListeners();
        return conversationId;
      }

      // 2) Strong dedupe: check users/{me}/chats for otherPublicId or resolvedOther
      if (otherPublicId != null && otherPublicId.isNotEmpty) {
        final q = await _firestore
            .collection('users')
            .doc(uid)
            .collection('chats')
            .where('otherPublicId', isEqualTo: otherPublicId)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          final doc = q.docs.first;
          final archived = (doc.data()['archived'] as bool?) ?? false;
          if (archived) {
            try {
              await doc.reference.update({'archived': false, 'lastUpdated': FieldValue.serverTimestamp()});
            } catch (_) {}
          }
          isLoading = false;
          notifyListeners();
          return doc.id;
        }
      }

      // try also by otherPublicId == resolvedOther (sometimes stored as uid)
      final q2 = await _firestore
          .collection('users')
          .doc(uid)
          .collection('chats')
          .where('otherPublicId', isEqualTo: resolvedOther)
          .limit(1)
          .get();
      if (q2.docs.isNotEmpty) {
        final doc = q2.docs.first;
        final archived = (doc.data()['archived'] as bool?) ?? false;
        if (archived) {
          try {
            await doc.reference.update({'archived': false, 'lastUpdated': FieldValue.serverTimestamp()});
          } catch (_) {}
        }
        isLoading = false;
        notifyListeners();
        return doc.id;
      }

      // 3) Search conversations that contain both members (limit small to avoid big scans)
      final convQuery = await _firestore.collection('conversations').where('members', arrayContains: uid).limit(50).get();
      for (final d in convQuery.docs) {
        final members = (d.data()['members'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];
        if (members.contains(resolvedOther)) {
          isLoading = false;
          notifyListeners();
          return d.id;
        }
      }

      // 4) Not found -> create canonical conversation using transaction to avoid duplicate creation
      final createdId = await _firestore.runTransaction<String?>((tx) async {
        final fresh = await tx.get(convRef);
        if (fresh.exists) {
          return convRef.id;
        }

        final now = FieldValue.serverTimestamp();
        final payload = {
          'members': [uid, resolvedOther],
          'isGroup': false,
          'createdAt': now,
          'lastUpdated': now,
        };

        tx.set(convRef, payload, SetOptions(merge: true));
        return convRef.id;
      }, timeout: const Duration(seconds: 15)).catchError((e) => null);

      if (createdId != null) {
        // Ensure per-user chat summary exists for current user.
        final myChatSummaryRef = _firestore.collection('users').doc(uid).collection('chats').doc(createdId);
        try {
          // Before writing, double-check if there is any per-user doc for same otherPublicId (race)
          if (otherPublicId != null && otherPublicId.isNotEmpty) {
            final existing = await _firestore
                .collection('users')
                .doc(uid)
                .collection('chats')
                .where('otherPublicId', isEqualTo: otherPublicId)
                .limit(1)
                .get();
            if (existing.docs.isNotEmpty) {
              // merge into existing rather than create a new doc
              final doc = existing.docs.first;
              await doc.reference.set({
                'lastUpdated': FieldValue.serverTimestamp(),
                'lastMessage': FieldValue.serverTimestamp(), // keep schema: you can update appropriately
              }, SetOptions(merge: true));
              isLoading = false;
              notifyListeners();
              return doc.id;
            }
          }

          await myChatSummaryRef.set({
            'title': contact.displayName,
            'lastMessage': '',
            'lastUpdated': FieldValue.serverTimestamp(),
            'otherPublicId': otherPublicId ?? resolvedOther,
            'isGroup': false,
            'pinned': false,
            'archived': false,
            'unreadCount': 0,
          }, SetOptions(merge: true));
        } catch (_) {
          // ignore; it's okay if rules prevent writing to users/{my}/chats
        }

        // Attempt best-effort to create other user's chat summary (may fail due to rules)
        try {
          final otherChatRef = _firestore.collection('users').doc(resolvedOther).collection('chats').doc(createdId);
          await otherChatRef.set({
            'title': (contact.displayName.isNotEmpty) ? contact.displayName : uid,
            'lastMessage': '',
            'lastUpdated': FieldValue.serverTimestamp(),
            'otherPublicId': uid,
            'isGroup': false,
            'pinned': false,
            'archived': false,
            'unreadCount': 0,
          }, SetOptions(merge: true));
        } catch (_) {}

        isLoading = false;
        notifyListeners();
        return createdId;
      }

      // transaction failed - final attempt to re-check canonical
      final finalSnap = await convRef.get();
      if (finalSnap.exists) {
        isLoading = false;
        notifyListeners();
        return convRef.id;
      }

      throw StateError('Failed to create or find conversation');
    } catch (e) {
      debugPrint('[NewChatVM] openOrCreateConversation error: $e');
      isLoading = false;
      errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
