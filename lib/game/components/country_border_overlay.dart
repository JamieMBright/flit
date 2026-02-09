import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/services/error_service.dart';
import '../../core/theme/flit_colors.dart';
import '../../core/utils/game_log.dart';
import '../flit_game.dart';
import '../map/country_data.dart';

/// Renders a grid-based climate base layer, country border outlines, and
/// highlights the country the plane is currently flying over.
///
/// The climate layer uses a lat/lng grid with Köppen-Geiger classification
/// at each cell centre — completely independent of country polygons.
/// Country borders are drawn as strokes on top. The active country
/// (where the plane is) gets a brighter, thicker border.
///
/// Rendering budget scales with altitude to prevent canvas overload on iOS
/// Safari, where large paths at low altitude kill the web worker.
class CountryBorderOverlay extends Component with HasGameRef<FlitGame> {
  @override
  void render(Canvas canvas) {
    super.render(canvas);

    try {
      if (!gameRef.isShaderActive) return;

      final continuousAlt = gameRef.plane.continuousAltitude;
      final screenW = gameRef.size.x;
      final screenH = gameRef.size.y;

      // --- 1. Climate grid base layer ---
      _renderClimateGrid(canvas, continuousAlt, screenW, screenH);

      // --- 2. Country borders + active highlight ---
      _renderCountryBorders(canvas, continuousAlt, screenW, screenH);
    } catch (e, st) {
      final log = GameLog.instance;
      log.error('border_overlay', 'Country border rendering failed',
        error: e,
        stackTrace: st,
        data: {
          'altitude': gameRef.plane.continuousAltitude.toStringAsFixed(2),
          'platform': kIsWeb ? 'web' : 'native',
        },
      );
      ErrorService.instance.reportCritical(
        e,
        st,
        context: {
          'source': 'CountryBorderOverlay.render',
          'altitude': gameRef.plane.continuousAltitude.toString(),
          'isWeb': kIsWeb.toString(),
        },
      );
      try {
        gameRef.onError?.call(e, st);
      } catch (_) {}
    }
  }

  // -----------------------------------------------------------------------
  // Climate grid — KG classification on a lat/lng grid, drawn as quads
  // -----------------------------------------------------------------------

  void _renderClimateGrid(
    Canvas canvas,
    double alt,
    double screenW,
    double screenH,
  ) {
    // Grid resolution adapts to altitude:
    // High altitude → coarse grid (10°), low → finer (5°).
    // On web, use coarser grids to keep within canvas budget.
    final double cellSize;
    final int maxCells;
    if (kIsWeb) {
      cellSize = 10.0;
      maxCells = alt < 0.4 ? 60 : 120;
    } else {
      cellSize = alt < 0.4 ? 5.0 : 10.0;
      maxCells = alt < 0.4 ? 100 : 200;
    }

    // Climate fill opacity — subtle tint over satellite texture.
    final fillOpacity = alt >= 0.6
        ? (0.18 * (1.0 - (alt - 0.6) / 0.4)).clamp(0.04, 0.18)
        : (0.18 + 0.12 * (1.0 - alt / 0.6)).clamp(0.0, 0.30);
    if (fillOpacity < 0.02) return;

    // Determine visible lat/lng range from camera position.
    final playerPos = gameRef.worldPosition;
    final visRadius = alt < 0.3 ? 30.0 : alt < 0.6 ? 60.0 : 90.0;
    final minLat = (playerPos.y - visRadius).clamp(-90.0, 90.0);
    final maxLat = (playerPos.y + visRadius).clamp(-90.0, 90.0);
    final minLng = playerPos.x - visRadius;
    final maxLng = playerPos.x + visRadius;

    // Snap to grid.
    final startLat = (minLat / cellSize).floor() * cellSize;
    final startLng = (minLng / cellSize).floor() * cellSize;

    var cells = 0;
    for (var lat = startLat; lat < maxLat; lat += cellSize) {
      for (var lng = startLng; lng < maxLng; lng += cellSize) {
        if (cells >= maxCells) break;

        // Normalise longitude to [-180, 180] for classification.
        var nLng = lng;
        while (nLng > 180) nLng -= 360;
        while (nLng < -180) nLng += 360;

        // Cell centre for climate classification.
        final cLat = lat + cellSize * 0.5;
        final cLng = nLng + cellSize * 0.5;

        final color = _getClimateColor(cLng, cLat);

        // Project corner points to screen.
        final tl = gameRef.worldToScreen(Vector2(lng, lat + cellSize));
        final tr = gameRef.worldToScreen(Vector2(lng + cellSize, lat + cellSize));
        final br = gameRef.worldToScreen(Vector2(lng + cellSize, lat));
        final bl = gameRef.worldToScreen(Vector2(lng, lat));

        // Skip cells behind camera.
        if (tl.x < -500 || tr.x < -500 || br.x < -500 || bl.x < -500) {
          continue;
        }

        // Skip cells entirely off-screen.
        final allLeft = tl.x < -50 && tr.x < -50 && br.x < -50 && bl.x < -50;
        final allRight = tl.x > screenW + 50 &&
            tr.x > screenW + 50 &&
            br.x > screenW + 50 &&
            bl.x > screenW + 50;
        final allTop = tl.y < -50 && tr.y < -50 && br.y < -50 && bl.y < -50;
        final allBottom = tl.y > screenH + 50 &&
            tr.y > screenH + 50 &&
            br.y > screenH + 50 &&
            bl.y > screenH + 50;
        if (allLeft || allRight || allTop || allBottom) continue;

        // Draw filled quad.
        final path = ui.Path()
          ..moveTo(tl.x, tl.y)
          ..lineTo(tr.x, tr.y)
          ..lineTo(br.x, br.y)
          ..lineTo(bl.x, bl.y)
          ..close();

        canvas.drawPath(
          path,
          Paint()..color = color.withOpacity(fillOpacity),
        );

        cells++;
      }
      if (cells >= maxCells) break;
    }
  }

