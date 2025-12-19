/// Crypto Service
/// ------------------------------------------------------------
/// High-level cryptographic API for Qleon
/// Combines AES (message encryption), RSA (key exchange)
/// and KeyManager (key lifecycle)
/// ------------------------------------------------------------

import 'dart:typed_data';

import '../../data/datasources/local/secure_storage_ds.dart';
import '../constants/encryption_constants.dart';
import 'aes_helper.dart';
import 'key_manager.dart';

class CryptoService {
  CryptoService(this._keyManager);

  final KeyManager _keyManager;

  /// -------------------------------
  /// INITIALIZATION
  /// -------------------------------

  /// Call once after login / app start
  Future<void> initialize() async {
    await _keyManager.ensureRsaKeyPair();
  }

  /// -------------------------------
  /// OUTGOING MESSAGE
  /// -------------------------------
  /// Encrypts message and returns payload ready for Firestore

  Future<Map<String, dynamic>> encryptMessage({
    required String chatId,
    required String plainText,
    required String recipientPublicKey,
  }) async {
    // Get or generate session key
    Uint8List? sessionKey = _keyManager.getCachedSessionKey(chatId);

    bool isNewSession = false;

    if (sessionKey == null) {
      sessionKey = _keyManager.generateSessionKey();
      _keyManager.cacheSessionKey(chatId: chatId, key: sessionKey);
      isNewSession = true;
    }

    // Encrypt message with AES
    final encryptedPayload = await AesHelper.encrypt(
      plainText: plainText,
      secretKeyBytes: sessionKey,
    );

    // Encrypt AES key if new session
    String? encryptedSessionKey;
    if (isNewSession) {
      encryptedSessionKey = await _keyManager.encryptSessionKeyForRecipient(
        sessionKey: sessionKey,
        recipientPublicKey: recipientPublicKey,
      );
    }

    return {
      EncryptionPayloadFields.iv: encryptedPayload[EncryptionPayloadFields.iv],
      EncryptionPayloadFields.cipherText:
          encryptedPayload[EncryptionPayloadFields.cipherText],
      EncryptionPayloadFields.authTag:
          encryptedPayload[EncryptionPayloadFields.authTag],
      if (encryptedSessionKey != null)
        EncryptionPayloadFields.encryptedSessionKey: encryptedSessionKey,
    };
  }

  /// -------------------------------
  /// INCOMING MESSAGE
  /// -------------------------------
  /// Decrypts message payload from Firestore

  Future<String> decryptMessage({
    required String chatId,
    required Map<String, dynamic> payload,
  }) async {
    Uint8List? sessionKey = _keyManager.getCachedSessionKey(chatId);

    // Decrypt AES key if provided
    if (payload.containsKey(
        EncryptionPayloadFields.encryptedSessionKey)) {
      sessionKey = await _keyManager.decryptSessionKeyFromSender(
        encryptedSessionKey:
            payload[EncryptionPayloadFields.encryptedSessionKey],
      );

      _keyManager.cacheSessionKey(chatId: chatId, key: sessionKey);
    }

    if (sessionKey == null) {
      throw EncryptionErrorCodes.sessionKeyMissing;
    }

    return AesHelper.decrypt(
      payload: payload,
      secretKeyBytes: sessionKey,
    );
  }

  /// -------------------------------
  /// SESSION MANAGEMENT
  /// -------------------------------

  void clearChatSession(String chatId) {
    _keyManager.clearSessionKey(chatId);
  }

  void clearAllSessions() {
    _keyManager.clearAllSessionKeys();
  }
}