import 'package:flutter/material.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: _buildAppBar(context),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileCard(),
          const SizedBox(height: 20),

          _buildSection(
            title: 'Account',
            items: [
              _SettingItem(
                icon: Icons.person_outline,
                title: 'Profile',
                onTap: () {},
              ),
              _SettingItem(
                icon: Icons.lock_outline,
                title: 'Privacy',
                onTap: () {},
              ),
              _SettingItem(
                icon: Icons.qr_code,
                title: 'My QR Code',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 20),

          _buildSection(
            title: 'Preferences',
            items: [
              _SettingItem(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                onTap: () {},
              ),
              _SettingItem(
                icon: Icons.dark_mode_outlined,
                title: 'Appearance',
                onTap: () {},
              ),
              _SettingItem(
                icon: Icons.language_outlined,
                title: 'Language',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 20),

          _buildSection(
            title: 'Support',
            items: [
              _SettingItem(
                icon: Icons.help_outline,
                title: 'Help Center',
                onTap: () {},
              ),
              _SettingItem(
                icon: Icons.info_outline,
                title: 'About Qleon',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 24),

          _buildLogoutButton(context),
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
        'Settings',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF111827),
        ),
      ),
    );
  }

  /// =============================================================
  /// PROFILE CARD
  /// =============================================================
  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
          const CircleAvatar(
            radius: 28,
            backgroundImage: NetworkImage(
              'https://i.pravatar.cc/150?img=11',
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Andi Wijaya',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tap to view profile',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }

  /// =============================================================
  /// SECTION
  /// =============================================================
  Widget _buildSection({
    required String title,
    required List<_SettingItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: items
                .map(
                  (item) => _SettingTile(item: item),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  /// =============================================================
  /// LOGOUT
  /// =============================================================
  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        leading: const Icon(Icons.logout, color: Colors.red),
        title: const Text(
          'Logout',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.red,
          ),
        ),
        onTap: () {
          // TODO: handle logout
        },
      ),
    );
  }
}

/// =============================================================
/// SETTING ITEM MODEL
/// =============================================================
class _SettingItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SettingItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}

/// =============================================================
/// SETTING TILE
/// =============================================================
class _SettingTile extends StatelessWidget {
  final _SettingItem item;

  const _SettingTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(item.icon, color: const Color(0xFF4F46E5)),
      title: Text(
        item.title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: item.onTap,
    );
  }
}
