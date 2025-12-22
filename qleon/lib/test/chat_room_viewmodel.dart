// // chat_room_viewmodel.dart
// import 'dart:async';
// import 'dart:io';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:flutter/foundation.dart';
// import 'package:uuid/uuid.dart';

// /// ChatMessage model used by ChatRoomView + ViewModel
// class ChatMessage {
//   final String id; // firestore doc id OR temp id (temp_...)
//   final String senderId;
//   final String text;
//   final String? replyToMessageId;
//   final String type; // 'text' | 'image' | 'file' | ...
//   final Timestamp createdAt; // server timestamp if available or built from createdAtClient
//   final bool isLocal; // optimistic local message waiting server confirm
//   final Map<String, dynamic>? extras;
//   final String? clientId; // client-side id for dedupe
//   final int? createdAtClient; // milliseconds since epoch (client-side)

//   ChatMessage({
//     required this.id,
//     required this.senderId,
//     required this.text,
//     this.replyToMessageId,
//     required this.type,
//     required this.createdAt,
//     this.isLocal = false,
//     this.extras,
//     this.clientId,
//     this.createdAtClient,
//   });

//   factory ChatMessage.fromMap(String id, Map<String, dynamic> m) {
//     // server may store createdAt (Timestamp) or createdAtClient (int)
//     Timestamp createdAt;
//     if (m['createdAt'] is Timestamp) {
//       createdAt = m['createdAt'] as Timestamp;
//     } else if (m['createdAtClient'] is int) {
//       createdAt = Timestamp.fromMillisecondsSinceEpoch(m['createdAtClient'] as int);
//     } else {
//       createdAt = Timestamp.now();
//     }

//     return ChatMessage(
//       id: id,
//       senderId: (m['senderId'] as String?) ?? '',
//       text: (m['text'] as String?) ?? '',
//       replyToMessageId: (m['replyTo'] as String?),
//       type: (m['type'] as String?) ?? 'text',
//       createdAt: createdAt,
//       isLocal: false,
//       extras: (m['extras'] as Map<String, dynamic>?) ?? null,
//       clientId: (m['clientId'] as String?) ?? (m['extras'] is Map ? (m['extras']['clientId'] as String?) : null),
//       createdAtClient: (m['createdAtClient'] is int) ? (m['createdAtClient'] as int) : null,
//     );
//   }

//   Map<String, dynamic> toMap() {
//     final map = <String, dynamic>{
//       'senderId': senderId,
//       'text': text,
//       'replyTo': replyToMessageId,
//       'type': type,
//       'extras': extras,
//     };
//     if (clientId != null) map['clientId'] = clientId;
//     if (createdAtClient != null) map['createdAtClient'] = createdAtClient;
//     // don't include server createdAt here
//     return map;
//   }

//   ChatMessage copyWith({
//     String? id,
//     String? senderId,
//     String? text,
//     String? replyToMessageId,
//     String? type,
//     Timestamp? createdAt,
//     bool? isLocal,
//     Map<String, dynamic>? extras,
//     String? clientId,
//     int? createdAtClient,
//   }) {
//     return ChatMessage(
//       id: id ?? this.id,
//       senderId: senderId ?? this.senderId,
//       text: text ?? this.text,
//       replyToMessageId: replyToMessageId ?? this.replyToMessageId,
//       type: type ?? this.type,
//       createdAt: createdAt ?? this.createdAt,
//       isLocal: isLocal ?? this.isLocal,
//       extras: extras ?? this.extras,
//       clientId: clientId ?? this.clientId,
//       createdAtClient: createdAtClient ?? this.createdAtClient,
//     );
//   }
// }

// /// ViewModel for chat room
// class ChatRoomViewModel extends ChangeNotifier {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseStorage _storage = FirebaseStorage.instance;

//   final String conversationId;
//   final int pageSize;

//   // optional: known participant ids
//   final List<String>? participantIds;

//   StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messagesSub;
//   List<ChatMessage> messages = [];
//   bool isLoading = true;
//   bool isSending = false;
//   String? errorMessage;

