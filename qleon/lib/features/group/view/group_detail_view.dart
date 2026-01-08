import 'package:flutter/material.dart';

class GroupDetailView extends StatefulWidget {
  const GroupDetailView({super.key});

  @override
  State<GroupDetailView> createState() => _GroupDetailViewState();
}

class _GroupDetailViewState extends State<GroupDetailView> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Group info',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          const GroupIdentitySection(),
          const SizedBox(height: 24),
          _buildAddMembersSection(),
          const SizedBox(height: 24),
          const MemberSection(),
          const SizedBox(height: 24),
          const ExitGroupSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAddMembersSection() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<List<DummyContact>>(
          context,
          MaterialPageRoute(builder: (_) => const AddMembersPage()),
        );
        if (result != null) {
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListTile(
          leading: const Icon(Icons.person_add_alt_1, color: Color(0xFF4F46E5)),
          title: const Text(
            'Add members',
            style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111827)),
          ),
          subtitle: const Text('Invite via public identity or QR', style: TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}

/// =============================================================
/// GROUP IDENTITY
/// =============================================================
class GroupIdentitySection extends StatelessWidget {
  const GroupIdentitySection({super.key});

  @override
  Widget build(BuildContext context) {
    const groupName = 'Flutter Devs';
    const groupPublicId = '0xA94F32C1';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Group identity',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 12),
          Text(
            groupName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 6),
          Text(
            'Public ID · $groupPublicId',
            style: const TextStyle(fontSize: 13, letterSpacing: 0.6, color: Color(0xFF4F46E5)),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => showRenameSheet(context, groupName),
            child: const Text('Edit group name', style: TextStyle(color: Color(0xFF4F46E5))),
          ),
        ],
      ),
    );
  }
}

/// =============================================================
/// ADD MEMBERS PAGE
/// =============================================================
class AddMembersPage extends StatefulWidget {
  const AddMembersPage({super.key});

  @override
  State<AddMembersPage> createState() => _AddMembersPageState();
}

