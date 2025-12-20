import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat_room_view.dart';
import 'new_chat_view.dart';
import '../../settings/view/settings_view.dart';
import '../../archive/view/archive_view.dart';

/// Simplified & fixed ChatListView (with bottom-sheet confirmations)
class ChatListView extends StatefulWidget {
  const ChatListView({super.key});

  @override
  State<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> {
  final Set<_DummyChat> _selectedChats = {};
  final List<_DummyChat> _chats = List<_DummyChat>.from(_initialDummyChats);
  final List<_DummyChat> _pinnedChats = [];
  final List<_DummyChat> _archivedChats = [];

  static const int maxPinned = 3;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  bool get _selectionMode => _selectedChats.isNotEmpty;
  bool get _isMultiSelect => _selectedChats.length > 1;
  String get _query => _searchController.text.trim();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // visible chats: exclude archived, apply query, pins first
  List<_DummyChat> get _visibleChats {
    final q = _query.toLowerCase();
    final filtered = _chats.where((c) {
      if (_archivedChats.contains(c)) return false;
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) || c.lastMessage.toLowerCase().contains(q);
    }).toList();

    final pinned = _pinnedChats.where((p) => filtered.contains(p)).toList();
    final others = filtered.where((c) => !_pinnedChats.contains(c)).toList();
    return [...pinned, ...others];
  }

  // selection helpers
  void _startSelection(_DummyChat chat) {
    HapticFeedback.lightImpact();
    setState(() => _selectedChats.add(chat));
  }

  void _toggleSelection(_DummyChat chat) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedChats.contains(chat)) _selectedChats.remove(chat);
      else _selectedChats.add(chat);
    });
  }

  void _clearSelection() => setState(() => _selectedChats.clear());

  // pin logic
  void _togglePinForSelected() {
    if (_selectedChats.isEmpty) return;
    _togglePin(_selectedChats.first);
  }

  void _togglePin(_DummyChat chat) {
    setState(() {
      if (_pinnedChats.contains(chat)) {
        _pinnedChats.remove(chat);
      } else {
        if (_pinnedChats.length >= maxPinned) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 3 pinned chats')));
          return;
        }
        _pinnedChats.add(chat);
        HapticFeedback.mediumImpact();
      }
      _selectedChats.clear();
    });
  }

  // bottom-sheet confirmation helper (replaces AlertDialog)
  Future<bool?> _showConfirmSheet({required String title, required String message, bool destructive = false}) {
    return showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Grab handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(message, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Colors.black87)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: destructive ? Colors.red : const Color(0xFF4F46E5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(destructive ? 'Delete' : 'Confirm', style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // archive / delete (now using bottom sheet)
  Future<void> _archiveSelected() async {
    if (_selectedChats.isEmpty) return;
    final ok = await _showConfirmSheet(
      title: _selectedChats.length > 1 ? 'Archive ${_selectedChats.length} chats?' : 'Archive chat?',
      message: 'Selected chats will be moved to archive.',
    );
    if (ok == true) {
      setState(() {
        for (final s in _selectedChats) {
          if (!_archivedChats.contains(s)) _archivedChats.add(s);
          _pinnedChats.remove(s);
          _chats.remove(s);
        }
        _selectedChats.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Archived')));
    }
  }

  Future<void> _archiveSingle(_DummyChat chat) async {
    final ok = await _showConfirmSheet(title: 'Archive chat?', message: 'Move "${chat.name}" to archive?');
    if (ok == true) {
      setState(() {
        if (!_archivedChats.contains(chat)) _archivedChats.add(chat);
        _pinnedChats.remove(chat);
        _chats.remove(chat);
        _selectedChats.remove(chat);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Archived')));
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedChats.isEmpty) return;
    final ok = await _showConfirmSheet(
      title: 'Delete ${_selectedChats.length} chats?',
      message: 'This will remove selected chats locally.',
      destructive: true,
    );
    if (ok == true) {
      setState(() {
        for (final s in _selectedChats) {
          _pinnedChats.remove(s);
          _chats.remove(s);
          _archivedChats.remove(s);
        }
        _selectedChats.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
    }
  }

  Future<void> _deleteSingle(_DummyChat chat) async {
    final ok = await _showConfirmSheet(
      title: 'Delete chat?',
      message: 'Delete chat with ${chat.name}?',
      destructive: true,
    );
    if (ok == true) {
      setState(() {
        _pinnedChats.remove(chat);
        _archivedChats.remove(chat);
        _chats.remove(chat);
        _selectedChats.remove(chat);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
    }
  }

  // open chat
  void _openChat(_DummyChat chat) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatRoomView(title: chat.name, isGroup: chat.isGroup)));
  }

  // callback from archive page
  void _onUnarchive(_DummyChat chat) {
    setState(() {
      if (_archivedChats.contains(chat)) {
        _archivedChats.remove(chat);
        if (!_chats.contains(chat)) _chats.insert(0, chat);
      }
    });
  }

  // AppBar search toggle
  void _toggleSearch() {
    setState(() {
      if (_isSearching) {
        _isSearching = false;
        _searchController.clear();
      } else {
        _isSearching = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleChats;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: _selectionMode ? _buildSelectionAppBar() : _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future<void>.delayed(const Duration(milliseconds: 500));
                // noop placeholder for data refresh
              },
              child: visible.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(40),
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text('No conversations', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final chat = visible[index];
                        final isSelected = _selectedChats.contains(chat);
                        final isPinned = _pinnedChats.contains(chat);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Dismissible(
                            key: ValueKey(chat.id),
                            direction: _selectionMode ? DismissDirection.none : DismissDirection.horizontal,
                            background: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 18),
                              decoration: BoxDecoration(color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(18)),
                              child: const Icon(Icons.archive, color: Colors.green),
                            ),
                            secondaryBackground: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 18),
                              decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(18)),
                              child: const Icon(Icons.delete, color: Colors.red),
                            ),
                            confirmDismiss: (dir) async {
                              if (dir == DismissDirection.startToEnd) {
                                await _archiveSingle(chat);
                                return false;
                              } else {
                                await _deleteSingle(chat);
                                return false;
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blue.withOpacity(0.12) : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                splashColor: Colors.blue.withOpacity(0.12),
                                highlightColor: Colors.blue.withOpacity(0.06),
                                onTap: () {
                                  if (_selectionMode) _toggleSelection(chat);
                                  else _openChat(chat);
                                },
                                onLongPress: () {
                                  if (!_selectionMode) {
                                    HapticFeedback.lightImpact();
                                    _startSelection(chat);
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
                                          if (isPinned) const Icon(Icons.push_pin, size: 16, color: Color(0xFF4F46E5)),
                                          const SizedBox(height: 4),
                                          _ChatMeta(chat: chat),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton(
              backgroundColor: const Color(0xFF4F46E5),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewChatView())),
              child: const Icon(Icons.edit),
            ),
    );
  }

  // AppBar when not selecting: search toggle + archive/settings
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: _isSearching
          ? SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search conversations',
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (_) => setState(() {}),
              ),
            )
          : const Text('Qleon', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF111827))),
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search, color: const Color(0xFF374151)),
          onPressed: _toggleSearch,
        ),
        PopupMenuButton<_MenuAction>(
          icon: const Icon(Icons.more_vert, color: Color(0xFF374151)),
          onSelected: (value) {
            switch (value) {
              case _MenuAction.archived:
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ArchiveView<_DummyChat>(archivedChats: _archivedChats, onUnarchive: _onUnarchive),
                  ),
                );
                break;
              case _MenuAction.settings:
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsView()));
                break;
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

  // AppBar when selection active
  PreferredSizeWidget _buildSelectionAppBar() {
    final single = _selectedChats.length == 1;
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      leading: IconButton(icon: const Icon(Icons.close, color: Color(0xFF111827)), onPressed: _clearSelection),
      title: Text(single ? _selectedChats.first.name : '${_selectedChats.length} selected', style: const TextStyle(color: Color(0xFF111827))),
      actions: [
        IconButton(icon: const Icon(Icons.archive, color: Color(0xFF4F46E5)), onPressed: _archiveSelected),
        if (single) IconButton(icon: const Icon(Icons.push_pin, color: Color(0xFF4F46E5)), onPressed: _togglePinForSelected),
        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _deleteSelected),
      ],
    );
  }
}

