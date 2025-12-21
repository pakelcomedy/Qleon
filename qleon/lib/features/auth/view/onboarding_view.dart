import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../app/app_routes.dart';

class OnboardingView extends StatelessWidget {
  const OnboardingView({super.key});

  /// Finish onboarding: simpan flag dulu, baru navigasi
  Future<void> _finishOnboarding(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('seen_onboarding', true);
      debugPrint('[Onboarding] seen_onboarding=true');
    } catch (e) {
      debugPrint('[Onboarding] error saving seen_onboarding: $e');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      debugPrint('[Onboarding] user logged in, go to AppShell');
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.shell, (_) => false);
      }
    } else {
      debugPrint('[Onboarding] user null, go to Login');
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
      }
    }
  }

  void _onHorizontalDragEnd(BuildContext context, DragEndDetails details) {
    if (details.primaryVelocity != null && details.primaryVelocity! < -120) {
      _finishOnboarding(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) => _onHorizontalDragEnd(context, details),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Spacer(),
                Text(
                  'Qleon',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Simple. Secure.\nReal-time messaging.',
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.45,
                    color: Colors.black54,
                  ),
                ),
                Spacer(),
                _SwipeHint(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeHint extends StatelessWidget {
  const _SwipeHint();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.35,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: const [
          Text(
            'Swipe to continue',
            style: TextStyle(fontSize: 13),
          ),
          SizedBox(width: 6),
          Icon(Icons.arrow_forward_ios, size: 14),
        ],
      ),
    );
  }
}
