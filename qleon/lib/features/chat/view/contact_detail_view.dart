import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../viewmodel/contact_detail_viewmodel.dart';

/// ContactDetailView
/// Usage:
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => ContactDetailView(conversationIdOrId: 'SOME_ID'),
/// ));
class ContactDetailView extends StatelessWidget {
  final String conversationIdOrId;
  final String? title;

  const ContactDetailView({super.key, required this.conversationIdOrId, this.title});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ContactDetailViewModel>(
      create: (_) => ContactDetailViewModel(conversationIdOrId: conversationIdOrId)..init(),
      child: Consumer<ContactDetailViewModel>(builder: (context, vm, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF1F3F6),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              title ?? 'Contact info',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
            ),
          ),
          body: _Body(vm: vm),
        );
      }),
    );
  }
}

class _Body extends StatelessWidget {
  final ContactDetailViewModel vm;
  const _Body({required this.vm});

  @override
  Widget build(BuildContext context) {
    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // displayName shown at top (local alias if present)
    final displayName = vm.localAlias ?? vm.getPublicIdentity();
    // QR payload (format name + temp + uid). May be empty if not resolvable.
    final payload = vm.getQrPayload();
    // public identity (name) to display inside the identity card
    final publicIdentity = vm.getPublicIdentity();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const SizedBox(height: 28),
        _AliasSection(displayName: displayName, vm: vm),
        const SizedBox(height: 24),
        _PublicIdentitySection(qrPayload: payload, publicIdentity: publicIdentity),
        const SizedBox(height: 28),
        _MetaSection(vm: vm),
        const SizedBox(height: 18),
        _ActionSection(vm: vm),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _AliasSection extends StatelessWidget {
  final String displayName;
  final ContactDetailViewModel vm;
  const _AliasSection({required this.displayName, required this.vm});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          displayName,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
        ),
        const SizedBox(height: 6),
        // simple Edit alias immediately under name
        TextButton(
          onPressed: () => _showRenameSheet(context, vm),
          child: const Text('Edit local name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF4F46E5))),
        ),
      ],
    );
  }
}

class _PublicIdentitySection extends StatelessWidget {
  final String qrPayload;
  final String publicIdentity;

  const _PublicIdentitySection({required this.qrPayload, required this.publicIdentity});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Column(
          children: [
            const Text('Public identity', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
            const SizedBox(height: 8),

            // <-- show the name (public identity) as primary label
            Text(
              publicIdentity,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
            ),

            const SizedBox(height: 12),

            // QR: show only if payload is non-empty; else show placeholder
            if (qrPayload.isNotEmpty)
              QrImageView(
                data: qrPayload,
                version: QrVersions.auto,
                size: 180.0,
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: const Color(0xFF4F46E5),
                ),
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF4F46E5),
                ),
              )
            else
              Container(
                height: 180,
                alignment: Alignment.center,
                child: const Text('QR not available', style: TextStyle(color: Color(0xFF6B7280))),
              ),

            const SizedBox(height: 14),
            const Text(
              'This code represents a public identity.\nScan it to add or verify this contact on another device.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _MetaSection extends StatelessWidget {
  final ContactDetailViewModel vm;
  const _MetaSection({required this.vm});

  @override
  Widget build(BuildContext context) {
    final data = vm.safeProfile();
    if (data.isEmpty) return Container();

    final rows = <Widget>[];

    if (data.containsKey('phone')) {
      rows.add(_InfoTile(label: 'Phone', value: data['phone'].toString()));
    }
    if (data.containsKey('about')) {
      rows.add(_InfoTile(label: 'About', value: data['about'].toString()));
    }

    if (rows.isEmpty) return Container();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(children: rows),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
      subtitle: Text(value, style: const TextStyle(color: Color(0xFF6B7280))),
      dense: true,
    );
  }
}

class _ActionSection extends StatelessWidget {
  final ContactDetailViewModel vm;
  const _ActionSection({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: FutureBuilder<bool>(
            future: vm.isContactBlocked(),
            builder: (context, snap) {
              final blocked = snap.data ?? false;
              return ListTile(
                leading: Icon(blocked ? Icons.lock_open : Icons.block, color: blocked ? Colors.orange : Colors.red),
                title: Text(
                  blocked ? 'Unblock contact' : 'Block contact',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: blocked ? Colors.orange : Colors.red),
                ),
                onTap: () async {
                  final ok = await _showConfirmSheet(
                    context,
                    title: blocked ? 'Unblock contact?' : 'Block contact?',
                    message: blocked ? 'Allow messages from this contact again.' : 'You will no longer receive messages or requests from this identity.',
                  );
                  if (!context.mounted) return;
                  if (ok == true) {
                    try {
                      if (blocked) {
                        await vm.unblockContact();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact unblocked')));
                      } else {
                        await vm.blockContact();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact blocked')));
                      }
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Operation failed: $e')));
                    }
                  }
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Container(
          color: Colors.white,
          child: ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Delete chat', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.red)),
            onTap: () async {
              final ok = await _showConfirmSheet(
                context,
                title: 'Delete chat?',
                message: 'All local messages in this conversation will be marked as deleted (soft-delete).',
              );
              if (!context.mounted) return;
              if (ok == true) {
                try {
                  await vm.clearConversation();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conversation cleared')));
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to clear conversation: $e')));
                }
              }
            },
          ),
        ),
      ],
    );
  }
}

// -------------------------
// Helpers / Sheets
// -------------------------

Future<void> _showRenameSheet(BuildContext context, ContactDetailViewModel vm) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return _RenameAliasSheet(vm: vm);
    },
  );
}

class _RenameAliasSheet extends StatefulWidget {
  final ContactDetailViewModel vm;
  const _RenameAliasSheet({required this.vm});

  @override
  State<_RenameAliasSheet> createState() => _RenameAliasSheetState();
}

class _RenameAliasSheetState extends State<_RenameAliasSheet> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.vm.localAlias ??
          widget.vm.contactData?['displayName']?.toString() ??
          widget.vm.contactData?['name']?.toString() ??
          '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newAlias = _controller.text.trim();
    setState(() => _saving = true);

    try {
      await widget.vm.saveLocalAlias(newAlias);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newAlias.isEmpty ? 'Alias removed' : 'Saved "$newAlias"')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save alias: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomInset,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Edit local name',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Enter a new alias',
                  filled: true,
                  fillColor: Color(0xFFF3F4F6),
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool?> _showConfirmSheet(BuildContext context, {required String title, required String message}) {
  return showModalBottomSheet<bool>(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    backgroundColor: Colors.white,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(fontSize: 14, color: Color(0xFF111827))),
            const SizedBox(height: 18),
            Row(children: [
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
            ]),
          ]),
        ),
      );
    },
  );
}
