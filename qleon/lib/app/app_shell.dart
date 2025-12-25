import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/chat/view/chat_list_view.dart';
import '../features/call/view/call_history_view.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  DateTime? _lastBackPressed;

  static const String _lastOnlineKey = 'last_online_at';

  /// 🔴 NOTIF JIKA OFFLINE ≥ 3 HARI
  static const Duration _offlineThreshold = Duration(days: 3);

  final List<Widget> _pages = const [
    ChatListView(),
    CallHistoryView(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    /// cek sekali saat app pertama dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOfflineAndShowIfNeeded();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // =============================================================
  // APP LIFECYCLE
  // =============================================================
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _saveLastOnline();
    }
  }

  Future<void> _saveLastOnline() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _lastOnlineKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  // =============================================================
  // OFFLINE CHECK (≥ 3 HARI)
  // =============================================================
  Future<void> _checkOfflineAndShowIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMillis = prefs.getInt(_lastOnlineKey);
      final now = DateTime.now();

      if (lastMillis != null) {
        final lastOnline =
            DateTime.fromMillisecondsSinceEpoch(lastMillis);
        final diff = now.difference(lastOnline);

        /// 🔔 MUNCUL JIKA SUDAH ATAU DI ATAS 3 HARI
        if (diff >= _offlineThreshold && mounted) {
          final days = diff.inDays;
          await _showOfflineDialog(days);
        }
      }

      /// update last online ke sekarang
      await prefs.setInt(
        _lastOnlineKey,
        now.millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('[AppShell] Offline check error: $e');
    }
  }

  Future<void> _showOfflineDialog(int days) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Koneksi Terputus',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Anda telah offline selama $days hari.\n'
            'Beberapa pesan mungkin tidak tersinkronisasi.',
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Mengerti'),
            ),
          ],
        );
      },
    );
  }

  // =============================================================
  // UI
  // =============================================================
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onBackPressed,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: SafeArea(child: _pages[_currentIndex]),
        bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }

  Future<bool> _onBackPressed() async {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return false;
    }

    final now = DateTime.now();

    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) >
            const Duration(seconds: 2)) {
      _lastBackPressed = now;

      HapticFeedback.lightImpact();

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
          ),
        );

      return false;
    }

    return true;
  }

  // =============================================================
  // BOTTOM NAV
  // =============================================================
  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        selectedItemColor: const Color(0xFF4F46E5),
        unselectedItemColor: const Color(0xFF9CA3AF),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline, size: 28),
            activeIcon: Icon(Icons.chat_bubble, size: 28),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.call_outlined, size: 28),
            activeIcon: Icon(Icons.call, size: 28),
            label: '',
          ),
        ],
      ),
    );
  }
}
