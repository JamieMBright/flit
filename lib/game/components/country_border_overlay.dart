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

    // Per-country vertex budget — distributed proportionally to polygon size
    // so larger landmasses get more detail than tiny islands.
    // Large countries (Canada, Russia, USA) need higher budgets because their
    // mainland polygon competes with hundreds of island polygons.
    const countryBudget = kIsWeb ? 1600 : 3200;
    const minCountryBudget = 50;
    // Minimum vertices for the largest polygon in each country — ensures
    // mainland coastlines always look smooth regardless of island count.
    const minMainlandBudget = kIsWeb ? 600 : 1200;

    final playerPos = gameRef.worldPosition;

    // Visibility radius in degrees — only render countries near the player
    // to avoid projecting the entire globe every frame.
    final visRadius = continuousAlt < 0.5 ? 50.0 : 100.0;

    final activeCountryName = gameRef.currentCountryName;

    for (final country in CountryData.countries) {
      // Skip the active country — it gets the red highlight instead.
      if (country.name == activeCountryName) continue;

      // Skip Antarctica — its polygon spans 360° of longitude and creates
      // visual wrapping artifacts near the south pole. The satellite texture
      // shows Antarctica clearly without a border overlay.
      if (country.code == 'AQ') continue;

      // Compute total vertices across all polygons for proportional allocation.
      var totalVerts = 0;
      for (final polygon in country.polygons) {
        totalVerts += polygon.length;
      }
      final budget = totalVerts < minCountryBudget
          ? totalVerts
          : countryBudget.clamp(minCountryBudget, totalVerts);

      // Find the largest polygon (mainland) so we can guarantee it a minimum.
      var maxPolyLen = 0;
      for (final polygon in country.polygons) {
        if (polygon.length > maxPolyLen) maxPolyLen = polygon.length;
      }

      for (final polygon in country.polygons) {
        if (polygon.length < 3) continue;

        // Skip tiny polygons — they appear as small diamonds at globe scale
        // and waste vertex budget.
        if (polygon.length < 6) continue;

        // Quick center-of-polygon check for visibility culling.
        final center = polygon[polygon.length ~/ 2];
        final dx = (center.x - playerPos.x).abs();
        final dy = (center.y - playerPos.y).abs();
        // Handle antimeridian wrapping.
        final dxWrapped = dx > 180 ? 360 - dx : dx;
        if (dxWrapped > visRadius || dy > visRadius) continue;

        // Allocate vertices proportionally to polygon size.
        // Larger polygons (mainland) get more points than tiny islands.
        var polyBudget = (budget * polygon.length / totalVerts).ceil().clamp(
              3,
              polygon.length,
            );
        // Guarantee the largest polygon (mainland) a minimum vertex count
        // so countries with many islands still get smooth mainland outlines.
        if (polygon.length == maxPolyLen && polyBudget < minMainlandBudget) {
          polyBudget = minMainlandBudget.clamp(3, polygon.length);
        }
        final stride = polygon.length > polyBudget
            ? (polygon.length / polyBudget).ceil()
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

    // Per-country vertex budget for active highlight — higher for crisp look.
    const activeBudget = kIsWeb ? 2400 : 4800;
    const minActiveBudget = 50;
    const minActiveMainland = kIsWeb ? 800 : 1600;
    var activeTotalVerts = 0;
    for (final polygon in activeCountry.polygons) {
      activeTotalVerts += polygon.length;
    }
    final aBudget = activeTotalVerts < minActiveBudget
        ? activeTotalVerts
        : activeBudget.clamp(minActiveBudget, activeTotalVerts);

    // Find largest polygon for mainland minimum guarantee.
    var activeMaxPolyLen = 0;
    for (final polygon in activeCountry.polygons) {
      if (polygon.length > activeMaxPolyLen) activeMaxPolyLen = polygon.length;
    }

    for (final polygon in activeCountry.polygons) {
      if (polygon.length < 3) continue;

      // Skip very tiny polygons — not useful even for the active highlight.
      if (polygon.length < 4) continue;

      // Allocate vertices proportionally — larger polygons get more detail.
      var polyBudget = (aBudget * polygon.length / activeTotalVerts)
          .ceil()
          .clamp(3, polygon.length);
      // Guarantee mainland polygon a minimum so it's always crisp.
      if (polygon.length == activeMaxPolyLen &&
          polyBudget < minActiveMainland) {
        polyBudget = minActiveMainland.clamp(3, polygon.length);
      }
      final stride = polygon.length > polyBudget
          ? (polygon.length / polyBudget).ceil()
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
