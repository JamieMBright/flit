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
/// Only land cells are drawn; ocean is left to the satellite texture.
/// Country borders are drawn as strokes on top. The active country
/// (where the plane is) gets a brighter, thicker border.
class CountryBorderOverlay extends Component with HasGameRef<FlitGame> {
  // -----------------------------------------------------------------------
  // Land mask — precomputed once from country polygon vertices.
  // A cell is "land" if any polygon vertex falls inside it.
  // Resolution: 2° cells → 180 lng × 90 lat = 16200 entries.
  // -----------------------------------------------------------------------

  static const double _maskRes = 2.0;
  static const int _maskW = 180; // 360 / 2
  static const int _maskH = 90; // 180 / 2
  static List<bool>? _landMask;

  static void _buildLandMask() {
    if (_landMask != null) return;
    final mask = List<bool>.filled(_maskW * _maskH, false);

    for (final country in CountryData.countries) {
      for (final polygon in country.polygons) {
        for (final v in polygon) {
          final ci = ((v.x + 180) / _maskRes).floor().clamp(0, _maskW - 1);
          final cj = ((v.y + 90) / _maskRes).floor().clamp(0, _maskH - 1);
          mask[cj * _maskW + ci] = true;
          // Also mark direct neighbours to fill gaps between sparse vertices.
          if (ci > 0) mask[cj * _maskW + ci - 1] = true;
          if (ci < _maskW - 1) mask[cj * _maskW + ci + 1] = true;
          if (cj > 0) mask[(cj - 1) * _maskW + ci] = true;
          if (cj < _maskH - 1) mask[(cj + 1) * _maskW + ci] = true;
        }
      }
    }
    _landMask = mask;
  }

