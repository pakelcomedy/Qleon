import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../call/view/call_view.dart';
import '../../group/view/group_detail_view.dart';
import 'contact_detail_view.dart';

/// Chat room view with:
/// - message multi-select (long press to start, tap to toggle)
/// - single-select actions: reply / copy / delete
/// - multi-select: copy / delete (reply hidden)
/// - swipe right to reply (confirmDismiss used to prevent removal)
/// - reply preview above input (like WhatsApp)
class ChatRoomView extends StatefulWidget {
  final String title;
  final bool isGroup;

  const ChatRoomView({
    super.key,
    required this.title,
    this.isGroup = false,
  });

  @override
  State<ChatRoomView> createState() => _ChatRoomViewState();
}

class _ChatRoomViewState extends State<ChatRoomView> {
  final Set<int> _selected = {}; // store message indices
  String? _replyMessageId; // id of message we're replying to
  final TextEditingController _controller = TextEditingController();

  bool get selectionMode => _selected.isNotEmpty;
  _DummyMessage? get _replyMessage {
    if (_replyMessageId == null) return null;
    return dummyMessages.firstWhere((m) => m.id == _replyMessageId, orElse: () => null as _DummyMessage);
  }

  void _startSelection(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _selected.add(index);
      _replyMessageId = null; // disable reply when selecting
    });
  }

  void _toggleSelection(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(index)) _selected.remove(index);
      else _selected.add(index);
      if (_selected.isNotEmpty) _replyMessageId = null; // reply hidden when selection active
    });
  }

  void _clearSelection() => setState(() => _selected.clear());

  void _setReply(String messageId) {
    setState(() {
      _replyMessageId = messageId;
      _selected.clear(); // reply mode cancels selection
    });
  }

  void _cancelReply() => setState(() => _replyMessageId = null);

  void _sendMessage() {
    // placeholder: integrate send logic here
    // when sending, you would include replyTo metadata if _replyMessageId != null
    _controller.clear();
    _cancelReply();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      appBar: selectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _MessageList(
              selected: _selected,
              onLongPressSelect: _startSelection,
              onTapSelect: (i) {
                if (selectionMode) _toggleSelection(i);
              },
              onSwipeReply: (message) {
                // Swipe -> set reply (only if not in selection mode)
                if (!selectionMode) _setReply(message.id);
              },
            ),
          ),
          if (_replyMessage != null && !selectionMode)
            ReplyPreview(
              message: _replyMessage!,
              onCancel: _cancelReply,
            ),
          _buildInputBar(),
        ],
      ),
    );
  }

  AppBar _buildNormalAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Color(0xFF111827),
            ),
          ),
          Text(
            widget.isGroup ? 'Group chat' : 'Online',
            style: TextStyle(
              fontSize: 12,
              color: widget.isGroup ? Colors.grey : Colors.green,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.call_outlined, color: Color(0xFF374151)),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CallView()));
          },
        ),
        PopupMenuButton<_ChatMenuAction>(
          icon: const Icon(Icons.more_vert, color: Color(0xFF374151)),
          onSelected: (action) {
            if (action == _ChatMenuAction.info) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => widget.isGroup ? const GroupDetailView() : const ContactDetailView()),
              );
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: _ChatMenuAction.info, child: Text(widget.isGroup ? 'Group info' : 'Contact info')),
          ],
        ),
      ],
    );
  }

  AppBar _buildSelectionAppBar() {
    final single = _selected.length == 1;
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      leading: IconButton(icon: const Icon(Icons.close, color: Color(0xFF111827)), onPressed: _clearSelection),
      title: Text(single ? '1 selected' : '${_selected.length} selected', style: const TextStyle(color: Color(0xFF111827))),
      actions: [
        if (single) // Reply only available when exactly one selected
          IconButton(
            icon: const Icon(Icons.reply, color: Color(0xFF4F46E5)),
            onPressed: () {
              final idx = _selected.first;
              final m = dummyMessages[idx];
              _setReply(m.id);
            },
          ),
        IconButton(
          icon: const Icon(Icons.copy, color: Color(0xFF4F46E5)),
          onPressed: () async {
            // Copy selected messages text joined
            final texts = _selected.map((i) => dummyMessages[i].text).join('\n');
            await Clipboard.setData(ClipboardData(text: texts));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
            _clearSelection();
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _confirmDeleteSelected(context),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteSelected(BuildContext context) async {
    final count = _selected.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(count == 1 ? 'Delete message?' : 'Delete ${count} messages?'),
        content: Text(count == 1 ? 'Choose delete option' : 'This will delete the selected messages from your device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              // TODO: perform delete locally / remotely as needed
              Navigator.pop(context, true);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) setState(() => _selected.clear());
  }

  Widget _buildInputBar() {
    final disabled = selectionMode;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add, color: Colors.grey),
              onPressed: disabled ? null : () {},
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: const Color(0xFFF1F3F6), borderRadius: BorderRadius.circular(20)),
                child: TextField(
                  controller: _controller,
                  enabled: !disabled,
                  decoration: const InputDecoration(border: InputBorder.none, hintText: 'Type a message'),
                  // Optionally: handle send on submit
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: disabled ? Colors.grey.shade400 : const Color(0xFF4F46E5),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: disabled ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Message list widget: handles taps/longpress/swipe -> delegates to callbacks
class _MessageList extends StatelessWidget {
  final Set<int> selected;
  final void Function(int) onLongPressSelect;
  final void Function(int) onTapSelect;
  final void Function(_DummyMessage) onSwipeReply;

  const _MessageList({
    required this.selected,
    required this.onLongPressSelect,
    required this.onTapSelect,
    required this.onSwipeReply,
  });

  @override
  Widget build(BuildContext context) {
    // reverse list so newest at bottom but ListView is reversed (common pattern)
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: dummyMessages.length,
      itemBuilder: (context, indexFromFront) {
        // Because reverse: indexFromFront 0 is last element; we want logical index
        final idx = indexFromFront;
        final message = dummyMessages[idx];
        final isSelected = selected.contains(idx);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _MessageTile(
            message: message,
            selected: isSelected,
            selectionMode: selected.isNotEmpty,
            onTap: () => onTapSelect(idx),
            onLongPress: () => onLongPressSelect(idx),
            onSwipeReply: () => onSwipeReply(message),
          ),
        );
      },
    );
  }
}

/// Single message tile: Dismissible (swipe right) to reply, selection visuals, animations
class _MessageTile extends StatelessWidget {
  final _DummyMessage message;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onSwipeReply;

  const _MessageTile({
    required this.message,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onSwipeReply,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    final bgColor = isMe ? const Color(0xFF4F46E5) : Colors.white;
    final textColor = isMe ? Colors.white : const Color(0xFF111827);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Dismissible(
        key: ValueKey(message.id),
        direction: selectionMode ? DismissDirection.none : DismissDirection.startToEnd,
        confirmDismiss: (dir) async {
          // Intercept dismiss: trigger reply and prevent actual dismissal
          onSwipeReply();
          return false;
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          child: const Icon(Icons.reply, color: Colors.grey),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: selected ? Colors.indigo.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                    bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(message.text, style: TextStyle(color: textColor)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(message.time, style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 10)),
                        if (selected) const SizedBox(width: 8),
                        if (selected)
                          const Icon(Icons.check_circle, size: 16, color: Color(0xFF4F46E5)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reply preview (above input)
class ReplyPreview extends StatelessWidget {
  final _DummyMessage message;
  final VoidCallback onCancel;

  const ReplyPreview({required this.message, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final label = message.isMe ? 'You' : 'Contact';
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(width: 4, height: 40, color: const Color(0xFF4F46E5)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 6),
                Text(message.text, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.close), onPressed: onCancel),
        ],
      ),
    );
  }
}

/// Chat menu actions
enum _ChatMenuAction { info }

/// Simple message model for UI demo
class _DummyMessage {
  final String id;
  final bool isMe;
  final String text;
  final String time;

  const _DummyMessage({
    required this.id,
    required this.isMe,
    required this.text,
    required this.time,
  });
}

/// Dummy data
final dummyMessages = [
  const _DummyMessage(id: 'm1', isMe: true, text: 'Halo, sudah lihat file?', time: '21:10'),
  const _DummyMessage(id: 'm2', isMe: false, text: 'Sudah, nanti aku cek', time: '21:11'),
  const _DummyMessage(id: 'm3', isMe: true, text: 'Sip 👍', time: '21:12'),
];
