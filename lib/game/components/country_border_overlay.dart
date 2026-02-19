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

/// Renders geographic feature overlays and highlights the country the plane
/// is currently flying over at high altitude.
///
/// Features rendered (from OSM / public domain data):
/// - Major rivers (simplified polylines)
/// - Major lakes (filled circles)
/// - Mountain peaks (triangle markers)
/// - Airports (dot markers with IATA codes)
/// - Sea/ocean labels
/// - Volcanoes (diamond markers)
/// - Active country border highlight
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

      // --- Geographic feature overlays ---
      _renderRivers(canvas, continuousAlt, screenW, screenH);
      _renderLakes(canvas, continuousAlt, screenW, screenH);
      _renderSeaLabels(canvas, continuousAlt, screenW, screenH);
      _renderMountains(canvas, continuousAlt, screenW, screenH);
      _renderVolcanoes(canvas, continuousAlt, screenW, screenH);
      _renderAirports(canvas, continuousAlt, screenW, screenH);

      // --- Active country highlight ---
      _renderCountryBorders(canvas, continuousAlt, screenW, screenH);
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
  // Rivers — simplified polylines of major world rivers
  // -----------------------------------------------------------------------

  void _renderRivers(
    Canvas canvas,
    double alt,
    double screenW,
    double screenH,
  ) {
    // Rivers visible at mid-to-high altitude
    final opacity = (alt * 0.6).clamp(0.0, 0.5);
    if (opacity < 0.05) return;

    final paint = Paint()
      ..color = const Color(0xFF4488CC).withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = alt > 0.7 ? 1.0 : 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final playerPos = gameRef.worldPosition;
    final visRadius = alt < 0.5 ? 40.0 : 90.0;

    for (final river in OsmFeatures.rivers) {
      // Quick bounding check — skip rivers far from camera
      var anyNear = false;
      for (final pt in river.points) {
        if ((pt.x - playerPos.x).abs() < visRadius &&
            (pt.y - playerPos.y).abs() < visRadius) {
          anyNear = true;
          break;
        }
      }
      if (!anyNear) continue;

      final path = ui.Path();
      var started = false;

      for (final pt in river.points) {
        final screenPos = gameRef.worldToScreenGlobe(pt);
        if (screenPos.x < -500 || screenPos.y < -500) {
          started = false;
          continue;
        }
        if (!started) {
          path.moveTo(screenPos.x, screenPos.y);
          started = true;
        } else {
          path.lineTo(screenPos.x, screenPos.y);
        }
      }

      canvas.drawPath(path, paint);
    }
  }

  // -----------------------------------------------------------------------
  // Lakes — filled circles at lake centers
  // -----------------------------------------------------------------------

  void _renderLakes(Canvas canvas, double alt, double screenW, double screenH) {
    final opacity = (alt * 0.5).clamp(0.0, 0.4);
    if (opacity < 0.05) return;

    final fillPaint = Paint()
      ..color = const Color(0xFF3366AA).withOpacity(opacity)
      ..style = PaintingStyle.fill;

    final playerPos = gameRef.worldPosition;
    final visRadius = alt < 0.5 ? 40.0 : 90.0;

    for (final lake in OsmFeatures.lakes) {
      if ((lake.center.x - playerPos.x).abs() > visRadius ||
          (lake.center.y - playerPos.y).abs() > visRadius) continue;

      final screenPos = gameRef.worldToScreenGlobe(lake.center);
      if (screenPos.x < -500 || screenPos.y < -500) continue;
      if (screenPos.x < -50 ||
          screenPos.x > screenW + 50 ||
          screenPos.y < -50 ||
          screenPos.y > screenH + 50) continue;

      // Scale radius based on altitude and lake size
      final screenRadius = (lake.radiusDegrees * 8.0 / (alt + 0.3)).clamp(
        2.0,
        15.0,
      );
      canvas.drawCircle(
        Offset(screenPos.x, screenPos.y),
        screenRadius,
        fillPaint,
      );
    }
  }

  // -----------------------------------------------------------------------
  // Sea/Ocean labels — text labels at ocean centers
  // -----------------------------------------------------------------------

  static final Map<String, TextPainter> _seaLabelCache = {};

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
          (sea.center.y - playerPos.y).abs() > 90) continue;

      final screenPos = gameRef.worldToScreenGlobe(sea.center);
      if (screenPos.x < -500 || screenPos.y < -500) continue;
      if (screenPos.x < 0 ||
          screenPos.x > screenW ||
          screenPos.y < 0 ||
          screenPos.y > screenH) continue;

      final painter = _seaLabelCache.putIfAbsent(sea.name, () {
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
        return tp;
      });

      // Update opacity each frame
      painter.text = TextSpan(
        text: sea.name.toUpperCase(),
        style: TextStyle(
          color: const Color(0xFF88AACC).withOpacity(opacity),
          fontSize: 9,
          fontWeight: FontWeight.w300,
          letterSpacing: 2.0,
        ),
      );
      painter.layout();

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
  // Mountain peaks — small triangle markers
  // -----------------------------------------------------------------------

  void _renderMountains(
    Canvas canvas,
    double alt,
    double screenW,
    double screenH,
  ) {
    if (alt < 0.3) return;

    final opacity = ((alt - 0.3) * 0.8).clamp(0.0, 0.5);
    if (opacity < 0.05) return;

    final paint = Paint()
      ..color = const Color(0xFFCC8844).withOpacity(opacity)
      ..style = PaintingStyle.fill;

    final playerPos = gameRef.worldPosition;
    final visRadius = alt < 0.5 ? 30.0 : 70.0;
    const maxPeaks = kIsWeb ? 8 : 15;
    var drawn = 0;

    for (final peak in OsmFeatures.peaks) {
      if (drawn >= maxPeaks) break;
      if ((peak.location.x - playerPos.x).abs() > visRadius ||
          (peak.location.y - playerPos.y).abs() > visRadius) continue;

      final screenPos = gameRef.worldToScreenGlobe(peak.location);
      if (screenPos.x < -500 || screenPos.y < -500) continue;
      if (screenPos.x < -20 ||
          screenPos.x > screenW + 20 ||
          screenPos.y < -20 ||
          screenPos.y > screenH + 20) continue;

      // Small triangle marker
      const size = 4.0;
      final path = ui.Path()
        ..moveTo(screenPos.x, screenPos.y - size)
        ..lineTo(screenPos.x - size * 0.7, screenPos.y + size * 0.5)
        ..lineTo(screenPos.x + size * 0.7, screenPos.y + size * 0.5)
        ..close();

      canvas.drawPath(path, paint);
      drawn++;
    }
  }

  // -----------------------------------------------------------------------
  // Volcanoes — small diamond markers
  // -----------------------------------------------------------------------

  void _renderVolcanoes(
    Canvas canvas,
    double alt,
    double screenW,
    double screenH,
  ) {
    if (alt < 0.4) return;

    final opacity = ((alt - 0.4) * 0.7).clamp(0.0, 0.4);
    if (opacity < 0.05) return;

    final playerPos = gameRef.worldPosition;
    final visRadius = alt < 0.5 ? 30.0 : 70.0;
    const maxVolcanoes = kIsWeb ? 6 : 12;
    var drawn = 0;

    for (final volcano in OsmFeatures.volcanoes) {
      if (drawn >= maxVolcanoes) break;
      if ((volcano.location.x - playerPos.x).abs() > visRadius ||
          (volcano.location.y - playerPos.y).abs() > visRadius) continue;

      final screenPos = gameRef.worldToScreenGlobe(volcano.location);
      if (screenPos.x < -500 || screenPos.y < -500) continue;
      if (screenPos.x < -20 ||
          screenPos.x > screenW + 20 ||
          screenPos.y < -20 ||
          screenPos.y > screenH + 20) continue;

      final color = volcano.isActive
          ? const Color(0xFFDD4422).withOpacity(opacity)
          : const Color(0xFF886644).withOpacity(opacity * 0.7);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      // Diamond marker
      const size = 3.5;
      final path = ui.Path()
        ..moveTo(screenPos.x, screenPos.y - size)
        ..lineTo(screenPos.x + size * 0.6, screenPos.y)
        ..lineTo(screenPos.x, screenPos.y + size)
        ..lineTo(screenPos.x - size * 0.6, screenPos.y)
        ..close();

      canvas.drawPath(path, paint);
      drawn++;
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
          (airport.location.y - playerPos.y).abs() > visRadius) continue;

      final screenPos = gameRef.worldToScreenGlobe(airport.location);
      if (screenPos.x < -500 || screenPos.y < -500) continue;
      if (screenPos.x < 0 ||
          screenPos.x > screenW ||
          screenPos.y < 0 ||
          screenPos.y > screenH) continue;

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

  // -----------------------------------------------------------------------
  // Active country highlight only — all border lines are now rendered by
  // the globe shader (V7) from the distance field in uShoreDist green channel.
  // -----------------------------------------------------------------------

  void _renderCountryBorders(
    Canvas canvas,
    double continuousAlt,
    double screenW,
    double screenH,
  ) {
    // Only draw the active (hovered) country highlight
    final activeCountryName = gameRef.currentCountryName;
    if (activeCountryName == null) return;

    // Find the active country
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

    final highlightPaint = Paint()
      ..color = FlitColors.accent.withOpacity(
        (borderOpacity * 1.0).clamp(0.4, 1.0),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = continuousAlt >= 0.6 ? 2.5 : 3.5
      ..strokeJoin = StrokeJoin.round;

    // Point budget per polygon (web is tighter)
    const maxPointsPerPoly = kIsWeb ? 30 : 60;

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
}
