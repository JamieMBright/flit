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

  /// Current altitude mode.
  bool _isHighAltitude = true;

  /// Kept for speed-conversion compatibility.
  static const double mapWidth = 3600;
  static const double mapHeight = 1800;

  /// Angular radius of the visible globe in radians.
  /// Lower values = closer to the surface. Earth curvature just visible.
  /// Calibrated so countries fill the screen and curvature is subtle.
  static const double _highAltitudeRadius = 0.18; // ~10° — countries fill screen
  static const double _lowAltitudeRadius = 0.06; // ~3.4° — city-level detail

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
      ..shader = RadialGradient(
        colors: const [
          FlitColors.oceanShallow,
          FlitColors.ocean,
          FlitColors.oceanDeep,
        ],
        stops: const [0.0, 0.5, 1.0],
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

    final centerLat = _getCountryCenterLat(country);
    final landColor = _getLandColorByLatitude(centerLat);

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

  Color _getLandColorByLatitude(double lat) {
    final absLat = lat.abs();
    if (absLat > 65) return FlitColors.landSnow;
    if (absLat > 50) return FlitColors.landMass;
    if (absLat > 30) return FlitColors.landMassHighlight;
    if (absLat > 15) return FlitColors.landArid;
    return FlitColors.landMass;
  }

  double _getCountryCenterLat(CountryShape country) {
    var sum = 0.0;
    for (final p in country.points) {
      sum += p.y;
    }
    return sum / country.points.length;
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

    for (var i = 0; i < country.points.length; i++) {
      final p = country.points[i];
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

    if (c > _angularRadius * 1.05) return null;

    if (c < 0.0001) {
      return Offset(
        screenSize.x * FlitGame.projectionCenterX,
        screenSize.y * FlitGame.projectionCenterY,
      );
    }

    final sinC = sin(c);
    final px = cos(latR) * sin(dLng) / sinC;
    final py =
        (cos(lat0) * sin(latR) - sin(lat0) * cos(latR) * cos(dLng)) / sinC;

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
    final px = cos(latR) * sin(dLng) / sinC;
    final py =
        (cos(lat0) * sin(latR) - sin(lat0) * cos(latR) * cos(dLng)) / sinC;

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
