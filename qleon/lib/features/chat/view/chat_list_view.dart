import 'package:flutter/material.dart';
import 'chat_room_view.dart';
import 'new_chat_view.dart';
import '../../settings/view/settings_view.dart';
import '../../archive/view/archive_view.dart';

class ChatListView extends StatelessWidget {
  const ChatListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: dummyChats.length,
              itemBuilder: (context, index) {
                final chat = dummyChats[index];
                return _ChatCard(
                  chat: chat,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatRoomView(
                          title: chat.name,
                          isGroup: chat.isGroup,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4F46E5),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const NewChatView(),
            ),
          );
        },
        child: const Icon(Icons.edit),
      ),
    );
  }

  /// =============================================================
  /// APP BAR
  /// =============================================================
  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Qleon',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF111827),
        ),
      ),
      actions: [
        PopupMenuButton<_MenuAction>(
          icon: const Icon(Icons.more_vert, color: Color(0xFF374151)),
          onSelected: (value) {
            switch (value) {
              case _MenuAction.archived:
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ArchiveView(),
                  ),
                );
                break;
              case _MenuAction.settings:
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsView(),
                  ),
                );
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _MenuAction.archived,
              child: Text('Archived'),
            ),
            PopupMenuItem(
              value: _MenuAction.settings,
              child: Text('Settings'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.search, color: Colors.grey),
            SizedBox(width: 8),
            Text(
              'Search conversations',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

/// =============================================================
/// CHAT CARD
/// =============================================================
class _ChatCard extends StatelessWidget {
  final _DummyChat chat;
  final VoidCallback onTap;

  const _ChatCard({
    required this.chat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _IdentityIndicator(chat: chat),
            const SizedBox(width: 14),
            Expanded(child: _ChatInfo(chat: chat)),
            _ChatMeta(chat: chat),
          ],
        ),
      ),
    );
  }
}

/// =============================================================
/// IDENTITY INDICATOR (NO AVATAR)
/// =============================================================
class _IdentityIndicator extends StatelessWidget {
  final _DummyChat chat;
  const _IdentityIndicator({required this.chat});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: chat.unreadCount > 0
            ? const Color(0xFFEEF2FF)
            : const Color(0xFFE5E7EB),
      ),
      child: Center(
        child: Icon(
          chat.isGroup ? Icons.groups : Icons.person_outline,
          color: chat.unreadCount > 0
              ? const Color(0xFF4F46E5)
              : Colors.grey,
          size: 22,
        ),
      ),
    );
  }
}

/// =============================================================
/// CHAT INFO
/// =============================================================
class _ChatInfo extends StatelessWidget {
  final _DummyChat chat;
  const _ChatInfo({required this.chat});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          chat.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Color(0xFF111827),
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          chat.lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}

/// =============================================================
/// CHAT META
/// =============================================================
class _ChatMeta extends StatelessWidget {
  final _DummyChat chat;
  const _ChatMeta({required this.chat});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          chat.time,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 6),
        if (chat.unreadCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              chat.unreadCount.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

/// =============================================================
/// MODELS
/// =============================================================
enum _MenuAction { settings, archived }

class _DummyChat {
  final String name;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final bool isGroup;

  const _DummyChat({
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.isGroup,
  });
}

/// =============================================================
/// DUMMY DATA
/// =============================================================
const dummyChats = [
  _DummyChat(
    name: 'Andi Wijaya',
    lastMessage: 'File sudah aku upload ke drive',
    time: '22:10',
    unreadCount: 3,
    isGroup: false,
  ),
  _DummyChat(
    name: 'Tim Qleon',
    lastMessage: 'Standup besok jam 9 pagi',
    time: '20:40',
    unreadCount: 2,
    isGroup: true,
  ),
  _DummyChat(
    name: 'Flutter Study Group',
    lastMessage: 'Pull request sudah di-merge',
    time: '19:15',
    unreadCount: 0,
    isGroup: true,
  ),
  _DummyChat(
    name: 'Dosen PA',
    lastMessage: 'Revisi proposal minggu depan',
    time: '18:05',
    unreadCount: 1,
    isGroup: false,
  ),
];
