import 'package:flutter/material.dart';
import 'call_view.dart';
import 'call_list_view.dart';

class CallHistoryView extends StatelessWidget {
  const CallHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: _buildAppBar(context),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: dummyCalls.length,
        itemBuilder: (context, index) {
          final call = dummyCalls[index];
          return _CallCard(
            call: call,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CallView()),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4F46E5),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CallListView()),
          );
        },
        child: const Icon(Icons.add_call),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Calls',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF111827),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Color(0xFF374151)),
          onPressed: () {
            // TODO: search call history
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Color(0xFF374151)),
          onSelected: (value) {
            if (value == 'clear') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Call history cleared'),
                ),
              );
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'clear',
              child: Text('Clear call history'),
            ),
          ],
        ),
      ],
    );
  }
}

/// =============================================================
/// CALL CARD
/// =============================================================
class _CallCard extends StatelessWidget {
  final _DummyCall call;
  final VoidCallback onTap;

  const _CallCard({
    required this.call,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMissed = call.status == CallStatus.missed;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
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
            CircleAvatar(
              radius: 26,
              backgroundImage: NetworkImage(call.avatarUrl),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    call.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isMissed ? Colors.redAccent : Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        call.type == CallType.video
                            ? Icons.videocam_outlined
                            : Icons.call_outlined,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        call.subtitle,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  call.time,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Icon(
                  call.status == CallStatus.missed
                      ? Icons.call_missed
                      : Icons.call_made,
                  size: 16,
                  color: call.status == CallStatus.missed
                      ? Colors.redAccent
                      : Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// =============================================================
/// DUMMY DATA (UI ONLY)
/// =============================================================

enum CallType { voice, video }
enum CallStatus { incoming, outgoing, missed }

class _DummyCall {
  final String avatarUrl;
  final String name;
  final String subtitle;
  final String time;
  final CallType type;
  final CallStatus status;

  _DummyCall({
    required this.avatarUrl,
    required this.name,
    required this.subtitle,
    required this.time,
    required this.type,
    required this.status,
  });
}

final dummyCalls = [
  _DummyCall(
    avatarUrl: 'https://i.pravatar.cc/150?img=21',
    name: 'Andi Wijaya',
    subtitle: 'Outgoing • 3 min',
    time: '21:30',
    type: CallType.voice,
    status: CallStatus.outgoing,
  ),
  _DummyCall(
    avatarUrl: 'https://i.pravatar.cc/150?img=35',
    name: 'Tim Qleon',
    subtitle: 'Missed call',
    time: '19:12',
    type: CallType.video,
    status: CallStatus.missed,
  ),
  _DummyCall(
    avatarUrl: 'https://i.pravatar.cc/150?img=8',
    name: 'Dosen PA',
    subtitle: 'Incoming • 5 min',
    time: 'Yesterday',
    type: CallType.voice,
    status: CallStatus.incoming,
  ),
];
