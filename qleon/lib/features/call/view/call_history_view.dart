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
          onPressed: () {},
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
/// CALL CARD (NO AVATAR)
// =============================================================
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
            _CallIdentityIndicator(call: call),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    call.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isMissed
                          ? Colors.redAccent
                          : const Color(0xFF111827),
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
                        color: const Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        call.subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 6),
                Icon(
                  _statusIcon(call.status),
                  size: 16,
                  color: _statusColor(call.status),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _statusIcon(CallStatus status) {
    switch (status) {
      case CallStatus.incoming:
        return Icons.call_received;
      case CallStatus.outgoing:
        return Icons.call_made;
      case CallStatus.missed:
        return Icons.call_missed;
    }
  }

  Color _statusColor(CallStatus status) {
    switch (status) {
      case CallStatus.missed:
        return Colors.redAccent;
      default:
        return Colors.green;
    }
  }
}

/// =============================================================
/// IDENTITY INDICATOR
/// =============================================================
class _CallIdentityIndicator extends StatelessWidget {
  final _DummyCall call;
  const _CallIdentityIndicator({required this.call});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: call.isGroup
            ? const Color(0xFFE5E7EB)
            : const Color(0xFFEEF2FF),
      ),
      child: Icon(
        call.isGroup ? Icons.groups_outlined : Icons.person_outline,
        color: call.isGroup
            ? Colors.grey
            : const Color(0xFF4F46E5),
      ),
    );
  }
}

/// =============================================================
/// MODELS (UI ONLY)
// =============================================================
enum CallType { voice, video }
enum CallStatus { incoming, outgoing, missed }

class _DummyCall {
  final String publicId;      // hasil QR / public identity
  final String displayName;   // alias lokal
  final String subtitle;
  final String time;
  final CallType type;
  final CallStatus status;
  final bool isGroup;

  const _DummyCall({
    required this.publicId,
    required this.displayName,
    required this.subtitle,
    required this.time,
    required this.type,
    required this.status,
    required this.isGroup,
  });
}

/// =============================================================
/// DUMMY DATA
/// =============================================================
const dummyCalls = [
  _DummyCall(
    publicId: '0xA91F23D9',
    displayName: 'Andi Wijaya',
    subtitle: 'Outgoing • 3 min',
    time: '21:30',
    type: CallType.voice,
    status: CallStatus.outgoing,
    isGroup: false,
  ),
  _DummyCall(
    publicId: '0x77BC119A',
    displayName: 'Tim Qleon',
    subtitle: 'Missed call',
    time: '19:12',
    type: CallType.video,
    status: CallStatus.missed,
    isGroup: true,
  ),
  _DummyCall(
    publicId: '0x0021AA90',
    displayName: 'Dosen PA',
    subtitle: 'Incoming • 5 min',
    time: 'Yesterday',
    type: CallType.voice,
    status: CallStatus.incoming,
    isGroup: false,
  ),
];