//   final Set<String> selectedMessageIds = {};
//   final Map<String, bool> typingByUser = {};

//   DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
//   bool hasMore = true;
//   bool isPaginating = false;

//   final Map<String, int> _localIndexByTempId = {};
//   StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _conversationSub;

//   final Set<String> _participantSet = {};
//   static final _uuid = const Uuid();

//   ChatRoomViewModel({
//     required this.conversationId,
//     this.pageSize = 40,
//     this.participantIds,
//   }) {
//     if (participantIds != null) _participantSet.addAll(participantIds!.where((e) => e.isNotEmpty));
//   }

//   String? get currentUid => _auth.currentUser?.uid;

//   /// Returns canonical conversation id for a 1-on-1 pair: sorted uids joined by underscore
//   /// Use this helper when creating/opening a 1-on-1 chat so both sides use same convo id.
//   static String canonicalConversationId(String a, String b) {
//     final list = [a, b]..sort();
//     return '${list[0]}_${list[1]}';
//   }

//   void addParticipants(List<String> ids) {
//     _participantSet.addAll(ids.where((e) => e.isNotEmpty));
//   }

//   Future<void> init() async {
//     if (currentUid == null) {
//       isLoading = false;
//       errorMessage = 'User not logged in';
//       notifyListeners();
//       return;
//     }

//     await _ensureParticipants();

//     await _messagesSub?.cancel();
//     _messagesSub = null;

//     isLoading = true;
//     notifyListeners();

//     final baseQuery = _firestore
//         .collection('conversations')
//         .doc(conversationId)
//         .collection('messages')
//         .orderBy('createdAt', descending: true)
//         .limit(pageSize);

//     _messagesSub = baseQuery.snapshots(includeMetadataChanges: true).listen((snap) async {
//       try {
//         _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
//         hasMore = snap.docs.length >= pageSize;

//         final docs = snap.docs;
//         final List<ChatMessage> loaded = docs.reversed.map((d) => ChatMessage.fromMap(d.id, d.data())).toList();

//         // If participants still empty, derive from loaded messages' senders and persist.
//         if (_participantSet.isEmpty) {
//           final senders = loaded.map((m) => m.senderId).where((s) => s.isNotEmpty).toSet();
//           if (senders.isNotEmpty) {
//             _participantSet.addAll(senders);
//             try {
//               await _firestore.collection('conversations').doc(conversationId).set({
//                 'participants': _participantSet.toList(),
//               }, SetOptions(merge: true));
//               if (kDebugMode) debugPrint('🔍 participants auto-saved from messages: $_participantSet');
//             } catch (e) {
//               if (kDebugMode) debugPrint('❌ failed to write participants: $e');
//             }
//           }
//         }

//         // Merge server-loaded messages + optimistic local
//         final merged = _mergeLoadedAndLocal(loaded);

//         // Deduplicate aggressively (prefer server).
//         final deduped = _dedupeAndSort(merged);

//         messages = deduped;
//         _rebuildLocalIndexMap();

//         isLoading = false;
//         errorMessage = null;
//         if (kDebugMode) {
//           debugPrint('📬 snapshot: server=${loaded.length}, localCandidates=${_localIndexByTempId.length}, merged=${messages.length}');
//         }

//         notifyListeners();
//       } catch (e, st) {
//         isLoading = false;
//         errorMessage = e.toString();
//         notifyListeners();
//         if (kDebugMode) debugPrint('❌ listener error: $e\n$st');
//       }
//     }, onError: (e) {
//       isLoading = false;
//       errorMessage = e.toString();
//       notifyListeners();
//       if (kDebugMode) debugPrint('Firestore snapshot error: $e');
//     });

//     await _conversationSub?.cancel();
//     _conversationSub = _firestore.collection('conversations').doc(conversationId).snapshots().listen((snap) {
//       if (snap.exists) {
//         final data = snap.data() ?? {};
//         final rawParticipants = data['participants'];
//         if (rawParticipants is List) {
//           _participantSet.addAll(rawParticipants.map((e) => e.toString()));
//         }
//         final Map<String, dynamic>? typing = (data['typing'] as Map<String, dynamic>?);
//         if (typing != null) {
//           typingByUser.clear();
//           typing.forEach((k, v) {
//             typingByUser[k] = v == true;
//           });
//           notifyListeners();
//         }
//       }
//     }, onError: (_) {});
//   }

