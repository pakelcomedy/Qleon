/// Qleon App Constants
/// Centralized, immutable, and environment-agnostic constants
/// This file MUST NOT contain secrets or environment-specific values

import 'package:flutter/material.dart';

/// -------------------------------
/// APP METADATA
/// -------------------------------
class AppConstants {
  AppConstants._(); // prevent instantiation

  static const String appName = 'Qleon';
  static const String appTagline = 'Private by design. Silent by choice.';
  static const String appVersion = '1.0.0';

  /// Used for logs, analytics, and storage prefixes
  static const String appId = 'com.qleon.chat';
}

/// -------------------------------
/// UI CONSTANTS
/// -------------------------------
class UIConstants {
  UIConstants._();

  // Spacing
  static const double paddingXS = 4;
  static const double paddingSM = 8;
  static const double paddingMD = 16;
  static const double paddingLG = 24;
  static const double paddingXL = 32;

  // Radius
  static const double radiusSM = 8;
  static const double radiusMD = 12;
  static const double radiusLG = 20;

  // Animation durations
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
}

/// -------------------------------
/// CHAT CONSTANTS
/// -------------------------------
class ChatConstants {
  ChatConstants._();

  static const int maxGroupMembers = 20;
  static const int maxMessageLength = 4000;

  static const Duration typingIndicatorTimeout = Duration(seconds: 3);

  // Message types
  static const String messageTypeText = 'text';
  static const String messageTypeImage = 'image';
  static const String messageTypeVoice = 'voice';
  static const String messageTypeSystem = 'system';
}

/// -------------------------------
/// SECURITY CONSTANTS
/// -------------------------------
class SecurityConstants {
  SecurityConstants._();

  static const int pinLength = 6;

  static const Duration appLockTimeout = Duration(seconds: 30);

  // Screenshot protection flag (used per-platform)
  static const bool enableScreenshotProtection = true;
}

/// -------------------------------
/// STORAGE KEYS (LOCAL & SECURE)
/// -------------------------------
class StorageKeys {
  StorageKeys._();

  // Secure storage
  static const String privateKey = 'private_key';
  static const String publicKey = 'public_key';
  static const String deviceId = 'device_id';
  static const String appPin = 'app_pin';

  // Local cache
  static const String cachedUser = 'cached_user';
  static const String cachedSettings = 'cached_settings';
}

/// -------------------------------
/// NOTIFICATION CONSTANTS
/// -------------------------------
class NotificationConstants {
  NotificationConstants._();

  static const String defaultChannelId = 'qleon_messages';
  static const String defaultChannelName = 'Messages';
  static const String defaultChannelDescription = 'Incoming secure messages';

  static const String silentPayload = 'SILENT_MESSAGE';
}

/// -------------------------------
/// NETWORK & TIMEOUTS
/// -------------------------------
class NetworkConstants {
  NetworkConstants._();

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
}

/// -------------------------------
/// SUPPORTED PLATFORMS
/// -------------------------------
class PlatformConstants {
  PlatformConstants._();

  static const List<TargetPlatform> supportedPlatforms = [
    TargetPlatform.android,
    TargetPlatform.iOS,
  ];
}