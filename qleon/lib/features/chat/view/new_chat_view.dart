// new_chat_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodel/new_chat_viewmodel.dart';
import 'chat_room_view.dart';
import 'add_contact_view.dart';
import '../../group/view/create_group_view.dart';

class NewChatView extends StatelessWidget {
  const NewChatView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NewChatViewModel>(
      create: (_) => NewChatViewModel(),
      child: const _NewChatBody(),
    );
  }
}

class _NewChatBody extends StatelessWidget {
  const _NewChatBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NewChatViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          _buildActionSection(context),
          _buildSearchBar(),
          Expanded(
            child: vm.isLoading
                ? const Center(child: CircularProgressIndicator())
                : vm.contacts.isEmpty
                    ? const _EmptyContactsPlaceholder()
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: vm.contacts.length,
                        itemBuilder: (context, index) {
                          final contact = vm.contacts[index];
                          return _ContactCard(
                            contact: contact,
                            onTap: () async {
                              // Try to open existing conversation or create one.
                              // We assume ChatContact has an `id`/identifier field.
                              // If your model uses a different name (publicId/uid), replace `contact.id`
                              // with the proper field.
                              String conversationId;
                              try {
                                // If your ViewModel exposes a helper to create/open a conversation,
                                // prefer that (e.g. vm.openConversationForContact(contact))
                                // optional: if you added this helper
                                conversationId = await vm.openOrCreateConversation(contact);
                                                            } catch (_) {
                                // Fallback to contact.id if helper absent or failed
                                conversationId = contact.id;
                              }

                              // navigate only if mounted
                              if (!context.mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatRoomView(
                                    conversationId: conversationId,
                                    title: contact.displayName,
                                    isGroup: false,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
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
        'New Chat',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF111827),
        ),
      ),
    );
  }

  /// =============================================================
  /// ACTION SECTION
  /// =============================================================
  Widget _buildActionSection(BuildContext context) {
    final vm = context.read<NewChatViewModel>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        children: [
          _ActionTile(
            icon: Icons.group_add,
            title: 'New Group',
            subtitle: 'Create a secure group',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateGroupView(),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.qr_code_scanner,
            title: 'Add New Contact',
            subtitle: 'Scan public identity',
            onTap: () async {
              // Launch AddContactView and wait for the scanned contact
              final result = await Navigator.push<dynamic>(
                context,
                MaterialPageRoute(builder: (_) => const AddContactView()),
              );

              // If AddContactView returns a ChatContact, save it and open chat
              if (result is ChatContact) {
                try {
                  await vm.addContact(result);

                  // immediately navigate to chat room
                  if (!context.mounted) return;

                  // same assumption: ChatContact has `id`. Replace if different.
                  String conversationId;
                  try {
                    conversationId = await vm.openOrCreateConversation(result);
                                    } catch (_) {
                    conversationId = result.id;
                  }

                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatRoomView(
                        conversationId: conversationId,
                        title: result.displayName,
                        isGroup: false,
                      ),
                    ),
                  );
                } catch (e) {
                  // show snackbar on error
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal menambahkan kontak: $e')),
                  );
                }
              }
            },
          ),
        ],
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.04 * 255).round()),
              blurRadius: 10,
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.search, color: Colors.grey),
            SizedBox(width: 8),
            Text(
              'Search contacts',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.04 * 255).round()),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEEF2FF),
              ),
              child: Icon(icon, color: const Color(0xFF4F46E5)),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Contact card that uses ChatContact model from viewmodel
class _ContactCard extends StatelessWidget {
  final ChatContact contact;
  final VoidCallback onTap;

  const _ContactCard({
    required this.contact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.04 * 255).round()),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _IdentityIndicator(isOnline: contact.isOnline),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Color(0xFF111827),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    contact.publicStatus,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityIndicator extends StatelessWidget {
  final bool isOnline;
  const _IdentityIndicator({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline ? const Color(0xFFEEF2FF) : const Color(0xFFE5E7EB),
      ),
      child: Icon(
        Icons.person_outline,
        color: isOnline ? const Color(0xFF4F46E5) : Colors.grey,
      ),
    );
  }
}

class _EmptyContactsPlaceholder extends StatelessWidget {
  const _EmptyContactsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No contacts yet. Tap "Add New Contact" to scan and add.',
        style: TextStyle(color: Colors.grey.shade600),
      ),
    );
  }
}