//   Future<void> disposeSubscriptions() async {
//     await _messagesSub?.cancel();
//     await _conversationSub?.cancel();
//     _messagesSub = null;
//     _conversationSub = null;
//   }

//   @override
//   void dispose() {
//     disposeSubscriptions();
//     super.dispose();
//   }

//   void _rebuildLocalIndexMap() {
//     _localIndexByTempId.clear();
//     for (var i = 0; i < messages.length; i++) {
//       final m = messages[i];
//       if (m.isLocal) _localIndexByTempId[m.id] = i;
//     }
//   }

//   Future<void> _ensureParticipants() async {
//     if (_participantSet.isNotEmpty) return;
//     try {
//       final convoRef = _firestore.collection('conversations').doc(conversationId);
//       final snap = await convoRef.get();
//       if (snap.exists) {
//         final data = snap.data() ?? {};
//         final raw = data['participants'];
//         if (raw is List) {
//           _participantSet.addAll(raw.map((e) => e.toString()));
//           if (kDebugMode) debugPrint('🔍 participants loaded from convo doc: $_participantSet');
//           return;
//         }
//       }

//       // fallback: infer from conversationId tokens
//       final parts = <String>{};
//       final separators = ['_', '-', ':'];
//       for (final sep in separators) {
//         if (conversationId.contains(sep)) {
//           final split = conversationId.split(sep);
//           for (final p in split) {
//             final t = p.trim();
//             if (t.length >= 8) parts.add(t);
//           }
//         }
//       }
//       if (parts.isNotEmpty) {
//         _participantSet.addAll(parts);
//         if (kDebugMode) debugPrint('🔍 participants inferred: $_participantSet');
//         return;
//       }

//       final uid = currentUid;
//       if (uid != null) {
//         _participantSet.add(uid);
//         if (kDebugMode) debugPrint('🔍 participants fallback to currentUid: $uid');
//       }
//     } catch (e) {
//       if (kDebugMode) debugPrint('❌ _ensureParticipants error: $e');
//     }
//   }

//   List<ChatMessage> _mergeLoadedAndLocal(List<ChatMessage> loaded) {
//     // server clientIds
//     final Set<String> serverClientIds = {};
//     for (final s in loaded) {
//       if (s.clientId != null && s.clientId!.isNotEmpty) serverClientIds.add(s.clientId!);
//     }

//     // local messages currently in state
//     final localMessages = messages.where((m) => m.isLocal).toList();

//     // keep local messages that are not present on server (by clientId)
//     final List<ChatMessage> keptLocal = [];
//     for (final lm in localMessages) {
//       final localTempId = lm.clientId ?? lm.id;
//       if (localTempId != null && serverClientIds.contains(localTempId)) {
//         // server has it -> drop optimistic local
//         continue;
//       } else {
//         keptLocal.add(lm);
//       }
//     }

//     // Combine: server (oldest->newest) + keptLocal at end
//     return [...loaded, ...keptLocal];
//   }

//   List<ChatMessage> _dedupeAndSort(List<ChatMessage> input) {
//     // Build map by server id and by clientId
//     final Map<String, ChatMessage> byId = {};
//     final Map<String, ChatMessage> byClientId = {};
//     for (final m in input) {
//       byId[m.id] = m;
//       if (m.clientId != null && m.clientId!.isNotEmpty) byClientId[m.clientId!] = m;
//     }

