```
lib/
│
├── main.dart
│
├── core/
│   ├── constants/
│   │   ├── app_constants.dart
│   │   ├── firebase_constants.dart
│   │   └── encryption_constants.dart
│   │
│   ├── utils/
│   │   ├── validators.dart
│   │   ├── formatters.dart
│   │   └── debouncer.dart
│   │
│   ├── encryption/
│   │   ├── crypto_service.dart
│   │   ├── aes_helper.dart
│   │   ├── rsa_helper.dart
│   │   └── key_manager.dart
│   │
│   ├── notifications/
│   │   ├── fcm_service.dart
│   │   └── local_notification_service.dart
│   │
│   ├── services/
│   │   ├── auth_service.dart
│   │   ├── firestore_service.dart
│   │   ├── storage_service.dart
│   │   └── connectivity_service.dart
│   │
│   └── theme/
│       ├── app_theme.dart
│       └── colors.dart
│
├── data/
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── chat_model.dart
│   │   ├── message_model.dart
│   │   └── group_model.dart
│   │
│   ├── datasources/
│   │   ├── remote/
│   │   │   ├── auth_remote_ds.dart
│   │   │   ├── chat_remote_ds.dart
│   │   │   └── message_remote_ds.dart
│   │   │
│   │   └── local/
│   │       ├── secure_storage_ds.dart
│   │       └── cache_ds.dart
│   │
│   └── repositories/
│       ├── auth_repository.dart
│       ├── chat_repository.dart
│       └── message_repository.dart
│
├── features/
│   ├── auth/
│   │   ├── view/
│   │   │   ├── login_view.dart
│   │   │   └── register_view.dart
│   │   │
│   │   ├── viewmodel/
│   │   │   └── auth_viewmodel.dart
│   │   │
│   │   └── auth_binding.dart
│   │
│   ├── chat/
│   │   ├── view/
│   │   │   ├── chat_list_view.dart
│   │   │   └── chat_room_view.dart
│   │   │
│   │   ├── viewmodel/
│   │   │   ├── chat_list_viewmodel.dart
│   │   │   └── chat_room_viewmodel.dart
│   │   │
│   │   └── chat_binding.dart
│   │
│   ├── profile/
│   │   ├── view/
│   │   │   └── profile_view.dart
│   │   │
│   │   └── viewmodel/
│   │       └── profile_viewmodel.dart
│   │
│   └── settings/
│       ├── view/
│       │   └── settings_view.dart
│       │
│       └── viewmodel/
│           └── settings_viewmodel.dart
│
├── routes/
│   └── app_routes.dart
│
└── di/
    ├── locator.dart
    └── injection.dart
```
