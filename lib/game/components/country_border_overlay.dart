import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../flit_game.dart';
import '../map/country_data.dart';

/// Renders climate-coloured country fills and border outlines when the shader
/// renderer is active.
///
/// The shader renders a satellite-textured globe but cannot draw vector data.
/// This overlay projects [CountryData.countries] polygons onto the screen
/// with semi-transparent Köppen-Geiger climate fills and border strokes.
class CountryBorderOverlay extends Component with HasGameRef<FlitGame> {
  /// Maximum countries to render per frame (cap on web for Safari).
  static const int _maxCountries = kIsWeb ? 30 : 80;

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    try {
      if (!gameRef.isShaderActive) return;

      final continuousAlt = gameRef.plane.continuousAltitude;

      // Fill + border opacity varies with altitude.
      // Low altitude: more opaque fills for country distinction.
      // High altitude: subtle tint.
      final fillOpacity = continuousAlt >= 0.6
          ? (0.15 * (1.0 - (continuousAlt - 0.6) / 0.4)).clamp(0.0, 0.15)
          : (0.15 + 0.15 * (1.0 - continuousAlt / 0.6)).clamp(0.0, 0.30);
      final borderOpacity = continuousAlt >= 0.6
          ? (0.4 * (1.0 - (continuousAlt - 0.6) / 0.4)).clamp(0.0, 0.4)
          : (0.5 + 0.5 * (1.0 - continuousAlt / 0.6)).clamp(0.0, 1.0);

      if (fillOpacity < 0.01 && borderOpacity < 0.01) return;

      final borderPaint = Paint()
        ..color = FlitColors.border.withOpacity(borderOpacity * 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = continuousAlt >= 0.6 ? 0.6 : 1.2
        ..strokeJoin = StrokeJoin.round;

      final screenW = gameRef.size.x;
      final screenH = gameRef.size.y;

      // Sort countries by distance from player for priority rendering.
      final playerPos = gameRef.worldPosition;
      final scored = <({double dist, CountryShape country, double cLng, double cLat})>[];

      for (final country in CountryData.countries) {
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
        scored.add((dist: dx * dx + dy * dy, country: country, cLng: cLng, cLat: cLat));
      }

      scored.sort((a, b) => a.dist.compareTo(b.dist));

      var rendered = 0;
      for (final entry in scored) {
        if (rendered >= _maxCountries) break;

        final climateColor = _getClimateColor(entry.cLng, entry.cLat);
        final fillPaint = Paint()
          ..color = climateColor.withOpacity(fillOpacity);

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
            // Draw climate fill, then border on top.
            canvas.drawPath(path, fillPaint);
            canvas.drawPath(path, borderPaint);
            rendered++;
          }
        }
      }
    } catch (e) {
      // Don't crash the game loop on projection errors.
    }
  }

  // ---------------------------------------------------------------------------
  // Köppen-Geiger climate colour classification
  // ---------------------------------------------------------------------------

  /// Determine land color based on Köppen-Geiger climate zone heuristics.
  static Color _getClimateColor(double lng, double lat) {
    final absLat = lat.abs();

    if (absLat > 75) return FlitColors.climateIceCap;
    if (absLat > 63) return FlitColors.climateTundra;
    if (absLat > 52) return FlitColors.climateBoreal;

    if (_isDesertRegion(lat, lng)) return FlitColors.climateHotDesert;
    if (_isSemiAridRegion(lat, lng)) return FlitColors.climateSemiArid;

    if (absLat > 30 && absLat < 45 && _isMediterraneanRegion(lat, lng)) {
      return FlitColors.climateMediterranean;
    }

    if (absLat > 35) return FlitColors.climateTemperate;
    if (absLat > 20) return FlitColors.climateHumidSubtropical;
    if (absLat > 10) return FlitColors.climateTropicalSavanna;

    return FlitColors.climateTropicalRain;
  }

  static bool _isDesertRegion(double lat, double lng) {
    final absLat = lat.abs();
    if (absLat < 12 || absLat > 38) return false;

    if (lat > 15 && lat < 35 && lng > -15 && lng < 35) return true;
    if (lat > 15 && lat < 32 && lng > 35 && lng < 60) return true;
    if (lat > 25 && lat < 40 && lng > 50 && lng < 70) return true;
    if (lat > 20 && lat < 30 && lng > 68 && lng < 76) return true;
    if (lat < -20 && lat > -32 && lng > 120 && lng < 145) return true;
    if (lat > 25 && lat < 35 && lng > -115 && lng < -105) return true;
    if (lat < -18 && lat > -30 && lng > -72 && lng < -68) return true;
    if (lat < -15 && lat > -30 && lng > 15 && lng < 25) return true;

    return false;
  }

  static bool _isSemiAridRegion(double lat, double lng) {
    final absLat = lat.abs();
    if (absLat < 10 || absLat > 45) return false;

    if (lat > 10 && lat < 15 && lng > -15 && lng < 40) return true;
    if (lat > 35 && lat < 50 && lng > 50 && lng < 90) return true;
    if (lat < -25 && lat > -45 && lng > -70 && lng < -60) return true;
    if (lat > 5 && lat < 15 && lng > 40 && lng < 52) return true;
    if (lat < -15 && lat > -25 && lng > 22 && lng < 35) return true;

    return false;
  }

  static bool _isMediterraneanRegion(double lat, double lng) {
    if (lat > 30 && lat < 45 && lng > -10 && lng < 40) return true;
    if (lat > 32 && lat < 40 && lng > -125 && lng < -115) return true;
    if (lat < -30 && lat > -38 && lng > -73 && lng < -70) return true;
    if (lat < -30 && lat > -37 && lng > 114 && lng < 120) return true;
    if (lat < -33 && lat > -35 && lng > 18 && lng < 20) return true;

    return false;
  }
}
