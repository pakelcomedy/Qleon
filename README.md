```
lib/
│
├── main.dart
│
├── app/
│   ├── app.dart
│   ├── app_routes.dart
│   ├── app_theme.dart
│   └── app_bindings.dart
│
├── core/
│   ├── constants/
│   │   ├── app_constants.dart
│   │   ├── firebase_constants.dart
│   │   └── encryption_constants.dart
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
│   │   ├── connectivity_service.dart
│   │   └── call_service.dart
│   │
│   └── utils/
│       ├── validators.dart
│       ├── formatters.dart
│       └── debouncer.dart
│
├── data/
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── chat_model.dart
│   │   ├── message_model.dart
│   │   ├── group_model.dart
│   │   └── call_model.dart
│   │
│   ├── datasources/
│   │   ├── local/
│   │   │   ├── secure_storage_ds.dart
│   │   │   ├── message_queue_ds.dart
│   │   │   └── cache_ds.dart
│   │   │
│   │   └── remote/
│   │       ├── auth_remote_ds.dart
│   │       ├── chat_remote_ds.dart
│   │       ├── message_remote_ds.dart
│   │       └── call_remote_ds.dart
│   │
│   └── repositories/
│       ├── auth_repository.dart
│       ├── chat_repository.dart
│       ├── message_repository.dart
│       └── call_repository.dart
│
├── features/
│   ├── auth/
│   │   ├── view/
│   │   │   ├── onboarding_view.dart
│   │   │   ├── login_view.dart
│   │   │   ├── register_view.dart
│   │   │   └── forgot_password_view.dart
│   │   │
│   │   └── viewmodel/
│   │       └── auth_viewmodel.dart
│   │
│   ├── chat/
│   │   ├── view/
│   │   │   ├── chat_list_view.dart
│   │   │   ├── chat_room_view.dart
│   │   │   ├── new_chat_view.dart
│   │   │   ├── contact_list_view.dart
│   │   │   ├── add_contact_view.dart
│   │   │   ├── chat_search_view.dart
│   │   │   ├── chat_media_view.dart
│   │   │   └── pinned_chat_view.dart
│   │   │
│   │   └── viewmodel/
│   │       └── chat_viewmodel.dart
│   │
│   ├── group/
│   │   ├── view/
│   │   │   ├── group_list_view.dart
│   │   │   ├── create_group_view.dart
│   │   │   ├── group_detail_view.dart
│   │   │   ├── group_member_view.dart
│   │   │   └── group_media_view.dart
│   │   │
│   │   └── viewmodel/
│   │       └── group_viewmodel.dart
│   │
│   ├── call/
│   │   ├── view/
│   │   │   ├── call_view.dart
│   │   │   ├── incoming_call_view.dart
│   │   │   ├── ongoing_call_view.dart
│   │   │   └── call_history_view.dart
│   │   │
│   │   └── viewmodel/
│   │       └── call_viewmodel.dart
│   │
│   ├── search/
│   │   ├── view/
│   │   │   ├── global_search_view.dart
│   │   │   └── search_result_view.dart
│   │   │
│   │   └── viewmodel/
│   │       └── global_search_viewmodel.dart
│   │
│   ├── archive/
│   │   ├── view/
│   │   │   ├── archive_view.dart
│   │   │   └── archived_chat_detail_view.dart
│   │   │
│   │   └── viewmodel/
│   │       └── archive_viewmodel.dart
│   │
│   ├── settings/
│   │   ├── view/
│   │   │   ├── settings_view.dart
│   │   │   ├── profile_view.dart
│   │   │   ├── privacy_view.dart
│   │   │   ├── blocked_user_view.dart
│   │   │   ├── notification_settings_view.dart
│   │   │   ├── security_view.dart
│   │   │   └── about_app_view.dart
│   │   │
│   │   └── viewmodel/
│   │       └── settings_viewmodel.dart
│   │
│   └── shared/
│       ├── view/
│       │   ├── empty_view.dart
│       │   ├── loading_view.dart
│       │   ├── error_view.dart
│       │   └── maintenance_view.dart
│       │
│       └── viewmodel/
│           └── ui_state_viewmodel.dart
│
├── di/
│   └── locator.dart
│
└── test/
    ├── encryption/
    ├── chat/
    └── group/
```
