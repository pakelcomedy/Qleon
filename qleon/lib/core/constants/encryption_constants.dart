/// Qleon Encryption Constants
/// ------------------------------------------------------------
/// SECURITY RULES:
/// - NO keys, secrets, or runtime-generated values here
/// - Constants only (sizes, algorithms, labels)
/// - Used by crypto_service, helpers, and key_manager
/// ------------------------------------------------------------

/// -------------------------------
/// ALGORITHM IDENTIFIERS
/// -------------------------------
class EncryptionAlgorithms {
  EncryptionAlgorithms._();

  // Symmetric
  static const String aesGcm = 'AES/GCM/NoPadding';

  // Asymmetric
  static const String rsaOaep = 'RSA/ECB/OAEPWithSHA-256AndMGF1Padding';

  // Hash
  static const String sha256 = 'SHA-256';
}

/// -------------------------------
/// KEY & BLOCK SIZES (BYTES)
/// -------------------------------
class EncryptionSizes {
  EncryptionSizes._();

  // AES
  static const int aesKeySize = 32; // 256-bit
  static const int aesIvSize = 12; // Recommended for GCM
  static const int aesTagSize = 16; // 128-bit auth tag

  // RSA
  static const int rsaKeySize = 2048; // bits

  // Hash
  static const int hashSize = 32; // SHA-256 output
}

/// -------------------------------
/// ENCRYPTION VERSIONING
/// -------------------------------
/// Used for forward compatibility and key rotation
class EncryptionVersion {
  EncryptionVersion._();

  static const String current = 'v1';
}

/// -------------------------------
/// PAYLOAD FIELD NAMES
/// -------------------------------
/// These fields are embedded inside encrypted JSON payloads
class EncryptionPayloadFields {
  EncryptionPayloadFields._();

  static const String version = 'ver';
  static const String iv = 'iv';
  static const String cipherText = 'ct';
  static const String authTag = 'tag';
  static const String encryptedKey = 'ek';
}

/// -------------------------------
/// KEY PURPOSE LABELS
/// -------------------------------
/// Used by key_manager to identify stored keys
class KeyPurpose {
  KeyPurpose._();

  static const String identity = 'identity'; // RSA keypair
  static const String session = 'session'; // AES per-chat
}

/// -------------------------------
/// SECURITY LIMITS
/// -------------------------------
class EncryptionLimits {
  EncryptionLimits._();

  static const int maxPlainTextLength = 4000;
  static const int maxEncryptedPayloadSize = 8192;
}

/// -------------------------------
/// ERROR CODES (INTERNAL)
/// -------------------------------
class EncryptionErrorCodes {
  EncryptionErrorCodes._();

  static const String invalidPayload = 'INVALID_ENCRYPTED_PAYLOAD';
  static const String unsupportedVersion = 'UNSUPPORTED_ENCRYPTION_VERSION';
  static const String keyNotFound = 'ENCRYPTION_KEY_NOT_FOUND';
  static const String decryptionFailed = 'DECRYPTION_FAILED';
}
