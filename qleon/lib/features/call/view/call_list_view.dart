import 'package:flutter/material.dart';
import 'call_view.dart';

class CallListView extends StatelessWidget {
  const CallListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: dummyCallContacts.length,
              itemBuilder: (context, index) {
                final contact = dummyCallContacts[index];
                return _CallContactCard(contact: contact);
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
        'Select contact',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF111827),
        ),
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
            Icon(Icons.search, color: Color(0xFF9CA3AF)),
            SizedBox(width: 8),
            Text(
              'Search contacts or groups',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 13,
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
class _CallContactCard extends StatelessWidget {
  final _CallContact contact;

  const _CallContactCard({required this.contact});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          /// ICON (NO PROFILE PHOTO)
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              contact.isGroup ? Icons.group : Icons.person,
              color: const Color(0xFF4F46E5),
            ),
          ),
          const SizedBox(width: 12),

          /// NAME & STATUS
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  contact.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),

          /// ACTIONS
          IconButton(
            icon: const Icon(Icons.call, color: Color(0xFF4F46E5)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CallView(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// =============================================================
/// DUMMY DATA (UI ONLY)
/// =============================================================
class _CallContact {
  final String name;
  final String subtitle;
  final bool isGroup;

  const _CallContact({
    required this.name,
    required this.subtitle,
    required this.isGroup,
  });
}

const dummyCallContacts = [
  _CallContact(
    name: 'Andi Wijaya',
    subtitle: 'Online',
    isGroup: false,
  ),
  _CallContact(
    name: 'Budi Santoso',
    subtitle: 'Last seen 10 min ago',
    isGroup: false,
  ),
  _CallContact(
    name: 'Tim Qleon',
    subtitle: 'Group • 4 members',
    isGroup: true,
  ),
  _CallContact(
    name: 'Dosen PA',
    subtitle: 'Available',
    isGroup: false,
  ),
];