class _AddMembersPageState extends State<AddMembersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  final Set<DummyContact> _selectedMembers = {};

  @override
  Widget build(BuildContext context) {
    final filteredContacts = dummyContacts
        .where((c) => c.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Members'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 1,
        actions: [
          TextButton(
            onPressed: _selectedMembers.isEmpty
                ? null
                : () => Navigator.pop(context, _selectedMembers.toList()),
            child: const Text('Done', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedMembers.isNotEmpty) _buildSelectedPreview(),
          _buildSearchBar(),
          Expanded(child: _buildContactList(filteredContacts)),
        ],
      ),
    );
  }

  Widget _buildSelectedPreview() {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: _selectedMembers.map((contact) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedMembers.remove(contact)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Text(contact.name, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    const Icon(Icons.close, size: 16, color: Color(0xFF4F46E5)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(hintText: 'Search contacts', border: InputBorder.none),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactList(List<DummyContact> contacts) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        final selected = _selectedMembers.contains(contact);
        return GestureDetector(
          onTap: () => setState(() {
            selected ? _selectedMembers.remove(contact) : _selectedMembers.add(contact);
          }),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(contact.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                if (selected) const Icon(Icons.check_circle, color: Color(0xFF4F46E5)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// =============================================================
/// MEMBER SECTION
/// =============================================================
class MemberSection extends StatelessWidget {
  const MemberSection({super.key});

  @override
  Widget build(BuildContext context) {
    const isCurrentUserAdmin = true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('${dummyMembers.length} participants',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
        ),
        const SizedBox(height: 8),
        ...dummyMembers.map(
          (member) => MemberTile(member: member, canManage: isCurrentUserAdmin),
        ),
      ],
    );
  }
}

class MemberTile extends StatelessWidget {
  final GroupMember member;
  final bool canManage;

  const MemberTile({super.key, required this.member, required this.canManage});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: Icon(
          member.isSelf
              ? Icons.person
              : member.isAdmin
                  ? Icons.shield_outlined
                  : Icons.person_outline,
          color: member.isAdmin ? const Color(0xFF4F46E5) : Colors.grey,
        ),
        title: Text(member.displayName,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF111827))),
        subtitle: Text(
          member.isSelf ? 'You' : member.isAdmin ? 'Admin' : 'Member',
          style: TextStyle(fontSize: 12, color: member.isAdmin ? const Color(0xFF4F46E5) : const Color(0xFF6B7280)),
        ),
        trailing: canManage && !member.isSelf
            ? PopupMenuButton<String>(
                onSelected: (value) => handleMemberAction(context, value, member),
                itemBuilder: (_) => [
                  if (!member.isAdmin)
                    const PopupMenuItem(value: 'make_admin', child: Text('Make admin')),
                  if (member.isAdmin)
                    const PopupMenuItem(value: 'remove_admin', child: Text('Remove admin')),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Text('Remove from group', style: TextStyle(color: Colors.red)),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

/// =============================================================
/// EXIT GROUP
/// =============================================================
class ExitGroupSection extends StatelessWidget {
  const ExitGroupSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: const Icon(Icons.logout, color: Colors.red),
        title: const Text('Exit group', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
        onTap: () => showConfirmSheet(context,
            title: 'Exit group?', message: 'You will no longer receive messages from this group.'),
      ),
    );
  }
}

Future<void> showRenameSheet(BuildContext context, String currentName) async {
  final controller = TextEditingController(text: currentName);

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    backgroundColor: Colors.white,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 16,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Edit group name', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Enter new name',
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Color(0xFFF3F4F6),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF111827))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Save', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    },
  );

  // read value and cleanup
  final newName = controller.text.trim();
  controller.dispose();
  if (result == true && newName.isNotEmpty) {
    // TODO: persist group rename
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Group renamed to "$newName" (placeholder)')));
  }
}

Future<void> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  bool destructive = true,
  String primaryLabel = 'Confirm',
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    backgroundColor: Colors.white,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(message, style: const TextStyle(fontSize: 14, color: Color(0xFF111827))),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF111827))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: destructive ? Colors.red : const Color(0xFF4F46E5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(primaryLabel, style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  if (ok == true) {
    // TODO: implement actual action (remove, make admin, exit, etc.)
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action confirmed (placeholder)')));
  }
}

/// =============================================================
/// MEMBER ACTIONS
/// =============================================================
void handleMemberAction(BuildContext context, String action, GroupMember member) {
  final title = switch (action) {
    'make_admin' => 'Make admin?',
    'remove_admin' => 'Remove admin?',
    _ => 'Remove member?',
  };

  final message = switch (action) {
    'make_admin' => '${member.displayName} will gain admin privileges.',
    'remove_admin' => '${member.displayName} will lose admin privileges.',
    _ => '${member.displayName} will be removed from this group.',
  };

  showConfirmSheet(context, title: title, message: message);
}

/// =============================================================
/// MODELS & DUMMY DATA
/// =============================================================
class GroupMember {
  final String publicId;
  final String displayName;
  final bool isAdmin;
  final bool isSelf;

  const GroupMember({required this.publicId, required this.displayName, this.isAdmin = false, this.isSelf = false});
}

class DummyContact {
  final String id;
  final String name;

  const DummyContact({required this.id, required this.name});
}

final dummyContacts = [
  const DummyContact(id: 'u1', name: 'Andi Wijaya'),
  const DummyContact(id: 'u2', name: 'Budi Santoso'),
  const DummyContact(id: 'u3', name: 'Citra Lestari'),
  const DummyContact(id: 'u4', name: 'Dosen PA'),
];

final dummyMembers = [
  const GroupMember(publicId: '0x001', displayName: 'You', isAdmin: true, isSelf: true),
  const GroupMember(publicId: '0xA19F', displayName: 'Andi Wijaya'),
  const GroupMember(publicId: '0xB88C', displayName: 'Budi Santoso'),
  const GroupMember(publicId: '0xC312', displayName: 'Citra Lestari'),
];
