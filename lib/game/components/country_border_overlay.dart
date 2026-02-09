import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/services/error_service.dart';
import '../../core/theme/flit_colors.dart';
import '../../core/utils/game_log.dart';
import '../flit_game.dart';
import '../map/country_data.dart';

/// Renders country border outlines when the shader renderer is active.
///
/// The shader renders a satellite-textured globe but cannot draw vector data.
/// This overlay projects [CountryData.countries] polygons onto the screen
/// as border strokes only — the satellite texture provides all the visual
/// geographic context, so no climate fills are needed.
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

      // --- Altitude-adaptive rendering budget ---
      // At low altitude polygons are huge on screen, so we must draw fewer
      // with heavy decimation. At high altitude they are small and cheap.
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

      // Border stroke opacity - maintain minimum visibility at high altitude.
      final borderOpacity = continuousAlt >= 0.6
          ? (0.5 * (1.0 - (continuousAlt - 0.6) / 0.4)).clamp(0.15, 0.5)
          : (0.5 + 0.5 * (1.0 - continuousAlt / 0.6)).clamp(0.0, 1.0);

      if (borderOpacity < 0.01) return;

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
            canvas.drawPath(path, borderPaint);
            rendered++;
          }
        }
      }
    } catch (e, st) {
      // Report errors to telemetry for iOS Safari debugging.
      final log = GameLog.instance;
      log.error('border_overlay', 'Country border rendering failed',
        error: e,
        stackTrace: st,
        data: {
          'altitude': gameRef.plane.continuousAltitude.toStringAsFixed(2),
          'platform': kIsWeb ? 'web' : 'native',
        },
      );

      // Report as critical for iOS to ensure immediate flush.
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
}