  // -----------------------------------------------------------------------
  // Country borders + active country highlight
  // -----------------------------------------------------------------------

  void _renderCountryBorders(
    Canvas canvas,
    double continuousAlt,
    double screenW,
    double screenH,
  ) {
    final int maxCountries;
    final int maxTotalPoints;
    final int maxPointsPerPoly;

    if (kIsWeb) {
      if (continuousAlt < 0.3) {
        maxCountries = 4;
        maxTotalPoints = 400;
        maxPointsPerPoly = 15;
      } else if (continuousAlt < 0.6) {
        maxCountries = 8;
        maxTotalPoints = 800;
        maxPointsPerPoly = 20;
      } else {
        maxCountries = 12;
        maxTotalPoints = 1200;
        maxPointsPerPoly = 30;
      }
    } else {
      if (continuousAlt < 0.3) {
        maxCountries = 15;
        maxTotalPoints = 2000;
        maxPointsPerPoly = 40;
      } else if (continuousAlt < 0.6) {
        maxCountries = 30;
        maxTotalPoints = 4000;
        maxPointsPerPoly = 50;
      } else {
        maxCountries = 40;
        maxTotalPoints = 6000;
        maxPointsPerPoly = 60;
      }
    }

    final borderOpacity = continuousAlt >= 0.6
        ? (0.5 * (1.0 - (continuousAlt - 0.6) / 0.4)).clamp(0.15, 0.5)
        : (0.5 + 0.5 * (1.0 - continuousAlt / 0.6)).clamp(0.0, 1.0);

    if (borderOpacity < 0.01) return;

    final borderPaint = Paint()
      ..color = FlitColors.border.withOpacity(borderOpacity * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = continuousAlt >= 0.6 ? 0.6 : 1.0
      ..strokeJoin = StrokeJoin.round;

    // Active country highlight: thicker, brighter border.
    final activeCountryName = gameRef.currentCountryName;
    final highlightPaint = Paint()
      ..color = FlitColors.accent.withOpacity(
          (borderOpacity * 0.9).clamp(0.3, 0.9))
      ..style = PaintingStyle.stroke
      ..strokeWidth = continuousAlt >= 0.6 ? 1.5 : 2.5
      ..strokeJoin = StrokeJoin.round;

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

      final isActive = activeCountryName != null &&
          entry.country.name == activeCountryName;
      final paint = isActive ? highlightPaint : borderPaint;

      for (final polygon in entry.country.polygons) {
        if (polygon.length < 3) continue;
        if (totalPoints >= maxTotalPoints) break;

        final stride = polygon.length > maxPointsPerPoly
            ? (polygon.length / maxPointsPerPoly).ceil()
            : 1;

        final path = ui.Path();
        var started = false;
        var anyVisible = false;
        var pointsInPath = 0;

        for (var i = 0; i < polygon.length; i += stride) {
          final screenPos = gameRef.worldToScreen(polygon[i]);

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
          canvas.drawPath(path, paint);
          rendered++;
        }
      }
    }
  }

