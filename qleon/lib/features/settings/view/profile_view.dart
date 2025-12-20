import 'package:flutter/material.dart';

class PublicIdentityView extends StatelessWidget {
  const PublicIdentityView({super.key});

  @override
  Widget build(BuildContext context) {
    const publicId = '0xA94F32C1F8E21B9D';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: _appBar(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 12),

            /// QR CODE PLACEHOLDER
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Center(
                child: Icon(
                  Icons.qr_code_2,
                  size: 140,
                  color: Color(0xFF111827),
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Public Identity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Share this ID to start a secure conversation',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            /// PUBLIC ID
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      publicId,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Public ID copied')),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            /// INFO
            const Text(
              'This identity is cryptographically generated.\n'
              'It does not reveal your name, number, or device.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  AppBar _appBar() => AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Public identity',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
      );
}
