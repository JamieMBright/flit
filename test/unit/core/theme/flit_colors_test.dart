import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flit/core/theme/flit_colors.dart';

void main() {
  group('FlitColors', () {
    test('background colors are dark', () {
      expect(FlitColors.backgroundDark.computeLuminance(), lessThan(0.2));
      expect(FlitColors.backgroundMid.computeLuminance(), lessThan(0.2));
    });

    test('text colors are light', () {
      expect(FlitColors.textPrimary.computeLuminance(), greaterThan(0.8));
    });

    test('accent color has sufficient contrast', () {
      // Accent should be visible against dark background
      final contrastRatio = _contrastRatio(
        FlitColors.accent,
        FlitColors.backgroundDark,
      );
      // WCAG AA requires 4.5:1 for normal text
      expect(contrastRatio, greaterThan(4.5));
    });

    test('color palette is limited (low-fi aesthetic)', () {
      // Core palette should be 2-3 main colors
      final coreColors = {
        FlitColors.backgroundDark,
        FlitColors.accent,
        FlitColors.textPrimary,
      };
      expect(coreColors.length, equals(3));
    });
  });
}

/// Calculate contrast ratio between two colors (WCAG formula)
double _contrastRatio(Color foreground, Color background) {
  final fgLuminance = foreground.computeLuminance() + 0.05;
  final bgLuminance = background.computeLuminance() + 0.05;
  return fgLuminance > bgLuminance
      ? fgLuminance / bgLuminance
      : bgLuminance / fgLuminance;
}