//     // Replace optimistic local (isLocal==true) with server message if clientId matches
//     final List<ChatMessage> cleaned = [];
//     final seenServerIds = <String>{};
//     for (final m in input) {
//       if (!m.isLocal) {
//         // server message: add
//         if (!seenServerIds.contains(m.id)) {
//           cleaned.add(m);
//           seenServerIds.add(m.id);
//         }
//       } else {
//         // local optimistic: if server already has same clientId, skip
//         final localTempId = m.clientId ?? m.id;
//         if (localTempId != null && byClientId.containsKey(localTempId) && byClientId[localTempId] != m) {
//           // skip because server version exists
//           continue;
//         }
//         // otherwise keep optimistic
//         cleaned.add(m);
//       }
//     }

//     // Additional heuristic de-dup: group by (sender|text|replyTo) and prefer server version
//     final Map<String, ChatMessage> keyToMessage = {};
//     for (final m in cleaned) {
//       final key = '${m.senderId}|${m.type}|${m.text}|${m.replyToMessageId ?? ''}';
//       if (!keyToMessage.containsKey(key)) {
//         keyToMessage[key] = m;
//       } else {
//         final prev = keyToMessage[key]!;
//         // prefer non-local
//         if (!prev.isLocal && m.isLocal) continue;
//         if (!m.isLocal && prev.isLocal) keyToMessage[key] = m;
//         // otherwise keep earlier one
//       }
//     }

//     final List<ChatMessage> out = keyToMessage.values.toList();

//     // Sort by createdAt (server Timestamp if present) falling back to createdAtClient
//     out.sort((a, b) {
//       final aMillis = _timestampToMillis(a.createdAt) ?? a.createdAtClient ?? 0;
//       final bMillis = _timestampToMillis(b.createdAt) ?? b.createdAtClient ?? 0;
//       return aMillis.compareTo(bMillis);
//     });

//     return out;
//   }

//   int? _timestampToMillis(Timestamp? ts) {
//     if (ts == null) return null;
//     try {
//       return ts.millisecondsSinceEpoch;
//     } catch (_) {
//       return null;
//     }
//   }

//   Future<void> sendTextMessage(String text, {String? replyToMessageId}) async {
//     if (text.trim().isEmpty) return;
//     if (currentUid == null) throw Exception('User not logged in');

//     isSending = true;
//     notifyListeners();

//     final tempId = 'temp_${_uuid.v4()}';
//     final nowMillis = DateTime.now().millisecondsSinceEpoch;
//     final nowTs = Timestamp.fromMillisecondsSinceEpoch(nowMillis);

//     final localMsg = ChatMessage(
//       id: tempId,
//       senderId: currentUid!,
//       text: text,
//       replyToMessageId: replyToMessageId,
//       type: 'text',
//       createdAt: nowTs,
//       isLocal: true,
//       clientId: tempId,
//       createdAtClient: nowMillis,
//     );

//     // optimistic append
//     messages.add(localMsg);
//     _localIndexByTempId[tempId] = messages.length - 1;
//     notifyListeners();

//     try {
//       final msgRef = _firestore.collection('conversations').doc(conversationId).collection('messages').doc();

//       // ensure participants known
//       await _ensureParticipants();

//       final payload = {
//         'senderId': currentUid,
//         'text': text,
//         'replyTo': replyToMessageId,
//         'type': 'text',
//         'createdAt': FieldValue.serverTimestamp(),
//         'createdAtClient': nowMillis,
//         'clientId': tempId,
//         'participants': _participantSet.toList(),
//       };

//       await msgRef.set(payload);

//       // Update conversation metadata and per-user chat docs
//       await _updateConversationAndNotifyParticipants(
//         previewText: text,
//         messageId: msgRef.id,
//         clientId: tempId,
//       );

//       // update sender chat summary
//       await _updateUserChatSummaryOnSend(text);
//     } catch (e) {
//       errorMessage = e.toString();
//       notifyListeners();
//       rethrow;
//     } finally {
//       isSending = false;
//       notifyListeners();
//     }
//   }

//   Future<void> sendAttachment({
//     required File file,
//     required String fileName,
//     required String contentType,
//     String? replyToMessageId,
//   }) async {
//     if (currentUid == null) throw Exception('User not logged in');

//     isSending = true;
//     notifyListeners();

//     final tempId = 'temp_${_uuid.v4()}';
//     final nowMillis = DateTime.now().millisecondsSinceEpoch;
//     final nowTs = Timestamp.fromMillisecondsSinceEpoch(nowMillis);

