import 'package:flutter/material.dart';

class BlockedUserView extends StatelessWidget {
  const BlockedUserView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: _appBar(),
      body: dummyBlocked.isEmpty
          ? _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: dummyBlocked.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final user = dummyBlocked[i];
                return _BlockedUserTile(userId: user);
              },
            ),
    );
  }

  AppBar _appBar() => AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Blocked users',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
      );
}

/// =============================================================
/// BLOCKED USER TILE
/// =============================================================
class _BlockedUserTile extends StatelessWidget {
  final String userId;

  const _BlockedUserTile({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          const Icon(
            Icons.block,
            color: Color(0xFFEF4444),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Public identity',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  userId,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _confirmUnblock(context),
            child: const Text(
              'Unblock',
              style: TextStyle(
                color: Color(0xFF4F46E5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmUnblock(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Unblock user?'),
        content: const Text(
          'This user will be able to contact you again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: handle unblock logic
            },
            child: const Text(
              'Unblock',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
  }
}

/// =============================================================
/// EMPTY STATE
/// =============================================================
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.shield_outlined,
            size: 48,
            color: Color(0xFF9CA3AF),
          ),
          SizedBox(height: 12),
          Text(
            'No blocked users',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'You haven’t blocked anyone',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

/// =============================================================
/// DUMMY DATA (UI ONLY)
/// =============================================================
final dummyBlocked = [
  '0xA21F93C8',
  '0x44E9B102',
];
