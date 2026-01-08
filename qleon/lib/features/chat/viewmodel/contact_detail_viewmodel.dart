import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ContactDetailViewModel (updated)
///
/// - QR payload: name + temp + uid (exact format matching ProfileViewModel).
/// - Public identity: name (fallback to uid or provided id).
/// - safeProfile(): returns profile map excluding sensitive fields like 'email'.
class ContactDetailViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String conversationIdOrId; // can be canonical conv id, legacy conv id, or otherUid/publicId

  // resolved values
  String? currentUid;
  String? contactUid; // resolved other party uid (if available)
  String? conversationId; // resolved canonical conversation id (if available)

  // contact profile (mirror of users/{contactUid})
  Map<String, dynamic>? contactData;

  // convenience accessors for QR format
  String? contactName;
  String? contactTemp;

  // local alias persisted in SharedPreferences
  String? localAlias;

  // state
  bool isLoading = true;
  bool isBlocking = false;
  bool isDeleting = false;
  String? errorMessage;

  // subscriptions
  StreamSubscription<DocumentSnapshot>? _contactSub;
  StreamSubscription<DocumentSnapshot>? _conversationSub;

  ContactDetailViewModel({required this.conversationIdOrId});

  /// Initialize the viewmodel: resolve current user, contact uid and start listeners.
  Future<void> init() async {
    if (currentUid != null) return; // already inited

    try {
      final user = FirebaseAuth.instance.currentUser;
      currentUid = user?.uid;

      // Try resolving conversation -> contact
      conversationId = conversationIdOrId;

      // If conversation doc exists, try to read members and infer contact uid
      final convDoc = await _firestore.collection('conversations').doc(conversationId!).get();
      if (convDoc.exists) {
        final members = (convDoc.data()?['members'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        if (currentUid != null && members.length == 2 && members.contains(currentUid)) {
          contactUid = members.firstWhere((m) => m != currentUid);
        }
      }

      // If we couldn't find contactUid from conversation, try to treat conversationIdOrId as a user id or public id
      if (contactUid == null) {
        final resolved = await _resolveToUidIfNeeded(conversationIdOrId);
        if (resolved != null) {
          contactUid = resolved;
        }
      }

      // If contact uid is known, load local alias and subscribe to contact doc
      await _loadLocalAlias();

      if (contactUid != null) {
        _subscribeToContact(contactUid!);
      }

      // Always subscribe to conversation doc (if exists) to reflect lastUpdated / members
      if (conversationId != null) {
        _subscribeToConversation(conversationId!);
      }

      isLoading = false;
      notifyListeners();
    } catch (e, st) {
      errorMessage = e.toString();
      isLoading = false;
      notifyListeners();
      debugPrint('[ContactVM] init error: $e\n$st');
    }
  }

  /// Listen to users/{contactUid} and update contactData (also update name/temp)
  void _subscribeToContact(String uid) {
    _contactSub?.cancel();
    _contactSub = _firestore.collection('users').doc(uid).snapshots().listen((snap) {
      if (!snap.exists) {
        contactData = null;
        contactName = null;
        contactTemp = null;
        notifyListeners();
        return;
      }
      final data = snap.data();
      contactData = data ?? {};
      // keep convenience fields in sync
      contactName = (data?['name'] as String?) ?? (data?['displayName'] as String?);
      contactTemp = (data?['temp'] as String?);
      notifyListeners();
    }, onError: (e) {
      debugPrint('[ContactVM] contact subscription error: $e');
    });
  }

  void _subscribeToConversation(String convId) {
    _conversationSub?.cancel();
    _conversationSub = _firestore.collection('conversations').doc(convId).snapshots().listen((snap) {
      if (!snap.exists) return;
      final data = snap.data();
      // if members changed and we don't have contactUid, attempt to resolve
      if (data != null && contactUid == null && currentUid != null) {
        final members = (data['members'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        if (members.length == 2 && members.contains(currentUid)) {
          contactUid = members.firstWhere((m) => m != currentUid);
          _loadLocalAlias();
          _subscribeToContact(contactUid!);
        }
      }
      notifyListeners();
    }, onError: (e) {
      debugPrint('[ContactVM] conversation subscription error: $e');
    });
  }

  /// Resolve publicId (like 0x...) or doc id to UID where possible. Returns null if cannot resolve.
  Future<String?> _resolveToUidIfNeeded(String part) async {
    try {
      if (part.isEmpty) return null;
      // quick check: if user doc exists with id == part, treat it as uid
      final doc = await _firestore.collection('users').doc(part).get();
      if (doc.exists) {
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

      return null;
    } catch (e) {
      debugPrint('[ContactVM] _resolveToUidIfNeeded error for $part: $e');
      return null;
    }
  }

  /// Local alias storage key
  String _aliasKey(String uid) => 'contact_alias_$uid';

  Future<void> _loadLocalAlias() async {
    if (contactUid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      localAlias = prefs.getString(_aliasKey(contactUid!));
      notifyListeners();
    } catch (e) {
      debugPrint('[ContactVM] loadLocalAlias error: $e');
    }
  }

  /// Save local alias (persisted locally only)
  Future<void> saveLocalAlias(String alias) async {
    if (contactUid == null) throw StateError('contactUid not resolved');
    try {
      final prefs = await SharedPreferences.getInstance();
      if (alias.isEmpty) {
        await prefs.remove(_aliasKey(contactUid!));
        localAlias = null;
      } else {
        await prefs.setString(_aliasKey(contactUid!), alias);
        localAlias = alias;
      }
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // =========================
  // QR / Public identity API
  // =========================

  /// QR payload expected by app: name + temp + uid (exact)
  /// Returns empty string when any component missing.
  String getQrPayload() {
    final n = contactName ?? contactData?['name']?.toString() ?? contactData?['displayName']?.toString() ?? '';
    final t = contactTemp ?? contactData?['temp']?.toString() ?? '';
    final u = contactUid ?? '';
    if (n.isEmpty || t.isEmpty || u.isEmpty) return '';
    return '$n$t$u';
  }

  /// Public identity for display: prefer name (public id). Fallback to uid, then conversation id.
  String getPublicIdentity() {
    final n = contactName ?? contactData?['name']?.toString() ?? contactData?['displayName']?.toString();
    if (n != null && n.isNotEmpty) return n;
    if (contactUid != null && contactUid!.isNotEmpty) return contactUid!;
    return conversationIdOrId;
  }

  /// Safe profile map for the view: exclude sensitive fields like 'email'
  /// The view should use this rather than contactData directly to avoid leaking email.
  Map<String, dynamic> safeProfile() {
    final src = contactData ?? {};
    final result = <String, dynamic>{};
    // allowlist keys (adjust if you want to expose more)
    const allowed = ['name', 'displayName', 'about', 'phone', 'avatarUrl'];
    for (final k in allowed) {
      if (src.containsKey(k)) result[k] = src[k];
    }
    return result;
  }

  /// A short human-readable identity code (stable-ish) for display
  String generateIdentityCode(String payload) {
    final hash = payload.hashCode.toUnsigned(32);
    return '0x${hash.toRadixString(16).toUpperCase()}';
  }

  // =========================
  // Block / unblock
  // =========================

  /// BLOCK / UNBLOCK
  /// Implementation: maintain a doc at users/{me}/blocked/{them} with blockedAt timestamp.
  Future<void> blockContact() async {
    if (currentUid == null) throw StateError('Not authenticated');
    if (contactUid == null) throw StateError('Contact UID not resolved');
    isBlocking = true;
    notifyListeners();
    try {
      final ref = _firestore.collection('users').doc(currentUid).collection('blocked').doc(contactUid);
      await ref.set({'blockedAt': FieldValue.serverTimestamp(), 'contactUid': contactUid});
      isBlocking = false;
      notifyListeners();
    } catch (e) {
      isBlocking = false;
      errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> unblockContact() async {
    if (currentUid == null) throw StateError('Not authenticated');
    if (contactUid == null) throw StateError('Contact UID not resolved');
    isBlocking = true;
    notifyListeners();
    try {
      final ref = _firestore.collection('users').doc(currentUid).collection('blocked').doc(contactUid);
      await ref.delete();
      isBlocking = false;
      notifyListeners();
    } catch (e) {
      isBlocking = false;
      errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Check if contact is currently blocked by the user
  Future<bool> isContactBlocked() async {
    if (currentUid == null) return false;
    if (contactUid == null) return false;
    try {
      final doc = await _firestore.collection('users').doc(currentUid).collection('blocked').doc(contactUid).get();
      return doc.exists;
    } catch (e) {
      debugPrint('[ContactVM] isContactBlocked error: $e');
      return false;
    }
  }

  // =========================
  // Clear conversation
  // =========================

  /// Delete / clear conversation: soft-delete messages by setting isDeleted=true in batches.
  /// This operation updates messages under conversations/{conversationId}/messages.
  /// Note: Firestore batch write limit is 500 operations; we split into batches accordingly.
  Future<void> clearConversation({int batchSize = 400}) async {
    if (conversationId == null) throw StateError('conversationId not resolved');
    isDeleting = true;
    notifyListeners();

    try {
      final coll = _firestore.collection('conversations').doc(conversationId).collection('messages');
      // paginate using query cursors
      Query query = coll.orderBy('createdAt').limit(batchSize);
      while (true) {
        final snap = await query.get();
        if (snap.docs.isEmpty) break;

        // build batch
        final batch = _firestore.batch();
        for (final d in snap.docs) {
          batch.update(d.reference, {'isDeleted': true});
        }
        await batch.commit();

        if (snap.docs.length < batchSize) break;
        // advance cursor
        final last = snap.docs.last;
        query = coll.orderBy('createdAt').startAfterDocument(last).limit(batchSize);
      }

      isDeleting = false;
      notifyListeners();
    } catch (e) {
      isDeleting = false;
      errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _contactSub?.cancel();
    _conversationSub?.cancel();
    super.dispose();
  }
}
