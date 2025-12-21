import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app/app_routes.dart';
import 'di/locator.dart';
import 'features/shared/view/splash_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    debugPrint("🔥 Firebase initialized successfully");

    // debug: show firebase apps and currentUser at startup
    try {
      final apps = Firebase.apps.map((a) => a.name).toList();
      debugPrint('Firebase.apps: $apps');
    } catch (e) {
      debugPrint('Firebase.apps read error: $e');
    }

    debugPrint("startup currentUser=${FirebaseAuth.instance.currentUser?.uid}");

    // also log the first idTokenChanges event (tiny helper)
    FirebaseAuth.instance.idTokenChanges().take(1).listen((u) {
      debugPrint('startup idTokenChanges emitted user=${u?.uid}');
    }, onError: (e) {
      debugPrint('startup idTokenChanges error: $e');
    });
  } catch (e) {
    debugPrint("❌ Firebase init failed: $e");
  }

  // DI (register services / singletons)
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
      home: const SplashView(),
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
