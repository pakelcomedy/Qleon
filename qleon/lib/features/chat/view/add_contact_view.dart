import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class AddContactView extends StatefulWidget {
  const AddContactView({super.key});

  @override
  State<AddContactView> createState() => _AddContactViewState();
}

class _AddContactViewState extends State<AddContactView> {
  bool _isScanned = false;

  @override
  Widget build(BuildContext context) {
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
            onDetect: (barcode) {
              if (_isScanned) return;

              final String? value = barcode.barcodes.first.rawValue;
              if (value == null) return;

              setState(() => _isScanned = true);

              _handleQrResult(context, value);
            },
          ),

          /// SCAN FRAME
          _ScanOverlay(),

          /// INFO TEXT
          Positioned(
            bottom: 40,
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
        ],
      ),
    );
  }

  void _handleQrResult(BuildContext context, String data) {
    /// CONTOH FORMAT QR:
    /// qleon://user/USER_ID_123

    if (!data.startsWith('qleon://user/')) {
      _showError(context);
      return;
    }

    final userId = data.replaceFirst('qleon://user/', '');

    /// TODO:
    /// - fetch user by userId
    /// - save to contact list
    /// - open chat room

    Future.delayed(const Duration(milliseconds: 300), () {
      Navigator.pop(context);
    });
  }

  void _showError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invalid QR Code'),
        backgroundColor: Colors.red,
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      setState(() => _isScanned = false);
    });
  }
}

/// =============================================================
/// SCAN OVERLAY UI
/// =============================================================
class _ScanOverlay extends StatelessWidget {
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