//     final localMsg = ChatMessage(
//       id: tempId,
//       senderId: currentUid!,
//       text: fileName,
//       replyToMessageId: replyToMessageId,
//       type: 'file',
//       createdAt: nowTs,
//       isLocal: true,
//       extras: {'uploadName': fileName},
//       clientId: tempId,
//       createdAtClient: nowMillis,
//     );

//     messages.add(localMsg);
//     _localIndexByTempId[tempId] = messages.length - 1;
//     notifyListeners();

//     try {
//       final storagePath = 'conversations/$conversationId/${_uuid.v4()}_$fileName';
//       final ref = _storage.ref().child(storagePath);

//       final metadata = SettableMetadata(contentType: contentType);
//       final uploadTask = ref.putFile(file, metadata);
//       final snapshot = await uploadTask.whenComplete(() {});
//       final url = await snapshot.ref.getDownloadURL();

//       final msgRef = _firestore.collection('conversations').doc(conversationId).collection('messages').doc();

//       await _ensureParticipants();

//       final payload = {
//         'senderId': currentUid,
//         'text': url,
//         'displayName': fileName,
//         'type': 'file',
//         'createdAt': FieldValue.serverTimestamp(),
//         'createdAtClient': nowMillis,
//         'extras': {
//           'contentType': contentType,
//           'storagePath': storagePath,
//           'fileName': fileName,
//         },
//         'replyTo': replyToMessageId,
//         'clientId': tempId,
//         'participants': _participantSet.toList(),
//       };

//       await msgRef.set(payload);

//       await _updateConversationAndNotifyParticipants(
//         previewText: '[Attachment]',
//         messageId: msgRef.id,
//         clientId: tempId,
//       );

//       await _updateUserChatSummaryOnSend('[Attachment]');
//     } catch (e) {
//       errorMessage = e.toString();
//       notifyListeners();
//       rethrow;
//     } finally {
//       isSending = false;
//       notifyListeners();
//     }
//   }

//   Future<void> deleteMessages(List<String> messageIds) async {
//     if (currentUid == null) throw Exception('User not logged in');
//     if (messageIds.isEmpty) return;

//     isSending = true;
//     notifyListeners();

//     final batch = _firestore.batch();
//     try {
//       for (final id in messageIds) {
//         final ref = _firestore.collection('conversations').doc(conversationId).collection('messages').doc(id);
//         batch.delete(ref);
//       }
//       await batch.commit();

//       messages.removeWhere((m) => messageIds.contains(m.id));
//       selectedMessageIds.removeAll(messageIds);
//       notifyListeners();
//     } catch (e) {
//       errorMessage = e.toString();
//       notifyListeners();
//       rethrow;
//     } finally {
//       isSending = false;
//       notifyListeners();
//     }
//   }

//   Future<void> markConversationRead() async {
//     final uid = currentUid;
//     if (uid == null) return;
//     try {
//       final docRef = _firestore.collection('users').doc(uid).collection('chats').doc(conversationId);
//       await docRef.update({'unreadCount': 0, 'lastSeenAt': FieldValue.serverTimestamp()});
//     } catch (_) {}
//   }

//   Future<void> setTyping(bool isTyping) async {
//     final uid = currentUid;
//     if (uid == null) return;
//     try {
//       final convoRef = _firestore.collection('conversations').doc(conversationId);
//       await convoRef.set({
//         'typing': {uid: isTyping}
//       }, SetOptions(merge: true));
//     } catch (_) {}
//   }

//   void startSelection(String messageId) {
//     selectedMessageIds.add(messageId);
//     notifyListeners();
//   }

//   void toggleSelection(String messageId) {
//     if (selectedMessageIds.contains(messageId))
//       selectedMessageIds.remove(messageId);
//     else
//       selectedMessageIds.add(messageId);
//     notifyListeners();
//   }

//   void clearSelection() {
//     selectedMessageIds.clear();
//     notifyListeners();
//   }

