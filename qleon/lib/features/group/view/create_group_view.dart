import 'package:flutter/material.dart';

class CreateGroupView extends StatefulWidget {
  const CreateGroupView({super.key});

  @override
  State<CreateGroupView> createState() => _CreateGroupViewState();
}

class _CreateGroupViewState extends State<CreateGroupView> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final Set<_DummyContact> _selectedMembers = {};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filteredContacts = dummyContacts
        .where(
          (c) => c.name.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          _buildGroupNameInput(),

          if (_selectedMembers.isNotEmpty)
            _buildSelectedPreview(),

          _buildSearchBar(),
          Expanded(child: _buildContactList(filteredContacts)),
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
        'New Group',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF111827),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _canCreateGroup ? _createGroup : null,
          child: const Text(
            'Create',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  /// =============================================================
  /// GROUP NAME INPUT
  /// =============================================================
  Widget _buildGroupNameInput() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _groupNameController,
        decoration: InputDecoration(
          hintText: 'Group name',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  /// =============================================================
  /// SELECTED MEMBERS PREVIEW
  /// =============================================================
Widget _buildSelectedPreview() {
  return SizedBox(
    height: 86,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: _selectedMembers.map((contact) {
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Column(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundImage: NetworkImage(contact.avatarUrl),
                  ),
                  Positioned(
                    right: -2,
                    top: -2,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMembers.remove(contact);
                        });
                      },
                      child: const CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.red,
                        child: Icon(
                          Icons.close,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 52,
                child: Text(
                  contact.name,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ),
  );
}

  /// =============================================================
  /// SEARCH BAR
  /// =============================================================
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
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search contacts',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() => _query = value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// =============================================================
  /// CONTACT LIST
  /// =============================================================
  Widget _buildContactList(List<_DummyContact> contacts) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        final selected = _selectedMembers.contains(contact);

        return GestureDetector(
          onTap: () {
            setState(() {
              selected
                  ? _selectedMembers.remove(contact)
                  : _selectedMembers.add(contact);
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundImage: NetworkImage(contact.avatarUrl),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    contact.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF4F46E5),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// =============================================================
  /// CREATE GROUP
  /// =============================================================
  bool get _canCreateGroup =>
      _groupNameController.text.isNotEmpty && _selectedMembers.isNotEmpty;

  void _createGroup() {
    /// TODO:
    /// - generate groupId
    /// - save group (name + members)
    /// - navigate to GroupChatView

    Navigator.pop(context);
  }
}

/// =============================================================
/// DUMMY MODEL
/// =============================================================
class _DummyContact {
  final String id;
  final String name;
  final String avatarUrl;

  const _DummyContact({
    required this.id,
    required this.name,
    required this.avatarUrl,
  });
}

/// =============================================================
/// DUMMY DATA
/// =============================================================
const dummyContacts = [
  _DummyContact(
    id: 'u1',
    name: 'Andi Wijaya',
    avatarUrl: 'https://i.pravatar.cc/150?img=41',
  ),
  _DummyContact(
    id: 'u2',
    name: 'Budi Santoso',
    avatarUrl: 'https://i.pravatar.cc/150?img=12',
  ),
  _DummyContact(
    id: 'u3',
    name: 'Citra Lestari',
    avatarUrl: 'https://i.pravatar.cc/150?img=27',
  ),
  _DummyContact(
    id: 'u4',
    name: 'Dosen PA',
    avatarUrl: 'https://i.pravatar.cc/150?img=6',
  ),
];
