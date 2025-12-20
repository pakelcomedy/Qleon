import 'package:flutter/material.dart';
import 'app/app_routes.dart';

void main() {
  runApp(const QleonApp());
}

class QleonApp extends StatelessWidget {
  const QleonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qleon',
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.shell,
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