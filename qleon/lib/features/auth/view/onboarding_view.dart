import 'package:flutter/material.dart';
import 'login_view.dart';

class OnboardingView extends StatelessWidget {
  const OnboardingView({super.key});

  void _goToLogin(BuildContext context) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, __, ___) => const LoginView(),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null &&
            details.primaryVelocity! < -120) {
          _goToLogin(context);
        }
      },
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

/// subtle, tidak mengganggu
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
