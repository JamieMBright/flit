import 'package:flame/components.dart' hide Matrix4;
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return InteractiveViewer(
              transformationController: _transformController,
              minScale: 1.0,
              maxScale: 5.0,
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
    // Transform the tap position from screen to content coordinates
    final matrix = _transformController.value;
    final inverseMatrix = Matrix4.inverted(matrix);
    final transformed = MatrixUtils.transformPoint(
      inverseMatrix,
      position,
    );

    final painter = _RegionMapPainter(
      region: widget.region,
      stateVisuals: widget.stateVisuals,
      highlightCode: widget.highlightCode,
      pulseValue: 0,
      showLabels: widget.showLabels,
      eliminatedCodes: widget.eliminatedCodes,
      correctCodes: widget.correctCodes,
    );

    final code = painter.hitTestArea(transformed, size);
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
  });

  final GameRegion region;
  final Map<String, StateVisual> stateVisuals;
  final String? highlightCode;
  final double pulseValue;
  final bool showLabels;
  final Set<String> eliminatedCodes;
  final Set<String> correctCodes;

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

    // Draw clean borders (subtle, single pass)
    final borderPaint = Paint()
      ..color = const Color(0xFF1A2A32).withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    for (final area in areas) {
      if (eliminatedCodes.contains(area.code)) continue;
      final path = _buildPath(area.points, transform, polygons: area.polygons);
      canvas.drawPath(path, borderPaint);
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
    final fillColor = _getFillColor(status, isHighlighted, isCorrectlyGuessed);
    canvas.drawPath(path, Paint()..color = fillColor);
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

  String? hitTestArea(Offset position, Size size) {
    final areas = RegionalData.getAreas(region);
    final transform = _regionTransform(size);

    // Collect all matching regions to handle border overlaps.
    final matches = <String>[];
    for (final area in areas) {
      // Can't tap eliminated areas
      if (eliminatedCodes.contains(area.code)) continue;
      if (_pointInPolygon(position, area.points, transform)) {
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
