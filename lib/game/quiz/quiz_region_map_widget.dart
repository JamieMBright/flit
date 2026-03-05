import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../map/region.dart';
import 'quiz_map_widget.dart';

/// Generic region map widget for Flight School quiz mode on non-US regions.
///
/// Renders any set of [RegionalArea] polygons within the region's bounds.
/// Supports tap detection, visual feedback, and labels.
class QuizRegionMapWidget extends StatefulWidget {
  const QuizRegionMapWidget({
    super.key,
    required this.region,
    required this.stateVisuals,
    required this.onStateTapped,
    this.highlightCode,
    this.showLabels = true,
  });

  final GameRegion region;
  final Map<String, StateVisual> stateVisuals;
  final OnStateTapped onStateTapped;
  final String? highlightCode;
  final bool showLabels;

  @override
  State<QuizRegionMapWidget> createState() => _QuizRegionMapWidgetState();
}

class _QuizRegionMapWidgetState extends State<QuizRegionMapWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return GestureDetector(
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
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _handleTap(Offset position, Size size) {
    final painter = _RegionMapPainter(
      region: widget.region,
      stateVisuals: widget.stateVisuals,
      highlightCode: widget.highlightCode,
      pulseValue: 0,
      showLabels: widget.showLabels,
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
  });

  final GameRegion region;
  final Map<String, StateVisual> stateVisuals;
  final String? highlightCode;
  final double pulseValue;
  final bool showLabels;

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

    // Draw borders
    for (final area in areas) {
      _drawAreaBorder(canvas, area, transform);
    }

    // Draw labels for larger areas (only when enabled)
    if (showLabels) {
      for (final area in areas) {
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

    final visual = stateVisuals[area.code];
    final status = visual?.status ?? StateVisualStatus.idle;
    final isHighlighted = highlightCode == area.code;

    final path = _buildPath(area.points, transform);
    final fillColor = _getFillColor(status, isHighlighted);
    canvas.drawPath(path, Paint()..color = fillColor);
  }

  void _drawAreaBorder(
    Canvas canvas,
    RegionalArea area,
    _GeoTransform transform,
  ) {
    if (area.points.isEmpty) return;
    final path = _buildPath(area.points, transform);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF3A5A6A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
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

  Color _getFillColor(StateVisualStatus status, bool isHighlighted) {
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

  Path _buildPath(List<Vector2> points, _GeoTransform transform) {
    final path = Path();
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

    for (final area in areas) {
      if (_pointInPolygon(position, area.points, transform)) {
        return area.code;
      }
    }
    return null;
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
