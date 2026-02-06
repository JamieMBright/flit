import 'package:flutter/material.dart';

/// Pop art lo-fi realism color palette for Flit.
/// Inspired by vintage atlas aesthetics with natural, earthy tones.
/// Muted but warm - like a well-worn paper map under lamplight.
abstract final class FlitColors {
  // Ocean tones - deep, natural water colors
  static const Color oceanDeep = Color(0xFF1B3A4B);
  static const Color ocean = Color(0xFF2A5674);
  static const Color oceanShallow = Color(0xFF3D7A9E);
  static const Color oceanHighlight = Color(0xFF4A90B8);

  // Land tones - warm, earthy greens and tans
  static const Color landDark = Color(0xFF4A6741);
  static const Color landMass = Color(0xFF5C7A52);
  static const Color landMassHighlight = Color(0xFF7A9E6D);
  static const Color landArid = Color(0xFFB8A67A);
  static const Color landDesert = Color(0xFFD4C49A);
  static const Color landSnow = Color(0xFFE8E2D6);

  // Border and coastline
  static const Color border = Color(0xFF3D5A3A);
  static const Color coastline = Color(0xFF1E4D6B);

  // Background (atlas paper feel)
  static const Color backgroundDark = Color(0xFF1A2A32);
  static const Color backgroundMid = Color(0xFF1E3340);
  static const Color backgroundLight = Color(0xFF264050);

  // Accent - warm vintage red/orange (pop art touch)
  static const Color accent = Color(0xFFD4654A);
  static const Color accentLight = Color(0xFFE8825A);
  static const Color accentDark = Color(0xFFB84E38);

  // Secondary accent - vintage gold
  static const Color gold = Color(0xFFD4A944);
  static const Color goldLight = Color(0xFFE8C458);

  // Text colors - warm, readable
  static const Color textPrimary = Color(0xFFF0E8DC);
  static const Color textSecondary = Color(0xFFB8A890);
  static const Color textMuted = Color(0xFF7A6E5E);

  // City markers
  static const Color city = Color(0xFFE8C458);
  static const Color cityCapital = Color(0xFFD4654A);

  // UI elements
  static const Color cardBackground = Color(0xFF1E3340);
  static const Color cardBorder = Color(0xFF3A5060);
  static const Color success = Color(0xFF6AAB5C);
  static const Color warning = Color(0xFFD4A944);
  static const Color error = Color(0xFFCC4444);

  // Plane colors - vintage aircraft feel
  static const Color planeBody = Color(0xFFF0E8DC);
  static const Color planeWing = Color(0xFFD4C4A8);
  static const Color planeAccent = Color(0xFFD4654A);
  static const Color planeShadow = Color(0x40000000);

  // Contrail - subtle white wisps
  static const Color contrail = Color(0xB0F0E8DC);

  // Atmosphere and effects
  static const Color atmosphereHaze = Color(0x18F0E8DC);
  static const Color gridLine = Color(0x15F0E8DC);
  static const Color shadow = Color(0x30000000);
}
