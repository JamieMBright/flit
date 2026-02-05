import 'package:flutter/material.dart';

/// Low-fi color palette for Flit.
/// 2-3 contrasting colors, low light, shadows and highlights.
abstract final class FlitColors {
  // Background colors (dark, calming)
  static const Color backgroundDark = Color(0xFF1A1A2E);
  static const Color backgroundMid = Color(0xFF16213E);
  static const Color backgroundLight = Color(0xFF0F3460);

  // Accent color (warm contrast)
  static const Color accent = Color(0xFFE94560);
  static const Color accentLight = Color(0xFFFF6B6B);
  static const Color accentDark = Color(0xFFC73E54);

  // Text colors
  static const Color textPrimary = Color(0xFFFAFAFA);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textMuted = Color(0xFF6B6B6B);

  // Game elements
  static const Color landMass = Color(0xFF2D4A6E);
  static const Color landMassHighlight = Color(0xFF3D5A7E);
  static const Color ocean = Color(0xFF1A1A2E);
  static const Color border = Color(0xFF4A6FA5);
  static const Color city = Color(0xFFFFD93D);

  // UI elements
  static const Color cardBackground = Color(0xFF16213E);
  static const Color cardBorder = Color(0xFF2D4A6E);
  static const Color success = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFEF4444);

  // Plane colors (customizable via cosmetics later)
  static const Color planeBody = Color(0xFFFAFAFA);
  static const Color planeAccent = Color(0xFFE94560);
  static const Color contrail = Color(0x80FFFFFF);
}
