/// User Model
/// ------------------------------------------------------------
/// Represents a Qleon user profile
/// - Firestore compatible
/// - Immutable
/// - No business logic
/// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    required this.publicKey,
    this.photoUrl,
    this.createdAt,
    this.lastSeen,
  });

  /// -------------------------------
  /// CORE FIELDS
  /// -------------------------------

  final String id;
  final String email;
  final String displayName;

  /// RSA public key (Base64)
  final String publicKey;

  /// Optional avatar
  final String? photoUrl;

  /// Metadata
  final Timestamp? createdAt;
  final Timestamp? lastSeen;

  /// -------------------------------
  /// SERIALIZATION
  /// -------------------------------

  factory UserModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return UserModel(
      id: documentId,
      email: map['email'] as String,
      displayName: map['displayName'] as String,
      publicKey: map['publicKey'] as String,
      photoUrl: map['photoUrl'] as String?,
      createdAt: map['createdAt'] as Timestamp?,
      lastSeen: map['lastSeen'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'publicKey': publicKey,
      'photoUrl': photoUrl,
      'createdAt': createdAt,
      'lastSeen': lastSeen,
    };
  }

  /// -------------------------------
  /// COPY
  /// -------------------------------

  UserModel copyWith({
    String? email,
    String? displayName,
    String? publicKey,
    String? photoUrl,
    Timestamp? lastSeen,
  }) {
    return UserModel(
      id: id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      publicKey: publicKey ?? this.publicKey,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}