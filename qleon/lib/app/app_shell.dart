import 'package:flutter/material.dart';
import '../features/chat/view/chat_list_view.dart';
import '../features/call/view/call_history_view.dart';
import '../features/archive/view/archive_view.dart';
import '../features/settings/view/settings_view.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  final _pages = const [
    ChatListView(),
    CallHistoryView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (value) => setState(() => _index = value),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.call_outlined),
            label: 'Calls',
          ),
        ],
      ),
    );
  }
}