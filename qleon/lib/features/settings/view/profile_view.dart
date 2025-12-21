// public_identity_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../viewmodel/profile_viewmodel.dart';

class PublicIdentityView extends StatelessWidget {
  const PublicIdentityView({super.key});

  @override
  Widget build(BuildContext context) {
    // Provide ProfileViewModel above this screen (if not provided globally)
    // Jika sudah disediakan di level lebih atas, hapus ChangeNotifierProvider ini.
    return ChangeNotifierProvider<ProfileViewModel>(
      create: (_) => ProfileViewModel(),
      child: const _PublicIdentityBody(),
    );
  }
}

class _PublicIdentityBody extends StatelessWidget {
  const _PublicIdentityBody({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileViewModel>();

    final publicId = vm.name ?? '';
    final qrData = vm.qrData;
    final isLoading = vm.isLoading;
    final isUpdating = vm.isUpdatingTemp;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: _appBar(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 12),

            // QR CODE container
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Center(
                child: Builder(builder: (_) {
                  if (isLoading) {
                    return const CircularProgressIndicator();
                  }

                  if (qrData.isEmpty) {
                    // fallback placeholder (same icon as you had)
                    return const Icon(
                      Icons.qr_code_2,
                      size: 140,
                      color: Color(0xFF111827),
                    );
                  }

                  // render QR using vm.qrData (name+temp+uid tanpa spasi)
                  return QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                  );
                }),
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

            // PUBLIC ID display + copy button
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
                      publicId.isEmpty ? '-' : publicId,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: publicId.isEmpty
                        ? null
                        : () async {
                            // capture messenger before async gap
                            final messenger = ScaffoldMessenger.of(context);
                            await Clipboard.setData(ClipboardData(text: publicId));
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Public ID copied')),
                            );
                          },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // info text
            const Text(
              'This identity is cryptographically generated.\n'
              'It does not reveal your name, number, or device.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            // change QR code button
            SizedBox(
              width: 220,
              child: ElevatedButton(
                onPressed: isUpdating
                    ? null
                    : () async {
                        // capture messenger before async gap to avoid use_build_context_synchronously warning
                        final messenger = ScaffoldMessenger.of(context);

                        await vm.changeTemp();

                        final err = vm.errorMessage;
                        if (err != null) {
                          messenger.showSnackBar(SnackBar(content: Text(err)));
                        } else {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('QR code changed')),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isUpdating
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Change QR code',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 12),

            // extra: show current qrData and copy button (optional)
            if (qrData.isNotEmpty) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: qrData));
                  messenger.showSnackBar(
                    const SnackBar(content: Text('QR data copied')),
                  );
                },
              ),
            ],
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
