/// Qleon Dependency Injection Wiring
/// ------------------------------------------------------------
/// This file connects:
/// Services → DataSources → Repositories → ViewModels
/// NO UI imports allowed here
/// ------------------------------------------------------------

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'locator.dart';

import '../core/services/auth_service.dart';
import '../core/services/firestore_service.dart';
import '../core/services/storage_service.dart';

import '../core/encryption/crypto_service.dart';

import '../data/datasources/remote/auth_remote_ds.dart';
import '../data/datasources/remote/chat_remote_ds.dart';
import '../data/datasources/remote/message_remote_ds.dart';

import '../data/datasources/local/secure_storage_ds.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/message_repository.dart';

import '../features/auth/viewmodel/auth_viewmodel.dart';
import '../features/chat/viewmodel/chat_list_viewmodel.dart';
import '../features/chat/viewmodel/chat_room_viewmodel.dart';
import '../features/profile/viewmodel/profile_viewmodel.dart';
import '../features/settings/viewmodel/settings_viewmodel.dart';

/// ------------------------------------------------------------
/// DATA SOURCES
/// ------------------------------------------------------------

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSource(
    locator<AuthService>(),
  ),
);

final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource>(
  (ref) => ChatRemoteDataSource(
    locator<FirestoreService>(),
  ),
);

final messageRemoteDataSourceProvider = Provider<MessageRemoteDataSource>(
  (ref) => MessageRemoteDataSource(
    locator<FirestoreService>(),
    locator<CryptoService>(),
  ),
);

final secureStorageProvider = Provider<SecureStorageDataSource>(
  (ref) => locator<SecureStorageDataSource>(),
);

/// ------------------------------------------------------------
/// REPOSITORIES
/// ------------------------------------------------------------

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    remote: ref.read(authRemoteDataSourceProvider),
    secureStorage: ref.read(secureStorageProvider),
  ),
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(
    remote: ref.read(chatRemoteDataSourceProvider),
  ),
);

final messageRepositoryProvider = Provider<MessageRepository>(
  (ref) => MessageRepository(
    remote: ref.read(messageRemoteDataSourceProvider),
  ),
);

/// ------------------------------------------------------------
/// VIEW MODELS
/// ------------------------------------------------------------

final authViewModelProvider = StateNotifierProvider<AuthViewModel, AuthState>(
  (ref) => AuthViewModel(
    authRepository: ref.read(authRepositoryProvider),
  ),
);

final chatListViewModelProvider = StateNotifierProvider<ChatListViewModel, ChatListState>(
  (ref) => ChatListViewModel(
    chatRepository: ref.read(chatRepositoryProvider),
  ),
);

final chatRoomViewModelProvider = StateNotifierProvider<ChatRoomViewModel, ChatRoomState>(
  (ref) => ChatRoomViewModel(
    messageRepository: ref.read(messageRepositoryProvider),
  ),
);

final profileViewModelProvider = StateNotifierProvider<ProfileViewModel, ProfileState>(
  (ref) => ProfileViewModel(
    authRepository: ref.read(authRepositoryProvider),
  ),
);

final settingsViewModelProvider = StateNotifierProvider<SettingsViewModel, SettingsState>(
  (ref) => SettingsViewModel(
    secureStorage: ref.read(secureStorageProvider),
  ),
);
