/// App Routes
/// ------------------------------------------------------------
/// Centralized routing configuration for Qleon
/// Uses named routes for clean navigation
/// ------------------------------------------------------------

import 'package:flutter/material.dart';

import '../features/auth/view/login_view.dart';
import '../features/auth/view/register_view.dart';
import '../features/chat/view/chat_list_view.dart';
import '../features/chat/view/chat_room_view.dart';
import '../features/profile/view/profile_view.dart';
import '../features/settings/view/settings_view.dart';

class AppRoutes {
  AppRoutes._();

  /// -------------------------------
  /// ROUTE NAMES
  /// -------------------------------

  static const String login = '/login';
  static const String register = '/register';
  static const String chats = '/chats';
  static const String chatRoom = '/chat-room';
  static const String profile = '/profile';
  static const String settings = '/settings';

  /// -------------------------------
  /// ROUTE GENERATOR
  /// -------------------------------

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return _page(const LoginView());

      case register:
        return _page(const RegisterView());

      case chats:
        return _page(const ChatListView());

      case chatRoom:
        final chatId = settings.arguments as String;
        return _page(ChatRoomView(chatId: chatId));

      case profile:
        return _page(const ProfileView());

      case settings:
        return _page(const SettingsView());

      default:
        return _page(const Scaffold(
          body: Center(child: Text('Route not found')),
        ));
    }
  }

  /// -------------------------------
  /// PAGE BUILDER
  /// -------------------------------

  static MaterialPageRoute _page(Widget child) {
    return MaterialPageRoute(builder: (_) => child);
  }
}