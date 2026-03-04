import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/services/error_service.dart';
import '../../core/theme/flit_colors.dart';
import '../../core/utils/game_log.dart';
import '../data/osm_features.dart';
import '../flit_game.dart';
import '../map/country_data.dart';

/// Renders geographic feature overlays on the shader globe:
/// - Faint white country outlines (all countries, always visible)
/// - Red flash highlight for the country the plane is currently in
/// - Sea/ocean labels
/// - Airports (dot markers with IATA codes)
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

      // --- Geographic feature overlays ---
      _renderSeaLabels(canvas, continuousAlt, screenW, screenH);
      _renderAirports(canvas, continuousAlt, screenW, screenH);
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
    // Fade in with altitude — subtle at high alt, invisible at ground level.
    final opacity = continuousAlt >= 0.6
        ? (0.25 * (1.0 - (continuousAlt - 0.6) / 0.4)).clamp(0.05, 0.25)
        : (0.25 * (continuousAlt / 0.6)).clamp(0.0, 0.25);
    if (opacity < 0.02) return;

    final outlinePaint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    // Point budget per polygon — higher than active highlight since outlines
    // are thinner and more forgiving of slight imprecision.
    const maxPointsPerPoly = kIsWeb ? 60 : 120;

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

    final borderOpacity = continuousAlt >= 0.6
        ? (0.5 * (1.0 - (continuousAlt - 0.6) / 0.4)).clamp(0.15, 0.5)
        : (0.5 + 0.5 * (1.0 - continuousAlt / 0.6)).clamp(0.0, 1.0);

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
    const maxPointsPerPoly = kIsWeb ? 100 : 200;

    for (final polygon in activeCountry.polygons) {
      if (polygon.length < 3) continue;

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

  // -----------------------------------------------------------------------
  // Sea/Ocean labels — text labels at ocean centers
  // -----------------------------------------------------------------------

  static final Map<String, TextPainter> _seaLabelCache = {};

  /// Tracks the last opacity value used to build each cached TextPainter so
  /// we only re-layout when opacity changes by more than 1/255 (one alpha step).
  static final Map<String, double> _seaLabelOpacityCache = {};

  void _renderSeaLabels(
    Canvas canvas,
    double alt,
    double screenW,
    double screenH,
  ) {
    // Only show at high altitude
    if (alt < 0.6) return;

    final opacity = ((alt - 0.6) * 2.0).clamp(0.0, 0.3);
    if (opacity < 0.05) return;

    final playerPos = gameRef.worldPosition;

    for (final sea in OsmFeatures.seas) {
      if ((sea.center.x - playerPos.x).abs() > 90 ||
          (sea.center.y - playerPos.y).abs() > 90)
        continue;

      final screenPos = gameRef.worldToScreenGlobe(sea.center);
      if (screenPos.x < -500 || screenPos.y < -500) continue;
      if (screenPos.x < 0 ||
          screenPos.x > screenW ||
          screenPos.y < 0 ||
          screenPos.y > screenH)
        continue;

      // Build a new TextPainter only on first use or when opacity changes
      // by more than one alpha step (1/255 ≈ 0.004). This avoids rebuilding
      // the painter every frame while still reflecting fade transitions.
      final cachedOpacity = _seaLabelOpacityCache[sea.name];
      final needsRebuild =
          cachedOpacity == null || (cachedOpacity - opacity).abs() > 0.004;

      if (needsRebuild) {
        final tp = TextPainter(
          text: TextSpan(
            text: sea.name.toUpperCase(),
            style: TextStyle(
              color: const Color(0xFF88AACC).withOpacity(opacity),
              fontSize: 9,
              fontWeight: FontWeight.w300,
              letterSpacing: 2.0,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        _seaLabelCache[sea.name] = tp;
        _seaLabelOpacityCache[sea.name] = opacity;
      }

      final painter = _seaLabelCache[sea.name]!;

      painter.paint(
        canvas,
        Offset(
          screenPos.x - painter.width / 2,
          screenPos.y - painter.height / 2,
        ),
      );
    }
  }

  // -----------------------------------------------------------------------
  // Airports — dot markers with IATA code labels
  // -----------------------------------------------------------------------

  static final Map<String, TextPainter> _airportLabelCache = {};

  void _renderAirports(
    Canvas canvas,
    double alt,
    double screenW,
    double screenH,
  ) {
    // Airports visible at mid altitude
    if (alt < 0.3 || alt > 0.8) return;

    final opacity = alt < 0.5
        ? ((alt - 0.3) * 2.5).clamp(0.0, 0.5)
        : ((0.8 - alt) * 2.5).clamp(0.0, 0.5);
    if (opacity < 0.05) return;

    final dotPaint = Paint()
      ..color = const Color(0xFFEEEEEE).withOpacity(opacity)
      ..style = PaintingStyle.fill;

    final playerPos = gameRef.worldPosition;
    const visRadius = 50.0;
    const maxAirports = kIsWeb ? 6 : 12;
    var drawn = 0;

    for (final airport in OsmFeatures.airports) {
      if (drawn >= maxAirports) break;
      if ((airport.location.x - playerPos.x).abs() > visRadius ||
          (airport.location.y - playerPos.y).abs() > visRadius)
        continue;

      final screenPos = gameRef.worldToScreenGlobe(airport.location);
      if (screenPos.x < -500 || screenPos.y < -500) continue;
      if (screenPos.x < 0 ||
          screenPos.x > screenW ||
          screenPos.y < 0 ||
          screenPos.y > screenH)
        continue;

      // Small dot
      canvas.drawCircle(Offset(screenPos.x, screenPos.y), 2.0, dotPaint);

      // IATA code label
      final painter = _airportLabelCache.putIfAbsent(airport.iataCode, () {
        return TextPainter(
          text: TextSpan(
            text: airport.iataCode,
            style: TextStyle(
              color: const Color(0xFFCCCCCC).withOpacity(opacity),
              fontSize: 7,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
      });

      painter.text = TextSpan(
        text: airport.iataCode,
        style: TextStyle(
          color: const Color(0xFFCCCCCC).withOpacity(opacity),
          fontSize: 7,
          fontWeight: FontWeight.w500,
        ),
      );
      painter.layout();

      painter.paint(
        canvas,
        Offset(screenPos.x + 4, screenPos.y - painter.height / 2),
      );
      drawn++;
    }
  }
}
