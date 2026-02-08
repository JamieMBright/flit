import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../flit_game.dart';
import '../map/country_data.dart';

/// Renders country border outlines when the shader renderer is active.
///
/// The shader renders a textured globe but cannot draw vector country borders.
/// This overlay fills that gap by projecting [CountryData.countries] polygon
/// outlines onto the screen using the same camera transform as the shader.
class CountryBorderOverlay extends Component with HasGameRef<FlitGame> {
  /// Maximum number of countries to render per frame.
  /// Cap on web to prevent Safari crashes.
  static const int _maxCountries = kIsWeb ? 30 : 80;

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    try {
      // Skip when using Canvas renderer — WorldMap renders borders directly.
      if (!gameRef.isShaderActive) return;

      final continuousAlt = gameRef.plane.continuousAltitude;

      // Border opacity varies with altitude.
      final opacity = continuousAlt >= 0.6
          ? (0.4 * (1.0 - (continuousAlt - 0.6) / 0.4)).clamp(0.0, 0.4)
          : (0.6 + 0.4 * (1.0 - continuousAlt / 0.6)).clamp(0.0, 1.0);
      if (opacity < 0.02) return;

      final borderPaint = Paint()
        ..color = FlitColors.border.withOpacity(opacity * 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = continuousAlt >= 0.6 ? 0.6 : 1.2
        ..strokeJoin = StrokeJoin.round;

      final screenW = gameRef.size.x;
      final screenH = gameRef.size.y;
      final centerX = screenW / 2;
      final centerY = screenH / 2;

      // Pre-filter countries by approximate distance from camera center.
      // Sort by distance to prioritize nearby countries.
      final playerPos = gameRef.worldPosition;
      final scored = <({double dist, CountryShape country})>[];

      for (final country in CountryData.countries) {
        // Quick bounding-box center estimate.
        final pts = country.polygons.first;
        if (pts.isEmpty) continue;
        var sumLng = 0.0;
        var sumLat = 0.0;
        final step = (pts.length > 10) ? pts.length ~/ 5 : 1;
        var count = 0;
        for (var i = 0; i < pts.length; i += step) {
          sumLng += pts[i].x;
          sumLat += pts[i].y;
          count++;
        }
        final cLng = sumLng / count;
        final cLat = sumLat / count;
        final dx = cLng - playerPos.x;
        final dy = cLat - playerPos.y;
        scored.add((dist: dx * dx + dy * dy, country: country));
      }

      scored.sort((a, b) => a.dist.compareTo(b.dist));

      var rendered = 0;
      for (final entry in scored) {
        if (rendered >= _maxCountries) break;

        for (final polygon in entry.country.polygons) {
          if (polygon.length < 3) continue;

          final path = ui.Path();
          var started = false;
          var anyVisible = false;

          for (var i = 0; i < polygon.length; i++) {
            final screenPos = gameRef.worldToScreen(polygon[i]);

            // Skip points behind camera.
            if (screenPos.x < -500 || screenPos.y < -500) {
              started = false;
              continue;
            }

            // Check if point is reasonably near screen.
            if (screenPos.x > -100 &&
                screenPos.x < screenW + 100 &&
                screenPos.y > -100 &&
                screenPos.y < screenH + 100) {
              anyVisible = true;
            }

            if (!started) {
              path.moveTo(screenPos.x, screenPos.y);
              started = true;
            } else {
              path.lineTo(screenPos.x, screenPos.y);
            }
          }

          if (anyVisible && started) {
            path.close();
            canvas.drawPath(path, borderPaint);
            rendered++;
          }
        }
      }
    } catch (e) {
      // Don't crash the game loop on projection errors.
    }
  }
}
