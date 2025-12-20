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
                          title: contact.displayName,
                          isGroup: false,
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

  /// =============================================================
  /// APP BAR
  /// =============================================================
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
  /// ACTION SECTION
  /// =============================================================
  Widget _buildActionSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        children: [
          _ActionTile(
            icon: Icons.group_add,
            title: 'New Group',
            subtitle: 'Create a secure group',
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
            icon: Icons.qr_code_scanner,
            title: 'Add New Contact',
            subtitle: 'Scan public identity',
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
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
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
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEEF2FF),
              ),
              child: Icon(icon, color: const Color(0xFF4F46E5)),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
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
/// CONTACT CARD (NO AVATAR)
// =============================================================
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
            _IdentityIndicator(contact: contact),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Color(0xFF111827),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    contact.publicStatus,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
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
/// IDENTITY INDICATOR
/// =============================================================
class _IdentityIndicator extends StatelessWidget {
  final _DummyContact contact;
  const _IdentityIndicator({required this.contact});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: contact.isOnline
            ? const Color(0xFFEEF2FF)
            : const Color(0xFFE5E7EB),
      ),
      child: Icon(
        Icons.person_outline,
        color: contact.isOnline
            ? const Color(0xFF4F46E5)
            : Colors.grey,
      ),
    );
  }
}

/// =============================================================
/// DUMMY MODEL
/// =============================================================
class _DummyContact {
  final String publicId;        // hasil QR / public identity
  final String displayName;     // local alias
  final String publicStatus;
  final bool isOnline;

  const _DummyContact({
    required this.publicId,
    required this.displayName,
    required this.publicStatus,
    required this.isOnline,
  });
}

/// =============================================================
/// DUMMY DATA
/// =============================================================
const dummyContacts = [
  _DummyContact(
    publicId: '0xA91F23D9',
    displayName: 'Andi Wijaya',
    publicStatus: 'Online',
    isOnline: true,
  ),
  _DummyContact(
    publicId: '0x77BC119A',
    displayName: 'Budi Santoso',
    publicStatus: 'Last seen 5 min ago',
    isOnline: false,
  ),
  _DummyContact(
    publicId: '0xFE19C442',
    displayName: 'Citra Lestari',
    publicStatus: 'Busy',
    isOnline: false,
  ),
  _DummyContact(
    publicId: '0x0021AA90',
    displayName: 'Dosen PA',
    publicStatus: 'Available',
    isOnline: true,
  ),
];