//   Future<void> loadMore() async {
//     if (!hasMore || isPaginating) return;
//     final uid = currentUid;
//     if (uid == null) return;
//     if (_lastDoc == null) return;

//     isPaginating = true;
//     notifyListeners();

//     try {
//       final nextSnap = await _firestore
//           .collection('conversations')
//           .doc(conversationId)
//           .collection('messages')
//           .orderBy('createdAt', descending: true)
//           .startAfterDocument(_lastDoc!)
//           .limit(pageSize)
//           .get();

//       final more = nextSnap.docs.reversed.map((d) => ChatMessage.fromMap(d.id, d.data())).toList();
//       messages = [...more, ...messages];
//       _lastDoc = nextSnap.docs.isNotEmpty ? nextSnap.docs.last : _lastDoc;
//       hasMore = nextSnap.docs.length >= pageSize;
//       _rebuildLocalIndexMap();
//       notifyListeners();
//     } catch (e) {
//       errorMessage = e.toString();
//       notifyListeners();
//       rethrow;
//     } finally {
//       isPaginating = false;
//       notifyListeners();
//     }
//   }

//   Future<void> _updateUserChatSummaryOnSend(String previewText) async {
//     final uid = currentUid;
//     if (uid == null) return;
//     final docRef = _firestore.collection('users').doc(uid).collection('chats').doc(conversationId);
//     try {
//       await docRef.set({
//         'lastMessage': previewText,
//         'lastUpdated': FieldValue.serverTimestamp(),
//         'unreadCount': 0,
//       }, SetOptions(merge: true));
//     } catch (_) {}
//   }

//   Future<void> _updateConversationAndNotifyParticipants({
//     required String previewText,
//     required String messageId,
//     required String clientId,
//   }) async {
//     final convoRef = _firestore.collection('conversations').doc(conversationId);
//     await _ensureParticipants();
//     final sender = currentUid;
//     if (sender != null) _participantSet.add(sender);

//     // Try to infer missing participants from conversationId if still only sender present
//     if (_participantSet.length == 1 && sender != null) {
//       final inferred = <String>{};
//       final separators = ['_', '-', ':'];
//       for (final sep in separators) {
//         if (conversationId.contains(sep)) {
//           final split = conversationId.split(sep);
//           for (final p in split) {
//             final t = p.trim();
//             if (t.isNotEmpty && t != sender && t.length >= 8) inferred.add(t);
//           }
//         }
//       }
//       if (inferred.isNotEmpty) _participantSet.addAll(inferred);
//     }

//     final convoPayload = {
//       'participants': _participantSet.toList(),
//       'lastMessage': previewText,
//       'lastUpdated': FieldValue.serverTimestamp(),
//     };
//     try {
//       await convoRef.set(convoPayload, SetOptions(merge: true));
//     } catch (e) {
//       if (kDebugMode) debugPrint('❌ failed to set convo payload: $e');
//     }

//     final batch = _firestore.batch();
//     for (final p in _participantSet) {
//       final chatDoc = _firestore.collection('users').doc(p).collection('chats').doc(conversationId);
//       if (p == sender) {
//         batch.set(chatDoc, {
//           'lastMessage': previewText,
//           'lastUpdated': FieldValue.serverTimestamp(),
//           'unreadCount': 0,
//         }, SetOptions(merge: true));
//       } else {
//         batch.set(chatDoc, {
//           'lastMessage': previewText,
//           'lastUpdated': FieldValue.serverTimestamp(),
//           'unreadCount': FieldValue.increment(1),
//         }, SetOptions(merge: true));
//       }
//     }

//     try {
//       await batch.commit();
//     } catch (e) {
//       if (kDebugMode) debugPrint('❌ batch commit failed: $e');
//     }

//     if (kDebugMode) debugPrint('🛰️ convo updated, participants=${_participantSet.length}, uids=${_participantSet.toList()}');
//   }

//   ChatMessage? findMessageById(String id) {
//     try {
//       return messages.firstWhere((m) => m.id == id);
//     } catch (_) {
//       return null;
//     }
//   }
// }
