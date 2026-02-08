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
///
/// Rendering budget scales with altitude to prevent canvas overload on iOS
/// Safari, where large filled paths at low altitude kill the web worker.
class CountryBorderOverlay extends Component with HasGameRef<FlitGame> {
  @override
  void render(Canvas canvas) {
    super.render(canvas);

    try {
      if (!gameRef.isShaderActive) return;

      final continuousAlt = gameRef.plane.continuousAltitude;

      // --- Altitude-adaptive rendering budget ---
      // At low altitude polygons are huge on screen, so we must draw fewer
      // with heavy decimation. At high altitude they are small and cheap.
      final int maxCountries;
      final int maxTotalPoints;
      final int maxPointsPerPoly;
      final bool drawFills;

      if (kIsWeb) {
        if (continuousAlt < 0.3) {
          // Very low altitude: borders only, minimal countries
          maxCountries = 4;
          maxTotalPoints = 400;
          maxPointsPerPoly = 15;
          drawFills = false;
        } else if (continuousAlt < 0.6) {
          // Mid altitude
          maxCountries = 8;
          maxTotalPoints = 800;
          maxPointsPerPoly = 20;
          drawFills = true;
        } else {
          // High altitude
          maxCountries = 12;
          maxTotalPoints = 1200;
          maxPointsPerPoly = 30;
          drawFills = true;
        }
      } else {
        if (continuousAlt < 0.3) {
          maxCountries = 15;
          maxTotalPoints = 2000;
          maxPointsPerPoly = 40;
          drawFills = true;
        } else if (continuousAlt < 0.6) {
          maxCountries = 30;
          maxTotalPoints = 4000;
          maxPointsPerPoly = 50;
          drawFills = true;
        } else {
          maxCountries = 40;
          maxTotalPoints = 6000;
          maxPointsPerPoly = 60;
          drawFills = true;
        }
      }

      // Climate fill opacity — visible at all altitudes, stronger at low alt.
      final fillOpacity = !drawFills
          ? 0.0
          : continuousAlt >= 0.6
              ? (0.30 * (1.0 - (continuousAlt - 0.6) / 0.4)).clamp(0.0, 0.30)
              : (0.30 + 0.20 * (1.0 - continuousAlt / 0.6)).clamp(0.0, 0.50);

      // Border stroke opacity.
      final borderOpacity = continuousAlt >= 0.6
          ? (0.4 * (1.0 - (continuousAlt - 0.6) / 0.4)).clamp(0.0, 0.4)
          : (0.5 + 0.5 * (1.0 - continuousAlt / 0.6)).clamp(0.0, 1.0);

      if (fillOpacity < 0.01 && borderOpacity < 0.01) return;

      final borderPaint = Paint()
        ..color = FlitColors.border.withOpacity(borderOpacity * 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = continuousAlt >= 0.6 ? 0.6 : 1.0
        ..strokeJoin = StrokeJoin.round;

      final screenW = gameRef.size.x;
      final screenH = gameRef.size.y;

      // Sort countries by distance from player for priority rendering.
      final playerPos = gameRef.worldPosition;
      final scored =
          <({double dist, CountryShape country, double cLng, double cLat})>[];

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
        scored.add((
          dist: dx * dx + dy * dy,
          country: country,
          cLng: cLng,
          cLat: cLat,
        ));
      }

      scored.sort((a, b) => a.dist.compareTo(b.dist));

      var rendered = 0;
      var totalPoints = 0;

      for (final entry in scored) {
        if (rendered >= maxCountries) break;
        if (totalPoints >= maxTotalPoints) break;

        final Paint? fillPaint;
        if (drawFills && fillOpacity > 0.01) {
          final climateColor = _getClimateColor(entry.cLng, entry.cLat);
          fillPaint = Paint()..color = climateColor.withOpacity(fillOpacity);
        } else {
          fillPaint = null;
        }

        for (final polygon in entry.country.polygons) {
          if (polygon.length < 3) continue;
          if (totalPoints >= maxTotalPoints) break;

          // Decimate large polygons to keep path complexity manageable.
          final stride = polygon.length > maxPointsPerPoly
              ? (polygon.length / maxPointsPerPoly).ceil()
              : 1;

          final path = ui.Path();
          var started = false;
          var anyVisible = false;
          var pointsInPath = 0;

          for (var i = 0; i < polygon.length; i += stride) {
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
            pointsInPath++;
          }

          totalPoints += pointsInPath;

          if (anyVisible && started) {
            path.close();
            if (fillPaint != null) {
              canvas.drawPath(path, fillPaint);
            }
            canvas.drawPath(path, borderPaint);
            rendered++;
          }
        }
      }
    } catch (e, st) {
      // Log errors instead of swallowing silently.
      try {
        gameRef.onError?.call(e, st);
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // Köppen-Geiger climate colour classification
  // ---------------------------------------------------------------------------

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
