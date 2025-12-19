/// Chat Model
/// ------------------------------------------------------------
/// Represents chat metadata (private or group)
/// - Firestore compatible
/// - Immutable
/// - Message-agnostic
/// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatType {
  direct,
  group,
}

class ChatModel {
  const ChatModel({
    required this.id,
    required this.type,
    required this.members,
    this.lastMessage,
    this.groupId,
    this.createdAt,
    this.updatedAt,
  });

  /// -------------------------------
  /// CORE FIELDS
  /// -------------------------------

  final String id;

  /// direct or group
  final ChatType type;

  /// User IDs participating
  final List<String> members;

  /// Decrypted preview (optional)
  final String? lastMessage;

  /// Linked group metadata (for group chat)
  final String? groupId;

  /// Metadata
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  /// -------------------------------
  /// SERIALIZATION
  /// -------------------------------

  factory ChatModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return ChatModel(
      id: documentId,
      type: map['type'] == 'group' ? ChatType.group : ChatType.direct,
      members: List<String>.from(map['members'] ?? const []),
      lastMessage: map['lastMessage'] as String?,
      groupId: map['groupId'] as String?,
      createdAt: map['createdAt'] as Timestamp?,
      updatedAt: map['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'members': members,
      'lastMessage': lastMessage,
      'groupId': groupId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// -------------------------------
  /// HELPERS
  /// -------------------------------

  bool isMember(String userId) => members.contains(userId);

  bool get isGroup => type == ChatType.group;

  /// Get peer userId (for direct chat)
  String? peerId(String currentUserId) {
    if (type != ChatType.direct) return null;
    return members.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }

  /// -------------------------------
  /// COPY
  /// -------------------------------

  ChatModel copyWith({
    List<String>? members,
    String? lastMessage,
    Timestamp? updatedAt,
  }) {
    return ChatModel(
      id: id,
      type: type,
      members: members ?? this.members,
      lastMessage: lastMessage ?? this.lastMessage,
      groupId: groupId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
