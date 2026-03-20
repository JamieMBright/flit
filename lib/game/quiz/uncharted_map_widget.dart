/// Map widget for the Uncharted game mode.
///
/// Renders all area outlines on a dark background. Revealed areas are
/// filled with colour and labelled. Supports pinch-to-zoom and pan.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../map/region.dart';

/// A zoomable, pannable map showing outlines of all areas for a region.
///
/// Areas in [revealedCodes] are filled and labelled; the rest are
/// outline-only silhouettes.
class UnchartedMapWidget extends StatefulWidget {
  const UnchartedMapWidget({
    super.key,
    required this.region,
    required this.revealedCodes,
    this.lastRevealedCode,
  });

  final GameRegion region;
  final Set<String> revealedCodes;

  /// The most recently revealed code — shown with a highlight animation.
  final String? lastRevealedCode;

  @override
  State<UnchartedMapWidget> createState() => _UnchartedMapWidgetState();
}

class _UnchartedMapWidgetState extends State<UnchartedMapWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flashController;
  final TransformationController _transformController =
      TransformationController();
  late List<RegionalArea> _areas;

  @override
  void initState() {
    super.initState();
    _areas = RegionalData.getAreas(widget.region);
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void didUpdateWidget(UnchartedMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lastRevealedCode != null &&
        widget.lastRevealedCode != oldWidget.lastRevealedCode) {
      _flashController.forward(from: 0);
    }
    if (widget.region != oldWidget.region) {
      _areas = RegionalData.getAreas(widget.region);
    }
  }

  @override
  void dispose() {
    _flashController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _flashController,
          builder: (context, _) {
            return InteractiveViewer(
              transformationController: _transformController,
              minScale: 1.0,
              maxScale: 25.0,
              boundaryMargin: const EdgeInsets.all(100),
              child: CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _UnchartedMapPainter(
                  areas: _areas,
                  region: widget.region,
                  revealedCodes: widget.revealedCodes,
                  lastRevealedCode: widget.lastRevealedCode,
                  flashProgress: _flashController.value,
                  zoomScale: _currentZoomScale,
                ),
              ),
            );
          },
        );
      },
    );
  }

  double get _currentZoomScale {
    final matrix = _transformController.value;
    return matrix.getMaxScaleOnAxis();
  }
}

class _UnchartedMapPainter extends CustomPainter {
  _UnchartedMapPainter({
    required this.areas,
    required this.region,
    required this.revealedCodes,
    required this.lastRevealedCode,
    required this.flashProgress,
    required this.zoomScale,
  });

  final List<RegionalArea> areas;
  final GameRegion region;
  final Set<String> revealedCodes;
  final String? lastRevealedCode;
  final double flashProgress;
  final double zoomScale;

  @override
  void paint(Canvas canvas, Size size) {
    // Background.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0D1B2A),
    );

    final bounds = region.bounds;
    final transform = _GeoTransform(
      minLng: bounds[0],
      maxLng: bounds[2],
      minLat: bounds[1],
      maxLat: bounds[3],
      canvasWidth: size.width,
      canvasHeight: size.height,
    );

    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / zoomScale
      ..color = const Color(0xFF3A5A7A);