  static bool _isLand(double lng, double lat) {
    final ci = ((lng + 180) / _maskRes).floor().clamp(0, _maskW - 1);
    final cj = ((lat + 90) / _maskRes).floor().clamp(0, _maskH - 1);
    return _landMask![cj * _maskW + ci];
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    try {
      if (!gameRef.isShaderActive) return;

      // Lazy-build land mask on first frame.
      _buildLandMask();

      final continuousAlt = gameRef.plane.continuousAltitude;
      final screenW = gameRef.size.x;
      final screenH = gameRef.size.y;

      // --- 1. Climate grid base layer (land only) ---
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
  // Climate grid — KG classification on a lat/lng grid, land cells only
  // -----------------------------------------------------------------------

  void _renderClimateGrid(
    Canvas canvas,
    double alt,
    double screenW,
    double screenH,
  ) {
    // Grid resolution: finer over land for visible detail.
    // Web keeps 5° for canvas budget; native uses 2°.
    final double cellSize;
    final int maxCells;
    if (kIsWeb) {
      cellSize = 5.0;
      maxCells = alt < 0.4 ? 80 : 150;
    } else {
      cellSize = 2.0;
      maxCells = alt < 0.4 ? 200 : 400;
    }

    // Subtle semi-transparent tint over satellite texture.
    final fillOpacity = alt >= 0.6
        ? (0.20 * (1.0 - (alt - 0.6) / 0.4)).clamp(0.05, 0.20)
        : (0.20 + 0.15 * (1.0 - alt / 0.6)).clamp(0.0, 0.35);
    if (fillOpacity < 0.02) return;

    // Visible lat/lng range around the camera.
    final playerPos = gameRef.worldPosition;
    final visRadius = alt < 0.3 ? 25.0 : alt < 0.6 ? 50.0 : 80.0;
    final minLat = (playerPos.y - visRadius).clamp(-90.0, 90.0);
    final maxLat = (playerPos.y + visRadius).clamp(-90.0, 90.0);
    final minLng = playerPos.x - visRadius;
    final maxLng = playerPos.x + visRadius;

    // Snap to grid.
    final startLat =
        ((minLat / cellSize).floor() * cellSize).clamp(-90.0, 90.0);
    final startLng = (minLng / cellSize).floor() * cellSize;

    var cells = 0;
    for (var lat = startLat; lat < maxLat; lat += cellSize) {
      for (var lng = startLng; lng < maxLng; lng += cellSize) {
        if (cells >= maxCells) break;

        // Normalise longitude.
        var nLng = lng;
        while (nLng > 180) nLng -= 360;
        while (nLng < -180) nLng += 360;

        // Cell centre.
        final cLat = lat + cellSize * 0.5;
        final cLng = nLng + cellSize * 0.5;

        // Skip ocean cells.
        if (!_isLand(cLng, cLat)) continue;

        final color = _getClimateColor(cLng, cLat);

        // Project corner points to screen.
        final tl = gameRef.worldToScreenGlobe(Vector2(lng, lat + cellSize));
        final tr =
            gameRef.worldToScreenGlobe(Vector2(lng + cellSize, lat + cellSize));
        final br = gameRef.worldToScreenGlobe(Vector2(lng + cellSize, lat));
        final bl = gameRef.worldToScreenGlobe(Vector2(lng, lat));

        // Skip cells behind camera.
        if (tl.x < -500 || tr.x < -500 || br.x < -500 || bl.x < -500) {
          continue;
        }

        // Skip cells entirely off-screen.
        if ((tl.x < -50 && tr.x < -50 && br.x < -50 && bl.x < -50) ||
            (tl.x > screenW + 50 &&
                tr.x > screenW + 50 &&
                br.x > screenW + 50 &&
                bl.x > screenW + 50) ||
            (tl.y < -50 && tr.y < -50 && br.y < -50 && bl.y < -50) ||
            (tl.y > screenH + 50 &&
                tr.y > screenH + 50 &&
                br.y > screenH + 50 &&
                bl.y > screenH + 50)) {
          continue;
        }

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
      ..color =
          FlitColors.accent.withOpacity((borderOpacity * 0.9).clamp(0.3, 0.9))
      ..style = PaintingStyle.stroke
      ..strokeWidth = continuousAlt >= 0.6 ? 1.5 : 2.5
      ..strokeJoin = StrokeJoin.round;

    // Point budget per polygon (web is tighter)
    final maxPointsPerPoly = kIsWeb ? 30 : 60;

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
  // Köppen-Geiger climate classification — expanded, geography-based
  // -----------------------------------------------------------------------
  //
  // Groups: A (tropical), B (arid), C (temperate), D (continental), E (polar)
  // Sub-types determined by specific geographic bounding boxes for accuracy.

  static Color _getClimateColor(double lng, double lat) {
    final absLat = lat.abs();

    // -- E: Polar --
    if (absLat > 75) return FlitColors.climateIceCap;
    if (absLat > 66) return FlitColors.climateTundra;

    // -- B: Arid (checked before latitude bands because deserts span bands) --
    if (_isHotDesert(lat, lng)) return FlitColors.climateHotDesert;
    if (_isColdDesert(lat, lng)) return FlitColors.climateColdDesert;
    if (_isHotSemiArid(lat, lng)) return FlitColors.climateHotSemiArid;
    if (_isColdSemiArid(lat, lng)) return FlitColors.climateColdSemiArid;

    // -- D: Continental / Boreal (high latitude, cold winters) --
    if (absLat > 55) return FlitColors.climateBoreal;
    if (absLat > 45 && _isHumidContinental(lat, lng)) {
      return FlitColors.climateHumidContinental;
    }

    // -- C: Temperate mid-latitudes --
    if (absLat > 30 && absLat < 45 && _isMediterranean(lat, lng)) {
      return FlitColors.climateMediterranean;
    }
    if (_isOceanic(lat, lng)) return FlitColors.climateOceanic;
    if (absLat > 35) return FlitColors.climateTemperate;
    if (absLat > 20) return FlitColors.climateHumidSubtropical;

    // -- A: Tropical --
    if (_isTropicalMonsoon(lat, lng)) return FlitColors.climateTropicalMonsoon;
    if (absLat > 8) return FlitColors.climateTropicalSavanna;

    return FlitColors.climateTropicalRain;
  }

  // -- Hot desert (BWh): subtropical high-pressure belts --
  static bool _isHotDesert(double lat, double lng) {
    final absLat = lat.abs();
    if (absLat < 12 || absLat > 38) return false;
    // Sahara
    if (lat > 18 && lat < 35 && lng > -15 && lng < 35) return true;
    // Arabian
    if (lat > 15 && lat < 32 && lng > 35 && lng < 60) return true;
    // Iranian / Afghan
    if (lat > 25 && lat < 38 && lng > 50 && lng < 70) return true;
    // Thar (India/Pakistan)
    if (lat > 22 && lat < 30 && lng > 68 && lng < 76) return true;
    // Australian interior
    if (lat < -20 && lat > -30 && lng > 122 && lng < 142) return true;
    // Sonoran / Chihuahuan
    if (lat > 25 && lat < 34 && lng > -115 && lng < -105) return true;
    // Atacama
    if (lat < -18 && lat > -28 && lng > -72 && lng < -68) return true;
    // Namib
    if (lat < -16 && lat > -28 && lng > 13 && lng < 18) return true;
    // Kalahari core
    if (lat < -20 && lat > -28 && lng > 19 && lng < 25) return true;
    return false;
  }

  // -- Cold desert (BWk): continental interior, rain shadow --
  static bool _isColdDesert(double lat, double lng) {
    // Gobi
    if (lat > 38 && lat < 48 && lng > 90 && lng < 115) return true;
    // Taklamakan
    if (lat > 36 && lat < 42 && lng > 76 && lng < 90) return true;
    // Karakum / Kyzylkum
    if (lat > 36 && lat < 44 && lng > 56 && lng < 68) return true;
    // Patagonian interior
    if (lat < -40 && lat > -50 && lng > -70 && lng < -66) return true;
    // Great Basin (USA)
    if (lat > 36 && lat < 42 && lng > -120 && lng < -110) return true;
    return false;
  }

  // -- Hot semi-arid (BSh): margins of hot deserts --
  static bool _isHotSemiArid(double lat, double lng) {
    final absLat = lat.abs();
    if (absLat < 8 || absLat > 35) return false;
    // Sahel belt
    if (lat > 10 && lat < 18 && lng > -17 && lng < 40) return true;
    // Horn of Africa
    if (lat > 2 && lat < 12 && lng > 38 && lng < 52) return true;
    // Southern African plateau
    if (lat < -15 && lat > -28 && lng > 22 && lng < 35) return true;
    // NW India / Pakistan fringe
    if (lat > 20 && lat < 28 && lng > 66 && lng < 72) return true;
    // NE Brazil (Sertão)
    if (lat < -3 && lat > -15 && lng > -42 && lng < -35) return true;
    // Australian semi-arid fringe
    if (lat < -14 && lat > -20 && lng > 125 && lng < 145) return true;
    if (lat < -28 && lat > -34 && lng > 135 && lng < 148) return true;
    return false;
  }

  // -- Cold semi-arid (BSk): steppe margins --
  static bool _isColdSemiArid(double lat, double lng) {
    // Central Asian steppe
    if (lat > 40 && lat < 52 && lng > 50 && lng < 85) return true;
    // Mongolian steppe
    if (lat > 44 && lat < 52 && lng > 95 && lng < 120) return true;
    // Patagonian steppe
    if (lat < -34 && lat > -48 && lng > -72 && lng < -64) return true;
    // US Great Plains (western)
    if (lat > 32 && lat < 48 && lng > -108 && lng < -100) return true;
    // South African highveld fringe
    if (lat < -28 && lat > -34 && lng > 24 && lng < 30) return true;
    return false;
  }

  // -- Mediterranean (Csa/Csb): dry summers, mild wet winters --
  static bool _isMediterranean(double lat, double lng) {
    // Mediterranean basin (S Europe, N Africa coast, Turkey)
    if (lat > 30 && lat < 44 && lng > -10 && lng < 38) return true;
    // California
    if (lat > 32 && lat < 40 && lng > -125 && lng < -117) return true;
    // Central Chile
    if (lat < -30 && lat > -38 && lng > -73 && lng < -70) return true;
    // SW Australia
    if (lat < -30 && lat > -37 && lng > 114 && lng < 120) return true;
    // Western Cape
    if (lat < -32 && lat > -35 && lng > 17 && lng < 21) return true;
    return false;
  }

  // -- Oceanic (Cfb): mild, wet, no dry season --
  static bool _isOceanic(double lat, double lng) {
    // British Isles, NW France, Benelux
    if (lat > 48 && lat < 60 && lng > -10 && lng < 8) return true;
    // Ireland
    if (lat > 51 && lat < 56 && lng > -11 && lng < -5) return true;
    // Pacific NW (Washington, Oregon, BC coast)
    if (lat > 42 && lat < 55 && lng > -128 && lng < -122) return true;
    // Southern Chile (Valdivia)
    if (lat < -38 && lat > -48 && lng > -76 && lng < -72) return true;
    // New Zealand
    if (lat < -34 && lat > -47 && lng > 166 && lng < 178) return true;
    // Tasmania
    if (lat < -40 && lat > -44 && lng > 144 && lng < 149) return true;
    // Norway coast
    if (lat > 58 && lat < 66 && lng > 4 && lng < 16) return true;
    return false;
  }

  // -- Humid continental (Dfa/Dfb): cold winters, warm summers --
  static bool _isHumidContinental(double lat, double lng) {
    // NE North America (Great Lakes, New England)
    if (lat > 40 && lat < 50 && lng > -90 && lng < -65) return true;
    // SE Canada
    if (lat > 44 && lat < 52 && lng > -80 && lng < -60) return true;
    // Eastern Europe (Poland, Baltics, Belarus, W Russia)
    if (lat > 48 && lat < 58 && lng > 14 && lng < 45) return true;
    // NE China, Korea, N Japan
    if (lat > 38 && lat < 50 && lng > 115 && lng < 145) return true;
    // Hokkaido
    if (lat > 42 && lat < 46 && lng > 140 && lng < 146) return true;
    return false;
  }

  // -- Tropical monsoon (Am): heavy seasonal rain --
  static bool _isTropicalMonsoon(double lat, double lng) {
    final absLat = lat.abs();
    if (absLat > 25) return false;
    // Indian subcontinent (west coast, Bengal)
    if (lat > 8 && lat < 25 && lng > 72 && lng < 92) return true;
    // SE Asia (Myanmar, Thailand, Vietnam, Cambodia)
    if (lat > 5 && lat < 22 && lng > 92 && lng < 110) return true;
    // Philippines
    if (lat > 6 && lat < 18 && lng > 118 && lng < 128) return true;
    // West Africa coast (Guinea, Sierra Leone, Liberia)
    if (lat > 4 && lat < 12 && lng > -15 && lng < -5) return true;
    // Central America Caribbean coast
    if (lat > 8 && lat < 18 && lng > -90 && lng < -78) return true;
    // N Australia coast
    if (lat < -10 && lat > -18 && lng > 125 && lng < 145) return true;
    // Bangladesh, NE India
    if (lat > 20 && lat < 28 && lng > 88 && lng < 96) return true;
    return false;
  }
}
