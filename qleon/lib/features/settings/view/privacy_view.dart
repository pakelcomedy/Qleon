import 'package:flutter/material.dart';

class PrivacyView extends StatefulWidget {
  const PrivacyView({super.key});

  @override
  State<PrivacyView> createState() => _PrivacyViewState();
}

class _PrivacyViewState extends State<PrivacyView> {
  String _lastSeen = 'Contacts';
  bool _readReceipts = true;
  bool _publicIdentity = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: _appBar(),
      body: Column(
        children: [
          _PrivacySelectorTile(
            title: 'Last seen',
            value: _lastSeen,
            onTap: () => _selectLastSeen(context),
          ),
          _PrivacySwitchTile(
            title: 'Read receipts',
            subtitle: 'Let others know when you read messages',
            value: _readReceipts,
            onChanged: (v) => setState(() => _readReceipts = v),
          ),
          _PrivacySwitchTile(
            title: 'Public identity',
            subtitle: 'Allow others to find you via QR code',
            value: _publicIdentity,
            onChanged: (v) => setState(() => _publicIdentity = v),
          ),
        ],
      ),
    );
  }

  AppBar _appBar() => AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Privacy',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
      );

  /// =============================
  /// LAST SEEN SELECTOR
  /// =============================
  void _selectLastSeen(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _option('Everyone'),
          _option('Contacts'),
          _option('Nobody'),
        ],
      ),
    );
  }

  Widget _option(String value) {
    return ListTile(
      title: Text(value),
      trailing: _lastSeen == value
          ? const Icon(Icons.check, color: Color(0xFF4F46E5))
          : null,
      onTap: () {
        setState(() => _lastSeen = value);
        Navigator.pop(context);
      },
    );
  }
}

/// =============================
/// TILES
/// =============================
class _PrivacySelectorTile extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onTap;

  const _PrivacySelectorTile({
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: Colors.white,
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(color: Color(0xFF6B7280)),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _PrivacySwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PrivacySwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      tileColor: Colors.white,
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 13),
      ),
      value: value,
      activeColor: const Color(0xFF4F46E5),
      onChanged: onChanged,
    );
  }
}
