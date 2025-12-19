import 'package:flutter/material.dart';

class GroupDetailView extends StatelessWidget {
  const GroupDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Group Info',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildMemberList()),
        ],
      ),
    );
  }

  /// =============================================================
  /// HEADER (FOTO + NAMA + JUMLAH ANGGOTA)
  /// =============================================================
  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: const NetworkImage(
              'https://i.pravatar.cc/150?img=31', // dummy foto grup
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Flutter Devs',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${dummyMembers.length} members',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// =============================================================
  /// MEMBER LIST
  /// =============================================================
  Widget _buildMemberList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dummyMembers.length,
      itemBuilder: (context, index) {
        final member = dummyMembers[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: NetworkImage(member.avatarUrl),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  member.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              if (member.isAdmin)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Admin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// =============================================================
/// DUMMY MEMBER MODEL
/// =============================================================
class _DummyMember {
  final String id;
  final String name;
  final String avatarUrl;
  final bool isAdmin;

  const _DummyMember({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.isAdmin = false,
  });
}

/// =============================================================
/// DUMMY DATA
/// =============================================================
const dummyMembers = [
  _DummyMember(
    id: 'm1',
    name: 'Andi Wijaya',
    avatarUrl: 'https://i.pravatar.cc/150?img=41',
    isAdmin: true,
  ),
  _DummyMember(
    id: 'm2',
    name: 'Budi Santoso',
    avatarUrl: 'https://i.pravatar.cc/150?img=12',
  ),
  _DummyMember(
    id: 'm3',
    name: 'Citra Lestari',
    avatarUrl: 'https://i.pravatar.cc/150?img=27',
  ),
  _DummyMember(
    id: 'm4',
    name: 'Dosen PA',
    avatarUrl: 'https://i.pravatar.cc/150?img=6',
  ),
];
