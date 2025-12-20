import 'package:flutter/material.dart';

import 'security_view.dart';
import 'profile_view.dart';
import 'privacy_view.dart';
import 'blocked_user_view.dart';
import 'about_app_view.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: _buildAppBar(context),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _Section(
            title: 'Account',
            children: [
              _SettingsTile(
                icon: Icons.badge_outlined,
                title: 'Public identity',
                subtitle: 'Your QR & public ID',
                onTap: () => _go(context, const PublicIdentityView()),
              ),
              _SettingsTile(
                icon: Icons.security_outlined,
                title: 'Security',
                subtitle: 'Encryption & account safety',
                onTap: () => _go(context, const SecurityView()),
              ),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy',
                subtitle: 'Visibility & permissions',
                onTap: () => _go(context, const PrivacyView()),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _Section(
            title: 'Preferences',
            children: [
              _SettingsTile(
                icon: Icons.block_outlined,
                title: 'Blocked users',
                subtitle: 'Manage blocked contacts',
                onTap: () => _go(context, const BlockedUserView()),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _Section(
            title: 'About',
            children: [
              _SettingsTile(
                icon: Icons.info_outline,
                title: 'About Qleon',
                subtitle: 'Version, license, acknowledgements',
                onTap: () => _go(context, const AboutAppView()),
              ),
            ],
          ),

          const SizedBox(height: 24),

          _LogoutTile(
            onTap: () => _confirmLogout(context),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Settings',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF111827),
        ),
      ),
    );
  }

  void _go(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need to sign in again to access your messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: clear session / token / secure storage
              // TODO: navigate to auth screen
            },
            child: const Text(
              'Log out',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

/// =============================================================
/// SECTION CONTAINER
/// =============================================================
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

/// =============================================================
/// SETTINGS TILE
/// =============================================================
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: const Color(0xFF4F46E5),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0xFF111827),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF6B7280),
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Color(0xFF9CA3AF),
      ),
    );
  }
}

/// =============================================================
/// LOGOUT TILE
/// =============================================================
class _LogoutTile extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: onTap,
        leading: const Icon(
          Icons.logout,
          color: Colors.red,
        ),
        title: const Text(
          'Log out',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.red,
          ),
        ),
      ),
    );
  }
}
