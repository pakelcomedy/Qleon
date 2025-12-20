import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/app_routes.dart';
import 'di/locator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Init Firebase DEFAULT (tanpa firebase_options)
  await Firebase.initializeApp();

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

      initialRoute: AppRoutes.splash,
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
