import 'package:flutter/material.dart';

class GroupDetailView extends StatelessWidget {
  const GroupDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    const groupName = 'Flutter Devs';
    const groupPublicId = '0xA94F32C1';

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

          /// GROUP IDENTITY
          _GroupIdentitySection(
            groupName: groupName,
            groupPublicId: groupPublicId,
          ),

          const SizedBox(height: 24),

          /// ADD MEMBERS
          _AddMembersSection(),

          const SizedBox(height: 24),

          /// MEMBER LIST
          _MemberSection(),

          const SizedBox(height: 24),

          /// EXIT GROUP
          _ExitGroupSection(context),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// =======================
/// GROUP IDENTITY
/// =======================
class _GroupIdentitySection extends StatelessWidget {
  final String groupName;
  final String groupPublicId;

  const _GroupIdentitySection({
    required this.groupName,
    required this.groupPublicId,
  });

  @override
  Widget build(BuildContext context) {
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
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            groupName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Public ID: $groupPublicId',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _showRenameDialog(context, groupName),
            child: const Text(
              'Edit group name',
              style: TextStyle(color: Color(0xFF4F46E5)),
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================
/// ADD MEMBERS
/// =======================
class _AddMembersSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFEEF2FF),
          child: Icon(Icons.person_add, color: Color(0xFF4F46E5)),
        ),
        title: const Text(
          'Add members',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        subtitle: const Text(
          'Invite contacts to this group',
          style: TextStyle(fontSize: 12),
        ),
        onTap: () {
          // TODO: Navigate to Add Members flow (reuse NewChat / contact picker)
        },
      ),
    );
  }
}

/// =======================
/// MEMBER SECTION
/// =======================
class _MemberSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const isCurrentUserAdmin = true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '${dummyMembers.length} participants',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...dummyMembers.map(
          (member) => _MemberTile(
            member: member,
            isAdmin: isCurrentUserAdmin,
          ),
        ),
      ],
    );
  }
}

/// =======================
/// MEMBER TILE
/// =======================
class _MemberTile extends StatelessWidget {
  final GroupMember member;
  final bool isAdmin;

  const _MemberTile({
    required this.member,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: NetworkImage(member.avatarUrl),
        ),
        title: Text(
          member.name,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111827),
          ),
        ),
        subtitle: member.isAdmin
            ? const Text(
                'Admin',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF4F46E5),
                  fontWeight: FontWeight.w500,
                ),
              )
            : null,
        trailing: isAdmin && !member.isSelf
            ? PopupMenuButton<String>(
                onSelected: (value) =>
                    _handleMemberAction(context, value, member),
                itemBuilder: (_) => [
                  if (!member.isAdmin)
                    const PopupMenuItem(
                      value: 'make_admin',
                      child: Text('Make admin'),
                    ),
                  if (member.isAdmin)
                    const PopupMenuItem(
                      value: 'remove_admin',
                      child: Text('Remove admin'),
                    ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Text(
                      'Remove from group',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

/// =======================
/// EXIT GROUP
/// =======================
class _ExitGroupSection extends StatelessWidget {
  final BuildContext context;

  const _ExitGroupSection(this.context);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: const Icon(Icons.logout, color: Colors.red),
        title: const Text(
          'Exit group',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: () => _confirmDialog(
          this.context,
          title: 'Exit group?',
          message: 'You will no longer receive messages from this group.',
        ),
      ),
    );
  }
}

/// =======================
/// DIALOGS
/// =======================
void _showRenameDialog(BuildContext context, String currentName) {
  final controller = TextEditingController(text: currentName);

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Edit group name'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          hintText: 'Enter new name',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text(
            'Save',
            style: TextStyle(
              color: Color(0xFF4F46E5),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

void _handleMemberAction(
  BuildContext context,
  String action,
  GroupMember member,
) {
  String title = '';
  String message = '';

  switch (action) {
    case 'make_admin':
      title = 'Make admin?';
      message = '${member.name} will gain admin privileges.';
      break;
    case 'remove_admin':
      title = 'Remove admin?';
      message = '${member.name} will no longer be an admin.';
      break;
    case 'remove':
      title = 'Remove member?';
      message = '${member.name} will be removed from this group.';
      break;
  }

  _confirmDialog(context, title: title, message: message);
}

void _confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text(
            'Confirm',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );
}

/// =======================
/// DUMMY DATA
/// =======================
class GroupMember {
  final String id;
  final String name;
  final String avatarUrl;
  final bool isAdmin;
  final bool isSelf;

  const GroupMember({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.isAdmin = false,
    this.isSelf = false,
  });
}

const dummyMembers = [
  GroupMember(
    id: 'u1',
    name: 'You',
    avatarUrl: 'https://i.pravatar.cc/150?img=1',
    isAdmin: true,
    isSelf: true,
  ),
  GroupMember(
    id: 'u2',
    name: 'Andi Wijaya',
    avatarUrl: 'https://i.pravatar.cc/150?img=41',
  ),
  GroupMember(
    id: 'u3',
    name: 'Budi Santoso',
    avatarUrl: 'https://i.pravatar.cc/150?img=12',
  ),
  GroupMember(
    id: 'u4',
    name: 'Citra Lestari',
    avatarUrl: 'https://i.pravatar.cc/150?img=27',
  ),
];
