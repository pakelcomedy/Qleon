import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ContactDetailView extends StatelessWidget {
  const ContactDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy data
    const avatarUrl = 'https://i.pravatar.cc/150?img=21';
    const qrData = 'contact-unique-id-12345';

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
          'Contact Info',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 32),
          CircleAvatar(
            radius: 50,
            backgroundImage: NetworkImage(avatarUrl),
          ),
          const SizedBox(height: 16),
          const Text(
            'Scan QR to add contact',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 220,
              gapless: false,
              foregroundColor: const Color(0xFF4F46E5),
            ),
          ),
        ],
      ),
    );
  }
}
