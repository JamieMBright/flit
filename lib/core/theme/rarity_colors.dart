import 'package:flutter/material.dart';

// =============================================================================
// Rarity colors — single source of truth
// =============================================================================

const Color bronzeColor = Color(0xFFCD7F32);
const Color silverColor = Color(0xFFC0C0C0);
const Color goldColor = Color(0xFFFFD700);
const Color diamondColor = Color(0xFFB9F2FF);

/// Returns the display color for a given rarity tier string.
Color colorForRarity(String rarityTier) {
  switch (rarityTier) {
    case 'Bronze':
      return bronzeColor;
    case 'Silver':
      return silverColor;
    case 'Gold':
      return goldColor;
    case 'Diamond':
      return diamondColor;
    case 'Perfect':
      return goldColor;
    default:
      return bronzeColor;
  }
}
