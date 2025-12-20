import 'package:flutter/material.dart';
import '../features/chat/view/chat_list_view.dart';
import '../features/call/view/call_history_view.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    ChatListView(),
    CallHistoryView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(child: _pages[_currentIndex]),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  /// =============================================================
  /// ICON-ONLY BOTTOM NAVIGATION BAR
  /// =============================================================
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