  // -----------------------------------------------------------------------
  // Köppen-Geiger climate classification (geography-based, not polygon-based)
  // -----------------------------------------------------------------------

  static Color _getClimateColor(double lng, double lat) {
    final absLat = lat.abs();

    // Polar / ice
    if (absLat > 75) return FlitColors.climateIceCap;
    if (absLat > 63) return FlitColors.climateTundra;
    if (absLat > 52) return FlitColors.climateBoreal;

    // Arid — specific desert regions
    if (_isDesertRegion(lat, lng)) return FlitColors.climateHotDesert;
    if (_isSemiAridRegion(lat, lng)) return FlitColors.climateSemiArid;

    // Mediterranean
    if (absLat > 30 && absLat < 45 && _isMediterraneanRegion(lat, lng)) {
      return FlitColors.climateMediterranean;
    }

    // Temperate / subtropical / tropical bands
    if (absLat > 35) return FlitColors.climateTemperate;
    if (absLat > 20) return FlitColors.climateHumidSubtropical;
    if (absLat > 10) return FlitColors.climateTropicalSavanna;

    return FlitColors.climateTropicalRain;
  }

  static bool _isDesertRegion(double lat, double lng) {
    final absLat = lat.abs();
    if (absLat < 12 || absLat > 38) return false;
    // Sahara / Arabian
    if (lat > 15 && lat < 35 && lng > -15 && lng < 35) return true;
    if (lat > 15 && lat < 32 && lng > 35 && lng < 60) return true;
    // Central Asian / Iranian
    if (lat > 25 && lat < 40 && lng > 50 && lng < 70) return true;
    // Thar
    if (lat > 20 && lat < 30 && lng > 68 && lng < 76) return true;
    // Australian
    if (lat < -20 && lat > -32 && lng > 120 && lng < 145) return true;
    // Sonoran / Chihuahuan
    if (lat > 25 && lat < 35 && lng > -115 && lng < -105) return true;
    // Atacama
    if (lat < -18 && lat > -30 && lng > -72 && lng < -68) return true;
    // Namib / Kalahari
    if (lat < -15 && lat > -30 && lng > 15 && lng < 25) return true;
    return false;
  }

  static bool _isSemiAridRegion(double lat, double lng) {
    final absLat = lat.abs();
    if (absLat < 10 || absLat > 45) return false;
    // Sahel
    if (lat > 10 && lat < 15 && lng > -15 && lng < 40) return true;
    // Central Asian steppe
    if (lat > 35 && lat < 50 && lng > 50 && lng < 90) return true;
    // Patagonian steppe
    if (lat < -25 && lat > -45 && lng > -70 && lng < -60) return true;
    // Horn of Africa
    if (lat > 5 && lat < 15 && lng > 40 && lng < 52) return true;
    // Southern African plateau
    if (lat < -15 && lat > -25 && lng > 22 && lng < 35) return true;
    return false;
  }

  static bool _isMediterraneanRegion(double lat, double lng) {
    // Mediterranean basin
    if (lat > 30 && lat < 45 && lng > -10 && lng < 40) return true;
    // California
    if (lat > 32 && lat < 40 && lng > -125 && lng < -115) return true;
    // Central Chile
    if (lat < -30 && lat > -38 && lng > -73 && lng < -70) return true;
    // SW Australia
    if (lat < -30 && lat > -37 && lng > 114 && lng < 120) return true;
    // Cape Town
    if (lat < -33 && lat > -35 && lng > 18 && lng < 20) return true;
    return false;
  }
}