/// Visual widgets
class _IdentityIndicator extends StatelessWidget {
  final _DummyChat chat;
  const _IdentityIndicator({required this.chat});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(shape: BoxShape.circle, color: chat.unreadCount > 0 ? const Color(0xFFEEF2FF) : const Color(0xFFE5E7EB)),
      child: Icon(chat.isGroup ? Icons.groups : Icons.person_outline, color: chat.unreadCount > 0 ? const Color(0xFF4F46E5) : Colors.grey),
    );
  }
}

class _ChatInfo extends StatelessWidget {
  final _DummyChat chat;
  const _ChatInfo({required this.chat});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(chat.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      const SizedBox(height: 6),
      Text(chat.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF6B7280))),
    ]);
  }
}

class _ChatMeta extends StatelessWidget {
  final _DummyChat chat;
  const _ChatMeta({required this.chat});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(chat.time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      if (chat.unreadCount > 0)
        Container(margin: const EdgeInsets.only(top: 6), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(12)), child: Text('${chat.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 12)))
    ]);
  }
}

/// Models & data
enum _MenuAction { settings, archived }

class _DummyChat {
  final String id;
  final String name;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final bool isGroup;

  const _DummyChat({required this.id, required this.name, required this.lastMessage, required this.time, required this.unreadCount, required this.isGroup});
}

const _initialDummyChats = [
  _DummyChat(id: 'c1', name: 'Andi Wijaya', lastMessage: 'File sudah aku upload ke drive', time: '22:10', unreadCount: 3, isGroup: false),
  _DummyChat(id: 'c2', name: 'Tim Qleon', lastMessage: 'Standup besok jam 9 pagi', time: '20:40', unreadCount: 2, isGroup: true),
  _DummyChat(id: 'c3', name: 'Flutter Study Group', lastMessage: 'Pull request sudah di-merge', time: '19:15', unreadCount: 0, isGroup: true),
  _DummyChat(id: 'c4', name: 'Dosen PA', lastMessage: 'Revisi proposal minggu depan', time: '18:05', unreadCount: 1, isGroup: false),
];
