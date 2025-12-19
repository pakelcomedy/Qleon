/// Qleon Color Palette
/// ------------------------------------------------------------
/// Calm, dark-first, privacy-oriented colors
/// No flashy tones, no pure blacks, eye-friendly contrast
/// ------------------------------------------------------------

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  /// -------------------------------
  /// BRAND COLORS
  /// -------------------------------

  /// Primary brand color (used for actions, highlights)
  static const Color primary = Color(0xFF7C8AFF); // soft indigo-blue

  /// Accent color (used sparingly)
  static const Color accent = Color(0xFF5EEAD4); // muted teal

  /// Error / destructive actions
  static const Color error = Color(0xFFFF6B6B); // soft red

  /// -------------------------------
  /// BACKGROUND & SURFACE
  /// -------------------------------

  /// Main app background (NOT pure black)
  static const Color background = Color(0xFF0E1117);

  /// Card, app bar, input background
  static const Color surface = Color(0xFF161B22);

  /// Elevated elements (dialogs, menus)
  static const Color surfaceElevated = Color(0xFF1C2128);

  /// -------------------------------
  /// TEXT COLORS
  /// -------------------------------

  /// Primary text (high emphasis)
  static const Color textPrimary = Color(0xFFE6EDF3);

  /// Secondary text (medium emphasis)
  static const Color textSecondary = Color(0xFF9BA3AF);

  /// Hint / disabled text
  static const Color textHint = Color(0xFF6E7681);

  /// -------------------------------
  /// ICONS & DIVIDERS
  /// -------------------------------

  /// Default icon color
  static const Color icon = Color(0xFF9BA3AF);

  /// Divider & borders (very subtle)
  static const Color divider = Color(0xFF2D333B);

  /// -------------------------------
  /// CHAT BUBBLES
  /// -------------------------------

  /// Incoming message bubble
  static const Color bubbleIncoming = Color(0xFF1E2633);

  /// Outgoing message bubble
  static const Color bubbleOutgoing = Color(0xFF2A3A8F);

  /// System / info messages
  static const Color bubbleSystem = Color(0xFF202632);

  /// -------------------------------
  /// STATUS COLORS
  /// -------------------------------

  static const Color online = Color(0xFF22C55E);
  static const Color offline = Color(0xFF64748B);

  /// -------------------------------
  /// OVERLAYS
  /// -------------------------------

  /// Used for modal barriers, image overlays
  static const Color overlay = Color(0x99000000);
}
