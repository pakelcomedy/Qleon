import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/app_routes.dart';
import 'di/locator.dart';
import 'features/auth/view/login_view.dart';
import 'app/app_shell.dart';
import 'features/auth/viewmodel/auth_viewmodel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Init Firebase default (pakai google-services.json auto config)
    await Firebase.initializeApp();
    debugPrint("🔥 Firebase initialized successfully");
  } catch (e) {
    debugPrint("❌ Firebase init failed: $e");
  }

  // DI
  setupLocator();

  runApp(const QleonApp());
}

class QleonApp extends StatelessWidget {
  const QleonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qleon',
      debugShowCheckedModeBanner: false,
      // Use AuthGate as home so we can decide initial screen based on auth state
      home: const AuthGate(),
      routes: AppRoutes.routes,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Colors.white,
          elevation: 0,
        ),
      ),
    );
  }
}

/// AuthGate listens to FirebaseAuth state and returns appropriate screen.
/// - if user != null -> AppShell (main app)
/// - else -> LoginView
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      // Listen to auth state changes so session persistence works automatically
      stream: AuthViewModel.firebaseAuth.authStateChanges(),
      builder: (context, snapshot) {
        // waiting for the first event -> show a simple splash/loader
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // if user is signed in, show main app
        if (snapshot.hasData && snapshot.data != null) {
          return const AppShell();
        }

        // otherwise show login
        return const LoginView();
      },
    );
  }
}