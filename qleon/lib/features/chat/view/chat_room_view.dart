import 'package:flutter/material.dart';

// IMPORT TARGET VIEWS
import '../../call/view/call_view.dart';
import '../../group/view/group_detail_view.dart';
import 'contact_detail_view.dart';

class ChatRoomView extends StatelessWidget {
  final String title;
  final String avatarUrl;
  final bool isGroup;

  const ChatRoomView({
    super.key,
    required this.title,
    required this.avatarUrl,
    this.isGroup = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      appBar: _buildAppBar(context),
      body: Column(
        children: const [
          Expanded(child: _MessageList()),
          _InputBar(),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leadingWidth: 40,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: NetworkImage(avatarUrl),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Color(0xFF111827),
                ),
              ),
              Text(
                isGroup ? 'Group chat' : 'Online',
                style: TextStyle(
                  fontSize: 12,
                  color: isGroup ? Colors.grey : Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.call_outlined, color: Color(0xFF374151)),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CallView()),
            );
          },
        ),
        PopupMenuButton<_ChatMenuAction>(
          icon: const Icon(Icons.more_vert, color: Color(0xFF374151)),
          onSelected: (action) {
            switch (action) {
              case _ChatMenuAction.groupInfo:
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GroupDetailView()),
                );
                break;
              case _ChatMenuAction.contactInfo:
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContactDetailView()),
                );
                break;
              case _ChatMenuAction.clear:
                _showClearChatDialog(context);
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _ChatMenuAction.groupInfo,
              child: Text('Group Info'),
            ),
            PopupMenuItem(
              value: _ChatMenuAction.contactInfo,
              child: Text('Contact Info'),
            ),
            PopupMenuItem(
              value: _ChatMenuAction.clear,
              child: Text(
                'Clear Chat',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// =============================================================
/// MENU ENUM + DIALOG
/// =============================================================
enum _ChatMenuAction { groupInfo, contactInfo, clear }

void _showClearChatDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Clear chat?'),
      content: const Text('All messages in this chat will be deleted.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            // TODO: clear chat logic
          },
          child: const Text(
            'Clear',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );
}

/// =============================================================
/// MESSAGE LIST
/// =============================================================
class _MessageList extends StatelessWidget {
  const _MessageList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: dummyMessages.length,
      itemBuilder: (context, index) {
        return _MessageBubble(message: dummyMessages[index]);
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _DummyMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                )
              : null,
          color: isMe ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft:
                isMe ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight:
                isMe ? const Radius.circular(4) : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.text != null)
              Text(
                message.text!,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              message.time,
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.white70 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =============================================================
/// INPUT BAR
/// =============================================================
class _InputBar extends StatelessWidget {
  const _InputBar();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add, color: Colors.grey),
              onPressed: () {},
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: 'Type a message',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: const Color(0xFF4F46E5),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =============================================================
/// DUMMY DATA
/// =============================================================
class _DummyMessage {
  final bool isMe;
  final String? text;
  final String time;

  _DummyMessage({
    required this.isMe,
    this.text,
    required this.time,
  });
}

final dummyMessages = [
  _DummyMessage(isMe: true, text: 'Halo, sudah lihat file?', time: '21:10'),
  _DummyMessage(isMe: false, text: 'Sudah, nanti aku cek', time: '21:11'),
  _DummyMessage(isMe: true, text: 'Sip 👍', time: '21:12'),
];
