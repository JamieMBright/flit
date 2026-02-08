import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../flit_game.dart';
import 'country_data.dart';

/// Degrees-to-radians constant.
const double _deg2rad = pi / 180;

/// Renders the world as a full-screen map using azimuthal equidistant projection.
///
/// The projection is centered on the plane's current position, giving
/// a "behind the plane" 3rd-person perspective. The map fills the entire
/// screen edge-to-edge — no circle boundary, no visible space. At the
/// zoomed-in angular radius, curvature is subtle: grid lines curve gently
/// and the horizon is implied by where land ends, not by a hard circle.
class WorldMap extends Component with HasGameRef<FlitGame> {
  WorldMap({this.onCountryTapped});

  final void Function(String countryCode)? onCountryTapped;

  /// Camera center in (longitude, latitude) degrees.
  Vector2 _cameraCenter = Vector2.zero();

  /// Camera heading in radians (navigation bearing: 0 = north, clockwise).
  /// Used to rotate the map so the heading direction points up on screen.
  double _cameraHeading = 0.0;

  /// Current altitude mode.
  bool _isHighAltitude = true;

  /// Kept for speed-conversion compatibility.
  static const double mapWidth = 3600;
  static const double mapHeight = 1800;

  /// Angular radius of the visible globe in radians.
  /// Higher = more of the globe visible. Lower = more zoomed in.
  /// High altitude shows continents; low altitude shows city-level detail.
  static const double _highAltitudeRadius = 0.30; // ~17° — closer view with curvature
  static const double _lowAltitudeRadius = 0.10; // ~5.7° — city-level detail

  /// Current interpolated angular radius.
  double _angularRadius = _highAltitudeRadius;

  bool get isHighAltitude => _isHighAltitude;
  Vector2 get cameraCenter => _cameraCenter;

  void setAltitude({required bool high}) {
    _isHighAltitude = high;
  }

  void setCameraCenter(Vector2 center) {
    _cameraCenter = center;
  }

  /// Set the camera heading (navigation bearing in radians: 0 = north).
  void setCameraHeading(double heading) {
    _cameraHeading = heading;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final target = _isHighAltitude ? _highAltitudeRadius : _lowAltitudeRadius;
    _angularRadius += (target - _angularRadius) * min(1.0, dt * 3);
    // Smooth altitude fraction for globe radius interpolation.
    final targetFrac = _isHighAltitude ? 1.0 : 0.0;
    _altitudeFraction += (targetFrac - _altitudeFraction) * min(1.0, dt * 3);
  }

  // ─── Rendering ──────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final screenSize = gameRef.size;
    final center = Offset(
      screenSize.x * FlitGame.projectionCenterX,
      screenSize.y * FlitGame.projectionCenterY,
    );
    final globeRadius = _globeScreenRadius(screenSize);

    // 1. Dark sky/space background — always drawn, visible at high altitude.
    _renderSkyBackground(canvas, screenSize);

    // 2. Ocean globe disc — smaller at high altitude to reveal horizon.
    _renderOceanBackground(canvas, screenSize, center, globeRadius);

    // 3. Atmospheric glow at globe edge (visible at high altitude).
    _renderAtmosphereRing(canvas, center, globeRadius);

    // 4. Grid lines
    _renderGrid(canvas, screenSize, globeRadius);

    // 5. Countries
    _renderCountries(canvas, screenSize, globeRadius);

    // 6. Coastline glow
    _renderCoastlines(canvas, screenSize, globeRadius);

