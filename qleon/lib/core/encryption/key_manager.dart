/// Key Manager
/// ------------------------------------------------------------
/// Responsible for managing cryptographic keys lifecycle
/// - RSA keypair initialization
/// - AES session key generation & caching
/// - SecureStorage integration
/// ------------------------------------------------------------

import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../../data/datasources/local/secure_storage_ds.dart';
import '../constants/encryption_constants.dart';
import 'rsa_helper.dart';

class KeyManager {
  KeyManager(this._secureStorage);

  final SecureStorageDataSource _secureStorage;

  /// In-memory AES session key cache
  final Map<String, Uint8List> _sessionKeys = {};

  /// -------------------------------
  /// RSA KEYPAIR
  /// -------------------------------

  Future<void> ensureRsaKeyPair() async {
    final existingPrivateKey = await _secureStorage.getPrivateKey();
    final existingPublicKey = await _secureStorage.getPublicKey();

    if (existingPrivateKey != null && existingPublicKey != null) {
      return;
    }

    final keyPair = await RsaHelper.generateKeyPair();

    await _secureStorage.savePrivateKey(
      keyPair[EncryptionKeyFields.privateKey]!,
    );

    await _secureStorage.savePublicKey(
      keyPair[EncryptionKeyFields.publicKey]!,
    );
  }

  Future<String> getPublicKey() async {
    final key = await _secureStorage.getPublicKey();
    if (key == null) {
      throw EncryptionErrorCodes.publicKeyNotFound;
    }
    return key;
  }

  Future<String> getPrivateKey() async {
    final key = await _secureStorage.getPrivateKey();
    if (key == null) {
      throw EncryptionErrorCodes.privateKeyNotFound;
    }
    return key;
  }

  /// -------------------------------
  /// AES SESSION KEYS
  /// -------------------------------

  Uint8List generateSessionKey() {
    final random = Random.secure();
    final key = List<int>.generate(
      EncryptionSizes.aesKeySize,
      (_) => random.nextInt(256),
    );
    return Uint8List.fromList(key);
  }

  void cacheSessionKey({
    required String chatId,
    required Uint8List key,
  }) {
    _sessionKeys[chatId] = key;
  }

  Uint8List? getCachedSessionKey(String chatId) {
    return _sessionKeys[chatId];
  }

  void clearSessionKey(String chatId) {
    _sessionKeys.remove(chatId);
  }

  void clearAllSessionKeys() {
    _sessionKeys.clear();
  }

  /// -------------------------------
  /// KEY EXCHANGE HELPERS
  /// -------------------------------

  Future<String> encryptSessionKeyForRecipient({
    required Uint8List sessionKey,
    required String recipientPublicKey,
  }) async {
    return RsaHelper.encryptAesKey(
      aesKey: sessionKey,
      recipientPublicKeyBase64: recipientPublicKey,
    );
  }

  Future<Uint8List> decryptSessionKeyFromSender({
    required String encryptedSessionKey,
  }) async {
    final privateKey = await getPrivateKey();
    return RsaHelper.decryptAesKey(
      encryptedAesKeyBase64: encryptedSessionKey,
      privateKeyBase64: privateKey,
    );
  }
}