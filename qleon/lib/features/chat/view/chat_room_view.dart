import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../call/view/call_view.dart';
import '../../group/view/group_detail_view.dart';
import 'contact_detail_view.dart';

/// Chat room view with:
/// - message multi-select (long press to start, tap to toggle)
/// - single-select actions: reply / copy / delete
/// - multi-select: copy / delete (reply hidden)
/// - small swipe-right to reply (gesture + small translation)
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
    for (var m in dummyMessages) {
      if (m.id == _replyMessageId) return m;
    }
    return null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final newMsg = _DummyMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      isMe: true,
      text: text,
      time: _formatTimeNow(),
    );

    setState(() {
      dummyMessages.add(newMsg); // newest appended to end
      _controller.clear();
      _cancelReply();
    });
    HapticFeedback.lightImpact();
  }

  String _formatTimeNow() {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  void _openAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              runSpacing: 8,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _AttachmentTile(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open gallery (placeholder)')));
                      },
                    ),
                    _AttachmentTile(
                      icon: Icons.insert_drive_file,
                      label: 'Document',
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open documents (placeholder)')));
                      },
                    ),
                    _AttachmentTile(
                      icon: Icons.location_on,
                      label: 'Location',
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick location (placeholder)')));
                      },
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

  Future<void> _showClearChatDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear chat?'),
        content: const Text('All messages in this conversation will be deleted locally.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              // TODO: clear chat logic (local / remote)
              Navigator.pop(context, true);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        dummyMessages.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat cleared (UI only)')));
    }
  }

  Future<void> _confirmCallAndNavigate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Call ${widget.title}?'),
        content: const Text('Start a voice call to this contact/group?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Call', style: TextStyle(color: Color(0xFF4F46E5))),
          ),
        ],
      ),
    );
    if (ok == true) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CallView()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reply = _replyMessage;
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
                // else could open message actions (not implemented here)
              },
              onSwipeReply: (message) {
                if (!selectionMode) _setReply(message.id);
              },
            ),
          ),
          if (reply != null && !selectionMode)
            ReplyPreview(message: reply, onCancel: _cancelReply),
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
      title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF111827))),
      actions: [
        IconButton(
          icon: const Icon(Icons.call_outlined, color: Color(0xFF374151)),
          onPressed: _confirmCallAndNavigate,
        ),
        PopupMenuButton<_ChatMenuAction>(
          icon: const Icon(Icons.more_vert, color: Color(0xFF374151)),
          onSelected: (action) {
            if (action == _ChatMenuAction.info) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => widget.isGroup ? const GroupDetailView() : const ContactDetailView()));
            } else if (action == _ChatMenuAction.clear) {
              _showClearChatDialog();
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: _ChatMenuAction.info, child: Text(widget.isGroup ? 'Group info' : 'Contact info')),
            const PopupMenuItem(value: _ChatMenuAction.clear, child: Text('Clear chat', style: TextStyle(color: Colors.red))),
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
        if (single)
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
        title: Text(count == 1 ? 'Delete message?' : 'Delete $count messages?'),
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
    final canSend = _controller.text.trim().isNotEmpty && !disabled;

    return SafeArea(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: disabled ? Colors.black12.withOpacity(0.06) : Colors.black12,
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ➕ Attachment
            IconButton(
              icon: Icon(Icons.add, color: disabled ? Colors.grey.shade400 : const Color(0xFF4F46E5)),
              onPressed: disabled ? null : _openAttachmentSheet,
            ),

            // ✍️ Text input (textarea-like)
            Expanded(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: disabled ? 0.5 : 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFF1F3F6), borderRadius: BorderRadius.circular(22)),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: Scrollbar(
                      child: TextField(
                        controller: _controller,
                        enabled: !disabled,
                        keyboardType: TextInputType.multiline,
                        minLines: 1,
                        maxLines: 6,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(hintText: 'Type a message', border: InputBorder.none, isDense: true),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) {
                          if (canSend) _sendMessage();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // 🚀 Send
            AnimatedScale(
              scale: canSend ? 1 : 0.92,
              duration: const Duration(milliseconds: 180),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: canSend ? const Color(0xFF4F46E5) : Colors.grey.shade400,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: canSend
                      ? () {
                          HapticFeedback.lightImpact();
                          _sendMessage();
                        }
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Attachment tile used in bottom sheet
class _AttachmentTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AttachmentTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 90,
        child: Column(
          children: [
            CircleAvatar(radius: 28, backgroundColor: const Color(0xFFEEF2FF), child: Icon(icon, color: const Color(0xFF4F46E5))),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 13), textAlign: TextAlign.center),
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
    // reverse true to have newest at bottom.
    // Map builder index to message index: idx = length-1 - indexFromFront
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: dummyMessages.length,
      itemBuilder: (context, indexFromFront) {
        final idx = dummyMessages.length - 1 - indexFromFront;
        final message = dummyMessages[idx];
        final isSelected = selected.contains(idx);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _MessageTile(
            key: ValueKey(message.id),
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

/// Single message tile (stateful to handle small drag/translation)
class _MessageTile extends StatefulWidget {
  final _DummyMessage message;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onSwipeReply;

  const _MessageTile({
    super.key,
    required this.message,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onSwipeReply,
  });

  @override
  State<_MessageTile> createState() => _MessageTileState();
}

class _MessageTileState extends State<_MessageTile> with SingleTickerProviderStateMixin {
  double _dragX = 0.0;
  late final AnimationController _animController;
  static const double triggerDistance = 40.0; // small swipe threshold

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    if (widget.selectionMode) return;
    setState(() {
      _dragX += d.delta.dx;
      if (_dragX < 0) _dragX = 0;
      if (_dragX > 100) _dragX = 100;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails e) {
    if (widget.selectionMode) {
      _resetDrag();
      return;
    }
    if (_dragX >= triggerDistance) {
      HapticFeedback.lightImpact();
      widget.onSwipeReply();
    }
    _resetDrag();
  }

  void _resetDrag() {
    _animController.reset();
    _animController.forward(from: 0);
    setState(() {
      _dragX = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.message.isMe;
    final bgColor = isMe ? const Color(0xFF4F46E5) : Colors.white;
    final textColor = isMe ? Colors.white : const Color(0xFF111827);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Transform.translate(
        offset: Offset(_dragX * 0.5, 0), // small visual move for feedback
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: widget.selected ? Colors.indigo.withOpacity(0.12) : Colors.transparent,
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
                    Text(widget.message.text, style: TextStyle(color: textColor)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.message.time, style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 10)),
                        if (widget.selected) const SizedBox(width: 8),
                        if (widget.selected) const Icon(Icons.check_circle, size: 16, color: Color(0xFF4F46E5)),
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
enum _ChatMenuAction { info, clear }

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

/// Dummy data (UI only). "final" list so we can add/remove items in demo.
final List<_DummyMessage> dummyMessages = [
  const _DummyMessage(id: 'm1', isMe: true, text: 'Halo, sudah lihat file?', time: '21:10'),
  const _DummyMessage(id: 'm2', isMe: false, text: 'Sudah, nanti aku cek', time: '21:11'),
  const _DummyMessage(id: 'm3', isMe: true, text: 'Sip 👍', time: '21:12'),
];
