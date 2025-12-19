import 'package:flutter/material.dart';
import 'app_shell.dart';

class AppRoutes {
  static const String shell = '/';

  static final Map<String, WidgetBuilder> routes = {
    shell: (_) => const AppShell(),
  };
}
