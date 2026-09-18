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

  /// Kept for speed-conversion compatibility.
  static const double mapWidth = 3600;
  static const double mapHeight = 1800;

  // -- Cached Paint objects (avoid per-frame allocation) --
  static final Paint _skyPaint = Paint()..color = FlitColors.space;
  final Paint _landFillPaint = Paint()..color = FlitColors.landMass;
  final Paint _borderHighPaint = Paint()
    ..color = FlitColors.border.withOpacity(0.6)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8;
  final Paint _oceanPaint = Paint();
  final Paint _atmoPaint = Paint();

  // -- Cached gradient state (recreate only on input change) --
  Offset _lastOceanCenter = Offset.zero;
  double _lastOceanRadius = 0.0;
  Offset _lastAtmoCenter = Offset.zero;
  double _lastAtmoRadius = 0.0;

  // -- Cached country paths (built once per frame, reused for coastlines) --
  final List<Path> _countryPathCache = [];

  /// Angular radius of the normal globe view.
  static const double _normalGlobeRadius =
      0.30; // ~17° — closer view with curvature
  static const double _angularRadius = _normalGlobeRadius;
  Vector2 get cameraCenter => _cameraCenter;

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

    _renderSkyBackground(canvas, screenSize);
    _renderOceanBackground(canvas, screenSize, center, globeRadius);
    _renderAtmosphereRing(canvas, center, globeRadius);
    _renderGrid(canvas, screenSize, globeRadius);
    _renderCountries(canvas, screenSize, globeRadius);
    _renderCoastlines(canvas, screenSize, globeRadius);
  }

  double _globeScreenRadius(Vector2 screenSize) {
    final cx = screenSize.x * FlitGame.projectionCenterX;
    final cy = screenSize.y * FlitGame.projectionCenterY;

    // Normal flight view: globe disc is smaller, revealing sky/space at edges.
    // Use ~85% of the distance to the nearest edge so horizon is visible.
    final nearTop = cy;
    final nearBottom = screenSize.y - cy;
    final nearSide = min(cx, screenSize.x - cx);
    final nearestEdge = min(min(nearTop, nearBottom), nearSide);
    final highRadius = max(
      nearestEdge * 1.6,
      min(screenSize.x, screenSize.y) * 0.6,
    );

    return highRadius;
  }

  /// Dark sky gradient visible around the normal globe view.
  void _renderSkyBackground(Canvas canvas, Vector2 screenSize) {
    final screenRect = Rect.fromLTWH(0, 0, screenSize.x, screenSize.y);
    canvas.drawRect(screenRect, _skyPaint);
  }

  /// Atmospheric glow ring around the globe edge.
  void _renderAtmosphereRing(Canvas canvas, Offset center, double radius) {
    final glowWidth = radius * 0.08;
    final totalRadius = radius + glowWidth;
    // Only recreate shader when inputs change
    if (center != _lastAtmoCenter || totalRadius != _lastAtmoRadius) {
      _lastAtmoCenter = center;
      _lastAtmoRadius = totalRadius;
      _atmoPaint.shader = RadialGradient(
        colors: [
          const Color(0x00668FCC),
          const Color.fromRGBO(100, 160, 230, 0.25),
          const Color.fromRGBO(140, 190, 255, 0.15),
          const Color(0x00000000),
        ],
        stops: const [0.88, 0.94, 0.98, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: totalRadius));
    }
    canvas.drawCircle(center, totalRadius, _atmoPaint);
  }

  /// Ocean background drawn as a filled circle (not full-screen rect).
  void _renderOceanBackground(
    Canvas canvas,
    Vector2 screenSize,
    Offset center,
    double radius,
  ) {
    // Only recreate shader when center or radius changes
    if (center != _lastOceanCenter || radius != _lastOceanRadius) {
      _lastOceanCenter = center;
      _lastOceanRadius = radius;
      _oceanPaint.shader = const RadialGradient(
        colors: [
          FlitColors.oceanShallow,
          FlitColors.ocean,
          FlitColors.oceanDeep,
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    }
    canvas.drawCircle(center, radius, _oceanPaint);
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
      _drawGridLine(
        canvas,
        screenSize,
        globeRadius,
        paint,
        segments,
        (t) => Vector2(-180 + t * 360, lat),
      );
    }

    // Longitude lines
    for (var lng = -180.0; lng < 180.0; lng += gridSpacing) {
      final isMajor = lng.abs() < 0.1;
      final paint = isMajor ? majorGridPaint : gridPaint;
      _drawGridLine(
        canvas,
        screenSize,
        globeRadius,
        paint,
        segments,
        (t) => Vector2(lng, -80 + t * 160),
      );
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

  void _renderCountries(Canvas canvas, Vector2 screenSize, double globeRadius) {
    // Build country paths once and cache for reuse in coastlines.
    _countryPathCache.clear();
    final borderPaint = _borderHighPaint;

    // Composite semi-transparent strokes into single paths so that shared
    // borders between adjacent countries are not double-blended (which
    // produces visible bright seams at every shared edge).
    final compositeBorderPath = Path();

    for (final country in CountryData.countries) {
      final path = _createCountryPath(country, screenSize, globeRadius);
      if (path == null) continue;
      _countryPathCache.add(path);

      // Land fill is fully opaque — safe to draw per-country.
      canvas.drawPath(path, _landFillPaint);
      compositeBorderPath.addPath(path, Offset.zero);
    }

    canvas.drawPath(compositeBorderPath, borderPaint);
  }

  void _renderCoastlines(
    Canvas canvas,
    Vector2 screenSize,
    double globeRadius,
  ) {
    final coastPaint = Paint()
      ..color = FlitColors.oceanShallow.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    // Composite all coastline paths into a single path before drawing so
    // that shared borders are not double-blended (semi-transparent + blurred).
    final compositeCoast = Path();
    for (final path in _countryPathCache) {
      compositeCoast.addPath(path, Offset.zero);
    }
    canvas.drawPath(compositeCoast, coastPaint);
  }

  Path? _createCountryPath(
    CountryShape country,
    Vector2 screenSize,
    double globeRadius,
  ) {
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

  // ─── Projection ─────────────────────────────────────────────────────

  /// Project (lng, lat) degrees → screen Offset via azimuthal equidistant.
  /// Returns null if beyond the visible horizon.
  Offset? _project(
    double lng,
    double lat,
    Vector2 screenSize,
    double globeRadius,
  ) {
    final lat0 = _cameraCenter.y * _deg2rad;
    final lng0 = _cameraCenter.x * _deg2rad;
    final latR = lat * _deg2rad;
    final lngR = lng * _deg2rad;
    final dLng = lngR - lng0;

    final cosC = sin(lat0) * sin(latR) + cos(lat0) * cos(latR) * cos(dLng);
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
    double lng,
    double lat,
    Vector2 screenSize,
    double globeRadius,
  ) {
    final lat0 = _cameraCenter.y * _deg2rad;
    final lng0 = _cameraCenter.x * _deg2rad;
    final latR = lat * _deg2rad;
    final lngR = lng * _deg2rad;
    final dLng = lngR - lng0;

    final cosC = sin(lat0) * sin(latR) + cos(lat0) * cos(latR) * cos(dLng);
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
  /// Returns null if the screen point is outside the visible globe.
  Vector2? screenToLatLng(Vector2 screenPos, Vector2 screenSize) {
    final cx = screenSize.x * FlitGame.projectionCenterX;
    final cy = screenSize.y * FlitGame.projectionCenterY;
    final globeRadius = _globeScreenRadius(screenSize);
    final scale = globeRadius / _angularRadius;

    final dx = screenPos.x - cx;
    final dy = -(screenPos.y - cy);

    final rho = sqrt(dx * dx + dy * dy) / scale;

    // Check if tap is outside the visible globe (beyond angular radius).
    // Add 15% margin to match _project's 1.15 factor.
    if (rho > _angularRadius * 1.15) return null;

    if (rho < 0.0001) return _cameraCenter.clone();

    final c = rho;
    final lat0 = _cameraCenter.y * _deg2rad;
    final lng0 = _cameraCenter.x * _deg2rad;

    final lat = asin(
      (cos(c) * sin(lat0) + dy / scale * sin(c) * cos(lat0) / rho).clamp(
        -1.0,
        1.0,
      ),
    );
    final lng = lng0 +
        atan2(
          dx / scale * sin(c),
          rho * cos(lat0) * cos(c) - dy / scale * sin(lat0) * sin(c),
        );

    return Vector2(lng * 180 / pi, lat * 180 / pi);
  }

  /// Forward projection: (lng, lat) → screen position.
  Vector2 latLngToScreen(Vector2 latLng, Vector2 screenSize) {
    final globeRadius = _globeScreenRadius(screenSize);
    final result = _project(latLng.x, latLng.y, screenSize, globeRadius);
    if (result != null) {
      return Vector2(result.dx, result.dy);
    }
    final clamped = _projectClamped(
      latLng.x,
      latLng.y,
      screenSize,
      globeRadius,
    );
    return Vector2(clamped.dx, clamped.dy);
  }
}
