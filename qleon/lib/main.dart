// lib/main.dart (ubah sesuai ini)
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/theme/app_theme.dart';
import 'routes/app_routes.dart';
import 'di/locator.dart'; // sebelumnya injection.dart

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  await setupLocator(); // nama fungsi di locator.dart

  runApp(const QleonApp());
}

class QleonApp extends StatelessWidget {
  const QleonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qleon',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(), // gunakan dark() karena kita buat dark()
      onGenerateRoute: AppRoutes.onGenerateRoute,
      initialRoute: AppRoutes.login,
    );
  }
}