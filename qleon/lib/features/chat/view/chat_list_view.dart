// chat_list_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../viewmodel/chat_list_viewmodel.dart';
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
  late final ChatListViewModel vm;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  bool get _selectionMode => vm.selectionMode;

  @override
  void initState() {
    super.initState();
    vm = ChatListViewModel();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    vm.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      vm.loadMore();
    }
  }

  void _onSearchChanged() {
    vm.setQuery(_searchController.text.trim());
  }

  Future<bool?> _showConfirmSheet({
    required String title,
    required String message,
    bool destructive = false,
  }) {
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
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
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

  Future<void> _archiveSelected() async {
    if (!vm.hasSelection) return;
    final ok = await _showConfirmSheet(
      title: vm.selectedIds.length > 1 ? 'Archive ${vm.selectedIds.length} chats?' : 'Archive chat?',
      message: 'Selected chats will be moved to archive.',
    );
    if (ok == true) {
      await vm.archiveChats();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Archived')));
    }
  }

  Future<void> _deleteSelected() async {
    if (!vm.hasSelection) return;
    final ok = await _showConfirmSheet(
      title: 'Delete ${vm.selectedIds.length} chats?',
      message: 'This will remove selected chats locally.',
      destructive: true,
    );
    if (ok == true) {
      await vm.deleteChats();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
    }
  }

  Future<void> _archiveSingle(String chatId, String chatTitle) async {
    final ok = await _showConfirmSheet(title: 'Archive chat?', message: 'Move "$chatTitle" to archive?');
    if (ok == true) {
      await vm.archiveChats(chatIds: [chatId]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Archived')));
    }
  }

  Future<void> _deleteSingle(String chatId, String chatTitle) async {
    final ok = await _showConfirmSheet(title: 'Delete chat?', message: 'Delete chat with $chatTitle?', destructive: true);
    if (ok == true) {
      await vm.deleteChats(chatIds: [chatId]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
    }
  }

  void _openChatByConversationId(String conversationId, String title, bool isGroup) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomView(conversationId: conversationId, title: title, isGroup: isGroup),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: _searchController.text.isNotEmpty ? SizedBox(
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
        ),
      ) : const Text('Qleon', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF111827))),
      actions: [
        IconButton(
          icon: Icon(_searchController.text.isNotEmpty ? Icons.close : Icons.search, color: const Color(0xFF374151)),
          onPressed: () {
            if (_searchController.text.isNotEmpty) {
              _searchController.clear();
              vm.setQuery('');
            } else {
              _searchController.selection = TextSelection.collapsed(offset: _searchController.text.length);
            }
            setState(() {});
          },
        ),
        PopupMenuButton<_MenuAction>(
          icon: const Icon(Icons.more_vert, color: Color(0xFF374151)),
          onSelected: (value) {
            switch (value) {
              case _MenuAction.archived:
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    // ArchiveView should read archived chats itself in production;
                    // provide a safe callback to refresh the list when user returns.
                    builder: (_) => ArchiveView<dynamic>(archivedChats: const [], onUnarchive: (item) => vm.refresh()),
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

  PreferredSizeWidget _buildSelectionAppBar() {
    final single = vm.selectedIds.length == 1;
    final firstId = vm.selectedIds.isNotEmpty ? vm.selectedIds.first : '';
    final first = vm.findById(firstId);
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      leading: IconButton(icon: const Icon(Icons.close, color: Color(0xFF111827)), onPressed: vm.clearSelection),
      title: Text(single ? (first?.title ?? '') : '${vm.selectedIds.length} selected', style: const TextStyle(color: Color(0xFF111827))),
      actions: [
        IconButton(icon: const Icon(Icons.archive, color: Color(0xFF4F46E5)), onPressed: _archiveSelected),
        if (single)
          IconButton(
            icon: const Icon(Icons.push_pin, color: Color(0xFF4F46E5)),
            onPressed: () {
              if (first != null) vm.togglePin(first.id);
            },
          ),
        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _deleteSelected),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: vm,
      child: Consumer<ChatListViewModel>(builder: (context, model, _) {
        final items = model.chats;
        return Scaffold(
          backgroundColor: const Color(0xFFF7F8FA),
          appBar: _selectionMode ? _buildSelectionAppBar() : _buildAppBar(),
          body: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await model.refresh();
                  },
                  child: model.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : items.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(40),
                              children: [
                                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.withAlpha((0.4 * 255).round())),
                                const SizedBox(height: 16),
                                const Text('No conversations', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                              ],
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              itemCount: items.length + (model.hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= items.length) {
                                  if (!model.isPaginating) model.loadMore();
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }

                                final chat = items[index];
                                final isSelected = model.selectedIds.contains(chat.id);

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Dismissible(
                                    key: ValueKey(chat.id),
                                    direction: model.selectionMode ? DismissDirection.none : DismissDirection.horizontal,
                                    background: Container(
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.only(left: 18),
                                      decoration: BoxDecoration(
                                          color: Colors.green.withAlpha((0.08 * 255).round()), borderRadius: BorderRadius.circular(18)),
                                      child: const Icon(Icons.archive, color: Colors.green),
                                    ),
                                    secondaryBackground: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 18),
                                      decoration: BoxDecoration(color: Colors.red.withAlpha((0.08 * 255).round()), borderRadius: BorderRadius.circular(18)),
                                      child: const Icon(Icons.delete, color: Colors.red),
                                    ),
                                    confirmDismiss: (dir) async {
                                      if (dir == DismissDirection.startToEnd) {
                                        await _archiveSingle(chat.id, chat.title);
                                        return false;
                                      } else {
                                        await _deleteSingle(chat.id, chat.title);
                                        return false;
                                      }
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.blue.withAlpha((0.12 * 255).round()) : Colors.white,
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.04 * 255).round()), blurRadius: 12, offset: const Offset(0, 4))],
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(18),
                                        splashColor: Colors.blue.withAlpha((0.12 * 255).round()),
                                        highlightColor: Colors.blue.withAlpha((0.06 * 255).round()),
                                        onTap: () {
                                          if (model.selectionMode) {
                                            model.toggleSelection(chat.id);
                                          } else {
                                            // Use conversationId = chat.id
                                            _openChatByConversationId(chat.id, chat.title, chat.isGroup);
                                          }
                                        },
                                        onLongPress: () {
                                          if (!model.selectionMode) {
                                            HapticFeedback.lightImpact();
                                            model.startSelection(chat.id);
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Row(
                                            children: [
                                              _IdentityIndicator(chat: chat),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                  Text(chat.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                                  const SizedBox(height: 6),
                                                  Text(chat.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF6B7280))),
                                                ]),
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  if (chat.pinned) const Icon(Icons.push_pin, size: 16, color: Color(0xFF4F46E5)),
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
          floatingActionButton: model.selectionMode
              ? null
              : FloatingActionButton(
                  backgroundColor: const Color(0xFF4F46E5),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewChatView())),
                  child: const Icon(Icons.edit),
                ),
        );
      }),
    );
  }
}

class _IdentityIndicator extends StatelessWidget {
  final ChatSummary chat;
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

class _ChatMeta extends StatelessWidget {
  final ChatSummary chat;
  const _ChatMeta({required this.chat});

  @override
  Widget build(BuildContext context) {
    final time = _formatTimestamp(chat.lastUpdated);
    return Column(children: [
      Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      if (chat.unreadCount > 0)
        Container(margin: const EdgeInsets.only(top: 6), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(12)), child: Text('${chat.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 12)))
    ]);
  }

  static String _formatTimestamp(Timestamp ts) {
    final dt = ts.toDate();
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

enum _MenuAction { settings, archived }
