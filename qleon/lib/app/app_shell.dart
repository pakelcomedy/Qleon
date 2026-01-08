import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async'; // for unawaited
// added imports
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../features/chat/view/chat_list_view.dart';
import '../features/call/view/call_history_view.dart';

// import LocalChatDb + ChatMessage from your viewmodel file
// adjust path if your actual file is at a different path
import '../features/chat/viewmodel/chat_room_viewmodel.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
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
      // ensure local DB initialized before doing ack work
      Future.microtask(() async {
        try {
          await LocalChatDb.init();
        } catch (e) {
          debugPrint('[AppShell] Local DB init failed: $e');
        }

        await _checkOfflineAndShowIfNeeded();

        // also best-effort: when app first opens, try to ACK undelivered local messages
        // do not await so UI won't block
        unawaited(_ackUndeliveredLocalMessages());
      });
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

    // WHEN APP RETURNS TO FOREGROUND -> trigger delivered ACK process
    if (state == AppLifecycleState.resumed) {
      // check offline dialog
      _checkOfflineAndShowIfNeeded();

      // ensure local DB ready and then try to ack undelivered messages (best-effort)
      Future.microtask(() async {
        try {
          await LocalChatDb.init();
        } catch (e) {
          debugPrint('[AppShell] Local DB init failed on resume: $e');
        }
        unawaited(_ackUndeliveredLocalMessages());
      });
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
        final lastOnline = DateTime.fromMillisecondsSinceEpoch(lastMillis);
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
  // DELIVERED: ACK undelivered local messages when app resumes / first open
  // =============================================================
  /// Best-effort: cari pesan lokal yang belum delivered (delivered == 0) dan
  /// sender != currentUser -> kirim update ke Firestore untuk set delivered:true.
  /// Update juga local DB (markDelivered).
  ///
  /// Safety notes:
  /// - Batasi jumlah updates per run (avoid giant writes on startup).
  /// - Catch errors: do not crash app.
  Future<void> _ackUndeliveredLocalMessages() async {
    try {
      // ensure local DB is initialized
      await LocalChatDb.init();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('[AppShell] _ackUndeliveredLocalMessages: user null -> skip');
        return;
      }
      final currentUid = user.uid;

      final db = LocalChatDb.db;

      // limit number rows to process per run (safety)
      const int limitPerRun = 100;

      final rows = await db.query(
        'messages',
        where: 'delivered = 0 AND senderId != ?',
        whereArgs: [currentUid],
        orderBy: 'createdAt ASC',
        limit: limitPerRun,
      );

      if (rows.isEmpty) {
        debugPrint('[AppShell] no undelivered local messages found');
        return;
      }

      debugPrint('[AppShell] found ${rows.length} undelivered local messages -> acking (limit $limitPerRun)');

      final firestore = FirebaseFirestore.instance;

      for (final row in rows) {
        try {
          final msg = ChatMessage.fromLocal(row);

          // Build doc ref and set delivered (idempotent)
          final docRef = firestore
              .collection('conversations')
              .doc(msg.conversationId)
              .collection('messages')
              .doc(msg.id);

          // 1) mark delivered (merge) - idempotent
          await docRef.set({
            'delivered': true,
            'deliveredAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // 2) attempt to delete server copy (best-effort). According to local-first design,
          // the server copy should only be removed once we have the message locally — which we do.
          try {
            await docRef.delete();
          } catch (e) {
            debugPrint('[AppShell] delete after ack failed for ${msg.id}: $e');
          }

          // 3) update local DB (mark delivered)
          await LocalChatDb.markDelivered(msg.conversationId, msg.id, deliveredAt: Timestamp.now());

          debugPrint('[AppShell] acked delivered for ${msg.id} in conv ${msg.conversationId}');
        } catch (e) {
          debugPrint('[AppShell] failed acking one message: $e');
          // continue with next
        }
      }
    } catch (e) {
      debugPrint('[AppShell] _ackUndeliveredLocalMessages error: $e');
    }
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
