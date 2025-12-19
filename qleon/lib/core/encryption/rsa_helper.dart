/// RSA Helper (RSA-OAEP)
/// ------------------------------------------------------------
/// Handles RSA key generation and AES key wrapping
/// Used for secure key exchange in E2EE
/// ------------------------------------------------------------

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../constants/encryption_constants.dart';

class RsaHelper {
  RsaHelper._();

  /// RSA-OAEP with SHA-256
  static final RsaOaep _algorithm = RsaOaep(
    hashAlgorithm: Sha256(),
  );

  /// -------------------------------
  /// KEY GENERATION
  /// -------------------------------

  static Future<Map<String, String>> generateKeyPair() async {
    final keyPair = await _algorithm.newKeyPair(
      keyPairType: KeyPairType.rsa,
    );

    final publicKey = await keyPair.extractPublicKey();
    final privateKey = await keyPair.extractPrivateKeyBytes();

    return {
      EncryptionKeyFields.publicKey:
          base64Encode(publicKey.bytes),
      EncryptionKeyFields.privateKey:
          base64Encode(privateKey),
    };
  }

  /// -------------------------------
  /// ENCRYPT (WRAP AES KEY)
  /// -------------------------------

  static Future<String> encryptAesKey({
    required Uint8List aesKey,
    required String recipientPublicKeyBase64,
  }) async {
    final publicKeyBytes = base64Decode(recipientPublicKeyBase64);
    final publicKey = SimplePublicKey(
      publicKeyBytes,
      type: KeyPairType.rsa,
    );

    final encrypted = await _algorithm.encrypt(
      aesKey,
      publicKey: publicKey,
    );

    return base64Encode(encrypted);
  }

  /// -------------------------------
  /// DECRYPT (UNWRAP AES KEY)
  /// -------------------------------

  static Future<Uint8List> decryptAesKey({
    required String encryptedAesKeyBase64,
    required String privateKeyBase64,
  }) async {
    try {
      final encryptedBytes = base64Decode(encryptedAesKeyBase64);
      final privateKeyBytes = base64Decode(privateKeyBase64);

      final privateKey = SimpleKeyPairData(
        privateKeyBytes,
        type: KeyPairType.rsa,
      );

      final decrypted = await _algorithm.decrypt(
        encryptedBytes,
        keyPair: privateKey,
      );

      return Uint8List.fromList(decrypted);
    } catch (_) {
      throw EncryptionErrorCodes.keyDecryptionFailed;
    }
  }
}
