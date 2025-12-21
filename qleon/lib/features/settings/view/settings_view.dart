import 'package:flutter/material.dart';

import 'security_view.dart';
import 'profile_view.dart';
import 'privacy_view.dart';
import 'blocked_user_view.dart';
import 'about_app_view.dart';

// ViewModel (pastikan file path sesuai)
import '../viewmodel/settings_viewmodel.dart';
import '../../../app/app_routes.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final SettingsViewModel vm;

  @override
  void initState() {
    super.initState();
    vm = SettingsViewModel();
    vm.addListener(_vmListener);
    vm.init(); // load initial data
  }

  void _vmListener() {
    // show errors as SnackBar (UI responsibility)
    if (vm.errorMessage != null && mounted) {
      final msg = vm.errorMessage!;
      // clear VM error after showing, so we don't show it repeatedly
      vm.clearError();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  void dispose() {
    vm.removeListener(_vmListener);
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: vm,
      builder: (context, _) {
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
                    onTap: vm.isLoading ? null : () => _go(context, const PublicIdentityView()),
                  ),
                  _SettingsTile(
                    icon: Icons.security_outlined,
                    title: 'Security',
                    subtitle: 'Encryption & account safety',
                    onTap: vm.isLoading ? null : () => _go(context, const SecurityView()),
                  ),
                  _SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy',
                    subtitle: 'Visibility & permissions',
                    onTap: vm.isLoading ? null : () => _go(context, const PrivacyView()),
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
                    onTap: vm.isLoading ? null : () => _go(context, const BlockedUserView()),
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
                    onTap: vm.isLoading ? null : () => _go(context, const AboutAppView()),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Logout tile uses vm.isLoggingOut to show loading/disable taps
              _LogoutTile(
                isLoading: vm.isLoggingOut,
                onTap: vm.isLoggingOut ? null : () => _confirmLogout(context),
              ),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
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

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // grab handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Log out?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text(
                  'You will need to sign in again to access your messages.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF111827)),
                ),
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
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Log out', style: TextStyle(color: Colors.white)),
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
      // call ViewModel logout, show local loading
      try {
        await vm.logout();
        // After successful logout, navigate to login (view handles nav)
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
      } catch (e) {
        final err = vm.errorMessage ?? e.toString();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logout failed: $err')));
        }
      }
    }
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
  final VoidCallback? onTap;

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
/// LOGOUT TILE (UI ONLY)
/// =============================================================
class _LogoutTile extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isLoading;

  const _LogoutTile({
    super.key,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isLoading ? null : onTap,
        child: ListTile(
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
          trailing: isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
