// add_contact_viewmodel.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'new_chat_viewmodel.dart'; // ChatContact model

class AddContactViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // MobileScanner controller (used by camera and optionally analyzeImage)
  final MobileScannerController cameraController = MobileScannerController();

  bool isProcessing = false;
  String? errorMessage;

  // parsing lengths - MUST match generator in ProfileViewModel
  static const int kNameLen = 10; // e.g. "0xA94F32C1"
  static const int kTempLen = 6;  // e.g. "9fhh9i"

  // prefix expected in QR payload (optional)
  static const String kPrefix = 'qleon://user/';

  AddContactViewModel();

  /// Process raw scanned string.
  /// Returns a ChatContact if successful, otherwise throws.
  Future<ChatContact> processScannedPayload(String raw) async {
    isProcessing = true;
    errorMessage = null;
    notifyListeners();

    try {
      // Allow either raw payload or with prefix
      String payload = raw;
      if (payload.startsWith(kPrefix)) {
        payload = payload.replaceFirst(kPrefix, '');
      }

      if (payload.length <= kNameLen + kTempLen) {
        throw FormatException('Payload too short');
      }

      final name = payload.substring(0, kNameLen);
      final temp = payload.substring(kNameLen, kNameLen + kTempLen);
      final uid = payload.substring(kNameLen + kTempLen);

      // sanity checks
      if (!name.startsWith('0x') || uid.isEmpty) {
        throw FormatException('Invalid payload format');
      }

      // Try to fetch user doc to enrich displayName/status
      final userDoc = await _firestore.collection('users').doc(uid).get();

      String displayName = name; // fallback to name as display alias
      String publicStatus = 'New contact';
      bool isOnline = false;

      if (userDoc.exists) {
        final data = userDoc.data()!;
        // The 'name' field in users doc is already the public identity (0x..)
        displayName = (data['name'] as String?) ?? displayName;
        // If you have additional profile fields like displayName/publicStatus/isOnline, map them here
        if (data.containsKey('displayName')) {
          displayName = (data['displayName'] as String?) ?? displayName;
        }
        if (data.containsKey('publicStatus')) {
          publicStatus = (data['publicStatus'] as String?) ?? publicStatus;
        }
        // if you track presence in users doc:
        if (data.containsKey('isOnline')) {
          isOnline = (data['isOnline'] as bool?) ?? false;
        }
      } else {
        // user doc not found — still create contact with minimal info
        displayName = name;
        publicStatus = 'No profile found';
      }

      final contact = ChatContact(
        publicId: name,
        displayName: displayName,
        publicStatus: publicStatus,
        isOnline: isOnline,
      );

      isProcessing = false;
      notifyListeners();
      return contact;
    } on FirebaseException catch (e) {
      isProcessing = false;
      errorMessage = e.message ?? e.code;
      notifyListeners();
      rethrow;
    } catch (e) {
      isProcessing = false;
      errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Try to decode QR from picked image path using MobileScannerController.analyzeImage
  /// Not all versions/platforms support analyzeImage; wrap in try/catch.
  Future<String?> decodeQrFromImage(String imagePath) async {
    try {
      // analyzeImage is available on some versions of mobile_scanner; this
      // call may throw/no-op if not available — keep defensive.
      final result = await cameraController.analyzeImage(imagePath);
      // analyzeImage may return BarcodeCapture or list, but the package API
      // may vary — handle common cases defensively:
      if (result == null) return null;

      // If result has barcodes property:
      try {
        // dynamic casting:
        final dynamic r = result;
        if (r is String) return r;
        if (r is Iterable && r.isNotEmpty) {
          final first = r.first;
          if (first is String) return first;
          if (first?.rawValue != null) return first.rawValue as String?;
        }
        if (r.rawValue != null) return r.rawValue as String?;
        if (r.barcodes != null && r.barcodes.isNotEmpty) {
          final barcode = r.barcodes.first;
          return barcode.rawValue as String?;
        }
      } catch (_) {
        // fallback try toString()
        return result.toString();
      }
      return result.toString();
    } catch (e) {
      // analyzeImage may not be implemented; return null so UI can show message
      debugPrint('[AddContactVM] decodeQrFromImage failed: $e');
      return null;
    }
  }

  @override
  void dispose() {
    try {
      cameraController.dispose();
    } catch (_) {}
    super.dispose();
  }
}