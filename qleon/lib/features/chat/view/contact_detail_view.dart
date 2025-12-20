import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ContactDetailView extends StatelessWidget {
  const ContactDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    /// Dummy data (replace later with real source)
    const contactAlias = 'Alex Johnson'; // local name
    const qrPayload = 'contact-unique-id-12345'; // public identity payload

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
          'Contact info',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 28),

          /// ALIAS HEADER
          _AliasSection(contactAlias: contactAlias),

          const SizedBox(height: 24),

          /// PUBLIC IDENTITY
          _PublicIdentitySection(qrPayload: qrPayload),

          const SizedBox(height: 28),

          /// ACTIONS
          const _ActionSection(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// =======================================================
/// ALIAS SECTION (NO AVATAR)
/// =======================================================
class _AliasSection extends StatelessWidget {
  final String contactAlias;

  const _AliasSection({
    required this.contactAlias,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          contactAlias,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () => _showRenameSheet(context, contactAlias),
          child: const Text(
            'Edit local name',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF4F46E5),
            ),
          ),
        ),
      ],
    );
  }
}

/// =======================================================
/// PUBLIC IDENTITY (QR + CODE)
/// =======================================================
class _PublicIdentitySection extends StatelessWidget {
  final String qrPayload;

  const _PublicIdentitySection({
    required this.qrPayload,
  });

  String _generateIdentityCode(String payload) {
    final hash = payload.hashCode.toUnsigned(32);
    return '0x${hash.toRadixString(16).toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final identityCode = _generateIdentityCode(qrPayload);

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            const Text(
              'Public identity',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              identityCode,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.4,
                color: Color(0xFF4F46E5),
              ),
            ),
            const SizedBox(height: 16),
            QrImageView(
              data: qrPayload,
              version: QrVersions.auto,
              size: 180,
              foregroundColor: const Color(0xFF4F46E5),
            ),
            const SizedBox(height: 14),
            const Text(
              'This code represents a public identity.\nScan it to add or verify this contact on another device.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =======================================================
/// ACTION SECTION
/// =======================================================
class _ActionSection extends StatelessWidget {
  const _ActionSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionTile(
          icon: Icons.block,
          label: 'Block contact',
          color: Colors.red,
          onTap: () => _confirmAction(
            context,
            title: 'Block contact?',
            message: 'You will no longer receive messages or requests from this identity.',
          ),
        ),
        _ActionTile(
          icon: Icons.delete_outline,
          label: 'Delete chat',
          color: Colors.red,
          onTap: () => _confirmAction(
            context,
            title: 'Delete chat?',
            message: 'All local messages in this conversation will be permanently removed.',
          ),
        ),
      ],
    );
  }
}

/// =======================================================
/// ACTION TILE
/// =======================================================
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

/// =======================================================
/// BOTTOM-SHEET DIALOGS (replaces AlertDialog)
/// =======================================================

Future<void> _showRenameSheet(BuildContext context, String currentName) async {
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
              const Text('Edit local name', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Enter a new alias',
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

  // cleanup and apply
  controller.dispose();
  if (result == true) {
    final newAlias = controller.text.trim();
    // TODO: save alias locally (no server impact)
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved "$newAlias" (placeholder)')));
  }
}

Future<void> _confirmAction(
  BuildContext context, {
  required String title,
  required String message,
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
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Confirm', style: TextStyle(color: Colors.white)),
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
    // TODO: implement block / delete logic
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action confirmed (placeholder)')));
  }
}
