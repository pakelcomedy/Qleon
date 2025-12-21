import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<double>(begin: 12, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.delayed(const Duration(milliseconds: 700));

    // --- baca onboarding flag dari SharedPreferences ---
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('seen_onboarding') ?? false;
    debugPrint('[Splash] seen_onboarding=$hasSeenOnboarding');

    // --- ambil user login Firebase ---
    User? user;
    try {
      user = await FirebaseAuth.instance.idTokenChanges().first.timeout(const Duration(seconds: 6));
    } catch (_) {
      user = FirebaseAuth.instance.currentUser;
    }

    if (!mounted) return;

    if (!hasSeenOnboarding) {
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.onboarding, (_) => false);
      return;
    }

    if (user != null) {
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.shell, (_) => false);
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
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
