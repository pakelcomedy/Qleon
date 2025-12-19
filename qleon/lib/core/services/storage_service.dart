/// Storage Service
/// ------------------------------------------------------------
/// Centralized Firebase Storage access
/// Used for:
/// - Profile images
/// - Chat media (image, video, file)
/// ------------------------------------------------------------

import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  StorageService(this._storage);

  final FirebaseStorage _storage;

  /// -------------------------------
  /// CORE INSTANCE
  /// -------------------------------

  FirebaseStorage get instance => _storage;

  /// -------------------------------
  /// REFERENCES
  /// -------------------------------

  Reference userAvatarRef(String userId) {
    return _storage.ref().child('users/$userId/avatar.jpg');
  }

  Reference chatMediaRef({
    required String chatId,
    required String fileName,
  }) {
    return _storage.ref().child('chats/$chatId/media/$fileName');
  }

  /// -------------------------------
  /// UPLOAD
  /// -------------------------------

  Future<String> uploadFile({
    required Reference ref,
    required File file,
    SettableMetadata? metadata,
  }) async {
    final task = await ref.putFile(file, metadata);
    return task.ref.getDownloadURL();
  }

  /// -------------------------------
  /// DELETE
  /// -------------------------------

  Future<void> deleteFile(Reference ref) async {
    await ref.delete();
  }
}
