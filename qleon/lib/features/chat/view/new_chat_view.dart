import 'package:flutter/material.dart';
import 'chat_room_view.dart';
import 'add_contact_view.dart';
import '../../group/view/create_group_view.dart';


class NewChatView extends StatelessWidget {
  const NewChatView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          _buildActionSection(context),
          _buildSearchBar(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: dummyContacts.length,
              itemBuilder: (context, index) {
                final contact = dummyContacts[index];
                return _ContactCard(
                  contact: contact,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatRoomView(
                          title: contact.name,
                          avatarUrl: contact.avatarUrl,
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
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'New Chat',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF111827),
        ),
      ),
    );
  }

  /// =============================================================
  /// ACTION SECTION (NEW GROUP / ADD CONTACT)
  /// =============================================================
  Widget _buildActionSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        children: [
          _ActionTile(
            icon: Icons.group_add,
            title: 'New Group',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateGroupView(),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.person_add,
            title: 'Add New Contact',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddContactView(),
                ),
              );
            },
          ),
        ],
      ),
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
              'Search contacts',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

/// =============================================================
/// ACTION TILE
/// =============================================================
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFEEF2FF),
              child: Icon(icon, color: const Color(0xFF4F46E5)),
            ),
            const SizedBox(width: 14),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =============================================================
/// CONTACT CARD
/// =============================================================
class _ContactCard extends StatelessWidget {
  final _DummyContact contact;
  final VoidCallback onTap;

  const _ContactCard({
    required this.contact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
              backgroundImage: NetworkImage(contact.avatarUrl),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    contact.status,
                    style: const TextStyle(color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
class _DummyContact {
  final String avatarUrl;
  final String name;
  final String status;

  _DummyContact({
    required this.avatarUrl,
    required this.name,
    required this.status,
  });
}

final dummyContacts = [
  _DummyContact(
    avatarUrl: 'https://i.pravatar.cc/150?img=41',
    name: 'Andi Wijaya',
    status: 'Online',
  ),
  _DummyContact(
    avatarUrl: 'https://i.pravatar.cc/150?img=12',
    name: 'Budi Santoso',
    status: 'Last seen 5 min ago',
  ),
  _DummyContact(
    avatarUrl: 'https://i.pravatar.cc/150?img=27',
    name: 'Citra Lestari',
    status: 'Busy',
  ),
  _DummyContact(
    avatarUrl: 'https://i.pravatar.cc/150?img=6',
    name: 'Dosen PA',
    status: 'Available',
  ),
];
