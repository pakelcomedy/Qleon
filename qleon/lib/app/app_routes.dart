import 'package:flutter/material.dart';

import '../features/auth/view/onboarding_view.dart';
import '../features/auth/view/login_view.dart';
import '../features/auth/view/register_view.dart';
import '../features/auth/view/forgot_password_view.dart';
import '../app/app_shell.dart';

class AppRoutes {
  // splash is handled as home in MaterialApp; no '/' mapping to avoid conflict
  static const splash = '/splash';

  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

  static const shell = '/app';

  static final Map<String, WidgetBuilder> routes = {
    onboarding: (_) => const OnboardingView(),
    login: (_) => const LoginView(),
    register: (_) => const RegisterView(),
    forgotPassword: (_) => const ForgotPasswordView(),
    shell: (_) => const AppShell(),
  };
}