    // 7. Cities (low altitude only)
    if (!_isHighAltitude) {
      _renderCities(canvas, screenSize, globeRadius);
    }
  }

  /// Smoothly interpolated globe radius fraction (0 = low alt, 1 = high alt).
  double _altitudeFraction = 1.0;

  double _globeScreenRadius(Vector2 screenSize) {
    final cx = screenSize.x * FlitGame.projectionCenterX;
    final cy = screenSize.y * FlitGame.projectionCenterY;

    // Distance to each corner — pick the farthest one.
    final d1 = sqrt(cx * cx + cy * cy);
    final d2 = sqrt((screenSize.x - cx) * (screenSize.x - cx) + cy * cy);
    final d3 = sqrt(cx * cx + (screenSize.y - cy) * (screenSize.y - cy));
    final d4 = sqrt((screenSize.x - cx) * (screenSize.x - cx) +
        (screenSize.y - cy) * (screenSize.y - cy));

    // Low altitude: fills the entire screen (no visible horizon).
    final maxRadius = max(max(d1, d2), max(d3, d4)) * 1.1;

    // High altitude: globe disc is smaller, revealing sky/space at edges.
    // Use ~85% of the distance to the nearest edge so horizon is visible.
    final nearTop = cy;
    final nearBottom = screenSize.y - cy;
    final nearSide = min(cx, screenSize.x - cx);
    final nearestEdge = min(min(nearTop, nearBottom), nearSide);
    final highRadius = max(nearestEdge * 1.6, min(screenSize.x, screenSize.y) * 0.6);

    // Interpolate between high-alt (horizon visible) and low-alt (fills screen).
    return highRadius + (maxRadius - highRadius) * (1.0 - _altitudeFraction);
  }

  /// Dark sky gradient — visible around the globe at high altitude.
  void _renderSkyBackground(Canvas canvas, Vector2 screenSize) {
    final screenRect = Rect.fromLTWH(0, 0, screenSize.x, screenSize.y);
    canvas.drawRect(screenRect, Paint()..color = FlitColors.space);
  }

  /// Atmospheric glow ring around the globe edge.
  void _renderAtmosphereRing(Canvas canvas, Offset center, double radius) {
    if (_altitudeFraction < 0.05) return; // Not visible at low altitude.
    final glowWidth = radius * 0.08;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0x00668FCC), // transparent inside
          Color.fromRGBO(100, 160, 230, 0.25 * _altitudeFraction),
          Color.fromRGBO(140, 190, 255, 0.15 * _altitudeFraction),
          const Color(0x00000000), // transparent outside
        ],
        stops: const [0.88, 0.94, 0.98, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius + glowWidth));
    canvas.drawCircle(center, radius + glowWidth, glowPaint);
  }

  /// Ocean background drawn as a filled circle (not full-screen rect).
  void _renderOceanBackground(
      Canvas canvas, Vector2 screenSize, Offset center, double radius) {
    final oceanPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          FlitColors.oceanShallow,
          FlitColors.ocean,
          FlitColors.oceanDeep,
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, oceanPaint);
  }

  void _renderGrid(Canvas canvas, Vector2 screenSize, double globeRadius) {
    final gridPaint = Paint()
      ..color = FlitColors.gridLine
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final majorGridPaint = Paint()
      ..color = FlitColors.gridLine.withOpacity(0.15)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const gridSpacing = 30.0;
    const segments = 60;

    // Latitude lines
    for (var lat = -60.0; lat <= 60.0; lat += gridSpacing) {
      final isMajor = lat.abs() < 0.1;
      final paint = isMajor ? majorGridPaint : gridPaint;
      _drawGridLine(canvas, screenSize, globeRadius, paint, segments,
          (t) => Vector2(-180 + t * 360, lat));
    }

    // Longitude lines
    for (var lng = -180.0; lng < 180.0; lng += gridSpacing) {
      final isMajor = lng.abs() < 0.1;
      final paint = isMajor ? majorGridPaint : gridPaint;
      _drawGridLine(canvas, screenSize, globeRadius, paint, segments,
          (t) => Vector2(lng, -80 + t * 160));
    }
  }

  void _drawGridLine(
    Canvas canvas,
    Vector2 screenSize,
    double globeRadius,
    Paint paint,
    int segments,
    Vector2 Function(double t) paramToLatLng,
  ) {
    final path = Path();
    var started = false;

    for (var i = 0; i <= segments; i++) {
      final t = i / segments;
      final ll = paramToLatLng(t);
      final projected = _project(ll.x, ll.y, screenSize, globeRadius);
      if (projected == null) {
        started = false;
        continue;
      }
      if (!started) {
        path.moveTo(projected.dx, projected.dy);
        started = true;
      } else {
        path.lineTo(projected.dx, projected.dy);
      }
    }

    canvas.drawPath(path, paint);
  }

  void _renderCountries(
      Canvas canvas, Vector2 screenSize, double globeRadius) {
    for (final country in CountryData.countries) {
      _renderCountry(canvas, screenSize, globeRadius, country);
    }
  }

  void _renderCountry(Canvas canvas, Vector2 screenSize, double globeRadius,
      CountryShape country) {
    final path = _createCountryPath(country, screenSize, globeRadius);
    if (path == null) return;

    final center = _getCountryCenter(country);
    final landColor = _getClimateColor(center.x, center.y);

    canvas.drawPath(path, Paint()..color = landColor);

    if (!_isHighAltitude) {
      canvas.drawPath(
        path,
        Paint()
          ..color = FlitColors.landMassHighlight.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = _isHighAltitude
            ? FlitColors.border.withOpacity(0.6)
            : FlitColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = _isHighAltitude ? 0.8 : 1.5,
    );
  }

  /// Determine land color based on Köppen-Geiger climate zone heuristics.
  /// Uses center (lng, lat) of each country to approximate the dominant climate.
  Color _getClimateColor(double lng, double lat) {
    final absLat = lat.abs();

    // Polar / ice cap
    if (absLat > 75) return FlitColors.climateIceCap;
    // Tundra
    if (absLat > 63) return FlitColors.climateTundra;
    // Boreal / subarctic (taiga)
    if (absLat > 52) return FlitColors.climateBoreal;

    // Desert detection: major arid belts (15-35° lat band + specific regions)
    if (_isDesertRegion(lat, lng)) return FlitColors.climateHotDesert;
    if (_isSemiAridRegion(lat, lng)) return FlitColors.climateSemiArid;

    // Mediterranean (western coasts, 30-45° lat)
    if (absLat > 30 && absLat < 45 && _isMediterraneanRegion(lat, lng)) {
      return FlitColors.climateMediterranean;
    }

    // Temperate (35-52° lat, not desert)
    if (absLat > 35) return FlitColors.climateTemperate;

    // Humid subtropical (20-35° lat, not desert)
    if (absLat > 20) return FlitColors.climateHumidSubtropical;

    // Tropical savanna (10-20° lat)
    if (absLat > 10) return FlitColors.climateTropicalSavanna;

    // Tropical rainforest (0-10° lat)
    return FlitColors.climateTropicalRain;
  }

  /// Heuristic for hot desert zones (BWh) based on geographic position.
  bool _isDesertRegion(double lat, double lng) {
    final absLat = lat.abs();
    if (absLat < 12 || absLat > 38) return false;

    // Sahara (N Africa: 15-35°N, 15°W-35°E)
    if (lat > 15 && lat < 35 && lng > -15 && lng < 35) return true;
    // Arabian (15-32°N, 35-60°E)
    if (lat > 15 && lat < 32 && lng > 35 && lng < 60) return true;
    // Iranian/Central Asian (25-40°N, 50-70°E)
    if (lat > 25 && lat < 40 && lng > 50 && lng < 70) return true;
    // Thar / Rajasthan (20-30°N, 68-76°E)
    if (lat > 20 && lat < 30 && lng > 68 && lng < 76) return true;
    // Australian interior (20-32°S, 120-145°E)
    if (lat < -20 && lat > -32 && lng > 120 && lng < 145) return true;
    // Sonoran/Chihuahuan (25-35°N, 105-115°W)
    if (lat > 25 && lat < 35 && lng > -115 && lng < -105) return true;
    // Atacama (18-30°S, 68-72°W)
    if (lat < -18 && lat > -30 && lng > -72 && lng < -68) return true;
    // Namib/Kalahari (15-30°S, 15-25°E)
    if (lat < -15 && lat > -30 && lng > 15 && lng < 25) return true;

    return false;
  }

  /// Heuristic for semi-arid steppe zones (BS).
  bool _isSemiAridRegion(double lat, double lng) {
    final absLat = lat.abs();
    if (absLat < 10 || absLat > 45) return false;

    // Sahel (10-15°N, 15°W-40°E)
    if (lat > 10 && lat < 15 && lng > -15 && lng < 40) return true;
    // Central Asian steppe (35-50°N, 50-90°E)
    if (lat > 35 && lat < 50 && lng > 50 && lng < 90) return true;
    // Patagonia/Gran Chaco (25-45°S, 60-70°W)
    if (lat < -25 && lat > -45 && lng > -70 && lng < -60) return true;
    // Horn of Africa (5-15°N, 40-52°E)
    if (lat > 5 && lat < 15 && lng > 40 && lng < 52) return true;
    // Southern Africa interior (15-25°S, 22-35°E)
    if (lat < -15 && lat > -25 && lng > 22 && lng < 35) return true;

    return false;
  }

  /// Heuristic for Mediterranean climate zones (Cs).
  bool _isMediterraneanRegion(double lat, double lng) {
    // Southern Europe / North Africa coast (30-45°N, 10°W-40°E)
    if (lat > 30 && lat < 45 && lng > -10 && lng < 40) return true;
    // California (32-40°N, 115-125°W)
    if (lat > 32 && lat < 40 && lng > -125 && lng < -115) return true;
    // Chile central (30-38°S, 70-73°W)
    if (lat < -30 && lat > -38 && lng > -73 && lng < -70) return true;
    // SW Australia (30-37°S, 114-120°E)
    if (lat < -30 && lat > -37 && lng > 114 && lng < 120) return true;
    // South Africa cape (33-35°S, 18-20°E)
    if (lat < -33 && lat > -35 && lng > 18 && lng < 20) return true;

    return false;
  }

  /// Get center (lng, lat) of a country shape.
  Vector2 _getCountryCenter(CountryShape country) {
    final pts = country.allPoints;
    if (pts.isEmpty) return Vector2.zero();
    var sumLng = 0.0;
    var sumLat = 0.0;
    for (final p in pts) {
      sumLng += p.x;
      sumLat += p.y;
    }
    return Vector2(sumLng / pts.length, sumLat / pts.length);
  }

  void _renderCoastlines(
      Canvas canvas, Vector2 screenSize, double globeRadius) {
    final coastPaint = Paint()
      ..color = FlitColors.oceanShallow.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _isHighAltitude ? 2.0 : 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    for (final country in CountryData.countries) {
      final path = _createCountryPath(country, screenSize, globeRadius);
      if (path != null) {
        canvas.drawPath(path, coastPaint);
      }
    }
  }

  Path? _createCountryPath(
      CountryShape country, Vector2 screenSize, double globeRadius) {
    final path = Path();
    var anyVisible = false;

    for (final polygon in country.polygons) {
      for (var i = 0; i < polygon.length; i++) {
        final p = polygon[i];
        final projected = _project(p.x, p.y, screenSize, globeRadius);

        if (projected != null) anyVisible = true;

        final pt =
            projected ?? _projectClamped(p.x, p.y, screenSize, globeRadius);

        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
    }

    return anyVisible ? path : null;
  }

  void _renderCities(
      Canvas canvas, Vector2 screenSize, double globeRadius) {
    final cityDotPaint = Paint()..color = FlitColors.city;
    final capitalDotPaint = Paint()..color = FlitColors.cityCapital;
    final cityOutlinePaint = Paint()
      ..color = FlitColors.shadow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (final city in CountryData.majorCities) {
      final projected =
          _project(city.location.x, city.location.y, screenSize, globeRadius);
      if (projected == null) continue;

      final dotSize = city.isCapital ? 4.0 : 2.5;
      final paint = city.isCapital ? capitalDotPaint : cityDotPaint;

      canvas.drawCircle(projected, dotSize, paint);
      canvas.drawCircle(projected, dotSize, cityOutlinePaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: city.name,
          style: TextStyle(
            color: city.isCapital
                ? FlitColors.textPrimary
                : FlitColors.textSecondary,
            fontSize: city.isCapital ? 10 : 8,
            fontWeight: city.isCapital ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(
            projected.dx + dotSize + 3, projected.dy - textPainter.height / 2),
      );
    }
  }

  // ─── Projection ─────────────────────────────────────────────────────

  /// Project (lng, lat) degrees → screen Offset via azimuthal equidistant.
  /// Returns null if beyond the visible horizon.
  Offset? _project(
      double lng, double lat, Vector2 screenSize, double globeRadius) {
    final lat0 = _cameraCenter.y * _deg2rad;
    final lng0 = _cameraCenter.x * _deg2rad;
    final latR = lat * _deg2rad;
    final lngR = lng * _deg2rad;
    final dLng = lngR - lng0;

    final cosC =
        sin(lat0) * sin(latR) + cos(lat0) * cos(latR) * cos(dLng);
    final c = acos(cosC.clamp(-1.0, 1.0));

    if (c > _angularRadius * 1.15) return null;

    if (c < 0.0001) {
      return Offset(
        screenSize.x * FlitGame.projectionCenterX,
        screenSize.y * FlitGame.projectionCenterY,
      );
    }

    final sinC = sin(c);
    final rawPx = cos(latR) * sin(dLng) / sinC;
    final rawPy =
        (cos(lat0) * sin(latR) - sin(lat0) * cos(latR) * cos(dLng)) / sinC;

    // Rotate by camera heading so heading direction points up on screen.
    final cosH = cos(_cameraHeading);
    final sinH = sin(_cameraHeading);
    final px = rawPx * cosH - rawPy * sinH;
    final py = rawPx * sinH + rawPy * cosH;

    final scale = globeRadius / _angularRadius;

    return Offset(
      screenSize.x * FlitGame.projectionCenterX + px * c * scale,
      screenSize.y * FlitGame.projectionCenterY - py * c * scale,
    );
  }

  /// Like [_project] but clamps to the horizon instead of returning null.
  Offset _projectClamped(
      double lng, double lat, Vector2 screenSize, double globeRadius) {
    final lat0 = _cameraCenter.y * _deg2rad;
    final lng0 = _cameraCenter.x * _deg2rad;
    final latR = lat * _deg2rad;
    final lngR = lng * _deg2rad;
    final dLng = lngR - lng0;

    final cosC =
        sin(lat0) * sin(latR) + cos(lat0) * cos(latR) * cos(dLng);
    var c = acos(cosC.clamp(-1.0, 1.0));

    if (c < 0.0001) {
      return Offset(
        screenSize.x * FlitGame.projectionCenterX,
        screenSize.y * FlitGame.projectionCenterY,
      );
    }

    final sinC = sin(c);
    final rawPx = cos(latR) * sin(dLng) / sinC;
    final rawPy =
        (cos(lat0) * sin(latR) - sin(lat0) * cos(latR) * cos(dLng)) / sinC;

    // Rotate by camera heading so heading direction points up on screen.
    final cosH = cos(_cameraHeading);
    final sinH = sin(_cameraHeading);
    final px = rawPx * cosH - rawPy * sinH;
    final py = rawPx * sinH + rawPy * cosH;

    if (c > _angularRadius) c = _angularRadius;

    final scale = globeRadius / _angularRadius;

    return Offset(
      screenSize.x * FlitGame.projectionCenterX + px * c * scale,
      screenSize.y * FlitGame.projectionCenterY - py * c * scale,
    );
  }

  /// Inverse projection: screen → (lng, lat) degrees.
  Vector2 screenToLatLng(Vector2 screenPos, Vector2 screenSize) {
    final cx = screenSize.x * FlitGame.projectionCenterX;
    final cy = screenSize.y * FlitGame.projectionCenterY;
    final globeRadius = _globeScreenRadius(screenSize);
    final scale = globeRadius / _angularRadius;

    final dx = screenPos.x - cx;
    final dy = -(screenPos.y - cy);

    final rho = sqrt(dx * dx + dy * dy) / scale;
    if (rho < 0.0001) return _cameraCenter.clone();

    final c = rho;
    final lat0 = _cameraCenter.y * _deg2rad;
    final lng0 = _cameraCenter.x * _deg2rad;

    final lat = asin(
      (cos(c) * sin(lat0) + dy / scale * sin(c) * cos(lat0) / rho)
          .clamp(-1.0, 1.0),
    );
    final lng = lng0 +
        atan2(dx / scale * sin(c),
            rho * cos(lat0) * cos(c) - dy / scale * sin(lat0) * sin(c));

    return Vector2(lng * 180 / pi, lat * 180 / pi);
  }

  /// Forward projection: (lng, lat) → screen position.
  Vector2 latLngToScreen(Vector2 latLng, Vector2 screenSize) {
    final globeRadius = _globeScreenRadius(screenSize);
    final result = _project(latLng.x, latLng.y, screenSize, globeRadius);
    if (result != null) {
      return Vector2(result.dx, result.dy);
    }
    final clamped =
        _projectClamped(latLng.x, latLng.y, screenSize, globeRadius);
    return Vector2(clamped.dx, clamped.dy);
  }
}
