import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/services/error_service.dart';
import '../../core/utils/game_log.dart';
import '../flit_game.dart';
import '../map/country_data.dart';

/// Renders country border overlays on the shader globe:
/// - White country outlines (all countries, visible at altitude)
/// - Red flash highlight for the country the plane is currently in
class CountryBorderOverlay extends Component with HasGameRef<FlitGame> {
  @override
  void render(Canvas canvas) {
    super.render(canvas);

    try {
      if (!gameRef.isShaderActive || gameRef.isFlatMapMode) return;

      // In descent mode, OSM tiles provide borders — skip our overlay
      // to avoid parallax mismatch with the flat map projection.
      if (!gameRef.plane.isHighAltitude) return;

      final continuousAlt = gameRef.plane.continuousAltitude;
      final screenW = gameRef.size.x;
      final screenH = gameRef.size.y;

      // --- Country outlines (all countries, faint white) ---
      _renderAllCountryOutlines(canvas, continuousAlt, screenW, screenH);

      // --- Active country highlight (red flash) ---
      _renderActiveCountryHighlight(canvas, continuousAlt, screenW, screenH);

      // Sea labels and airport markers removed — caused visual artifacts
      // on the globe at high altitude.
    } catch (e, st) {
      final log = GameLog.instance;
      log.error(
        'border_overlay',
        'Country border rendering failed',
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
  // All country outlines — faint white borders on the globe surface
  // -----------------------------------------------------------------------

  void _renderAllCountryOutlines(
    Canvas canvas,
    double continuousAlt,
    double screenW,
    double screenH,
  ) {
    // Fade in with altitude — visible at high alt, invisible at ground level.
    // Ramps up from 0 at ground to 0.35 at cruise altitude and stays there.
    final opacity = (0.35 * (continuousAlt / 0.6)).clamp(0.0, 0.35);
    if (opacity < 0.02) return;

    final outlinePaint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    // Point budget per polygon — use all available points for accurate borders.
    const maxPointsPerPoly = kIsWeb ? 200 : 400;

    final playerPos = gameRef.worldPosition;

    // Visibility radius in degrees — only render countries near the player
    // to avoid projecting the entire globe every frame.
    final visRadius = continuousAlt < 0.5 ? 50.0 : 100.0;

    final activeCountryName = gameRef.currentCountryName;

    for (final country in CountryData.countries) {
      // Skip the active country — it gets the red highlight instead.
      if (country.name == activeCountryName) continue;

      for (final polygon in country.polygons) {
        if (polygon.length < 3) continue;

        // Quick center-of-polygon check for visibility culling.
        final center = polygon[polygon.length ~/ 2];
        final dx = (center.x - playerPos.x).abs();
        final dy = (center.y - playerPos.y).abs();
        // Handle antimeridian wrapping.
        final dxWrapped = dx > 180 ? 360 - dx : dx;
        if (dxWrapped > visRadius || dy > visRadius) continue;

        // Skip tiny polygons (small islands) that add visual noise.
        // At high altitude, only show polygons spanning > 1° in any axis.
        // At medium altitude, show polygons > 0.3°.
        final minSpan = continuousAlt > 0.6 ? 1.0 : 0.3;
        if (polygon.length < 20) {
          var pMinX = polygon[0].x, pMaxX = polygon[0].x;
          var pMinY = polygon[0].y, pMaxY = polygon[0].y;
          for (var j = 1; j < polygon.length; j++) {
            final v = polygon[j];
            if (v.x < pMinX) pMinX = v.x;
            if (v.x > pMaxX) pMaxX = v.x;
            if (v.y < pMinY) pMinY = v.y;
            if (v.y > pMaxY) pMaxY = v.y;
          }
          if ((pMaxX - pMinX) < minSpan && (pMaxY - pMinY) < minSpan) continue;
        }

        final stride = polygon.length > maxPointsPerPoly
            ? (polygon.length / maxPointsPerPoly).ceil()
            : 1;

        final path = ui.Path();
        var started = false;
        var anyVisible = false;

        for (var i = 0; i < polygon.length; i += stride) {
          final screenPos = gameRef.worldToScreenGlobe(polygon[i]);

          // Occluded (far side of globe)
          if (screenPos.x < -500 || screenPos.y < -500) {
            started = false;
            continue;
          }

          if (screenPos.x > -50 &&
              screenPos.x < screenW + 50 &&
              screenPos.y > -50 &&
              screenPos.y < screenH + 50) {
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
          canvas.drawPath(path, outlinePaint);
        }
      }
    }
  }

  // -----------------------------------------------------------------------
  // Active country highlight — red flash when plane enters a country
  // -----------------------------------------------------------------------

  void _renderActiveCountryHighlight(
    Canvas canvas,
    double continuousAlt,
    double screenW,
    double screenH,
  ) {
    final activeCountryName = gameRef.currentCountryName;
    if (activeCountryName == null) return;

    // Find the active country.
    CountryShape? activeCountry;
    for (final country in CountryData.countries) {
      if (country.name == activeCountryName) {
        activeCountry = country;
        break;
      }
    }
    if (activeCountry == null) return;

    final borderOpacity = (0.6 * (continuousAlt / 0.6)).clamp(0.0, 0.6);

    if (borderOpacity < 0.01) return;

    // Red highlight for the active country border.
    final highlightPaint = Paint()
      ..color = const Color(
        0xFFFF3333,
      ).withOpacity((borderOpacity * 1.0).clamp(0.4, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = continuousAlt >= 0.6 ? 2.0 : 2.5
      ..strokeJoin = StrokeJoin.round;

    // Higher point budget for the active highlight — needs to look crisp.
    const maxPointsPerPoly = kIsWeb ? 300 : 600;

    for (final polygon in activeCountry.polygons) {
      if (polygon.length < 3) continue;

      // Skip tiny polygons (small islands) at high altitude.
      final minSpan = continuousAlt > 0.6 ? 1.0 : 0.3;
      if (polygon.length < 20) {
        var pMinX = polygon[0].x, pMaxX = polygon[0].x;
        var pMinY = polygon[0].y, pMaxY = polygon[0].y;
        for (var j = 1; j < polygon.length; j++) {
          final v = polygon[j];
          if (v.x < pMinX) pMinX = v.x;
          if (v.x > pMaxX) pMaxX = v.x;
          if (v.y < pMinY) pMinY = v.y;
          if (v.y > pMaxY) pMaxY = v.y;
        }
        if ((pMaxX - pMinX) < minSpan && (pMaxY - pMinY) < minSpan) continue;
      }

      final stride = polygon.length > maxPointsPerPoly
          ? (polygon.length / maxPointsPerPoly).ceil()
          : 1;

      final path = ui.Path();
      var started = false;
      var anyVisible = false;
      var hasOccluded = false;

      for (var i = 0; i < polygon.length; i += stride) {
        final screenPos = gameRef.worldToScreenGlobe(polygon[i]);

        if (screenPos.x < -500 || screenPos.y < -500) {
          started = false;
          hasOccluded = true;
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

      if (anyVisible) {
        if (!hasOccluded) {
          path.close();
        }
        canvas.drawPath(path, highlightPaint);
      }
    }
  }
}
