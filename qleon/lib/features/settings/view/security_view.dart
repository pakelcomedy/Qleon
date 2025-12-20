import 'package:flutter/material.dart';

class SecurityView extends StatelessWidget {
  const SecurityView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: _appBar(),
      body: Column(
        children: [
          _SecurityTile(
            icon: Icons.email_outlined,
            title: 'Change email',
            subtitle: 'Update your login email',
            onTap: () => _changeEmail(context),
          ),
          _SecurityTile(
            icon: Icons.lock_outline,
            title: 'Change password',
            subtitle: 'Update your account password',
            onTap: () => _changePassword(context),
          ),
          _SecurityTile(
            icon: Icons.help_outline,
            title: 'Forgot password',
            subtitle: 'Reset using your email',
            onTap: () => _forgotPassword(context),
          ),
        ],
      ),
    );
  }

  AppBar _appBar() => AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Security',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
      );

  /// =============================
  /// DIALOGS
  /// =============================

  void _changeEmail(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change email'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'New email address',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnack(context, 'Email updated');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _changePassword(BuildContext context) {
    final current = TextEditingController();
    final newPass = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: current,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Current password',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPass,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'New password',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnack(context, 'Password updated');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _forgotPassword(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset password'),
        content: const Text(
          'A password reset link will be sent to your email address.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnack(context, 'Reset email sent');
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}

/// =============================
/// TILE
/// =============================
class _SecurityTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SecurityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: Colors.white,
      leading: Icon(icon, color: const Color(0xFF4F46E5)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
