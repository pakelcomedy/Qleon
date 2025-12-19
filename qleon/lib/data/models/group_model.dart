/// Group Model
/// ------------------------------------------------------------
/// Represents a group chat metadata
/// - Firestore compatible
/// - Immutable
/// - No message / crypto logic here
/// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  const GroupModel({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.members,
    this.photoUrl,
    this.createdAt,
    this.updatedAt,
  });

  /// -------------------------------
  /// CORE FIELDS
  /// -------------------------------

  final String id;

  /// Group display name
  final String name;

  /// Creator userId
  final String createdBy;

  /// List of member userIds
  final List<String> members;

  /// Optional group avatar
  final String? photoUrl;

  /// Metadata
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  /// -------------------------------
  /// SERIALIZATION
  /// -------------------------------

  factory GroupModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return GroupModel(
      id: documentId,
      name: map['name'] as String,
      createdBy: map['createdBy'] as String,
      members: List<String>.from(map['members'] ?? const []),
      photoUrl: map['photoUrl'] as String?,
      createdAt: map['createdAt'] as Timestamp?,
      updatedAt: map['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdBy': createdBy,
      'members': members,
      'photoUrl': photoUrl,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// -------------------------------
  /// HELPERS
  /// -------------------------------

  bool isMember(String userId) => members.contains(userId);

  /// -------------------------------
  /// COPY
  /// -------------------------------

  GroupModel copyWith({
    String? name,
    List<String>? members,
    String? photoUrl,
    Timestamp? updatedAt,
  }) {
    return GroupModel(
      id: id,
      name: name ?? this.name,
      createdBy: createdBy,
      members: members ?? this.members,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
