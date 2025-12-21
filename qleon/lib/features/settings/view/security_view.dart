// lib/features/settings/view/security_view.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../viewmodel/security_viewmodel.dart';

class SecurityView extends StatefulWidget {
  const SecurityView({super.key});

  @override
  State<SecurityView> createState() => _SecurityViewState();
}

class _SecurityViewState extends State<SecurityView> {
  late final SecurityViewModel vm;

  @override
  void initState() {
    super.initState();
    vm = SecurityViewModel();
    vm.addListener(_vmListener);
  }

  void _vmListener() {
    // don't call vm.clearError() immediately while iterating listeners
    if (vm.errorMessage != null && mounted) {
      final msg = vm.errorMessage!;
      // schedule showing snackbar+clear on next frame to avoid re-entrancy
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        vm.clearError();
      });
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
          appBar: _appBar(),
          body: Column(
            children: [
              _SecurityTile(
                icon: Icons.email_outlined,
                title: 'Change email',
                subtitle: 'Update your login email (requires current password)',
                onTap: vm.isLoading ? null : () => _openChangeEmailSheet(context),
              ),
              _SecurityTile(
                icon: Icons.lock_outline,
                title: 'Change password',
                subtitle: 'Update your account password',
                onTap: vm.isLoading ? null : () => _openChangePasswordSheet(context),
              ),
              _SecurityTile(
                icon: Icons.help_outline,
                title: 'Forgot password',
                subtitle: 'Reset using your email',
                onTap: vm.isLoading ? null : () => _openForgotPasswordSheet(context),
              ),
            ],
          ),
        );
      },
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

  // -------------------------
  // Change Email (sheet)
  // -------------------------
  Future<void> _openChangeEmailSheet(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      backgroundColor: Colors.white,
      builder: (_) => ChangeEmailSheet(vm: vm),
    );

    // result true means email changed successfully inside sheet
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email updated')));
    }
  }

  // -------------------------
  // Change Password (sheet)
  // -------------------------
  Future<void> _openChangePasswordSheet(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      backgroundColor: Colors.white,
      builder: (_) => ChangePasswordSheet(vm: vm),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated')));
    }
  }

  // -------------------------
  // Forgot Password (sheet)
  // -------------------------
  Future<void> _openForgotPasswordSheet(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      backgroundColor: Colors.white,
      builder: (_) => ForgotPasswordSheet(vm: vm),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reset email sent')));
    }
  }
}

/// =====================================================
/// ChangeEmailSheet (Stateful) — owns controllers & lifecycle
/// =====================================================
class ChangeEmailSheet extends StatefulWidget {
  final SecurityViewModel vm;
  const ChangeEmailSheet({required this.vm, super.key});

  @override
  State<ChangeEmailSheet> createState() => _ChangeEmailSheetState();
}

class _ChangeEmailSheetState extends State<ChangeEmailSheet> {
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passwordCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController();
    _passwordCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Change email', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'New email address',
                border: OutlineInputBorder(borderSide: BorderSide.none),
                filled: true,
                fillColor: Color(0xFFF3F4F6),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Current password (required)',
                border: OutlineInputBorder(borderSide: BorderSide.none),
                filled: true,
                fillColor: Color(0xFFF3F4F6),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
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
                  child: AnimatedBuilder(
                    animation: vm,
                    builder: (_, __) {
                      return ElevatedButton(
                        onPressed: vm.isLoading ? null : _onSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: vm.isLoading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Save', style: TextStyle(color: Colors.white)),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _onSave() async {
    final email = _emailCtrl.text.trim();
    final pwd = _passwordCtrl.text;
    if (email.isEmpty || !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email');
      return;
    }
    if (pwd.isEmpty) {
      setState(() => _error = 'Please enter your current password');
      return;
    }

    setState(() => _error = null);
    final vm = widget.vm;
    final success = await vm.changeEmailWithPassword(currentPassword: pwd, newEmail: email);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = vm.errorMessage ?? 'Failed to change email');
    }
  }
}

/// =====================================================
/// ChangePasswordSheet (stateful)
/// =====================================================
class ChangePasswordSheet extends StatefulWidget {
  final SecurityViewModel vm;
  const ChangePasswordSheet({required this.vm, super.key});

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  late final TextEditingController _currentCtrl;
  late final TextEditingController _newCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentCtrl = TextEditingController();
    _newCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Change password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _currentCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Current password',
                border: OutlineInputBorder(borderSide: BorderSide.none),
                filled: true,
                fillColor: Color(0xFFF3F4F6),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _newCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'New password (min 6 chars)',
                border: OutlineInputBorder(borderSide: BorderSide.none),
                filled: true,
                fillColor: Color(0xFFF3F4F6),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
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
                  child: AnimatedBuilder(
                    animation: vm,
                    builder: (_, __) {
                      return ElevatedButton(
                        onPressed: vm.isLoading ? null : _onSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: vm.isLoading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Save', style: TextStyle(color: Colors.white)),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _onSave() async {
    final cur = _currentCtrl.text.trim();
    final np = _newCtrl.text.trim();

    if (cur.isEmpty || np.isEmpty) {
      setState(() => _error = 'Both fields are required');
      return;
    }
    if (np.length < 6) {
      setState(() => _error = 'New password must be at least 6 characters');
      return;
    }

    setState(() => _error = null);
    final ok = await widget.vm.changePassword(currentPassword: cur, newPassword: np);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = widget.vm.errorMessage ?? 'Failed to change password');
    }
  }
}

/// =====================================================
/// ForgotPasswordSheet (stateful)
/// =====================================================
class ForgotPasswordSheet extends StatefulWidget {
  final SecurityViewModel vm;
  const ForgotPasswordSheet({required this.vm, super.key});

  @override
  State<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<ForgotPasswordSheet> {
  late final TextEditingController _emailCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Reset password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('A password reset link will be sent to your email address.'),
            const SizedBox(height: 8),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'Your email address',
                border: OutlineInputBorder(borderSide: BorderSide.none),
                filled: true,
                fillColor: Color(0xFFF3F4F6),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
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
                  child: AnimatedBuilder(
                    animation: vm,
                    builder: (_, __) {
                      return ElevatedButton(
                        onPressed: vm.isLoading ? null : _onSend,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: vm.isLoading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Send', style: TextStyle(color: Colors.white)),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _onSend() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email');
      return;
    }

    setState(() => _error = null);
    final ok = await widget.vm.sendPasswordReset(email);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = widget.vm.errorMessage ?? 'Failed to send reset email');
    }
  }
}

/// =============================
/// TILE
/// =============================
class _SecurityTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

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
