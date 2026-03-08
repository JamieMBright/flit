import 'dart:ui' as ui;

import 'package:flame/components.dart' hide Matrix4;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../map/region.dart';
import 'quiz_map_widget.dart';

/// Generic region map widget for Flight School quiz mode on non-US regions.
///
/// Renders any set of [RegionalArea] polygons within the region's bounds.
/// Supports pinch-to-zoom, tap detection, visual feedback, and labels.
class QuizRegionMapWidget extends StatefulWidget {
  const QuizRegionMapWidget({
    super.key,
    required this.region,
    required this.stateVisuals,
    required this.onStateTapped,
    this.highlightCode,
    this.showLabels = true,
    this.eliminatedCodes = const {},
    this.correctCodes = const {},
  });

  final GameRegion region;
  final Map<String, StateVisual> stateVisuals;
  final OnStateTapped onStateTapped;
  final String? highlightCode;
  final bool showLabels;

  /// Codes that have been eliminated (hidden) during progressive hints.
  final Set<String> eliminatedCodes;

  /// Codes that were correctly guessed (shown in muted green).
  final Set<String> correctCodes;

  @override
  State<QuizRegionMapWidget> createState() => _QuizRegionMapWidgetState();
}

class _QuizRegionMapWidgetState extends State<QuizRegionMapWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  final TransformationController _transformController =
      TransformationController();
  ui.Image? _satelliteImage;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _loadSatelliteImage();
  }

  Future<void> _loadSatelliteImage() async {
    final data = await rootBundle.load('assets/textures/blue_marble.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() => _satelliteImage = frame.image);
    }
  }

  @override
  void dispose() {
    _satelliteImage?.dispose();
    _pulseController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: Listenable.merge([_pulseController, _transformController]),
          builder: (context, child) {
            final scale = _transformController.value.getMaxScaleOnAxis();
            return InteractiveViewer(
              transformationController: _transformController,
              minScale: 1.0,
              maxScale: 20.0,
              panEnabled: true,
              scaleEnabled: true,
              child: GestureDetector(
                onTapDown: (details) =>
                    _handleTap(details.localPosition, constraints.biggest),
                child: CustomPaint(
                  size: constraints.biggest,
                  painter: _RegionMapPainter(
                    region: widget.region,
                    stateVisuals: widget.stateVisuals,
                    highlightCode: widget.highlightCode,
                    pulseValue: _pulseController.value,
                    showLabels: widget.showLabels,
                    eliminatedCodes: widget.eliminatedCodes,
                    correctCodes: widget.correctCodes,
                    zoomScale: scale,
                    satelliteImage: _satelliteImage,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _handleTap(Offset position, Size size) {
    // GestureDetector is a child of InteractiveViewer's Transform widget,
    // so localPosition is already in content coordinates. No inverse
    // transform needed — applying one would double-invert and shift the
    // tap point proportionally to the zoom level.
    //
    // However, the actual zoom scale IS needed so that tiny-area marker
    // hit targets shrink as the user zooms in (countries that are too
    // small to tap at 1× become normal polygons at 5×).
    final scale = _transformController.value.getMaxScaleOnAxis();
    final painter = _RegionMapPainter(
      region: widget.region,
      stateVisuals: widget.stateVisuals,
      highlightCode: widget.highlightCode,
      pulseValue: 0,
      showLabels: widget.showLabels,
      eliminatedCodes: widget.eliminatedCodes,
      correctCodes: widget.correctCodes,
      zoomScale: scale,
      satelliteImage: _satelliteImage,
    );

    final code = painter.hitTestArea(position, size);
    if (code != null) {
      widget.onStateTapped(code);
    }
  }
}

class _RegionMapPainter extends CustomPainter {
  _RegionMapPainter({
    required this.region,
    required this.stateVisuals,
    required this.highlightCode,
    required this.pulseValue,
    this.showLabels = true,
    this.eliminatedCodes = const {},
    this.correctCodes = const {},
    this.zoomScale = 1.0,
    this.satelliteImage,
  });

  final GameRegion region;
  final Map<String, StateVisual> stateVisuals;
  final String? highlightCode;
  final double pulseValue;
  final bool showLabels;
  final Set<String> eliminatedCodes;
  final Set<String> correctCodes;
  final double zoomScale;
  final ui.Image? satelliteImage;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF1A2A32),
    );

    final areas = RegionalData.getAreas(region);
    final transform = _regionTransform(size);

    // Draw fills
    for (final area in areas) {
      _drawArea(canvas, size, area, transform);
    }

    // Draw clean borders (subtle, single pass).
    // Divide strokeWidth by zoom scale so borders stay visually constant.
    final borderPaint = Paint()
      ..color = const Color(0xFF1A2A32).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / zoomScale
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    for (final area in areas) {
      if (eliminatedCodes.contains(area.code)) continue;
      final path = _buildPath(area.points, transform, polygons: area.polygons);
      canvas.drawPath(path, borderPaint);
    }

    // Draw expanded markers for tiny areas (below minimum canvas size).
    // These ensure microstates and small islands are visible and tappable.
    for (final area in areas) {
      if (eliminatedCodes.contains(area.code)) continue;
      if (_isTinyArea(area, transform, size)) {
        _drawTinyMarker(canvas, size, area, transform);
      }
    }

    // Draw labels for larger areas (only when enabled)
    if (showLabels) {
      for (final area in areas) {
        if (eliminatedCodes.contains(area.code)) continue;
        _drawAreaLabel(canvas, size, area, transform);
      }
    }
  }

  _GeoTransform _regionTransform(Size size) {
    final bounds = region.bounds;
    final minLng = bounds[0];
    final minLat = bounds[1];
    final maxLng = bounds[2];
    final maxLat = bounds[3];

    final padX = size.width * 0.04;
    final padY = size.height * 0.04;
    final drawW = size.width - padX * 2;
    final drawH = size.height - padY * 2;

    // Preserve aspect ratio using a Mercator-like correction
    final lngSpan = maxLng - minLng;
    final latSpan = maxLat - minLat;
    final midLat = (minLat + maxLat) / 2;
    // Rough cos correction for latitude distortion
    final cosLat = _cos(midLat * 3.14159265 / 180.0);
    final geoAspect = (lngSpan * cosLat) / latSpan;
    final canvasAspect = drawW / drawH;

    double usedW, usedH;
    if (geoAspect > canvasAspect) {
      usedW = drawW;
      usedH = drawW / geoAspect;
    } else {
      usedH = drawH;
      usedW = drawH * geoAspect;
    }

    final offsetX = padX + (drawW - usedW) / 2;
    final offsetY = padY + (drawH - usedH) / 2;

    return _GeoTransform(
      minLng: minLng,
      maxLng: maxLng,
      minLat: minLat,
      maxLat: maxLat,
      offsetX: offsetX,
      offsetY: offsetY,
      width: usedW,
      height: usedH,
    );
  }

  static double _cos(double radians) {
    // Taylor approximation good enough for aspect ratio correction
    final x2 = radians * radians;
    return 1.0 - x2 / 2.0 + x2 * x2 / 24.0;
  }

  void _drawArea(
    Canvas canvas,
    Size size,
    RegionalArea area,
    _GeoTransform transform,
  ) {
    if (area.points.isEmpty) return;

    // Hidden (eliminated) countries
    if (eliminatedCodes.contains(area.code)) return;

    final visual = stateVisuals[area.code];
    final status = visual?.status ?? StateVisualStatus.idle;
    final isHighlighted = highlightCode == area.code;
    final isCorrectlyGuessed = correctCodes.contains(area.code);

    final path = _buildPath(area.points, transform, polygons: area.polygons);

    // Reveal satellite imagery for correctly guessed countries
    if ((isCorrectlyGuessed || status == StateVisualStatus.correct) &&
        satelliteImage != null) {
      _drawSatelliteFill(canvas, path, transform);
    } else {
      final fillColor =
          _getFillColor(status, isHighlighted, isCorrectlyGuessed);
      canvas.drawPath(path, Paint()..color = fillColor);
    }
  }

  /// Draw the Blue Marble satellite texture clipped to a polygon path.
  ///
  /// Maps the equirectangular satellite image (full world: -180..180 lng,
  /// -90..90 lat) to the region's canvas transform so the texture aligns
  /// with the geographic coordinates.
  void _drawSatelliteFill(
    Canvas canvas,
    Path path,
    _GeoTransform transform,
  ) {
    final img = satelliteImage!;

    // Map from geographic bounds to image pixels:
    // Image pixel x = ((lng + 180) / 360) * imageWidth
    // Image pixel y = ((90 - lat) / 180) * imageHeight
    //
    // We need the source rect in the satellite image that corresponds to
    // the region's geographic bounds.
    final srcLeft = ((transform.minLng + 180.0) / 360.0) * img.width;
    final srcRight = ((transform.maxLng + 180.0) / 360.0) * img.width;
    final srcTop = ((90.0 - transform.maxLat) / 180.0) * img.height;
    final srcBottom = ((90.0 - transform.minLat) / 180.0) * img.height;

    final srcRect = Rect.fromLTRB(srcLeft, srcTop, srcRight, srcBottom);

    // Destination rect is the region's canvas area
    final dstRect = Rect.fromLTWH(
      transform.offsetX,
      transform.offsetY,
      transform.width,
      transform.height,
    );

    canvas.save();
    canvas.clipPath(path);
    canvas.drawImageRect(
      img,
      srcRect,
      dstRect,
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();
  }

  void _drawAreaLabel(
    Canvas canvas,
    Size size,
    RegionalArea area,
    _GeoTransform transform,
  ) {
    final centroid = _centroid(area.points);
    final pos = transform.toCanvas(centroid.x, centroid.y);

    if (pos.dx < 0 ||
        pos.dx > size.width ||
        pos.dy < 0 ||
        pos.dy > size.height) {
      return;
    }

    final visual = stateVisuals[area.code];
    final status = visual?.status ?? StateVisualStatus.idle;
    final textColor = status == StateVisualStatus.completed
        ? const Color(0xFF5A7A8A)
        : const Color(0xFFB0C8D8);

    final textPainter = TextPainter(
      text: TextSpan(
        text: area.code,
        style: TextStyle(
          color: textColor,
          fontSize: 7,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2),
    );
  }

  Color _getFillColor(
    StateVisualStatus status,
    bool isHighlighted,
    bool isCorrectlyGuessed,
  ) {
    // Correctly guessed countries show muted green
    if (isCorrectlyGuessed &&
        status != StateVisualStatus.correct &&
        status != StateVisualStatus.wrong) {
      return const Color(0xFF1E4A2A);
    }

    if (isHighlighted) {
      final opacity = 0.4 + 0.4 * pulseValue;
      return Color.fromRGBO(232, 122, 90, opacity);
    }
    switch (status) {
      case StateVisualStatus.idle:
        return const Color(0xFF2A4A5A);
      case StateVisualStatus.correct:
        return const Color(0xFF2A8A4A);
      case StateVisualStatus.wrong:
        return const Color(0xFFAA3333);
      case StateVisualStatus.completed:
        return const Color(0xFF1E3340);
    }
  }

  Path _buildPath(List<Vector2> points, _GeoTransform transform,
      {List<List<Vector2>>? polygons}) {
    final path = Path();

    // When separate polygon rings are available, draw each as its own
    // sub-path so disjoint polygons (islands, exclaves) don't produce
    // stretching artefacts.
    if (polygons != null && polygons.isNotEmpty) {
      for (final ring in polygons) {
        if (ring.isEmpty) continue;
        final first = transform.toCanvas(ring.first.x, ring.first.y);
        path.moveTo(first.dx, first.dy);
        for (var i = 1; i < ring.length; i++) {
          final p = transform.toCanvas(ring[i].x, ring[i].y);
          path.lineTo(p.dx, p.dy);
        }
        path.close();
      }
      return path;
    }

    // Fallback: single flat list of points.
    if (points.isEmpty) return path;
    final first = transform.toCanvas(points.first.x, points.first.y);
    path.moveTo(first.dx, first.dy);

    for (var i = 1; i < points.length; i++) {
      final p = transform.toCanvas(points[i].x, points[i].y);
      path.lineTo(p.dx, p.dy);
    }

    path.close();
    return path;
  }

  Vector2 _centroid(List<Vector2> points) {
    if (points.isEmpty) return Vector2.zero();
    var sumX = 0.0;
    var sumY = 0.0;
    for (final p in points) {
      sumX += p.x;
      sumY += p.y;
    }
    return Vector2(sumX / points.length, sumY / points.length);
  }

  /// Minimum canvas diameter (in logical pixels) below which an area is
  /// considered "tiny" and gets an expanded marker.
  static const double _tinyThreshold = 18.0;

  /// Radius of the expanded marker drawn for tiny areas.
  static const double _markerRadius = 10.0;

  /// Whether an area's polygon footprint on canvas is too small to tap.
  bool _isTinyArea(RegionalArea area, _GeoTransform transform, Size size) {
    if (area.points.length < 3) return true;
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final p in area.points) {
      final cp = transform.toCanvas(p.x, p.y);
      if (cp.dx < minX) minX = cp.dx;
      if (cp.dx > maxX) maxX = cp.dx;
      if (cp.dy < minY) minY = cp.dy;
      if (cp.dy > maxY) maxY = cp.dy;
    }
    final w = (maxX - minX) * zoomScale;
    final h = (maxY - minY) * zoomScale;
    return w < _tinyThreshold && h < _tinyThreshold;
  }

  /// Draw a visible labeled marker for a tiny area (microstate / small island).
  void _drawTinyMarker(
    Canvas canvas,
    Size size,
    RegionalArea area,
    _GeoTransform transform,
  ) {
    final centroid = _centroid(area.points);
    final pos = transform.toCanvas(centroid.x, centroid.y);
    if (pos.dx < 0 || pos.dx > size.width || pos.dy < 0 || pos.dy > size.height)
      return;

    final visual = stateVisuals[area.code];
    final status = visual?.status ?? StateVisualStatus.idle;
    final isHighlighted = highlightCode == area.code;
    final isCorrectlyGuessed = correctCodes.contains(area.code);

    final r = _markerRadius / zoomScale;

    // Background circle
    Color fillColor;
    if (isHighlighted) {
      final opacity = 0.6 + 0.3 * pulseValue;
      fillColor = Color.fromRGBO(232, 122, 90, opacity);
    } else if (isCorrectlyGuessed || status == StateVisualStatus.correct) {
      fillColor = const Color(0xFF2A8A4A);
    } else if (status == StateVisualStatus.wrong) {
      fillColor = const Color(0xFFAA3333);
    } else {
      fillColor = const Color(0xFF3A6A7A);
    }
    canvas.drawCircle(pos, r, Paint()..color = fillColor);

    // Border ring
    canvas.drawCircle(
      pos,
      r,
      Paint()
        ..color = const Color(0xFF8AB0C0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 / zoomScale,
    );

    // Label
    final fontSize = 6.0 / zoomScale;
    final tp = TextPainter(
      text: TextSpan(
        text: area.code,
        style: TextStyle(
          color: const Color(0xFFE0F0FF),
          fontSize: fontSize.clamp(4.0, 8.0),
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  String? hitTestArea(Offset position, Size size) {
    final areas = RegionalData.getAreas(region);
    final transform = _regionTransform(size);

    // First pass: check tiny area markers (expanded circular hit targets).
    // These take priority because they're drawn on top.
    for (final area in areas) {
      if (eliminatedCodes.contains(area.code)) continue;
      if (_isTinyArea(area, transform, size)) {
        final centroid = _centroid(area.points);
        final pos = transform.toCanvas(centroid.x, centroid.y);
        final dx = position.dx - pos.dx;
        final dy = position.dy - pos.dy;
        // Use a generous tap radius (larger than the visual marker)
        final tapRadius = _markerRadius * 1.5 / zoomScale;
        if (dx * dx + dy * dy <= tapRadius * tapRadius) {
          return area.code;
        }
      }
    }

    // Second pass: standard polygon hit-testing.
    final matches = <String>[];
    for (final area in areas) {
      if (eliminatedCodes.contains(area.code)) continue;
      if (_hitTestPolygons(position, area, transform)) {
        matches.add(area.code);
      }
    }

    if (matches.isEmpty) return null;
    if (matches.length == 1) return matches.first;

    // Multiple overlapping polygons — pick the one whose centroid is closest.
    String? best;
    var bestDist = double.infinity;
    for (final code in matches) {
      final area = areas.firstWhere((a) => a.code == code);
      final centroid = _canvasCentroid(area.points, transform);
      final dx = centroid.dx - position.dx;
      final dy = centroid.dy - position.dy;
      final dist = dx * dx + dy * dy;
      if (dist < bestDist) {
        bestDist = dist;
        best = code;
      }
    }
    return best;
  }

  /// Compute the centroid of a polygon in canvas coordinates.
  Offset _canvasCentroid(List<Vector2> polygon, _GeoTransform transform) {
    if (polygon.isEmpty) return Offset.zero;
    var sumX = 0.0;
    var sumY = 0.0;
    for (final p in polygon) {
      final cp = transform.toCanvas(p.x, p.y);
      sumX += cp.dx;
      sumY += cp.dy;
    }
    return Offset(sumX / polygon.length, sumY / polygon.length);
  }

  /// Hit-test using individual polygon rings when available.
  ///
  /// Multi-polygon countries (e.g. France with mainland + Corsica) must test
  /// each ring separately. Using the flat `points` list (all rings concatenated)
  /// creates a single malformed polygon that stretches across unrelated areas.
  bool _hitTestPolygons(
    Offset point,
    RegionalArea area,
    _GeoTransform transform,
  ) {
    if (area.polygons != null && area.polygons!.isNotEmpty) {
      for (final ring in area.polygons!) {
        if (_pointInPolygon(point, ring, transform)) return true;
      }
      return false;
    }
    // Fallback: single polygon from flat point list
    return _pointInPolygon(point, area.points, transform);
  }

  bool _pointInPolygon(
    Offset point,
    List<Vector2> polygon,
    _GeoTransform transform,
  ) {
    if (polygon.length < 3) return false;

    var inside = false;
    var j = polygon.length - 1;

    for (var i = 0; i < polygon.length; i++) {
      final pi = transform.toCanvas(polygon[i].x, polygon[i].y);
      final pj = transform.toCanvas(polygon[j].x, polygon[j].y);

      if (((pi.dy > point.dy) != (pj.dy > point.dy)) &&
          (point.dx <
              (pj.dx - pi.dx) * (point.dy - pi.dy) / (pj.dy - pi.dy) + pi.dx)) {
        inside = !inside;
      }
      j = i;
    }

    return inside;
  }

  @override
  bool shouldRepaint(covariant _RegionMapPainter oldDelegate) {
    return oldDelegate.highlightCode != highlightCode ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.eliminatedCodes != eliminatedCodes ||
        oldDelegate.correctCodes != correctCodes ||
        true;
  }
}

class _GeoTransform {
  const _GeoTransform({
    required this.minLng,
    required this.maxLng,
    required this.minLat,
    required this.maxLat,
    required this.offsetX,
    required this.offsetY,
    required this.width,
    required this.height,
  });

  final double minLng;
  final double maxLng;
  final double minLat;
  final double maxLat;
  final double offsetX;
  final double offsetY;
  final double width;
  final double height;

  Offset toCanvas(double lng, double lat) {
    final x = offsetX + ((lng - minLng) / (maxLng - minLng)) * width;
    final y = offsetY + ((maxLat - lat) / (maxLat - minLat)) * height;
    return Offset(x, y);
  }
}
