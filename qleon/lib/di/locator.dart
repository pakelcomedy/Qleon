import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../core/services/auth_service.dart';
import '../core/services/firestore_service.dart';
import '../core/services/storage_service.dart';
import '../core/services/connectivity_service.dart';

import '../core/encryption/crypto_service.dart';
import '../core/notifications/fcm_service.dart';
import '../core/notifications/local_notification_service.dart';

import '../data/datasources/local/secure_storage_ds.dart';

final GetIt locator = GetIt.instance;

Future<void> setupLocator() async {
  /// -------------------------------
  /// PLATFORM / SDK
  /// -------------------------------
  locator.registerLazySingleton<Connectivity>(
    () => Connectivity(),
  );

  /// -------------------------------
  /// FIREBASE CORE
  /// -------------------------------
  locator.registerLazySingleton<FirebaseAuth>(
    () => FirebaseAuth.instance,
  );

  locator.registerLazySingleton<FirebaseFirestore>(
    () => FirebaseFirestore.instance,
  );

  locator.registerLazySingleton<FirebaseStorage>(
    () => FirebaseStorage.instance,
  );

  locator.registerLazySingleton<FirebaseMessaging>(
    () => FirebaseMessaging.instance,
  );

  /// -------------------------------
  /// LOCAL STORAGE
  /// -------------------------------
  locator.registerLazySingleton<SecureStorageDataSource>(
    () => SecureStorageDataSource(),
  );

  /// -------------------------------
  /// CORE SERVICES
  /// -------------------------------
  locator.registerLazySingleton<AuthService>(
    () => AuthService(locator<FirebaseAuth>()),
  );

  locator.registerLazySingleton<FirestoreService>(
    () => FirestoreService(locator<FirebaseFirestore>()),
  );

  locator.registerLazySingleton<StorageService>(
    () => StorageService(locator<FirebaseStorage>()),
  );

  locator.registerLazySingleton<ConnectivityService>(
    () => ConnectivityService(locator<Connectivity>()),
  );

  /// -------------------------------
  /// ENCRYPTION
  /// -------------------------------
  locator.registerLazySingleton<CryptoService>(
    () => CryptoService(locator<SecureStorageDataSource>()),
  );

  /// -------------------------------
  /// NOTIFICATIONS
  /// -------------------------------
  locator.registerLazySingleton<LocalNotificationService>(
    () => LocalNotificationService(),
  );

  locator.registerLazySingleton<FcmService>(
    () => FcmService(
      locator<FirebaseMessaging>(),
      locator<LocalNotificationService>(),
    ),
  );
}