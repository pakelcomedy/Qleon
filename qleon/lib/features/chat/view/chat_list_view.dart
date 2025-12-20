import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'chat_room_view.dart';
import 'new_chat_view.dart';
import '../../settings/view/settings_view.dart';
import '../../archive/view/archive_view.dart';

class ChatListView extends StatefulWidget {
  const ChatListView({super.key});

  @override
  State<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> {
  final Set<_DummyChat> _selectedChats = {};
  final List<_DummyChat> _pinnedChats = [];

  static const int maxPinned = 3;

  @override
  Widget build(BuildContext context) {
    final isMultiSelect = _selectedChats.length > 1;

    final chats = [
      ..._pinnedChats,
      ...dummyChats.where((c) => !_pinnedChats.contains(c)),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: _selectedChats.isEmpty
          ? _buildAppBar(context)
          : _buildSelectionAppBar(isMultiSelect),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                final isSelected = _selectedChats.contains(chat);
                final isPinned = _pinnedChats.contains(chat);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.blue.withOpacity(0.12)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      splashColor: Colors.blue.withOpacity(0.15),
                      highlightColor: Colors.blue.withOpacity(0.08),
                      onTap: () {
                        if (_selectedChats.isNotEmpty) {
                          setState(() {
                            if (isSelected) {
                              _selectedChats.remove(chat);
                            } else {
                              _selectedChats.add(chat);
                              HapticFeedback.lightImpact();
                            }
                          });
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatRoomView(
                                title: chat.name,
                                isGroup: chat.isGroup,
                              ),
                            ),
                          );
                        }
                      },
                      onLongPress: () {
                        if (_selectedChats.isEmpty) {
                          HapticFeedback.lightImpact();
                          setState(() => _selectedChats.add(chat));
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            _IdentityIndicator(chat: chat),
                            const SizedBox(width: 14),
                            Expanded(child: _ChatInfo(chat: chat)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (isPinned)
                                  const Icon(Icons.push_pin,
                                      size: 16,
                                      color: Color(0xFF4F46E5)),
                                const SizedBox(height: 4),
                                _ChatMeta(chat: chat),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedChats.isEmpty
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF4F46E5),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NewChatView()),
              ),
              child: const Icon(Icons.edit),
            )
          : null,
    );
  }

  AppBar _buildSelectionAppBar(bool isMultiSelect) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Color(0xFF111827)),
        onPressed: () => setState(() => _selectedChats.clear()),
      ),
      title: Text(
        _selectedChats.length == 1
            ? _selectedChats.first.name
            : '${_selectedChats.length} selected',
        style: const TextStyle(color: Color(0xFF111827)),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.archive, color: Color(0xFF4F46E5)),
          onPressed: () => setState(() => _selectedChats.clear()),
        ),
        if (!isMultiSelect)
          IconButton(
            icon: const Icon(Icons.push_pin, color: Color(0xFF4F46E5)),
            onPressed: _togglePin,
          ),
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => setState(() => _selectedChats.clear()),
        ),
      ],
    );
  }

  void _togglePin() {
    final chat = _selectedChats.first;

    setState(() {
      if (_pinnedChats.contains(chat)) {
        _pinnedChats.remove(chat);
      } else {
        if (_pinnedChats.length >= maxPinned) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 3 pinned chats'),
              duration: Duration(seconds: 1),
            ),
          );
          return;
        }
        _pinnedChats.add(chat);
        HapticFeedback.mediumImpact();
      }
      _selectedChats.clear();
    });
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Qleon',
        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF111827)),
      ),
      actions: [
        PopupMenuButton<_MenuAction>(
          icon: const Icon(Icons.more_vert, color: Color(0xFF374151)),
          onSelected: (value) {
            if (value == _MenuAction.archived) {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ArchiveView()));
            } else {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsView()));
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: _MenuAction.archived, child: Text('Archived')),
            PopupMenuItem(value: _MenuAction.settings, child: Text('Settings')),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.search, color: Colors.grey),
              SizedBox(width: 8),
              Text('Search conversations',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
}

/// ============================
/// CHAT PARTS
/// ============================

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
      child: Icon(
        chat.isGroup ? Icons.groups : Icons.person_outline,
        color:
            chat.unreadCount > 0 ? const Color(0xFF4F46E5) : Colors.grey,
      ),
    );
  }
}

class _ChatInfo extends StatelessWidget {
  final _DummyChat chat;
  const _ChatInfo({required this.chat});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(chat.name,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 6),
        Text(chat.lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF6B7280))),
      ],
    );
  }
}

class _ChatMeta extends StatelessWidget {
  final _DummyChat chat;
  const _ChatMeta({required this.chat});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(chat.time,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        if (chat.unreadCount > 0)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: const Color(0xFF4F46E5),
                borderRadius: BorderRadius.circular(12)),
            child: Text('${chat.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
      ],
    );
  }
}

/// ============================
/// DATA
/// ============================

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

const dummyChats = [
  _DummyChat(
      name: 'Andi Wijaya',
      lastMessage: 'File sudah aku upload ke drive',
      time: '22:10',
      unreadCount: 3,
      isGroup: false),
  _DummyChat(
      name: 'Tim Qleon',
      lastMessage: 'Standup besok jam 9 pagi',
      time: '20:40',
      unreadCount: 2,
      isGroup: true),
  _DummyChat(
      name: 'Flutter Study Group',
      lastMessage: 'Pull request sudah di-merge',
      time: '19:15',
      unreadCount: 0,
      isGroup: true),
  _DummyChat(
      name: 'Dosen PA',
      lastMessage: 'Revisi proposal minggu depan',
      time: '18:05',
      unreadCount: 1,
      isGroup: false),
];
