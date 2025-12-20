import 'package:flutter/material.dart';

import '../../../core/services/auth_service.dart';
import '../../../di/locator.dart';
import '../../../app/app_routes.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slide = Tween<double>(begin: 12, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.forward();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final auth = locator<AuthService>();

      await Future.delayed(const Duration(milliseconds: 900));

      if (!mounted) return;

      if (!auth.hasSeenOnboarding) {
        _go(AppRoutes.onboarding);
        return;
      }

      if (!auth.isLoggedIn) {
        _go(AppRoutes.login);
        return;
      }

      _go(AppRoutes.shell);
    } catch (_) {
      if (!mounted) return;
      _go(AppRoutes.login);
    }
  }

  void _go(String route) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      route,
      (_) => false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: AnimatedBuilder(
              animation: _slide,
              builder: (_, child) {
                return Transform.translate(
                  offset: Offset(0, _slide.value),
                  child: child,
                );
              },
              child: const _BrandText(),
            ),
          ),
        ),
      ),
    );
  }
}

/// =============================================================
/// BRAND TEXT ONLY
/// =============================================================

class _BrandText extends StatelessWidget {
  const _BrandText();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Text(
          'Qleon',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: Color(0xFF111827),
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Secure. Simple. Connected.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
