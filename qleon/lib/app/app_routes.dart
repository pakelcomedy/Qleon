import 'package:flutter/material.dart';

import '../features/shared/view/splash_view.dart';
import '../features/auth/view/onboarding_view.dart';
import '../features/auth/view/login_view.dart';
import '../features/auth/view/register_view.dart';
import '../features/auth/view/forgot_password_view.dart';
import '../app/app_shell.dart';

class AppRoutes {
  // ROOT
  static const splash = '/';

  // AUTH
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

  // MAIN APP (BOTTOM NAV / CHAT / ETC)
  static const shell = '/app';

  static final Map<String, WidgetBuilder> routes = {
    splash: (_) => const SplashView(),

    onboarding: (_) => const OnboardingView(),
    login: (_) => const LoginView(),
    register: (_) => const RegisterView(),
    forgotPassword: (_) => const ForgotPasswordView(),

    shell: (_) => const AppShell(),
  };
}