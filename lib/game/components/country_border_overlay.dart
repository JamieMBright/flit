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

    // Use all available vertices for crisp borders at every zoom level.
    // The polygon data is already in memory so there's no extra cost.
    // Visibility culling below prevents off-screen polygons from being drawn.

    final playerPos = gameRef.worldPosition;

    // Visibility radius in degrees — only render countries near the player
    // to avoid projecting the entire globe every frame.
    final visRadius = continuousAlt < 0.5 ? 50.0 : 100.0;

    final activeCountryName = gameRef.currentCountryName;

    // Composite all country outlines into a single path before drawing so
    // that shared borders between adjacent countries are not double-blended
    // (the stroke is semi-transparent, so overlapping draws produce visible
    // bright seams at every shared edge).
    final compositePath = ui.Path();

    for (final country in CountryData.countries) {
      // Skip the active country — it gets the red highlight instead.
      if (country.name == activeCountryName) continue;

      // Skip Antarctica — its polygon spans 360° of longitude and creates
      // visual wrapping artifacts near the south pole. The satellite texture
      // shows Antarctica clearly without a border overlay.
      if (country.code == 'AQ') continue;

      for (final polygon in country.polygons) {
        if (polygon.length < 3) continue;

        // Skip tiny polygons — they appear as small diamonds at globe scale.
        if (polygon.length < 6) continue;

        // Quick center-of-polygon check for visibility culling.
        final center = polygon[polygon.length ~/ 2];
        final dx = (center.x - playerPos.x).abs();
        final dy = (center.y - playerPos.y).abs();
        // Handle antimeridian wrapping.
        final dxWrapped = dx > 180 ? 360 - dx : dx;
        if (dxWrapped > visRadius || dy > visRadius) continue;

        final path = ui.Path();
        var started = false;
        var anyVisible = false;
        var hasOccluded = false;
        var lastX = 0.0;
        var lastY = 0.0;

        for (var i = 0; i < polygon.length; i++) {
          final screenPos = gameRef.worldToScreenGlobe(polygon[i]);

          // Occluded (far side of globe)
          if (screenPos.x < -500 || screenPos.y < -500) {
            started = false;
            hasOccluded = true;
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
            // Guard against huge screen-space jumps (antimeridian wrap or
            // vertices straddling the globe limb). Start a new sub-path
            // instead of drawing a line across the screen.
            final dx = screenPos.x - lastX;
            final dy = screenPos.y - lastY;
            if (dx * dx + dy * dy > screenW * screenW * 0.25) {
              path.moveTo(screenPos.x, screenPos.y);
              hasOccluded = true;
            } else {
              path.lineTo(screenPos.x, screenPos.y);
            }
          }
          lastX = screenPos.x;
          lastY = screenPos.y;
        }

        if (anyVisible) {
          if (!hasOccluded) {
            path.close();
          }
          compositePath.addPath(path, Offset.zero);
        }
      }
    }

    canvas.drawPath(compositePath, outlinePaint);
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

    // Skip Antarctica — its 360° polygon wraps visually near the south pole.
    if (activeCountry.code == 'AQ') return;

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

    for (final polygon in activeCountry.polygons) {
      if (polygon.length < 3) continue;

      final path = ui.Path();
      var started = false;
      var anyVisible = false;
      var hasOccluded = false;
      var lastX = 0.0;
      var lastY = 0.0;

      for (var i = 0; i < polygon.length; i++) {
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
          // Guard against huge screen-space jumps (antimeridian wrap).
          final dx = screenPos.x - lastX;
          final dy = screenPos.y - lastY;
          if (dx * dx + dy * dy > screenW * screenW * 0.25) {
            path.moveTo(screenPos.x, screenPos.y);
            hasOccluded = true;
          } else {
            path.lineTo(screenPos.x, screenPos.y);
          }
        }
        lastX = screenPos.x;
        lastY = screenPos.y;
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
