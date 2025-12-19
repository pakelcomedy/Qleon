/// Secure Storage Data Source
/// ------------------------------------------------------------
/// Wrapper around flutter_secure_storage
/// Used for encryption keys, PIN, and sensitive local data
/// ------------------------------------------------------------

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/app_constants.dart';

class SecureStorageDataSource {
  SecureStorageDataSource();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  /// -------------------------------
  /// GENERIC METHODS
  /// -------------------------------

  Future<void> write({
    required String key,
    required String value,
  }) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> read({
    required String key,
  }) async {
    return _storage.read(key: key);
  }

  Future<void> delete({
    required String key,
  }) async {
    await _storage.delete(key: key);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// -------------------------------
  /// ENCRYPTION KEYS
  /// -------------------------------

  Future<void> savePrivateKey(String privateKey) async {
    await write(
      key: StorageKeys.privateKey,
      value: privateKey,
    );
  }

  Future<String?> getPrivateKey() async {
    return read(key: StorageKeys.privateKey);
  }

  Future<void> savePublicKey(String publicKey) async {
    await write(
      key: StorageKeys.publicKey,
      value: publicKey,
    );
  }

  Future<String?> getPublicKey() async {
    return read(key: StorageKeys.publicKey);
  }

  /// -------------------------------
  /// DEVICE & APP LOCK
  /// -------------------------------

  Future<void> saveDeviceId(String deviceId) async {
    await write(
      key: StorageKeys.deviceId,
      value: deviceId,
    );
  }

  Future<String?> getDeviceId() async {
    return read(key: StorageKeys.deviceId);
  }

  Future<void> saveAppPin(String pin) async {
    await write(
      key: StorageKeys.appPin,
      value: pin,
    );
  }

  Future<String?> getAppPin() async {
    return read(key: StorageKeys.appPin);
  }

  Future<void> deleteAppPin() async {
    await delete(key: StorageKeys.appPin);
  }
}