    final revealedFill = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF1B6B4A);

    final revealedStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 / zoomScale
      ..color = const Color(0xFF2ECC71);

    for (final area in areas) {
      final path = _buildAreaPath(area, transform);
      final isRevealed = revealedCodes.contains(area.code);
      final isFlashing = area.code == lastRevealedCode && flashProgress < 1.0;
      final tiny = _isTinyArea(area, transform);

      if (isRevealed) {
        if (isFlashing) {
          // Flash effect: bright green fading to normal.
          final flashColor = Color.lerp(
            const Color(0xFF2ECC71),
            const Color(0xFF1B6B4A),
            flashProgress,
          )!;
          if (tiny) {
            _drawTinyMarker(canvas, area, transform,
                fill: Paint()..color = flashColor, stroke: revealedStroke);
          } else {
            canvas.drawPath(path, Paint()..color = flashColor);
          }
        } else {
          if (tiny) {
            _drawTinyMarker(canvas, area, transform,
                fill: revealedFill, stroke: revealedStroke);
          } else {
            canvas.drawPath(path, revealedFill);
          }
        }
        if (!tiny) canvas.drawPath(path, revealedStroke);
        _drawLabel(canvas, area, transform);
      } else {
        // Unrevealed: outline or marker for tiny areas.
        if (tiny) {
          _drawTinyMarker(canvas, area, transform, stroke: outlinePaint);
        } else {
          canvas.drawPath(path, outlinePaint);
        }
      }
    }
  }

  /// Minimum canvas diameter (logical pixels) below which an area gets a
  /// visible marker instead of its raw polygon outline.
  static const double _tinyThreshold = 14.0;

  /// Radius of the expanded marker drawn for tiny areas.
  static const double _markerRadius = 8.0;

  /// Whether an area is too small on canvas to be visible as a polygon.
  bool _isTinyArea(RegionalArea area, _GeoTransform transform) {
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

  /// Draw a circular marker for a tiny area so it's visible on the map.
  void _drawTinyMarker(
    Canvas canvas,
    RegionalArea area,
    _GeoTransform transform, {
    Paint? fill,
    required Paint stroke,
  }) {
    final centroid = _computeCentroid(area, transform);
    if (centroid == null) return;
    final r = _markerRadius / zoomScale;
    if (fill != null) {
      canvas.drawCircle(centroid, r, fill);
    }
    canvas.drawCircle(centroid, r, stroke);
  }

  Path _buildAreaPath(RegionalArea area, _GeoTransform transform) {
    final path = Path();
    final rings = area.polygons ?? [area.points];
    for (final ring in rings) {
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

  void _drawLabel(Canvas canvas, RegionalArea area, _GeoTransform transform) {
    final centroid = _computeCentroid(area, transform);
    if (centroid == null) return;

    // Scale font size inversely with zoom so it doesn't get huge when zoomed.
    final fontSize = (10.0 / zoomScale).clamp(3.0, 14.0);

    final textPainter = TextPainter(
      text: TextSpan(
        text: area.name,
        style: TextStyle(
          color: const Color(0xFFE0F0E0),
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          shadows: const [
            Shadow(color: Color(0xFF000000), blurRadius: 2),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    textPainter.paint(
      canvas,
      centroid - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  Offset? _computeCentroid(RegionalArea area, _GeoTransform transform) {
    final points = area.points;
    if (points.isEmpty) return null;
    var cx = 0.0;
    var cy = 0.0;
    for (final p in points) {
      final canvasP = transform.toCanvas(p.x, p.y);
      cx += canvasP.dx;
      cy += canvasP.dy;
    }
    return Offset(cx / points.length, cy / points.length);
  }

  @override
  bool shouldRepaint(_UnchartedMapPainter oldDelegate) {
    return revealedCodes.length != oldDelegate.revealedCodes.length ||
        lastRevealedCode != oldDelegate.lastRevealedCode ||
        flashProgress != oldDelegate.flashProgress ||
        zoomScale != oldDelegate.zoomScale;
  }
}

/// Longitude/latitude → canvas coordinate transformer.
class _GeoTransform {
  const _GeoTransform({
    required this.minLng,
    required this.maxLng,
    required this.minLat,
    required this.maxLat,
    required this.canvasWidth,
    required this.canvasHeight,
  });

  final double minLng, maxLng, minLat, maxLat;
  final double canvasWidth, canvasHeight;

  Offset toCanvas(double lng, double lat) {
    // Aspect-correct projection.
    final lngRange = maxLng - minLng;
    final latRange = maxLat - minLat;
    final midLat = (minLat + maxLat) / 2;
    final aspectCorrection = math.cos(midLat * math.pi / 180);

    final effectiveLngRange = lngRange * aspectCorrection;
    final scale = math.min(
      canvasWidth / effectiveLngRange,
      canvasHeight / latRange,
    );

    final projectedWidth = effectiveLngRange * scale;
    final projectedHeight = latRange * scale;
    final offsetX = (canvasWidth - projectedWidth) / 2;
    final offsetY = (canvasHeight - projectedHeight) / 2;

    final x = offsetX + ((lng - minLng) * aspectCorrection) * scale;
    final y = offsetY + ((maxLat - lat)) * scale;
    return Offset(x, y);
  }
}
