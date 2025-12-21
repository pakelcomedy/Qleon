// add_contact_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

import '../viewmodel/add_contact_viewmodel.dart';
import '../viewmodel/new_chat_viewmodel.dart'; // ChatContact model

class AddContactView extends StatefulWidget {
  const AddContactView({super.key});

  @override
  State<AddContactView> createState() => _AddContactViewState();
}

class _AddContactViewState extends State<AddContactView> {
  bool _isScanned = false;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AddContactViewModel>(
      create: (_) => AddContactViewModel(),
      child: const _AddContactBody(),
    );
  }
}

class _AddContactBody extends StatefulWidget {
  const _AddContactBody({super.key});

  @override
  State<_AddContactBody> createState() => _AddContactBodyState();
}

class _AddContactBodyState extends State<_AddContactBody> {
  bool _isScanned = false;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<AddContactViewModel>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Scan QR Code'),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          /// CAMERA
          MobileScanner(
            controller: vm.cameraController,
            onDetect: (capture) async {
              if (_isScanned) return;

              final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
              final String? value = barcode?.rawValue;
              if (value == null) return;

              setState(() => _isScanned = true);

              await _handleQrResult(context, value, vm);
            },
          ),

          /// SCAN FRAME
          const _ScanOverlay(),

          /// INFO TEXT
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Column(
              children: const [
                Text(
                  'Align QR code within frame',
                  style: TextStyle(color: Colors.white70),
                ),
                SizedBox(height: 6),
                Text(
                  'Contact will be added automatically',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),

          /// BUTTON GALERI
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              onPressed: () => _pickImageFromGallery(context),
              child: const Icon(Icons.photo, color: Colors.black),
            ),
          ),

          // processing overlay
          Consumer<AddContactViewModel>(
            builder: (context, vm, _) {
              if (vm.isProcessing) {
                return const Positioned.fill(
                  child: ColoredBox(
                    color: Color.fromRGBO(0, 0, 0, 0.45),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleQrResult(BuildContext context, String data, AddContactViewModel vm) async {
    // process data using VM
    try {
      final messenger = ScaffoldMessenger.of(context);
      // process and get ChatContact
      final ChatContact contact = await vm.processScannedPayload(data);

      // return the scanned contact back to previous screen
      if (!mounted) return;
      Navigator.pop(context, contact);
    } catch (e) {
      // show error and allow scanning again
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Invalid QR or failed to add contact: ${vm.errorMessage ?? e}')),
      );

      // allow re-scan
      setState(() => _isScanned = false);
    }
  }

  Future<void> _pickImageFromGallery(BuildContext context) async {
    final vm = context.read<AddContactViewModel>();
    final messenger = ScaffoldMessenger.of(context);

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    // try to decode using cameraController.analyzeImage (may not be available)
    try {
      final decoded = await vm.decodeQrFromImage(image.path);
      if (decoded == null || decoded.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No QR code found in image')),
        );
        return;
      }

      setState(() => _isScanned = true);

      try {
        final ChatContact contact = await vm.processScannedPayload(decoded);
        if (!mounted) return;
        Navigator.pop(context, contact);
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text('Cannot add contact: ${vm.errorMessage ?? e}')),
        );
        setState(() => _isScanned = false);
      }
    } catch (e) {
      // decode method not available or failed
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to decode image on this device')),
      );
    }
  }
}

/// =============================================================
/// SCAN OVERLAY UI
/// =============================================================
class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
        ),
      ),
    );
  }
}
