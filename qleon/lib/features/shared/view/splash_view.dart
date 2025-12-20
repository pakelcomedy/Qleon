import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<User?> _waitForAuthState({Duration timeout = const Duration(seconds: 5)}) async {
    // wait for the first auth state event, with timeout
    try {
      final user = await FirebaseAuth.instance.authStateChanges().first.timeout(timeout);
      debugPrint('[Splash] authStateChanges.first emitted: user=${user?.uid}');
      return user;
    } catch (e) {
      debugPrint('[Splash] authStateChanges.first timed out / error: $e');
      return FirebaseAuth.instance.currentUser;
    }
  }

  Future<void> _bootstrap() async {
    try {
      // small visual delay so the splash is visible
      await Future.delayed(const Duration(milliseconds: 700));

      // read onboarding flag (AuthService via locator if available, else SharedPreferences)
      bool hasSeenOnboarding = false;
      try {
        if (locator.isRegistered<AuthService>()) {
          final authService = locator<AuthService>();
          hasSeenOnboarding = authService.hasSeenOnboarding;
          debugPrint('[Splash] using AuthService.hasSeenOnboarding=$hasSeenOnboarding');
        } else {
          final prefs = await SharedPreferences.getInstance();
          hasSeenOnboarding = prefs.getBool('seen_onboarding') ?? false;
          debugPrint('[Splash] prefs seen_onboarding=$hasSeenOnboarding');
        }
      } catch (e) {
        debugPrint('[Splash] reading onboarding flag failed: $e');
        final prefs = await SharedPreferences.getInstance();
        hasSeenOnboarding = prefs.getBool('seen_onboarding') ?? false;
      }

      // Wait for Firebase auth state with small retries
      User? user = await _waitForAuthState(timeout: const Duration(seconds: 5));
      if (user == null) {
        // second try quickly
        await Future.delayed(const Duration(milliseconds: 300));
        user = FirebaseAuth.instance.currentUser;
        debugPrint('[Splash] fallback currentUser after short wait: ${user?.uid}');
      }

      // final safety: try reload current user token (no-op if null)
      if (user != null) {
        try {
          await user.reload();
          debugPrint('[Splash] reloaded user; uid=${FirebaseAuth.instance.currentUser?.uid}');
          user = FirebaseAuth.instance.currentUser;
        } catch (e) {
          debugPrint('[Splash] reload currentUser failed: $e');
        }
      }

      if (!mounted) return;

      if (!hasSeenOnboarding) {
        _go(AppRoutes.onboarding);
        return;
      }

      if (user != null) {
        _go(AppRoutes.shell);
        return;
      }

      _go(AppRoutes.login);
    } catch (e, st) {
      debugPrint('[Splash] bootstrap unexpected error: $e\n$st');
      if (!mounted) return;
      _go(AppRoutes.login);
    }
  }

  void _go(String route) {
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
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
