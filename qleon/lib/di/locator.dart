// import 'package:get_it/get_it.dart';

// import '../core/services/auth_service.dart';
// import '../core/services/firestore_service.dart';
// import '../core/services/storage_service.dart';
// import '../core/services/connectivity_service.dart';
// import '../core/services/call_service.dart';

// import '../core/notifications/fcm_service.dart';
// import '../core/notifications/local_notification_service.dart';

// import '../data/datasources/local/secure_storage_ds.dart';
// import '../data/datasources/local/message_queue_ds.dart';
// import '../data/datasources/local/cache_ds.dart';

// import '../data/datasources/remote/auth_remote_ds.dart';
// import '../data/datasources/remote/chat_remote_ds.dart';
// import '../data/datasources/remote/message_remote_ds.dart';
// import '../data/datasources/remote/call_remote_ds.dart';

// import '../data/repositories/auth_repository.dart';
// import '../data/repositories/chat_repository.dart';
// import '../data/repositories/message_repository.dart';
// import '../data/repositories/call_repository.dart';

// import '../features/auth/viewmodel/auth_viewmodel.dart';
// import '../features/chat/viewmodel/chat_viewmodel.dart';
// import '../features/group/viewmodel/group_viewmodel.dart';
// import '../features/call/viewmodel/call_viewmodel.dart';
// import '../features/archive/viewmodel/archive_viewmodel.dart';
// import '../features/settings/viewmodel/settings_viewmodel.dart';
// import '../features/shared/viewmodel/ui_state_viewmodel.dart';

// final GetIt locator = GetIt.instance;

// Future<void> setupLocator() async {
//   /// =============================================================
//   /// LOCAL DATASOURCES
//   /// =============================================================
//   locator.registerLazySingleton<SecureStorageDS>(
//     () => SecureStorageDS(),
//   );

//   locator.registerLazySingleton<MessageQueueDS>(
//     () => MessageQueueDS(),
//   );

//   locator.registerLazySingleton<CacheDS>(
//     () => CacheDS(),
//   );

//   /// =============================================================
//   /// REMOTE DATASOURCES
//   /// =============================================================
//   locator.registerLazySingleton<AuthRemoteDS>(
//     () => AuthRemoteDS(),
//   );

//   locator.registerLazySingleton<ChatRemoteDS>(
//     () => ChatRemoteDS(),
//   );

//   locator.registerLazySingleton<MessageRemoteDS>(
//     () => MessageRemoteDS(),
//   );

//   locator.registerLazySingleton<CallRemoteDS>(
//     () => CallRemoteDS(),
//   );

//   /// =============================================================
//   /// CORE SERVICES
//   /// =============================================================
//   locator.registerLazySingleton<AuthService>(
//     () => AuthService(
//       locator<AuthRemoteDS>(),
//       locator<SecureStorageDS>(),
//     ),
//   );

//   locator.registerLazySingleton<FirestoreService>(
//     () => FirestoreService(),
//   );

//   locator.registerLazySingleton<StorageService>(
//     () => StorageService(),
//   );

//   locator.registerLazySingleton<ConnectivityService>(
//     () => ConnectivityService(),
//   );

//   locator.registerLazySingleton<CallService>(
//     () => CallService(
//       locator<CallRemoteDS>(),
//     ),
//   );

//   /// =============================================================
//   /// NOTIFICATION SERVICES
//   /// =============================================================
//   locator.registerLazySingleton<FCMService>(
//     () => FCMService(),
//   );

//   locator.registerLazySingleton<LocalNotificationService>(
//     () => LocalNotificationService(),
//   );

//   /// =============================================================
//   /// REPOSITORIES
//   /// =============================================================
//   locator.registerLazySingleton<AuthRepository>(
//     () => AuthRepository(
//       locator<AuthService>(),
//     ),
//   );

//   locator.registerLazySingleton<ChatRepository>(
//     () => ChatRepository(
//       locator<ChatRemoteDS>(),
//       locator<FirestoreService>(),
//     ),
//   );

//   locator.registerLazySingleton<MessageRepository>(
//     () => MessageRepository(
//       locator<MessageRemoteDS>(),
//       locator<MessageQueueDS>(),
//       locator<FirestoreService>(),
//     ),
//   );

//   locator.registerLazySingleton<CallRepository>(
//     () => CallRepository(
//       locator<CallService>(),
//     ),
//   );

//   /// =============================================================
//   /// VIEWMODELS (FACTORY)
//   /// =============================================================
//   locator.registerFactory<AuthViewModel>(
//     () => AuthViewModel(
//       locator<AuthRepository>(),
//     ),
//   );

//   locator.registerFactory<ChatViewModel>(
//     () => ChatViewModel(
//       locator<ChatRepository>(),
//       locator<MessageRepository>(),
//     ),
//   );

//   locator.registerFactory<GroupViewModel>(
//     () => GroupViewModel(
//       locator<ChatRepository>(),
//     ),
//   );

//   locator.registerFactory<CallViewModel>(
//     () => CallViewModel(
//       locator<CallRepository>(),
//     ),
//   );

//   locator.registerFactory<ArchiveViewModel>(
//     () => ArchiveViewModel(
//       locator<ChatRepository>(),
//     ),
//   );

//   locator.registerFactory<SettingsViewModel>(
//     () => SettingsViewModel(
//       locator<AuthRepository>(),
//     ),
//   );

//   locator.registerLazySingleton<UIStateViewModel>(
//     () => UIStateViewModel(),
//   );
// }

import 'package:get_it/get_it.dart';

import '../core/services/auth_service.dart';

final GetIt locator = GetIt.instance;

void setupLocator() {
  // Services
  locator.registerLazySingleton<AuthService>(
    () => AuthService(),
  );
}