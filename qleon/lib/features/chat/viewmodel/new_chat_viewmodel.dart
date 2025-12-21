// new_chat_viewmodel.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Simple contact model used by NewChatView & AddContactView
class ChatContact {
  final String publicId; // unique public identity (e.g. name from other user)
  final String displayName; // local alias
  final String publicStatus; // e.g. "Online" or "Last seen ..."
  final bool isOnline;

  ChatContact({
    required this.publicId,
    required this.displayName,
    required this.publicStatus,
    required this.isOnline,
  });

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

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}