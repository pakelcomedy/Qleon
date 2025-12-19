/// AES Helper (AES-256-GCM)
/// ------------------------------------------------------------
/// Provides authenticated encryption & decryption
/// Used for encrypting message content locally (E2EE)
/// ------------------------------------------------------------

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../constants/encryption_constants.dart';

class AesHelper {
  AesHelper._();

  /// AES-GCM algorithm instance
  static final AesGcm _algorithm = AesGcm.with256bits();

  /// -------------------------------
  /// ENCRYPT
  /// -------------------------------
  /// Returns a payload map containing:
  /// iv, ct (cipherText), tag (authTag)
  static Future<Map<String, String>> encrypt({
    required String plainText,
    required Uint8List secretKeyBytes,
  }) async {
    if (plainText.length > EncryptionLimits.maxPlainTextLength) {
      throw EncryptionErrorCodes.invalidPayload;
    }

    final secretKey = SecretKey(secretKeyBytes);

    final iv = _generateIv();

    final secretBox = await _algorithm.encrypt(
      utf8.encode(plainText),
      secretKey: secretKey,
      nonce: iv,
    );

    return {
      EncryptionPayloadFields.iv: base64Encode(iv),
      EncryptionPayloadFields.cipherText:
          base64Encode(secretBox.cipherText),
      EncryptionPayloadFields.authTag: base64Encode(secretBox.mac.bytes),
    };
  }

  /// -------------------------------
  /// DECRYPT
  /// -------------------------------
  /// Accepts encrypted payload and returns plaintext
  static Future<String> decrypt({
    required Map<String, dynamic> payload,
    required Uint8List secretKeyBytes,
  }) async {
    try {
      final iv = base64Decode(payload[EncryptionPayloadFields.iv]);
      final cipherText =
          base64Decode(payload[EncryptionPayloadFields.cipherText]);
      final authTag =
          base64Decode(payload[EncryptionPayloadFields.authTag]);

      final secretKey = SecretKey(secretKeyBytes);

      final secretBox = SecretBox(
        cipherText,
        nonce: iv,
        mac: Mac(authTag),
      );

      final clearBytes = await _algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      return utf8.decode(clearBytes);
    } catch (_) {
      throw EncryptionErrorCodes.decryptionFailed;
    }
  }

  /// -------------------------------
  /// UTILITIES
  /// -------------------------------

  static Uint8List _generateIv() {
    final random = Random.secure();
    final iv = List<int>.generate(
      EncryptionSizes.aesIvSize,
      (_) => random.nextInt(256),
    );
    return Uint8List.fromList(iv);
  }
}