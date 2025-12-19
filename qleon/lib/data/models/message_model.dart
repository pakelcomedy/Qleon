/// Message Model
/// ------------------------------------------------------------
/// Represents a decrypted chat message
/// - Plaintext only (after decryption)
/// - Immutable
/// - UI-safe\n/// ------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  const MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    this.createdAt,
  });

  /// -------------------------------
  /// CORE FIELDS
  /// -------------------------------

  final String id;
  final String senderId;

  /// Decrypted plaintext message
  final String text;

  /// Server timestamp
  final Timestamp? createdAt;

  /// -------------------------------
  /// UI HELPERS
  /// -------------------------------

  bool isFrom(String userId) => senderId == userId;

  /// -------------------------------
  /// COPY
  /// -------------------------------

  MessageModel copyWith({
    String? text,
    Timestamp? createdAt,
  }) {
    return MessageModel(
      id: id,
      senderId: senderId,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
