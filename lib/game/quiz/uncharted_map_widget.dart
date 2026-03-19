/// Map widget for the Uncharted game mode.
///
/// Renders all area outlines on a dark background. Revealed areas show
/// the Blue Marble satellite texture clipped to the country polygon.
/// Supports pinch-to-zoom and pan.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../map/region.dart';
import 'border_smoothing.dart';

/// A zoomable, pannable map showing outlines of all areas for a region.
///
/// Areas in [revealedCodes] show the Blue Marble satellite imagery clipped
/// to the polygon shape; the rest are outline-only silhouettes.
class UnchartedMapWidget extends StatefulWidget {
  const UnchartedMapWidget({
    super.key,
    required this.region,
    required this.revealedCodes,
    this.lastRevealedCode,
    this.capitalsMode = false,
    this.pingProgress = 0.0,
  });

  final GameRegion region;
  final Set<String> revealedCodes;

  /// The most recently revealed code — shown with a highlight animation.
  final String? lastRevealedCode;

  /// When true, labels show capital name with red dot + (country code).
  final bool capitalsMode;

  /// 0.0 = no ping, 0.0-1.0 = ping animation progress for unrevealed areas.
  final double pingProgress;

  @override
  State<UnchartedMapWidget> createState() => _UnchartedMapWidgetState();
}

class _UnchartedMapWidgetState extends State<UnchartedMapWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flashController;
  final TransformationController _transformController =
      TransformationController();
  late List<RegionalArea> _areas;
  ui.Image? _satelliteImage;

  @override
  void initState() {
    super.initState();
    _areas = RegionalData.getAreas(widget.region);
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
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
    _satelliteImage?.dispose();
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
              constrained: false,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              child: CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _UnchartedMapPainter(
                  areas: _areas,
                  region: widget.region,
                  revealedCodes: widget.revealedCodes,
                  lastRevealedCode: widget.lastRevealedCode,
                  flashProgress: _flashController.value,
                  zoomScale: _currentZoomScale,
                  satelliteImage: _satelliteImage,
                  capitalsMode: widget.capitalsMode,
                  pingProgress: widget.pingProgress,
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
    this.satelliteImage,
    this.capitalsMode = false,
    this.pingProgress = 0.0,
  });

  final List<RegionalArea> areas;
  final GameRegion region;
  final Set<String> revealedCodes;
  final String? lastRevealedCode;
  final double flashProgress;
  final double zoomScale;
  final ui.Image? satelliteImage;
  final bool capitalsMode;
  final double pingProgress;

  @override
  void paint(Canvas canvas, Size size) {
    // Background.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0D1B2A),
    );

    final bounds = region.bounds;
    final transform = _GeoTransform.fromBounds(
      minLng: bounds[0],
      maxLng: bounds[2],
      minLat: bounds[1],
      maxLat: bounds[3],
      canvasWidth: size.width,
      canvasHeight: size.height,
    );

    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / zoomScale
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = const Color(0xFF3A5A7A);

    final revealedStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / zoomScale
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = const Color(0xFF2ECC71);

    // First pass: draw all fills, strokes, and markers.
    // Labels are deferred to a second pass so they aren't clipped by
    // neighbouring countries' satellite fills.
    final revealedAreas = <RegionalArea>[];

    for (final area in areas) {
      final path = _buildAreaPath(area, transform);
      final isRevealed = revealedCodes.contains(area.code);
      final isFlashing = area.code == lastRevealedCode && flashProgress < 1.0;

      final isTiny = _isTinyArea(area, transform, size);

      if (isRevealed) {
        if (isTiny) {
          // For tiny areas, reveal satellite fill inside the rounded rect
          // bounding box so the country is actually visible.
          final rrect = _tinyAreaRRect(area, transform);
          if (satelliteImage != null) {
            _drawSatelliteRRect(canvas, rrect, transform, size);
          } else {
            canvas.drawRRect(
              rrect,
              Paint()..color = const Color(0xFF1B6B4A),
            );
          }

          if (isFlashing) {
            final flashAlpha = (1.0 - flashProgress).clamp(0.0, 1.0);
            canvas.drawRRect(
              rrect,
              Paint()
                ..color = const Color(0xFF2ECC71).withValues(alpha: flashAlpha),
            );
          }

          // Green dashed border for revealed tiny areas.
          final rrectPath = Path()..addRRect(rrect);
          _drawDashedPath(canvas, rrectPath, revealedStroke, 16);
        } else {
          // Reveal satellite imagery clipped to the area polygon.
          if (satelliteImage != null) {
            _drawSatelliteFill(canvas, path, transform, size);
          } else {
            // Fallback if image hasn't loaded yet.
            canvas.drawPath(
              path,
              Paint()..color = const Color(0xFF1B6B4A),
            );
          }

          if (isFlashing) {
            // Flash overlay: bright green fading out to reveal satellite.
            final flashAlpha = (1.0 - flashProgress).clamp(0.0, 1.0);
            canvas.drawPath(
              path,
              Paint()
                ..color = const Color(0xFF2ECC71).withValues(alpha: flashAlpha),
            );
          }

          canvas.drawPath(path, revealedStroke);
        }
        revealedAreas.add(area);
      } else {
        // Unrevealed: just outline.
        canvas.drawPath(path, outlinePaint);

        // Draw dashed rounded polygon marker for tiny countries.
        if (isTiny) {
          _drawTinyMarker(canvas, area, transform);
        }

        // Ping flash: briefly highlight unrevealed areas.
        if (pingProgress > 0.0 && pingProgress < 1.0) {
          // Pulse alpha: rise then fall.
          final alpha = (pingProgress < 0.5
                  ? pingProgress * 2.0
                  : (1.0 - pingProgress) * 2.0)
              .clamp(0.0, 1.0);
          canvas.drawPath(
            path,
            Paint()
              ..color = const Color(0xFFE8A55A).withValues(alpha: alpha * 0.35),
          );
        }
      }
    }

    // Second pass: draw labels on top of all fills so they're never clipped
    // by neighbouring countries' satellite texture.
    for (final area in revealedAreas) {
      _drawLabel(canvas, area, transform);
    }
  }

  /// Minimum canvas diameter below which an area is considered "tiny".
  static const double _tinyThreshold = 18.0;

  /// Radius of the dashed circle marker for tiny areas.
  static const double _markerRadius = 10.0;

  /// Area codes that always get an expanded marker (micro-states & islands).
  /// Uses the shared set from border_smoothing.dart for consistency.
  static const Set<String> _alwaysTinyCodes = alwaysTinyCodes;

  /// Whether an area's polygon footprint on canvas is too small to see.
  bool _isTinyArea(RegionalArea area, _GeoTransform transform, Size size) {
    if (_alwaysTinyCodes.contains(area.code)) return true;
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

  /// Compute the bounding box of a tiny area's points on canvas, expanded
  /// to a minimum visible size and returned as a rounded rectangle.
  RRect _tinyAreaRRect(
    RegionalArea area,
    _GeoTransform transform,
  ) {
    final points = area.points;
    if (points.isEmpty) {
      final centroid = _computeCentroid(area, transform) ?? Offset.zero;
      final r = _markerRadius / zoomScale;
      return RRect.fromRectAndRadius(
        Rect.fromCircle(center: centroid, radius: r),
        Radius.circular(r),
      );
    }
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final p in points) {
      final cp = transform.toCanvas(p.x, p.y);
      if (cp.dx < minX) minX = cp.dx;
      if (cp.dx > maxX) maxX = cp.dx;
      if (cp.dy < minY) minY = cp.dy;
      if (cp.dy > maxY) maxY = cp.dy;
    }
    final minSize = _markerRadius * 2.0 / zoomScale;
    final pad = 4.0 / zoomScale;
    var w = maxX - minX;
    var h = maxY - minY;
    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;
    if (w < minSize) w = minSize;
    if (h < minSize) h = minSize;
    w += pad * 2;
    h += pad * 2;
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
    final radius = Radius.circular((w < h ? w : h) * 0.35);
    return RRect.fromRectAndRadius(rect, radius);
  }

  /// Draw a dashed version of a path.
  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint,
    int dashCount,
  ) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      final totalLen = metric.length;
      final dashLen = totalLen / dashCount * 0.6;
      final gapLen = totalLen / dashCount * 0.4;
      var distance = 0.0;
      while (distance < totalLen) {
        final end = distance + dashLen;
        final segment = metric.extractPath(distance, end.clamp(0, totalLen));
        canvas.drawPath(segment, paint);
        distance = end + gapLen;
      }
    }
  }

  /// Draw a faint dashed rounded polygon marker for a tiny unrevealed area.
  void _drawTinyMarker(
    Canvas canvas,
    RegionalArea area,
    _GeoTransform transform,
  ) {
    final rrect = _tinyAreaRRect(area, transform);
    final center = rrect.center;
    if (center.dx.isNaN || center.dy.isNaN) return;

    // Faint dashed border ring as rounded rect.
    final borderPaint = Paint()
      ..color = const Color(0xFF5A7A9A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / zoomScale;
    final rrectPath = Path()..addRRect(rrect);
    _drawDashedPath(canvas, rrectPath, borderPaint, 16);
  }

  /// Draw the Blue Marble satellite texture clipped to a polygon path.
  ///
  /// Uses viewport-relative texture mapping: only the portion of the
  /// satellite image that corresponds to the visible viewport is sampled,
  /// and the polygon path is intersected with the canvas bounds first.
  /// This prevents rendering artefacts from polygons that extend far
  /// beyond the viewport (e.g. Russia in Europe) and gives better texture
  /// resolution than stretching the full world image.
  void _drawSatelliteFill(
    Canvas canvas,
    Path path,
    _GeoTransform transform,
    Size canvasSize,
  ) {
    final img = satelliteImage!;

    // Extract only the satellite image region that matches the viewport.
    final srcLeft = ((transform.minLng + 180.0) / 360.0) * img.width;
    final srcRight = ((transform.maxLng + 180.0) / 360.0) * img.width;
    final srcTop = ((90.0 - transform.maxLat) / 180.0) * img.height;
    final srcBottom = ((90.0 - transform.minLat) / 180.0) * img.height;
    final srcRect = Rect.fromLTRB(srcLeft, srcTop, srcRight, srcBottom);

    // Map to the projected canvas area.
    final dstRect = Rect.fromLTWH(
      transform.offsetX,
      transform.offsetY,
      transform.projectedWidth,
      transform.projectedHeight,
    );

    canvas.save();
    // Clip to canvas bounds first — prevents rendering issues with
    // polygon paths that extend thousands of pixels off-screen.
    canvas.clipRect(Offset.zero & canvasSize);
    canvas.clipPath(path);
    canvas.drawImageRect(
      img,
      srcRect,
      dstRect,
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();
  }

  /// Draw the Blue Marble satellite texture clipped to a rounded rectangle
  /// for tiny areas.
  void _drawSatelliteRRect(
    Canvas canvas,
    RRect rrect,
    _GeoTransform transform,
    Size canvasSize,
  ) {
    final img = satelliteImage!;
    final clipPath = Path()..addRRect(rrect);

    final srcLeft = ((transform.minLng + 180.0) / 360.0) * img.width;
    final srcRight = ((transform.maxLng + 180.0) / 360.0) * img.width;
    final srcTop = ((90.0 - transform.maxLat) / 180.0) * img.height;
    final srcBottom = ((90.0 - transform.minLat) / 180.0) * img.height;
    final srcRect = Rect.fromLTRB(srcLeft, srcTop, srcRight, srcBottom);

    final dstRect = Rect.fromLTWH(
      transform.offsetX,
      transform.offsetY,
      transform.projectedWidth,
      transform.projectedHeight,
    );

    canvas.save();
    canvas.clipRect(Offset.zero & canvasSize);
    canvas.clipPath(clipPath);
    canvas.drawImageRect(
      img,
      srcRect,
      dstRect,
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();
  }

  Path _buildAreaPath(RegionalArea area, _GeoTransform transform) {
    final path = Path();
    final rings = area.polygons ?? [area.points];
    for (final ring in rings) {
      if (ring.isEmpty) continue;
      // Convert geo coordinates to canvas points.
      final canvasPoints = <Offset>[];
      for (final pt in ring) {
        canvasPoints.add(transform.toCanvas(pt.x, pt.y));
      }
      // Apply Chaikin subdivision for smoother borders.
      final smoothed = chaikinSmooth(canvasPoints, 2);
      if (smoothed.isEmpty) continue;
      path.moveTo(smoothed.first.dx, smoothed.first.dy);
      for (var i = 1; i < smoothed.length; i++) {
        path.lineTo(smoothed[i].dx, smoothed[i].dy);
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

    if (capitalsMode && area.capital != null) {
      // Capitals mode: red dot + "CapitalName (CC)"
      final dotRadius = (3.0 / zoomScale).clamp(1.0, 5.0);
      canvas.drawCircle(
        centroid,
        dotRadius,
        Paint()..color = const Color(0xFFE74C3C),
      );
      canvas.drawCircle(
        centroid,
        dotRadius,
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5 / zoomScale,
      );

      final label = '${area.capital} (${area.code})';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
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

      // Offset text to the right of the dot.
      final textOffset = Offset(
        centroid.dx + dotRadius + 3.0 / zoomScale,
        centroid.dy - textPainter.height / 2,
      );
      textPainter.paint(canvas, textOffset);
    } else {
      // Country name mode.
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
        zoomScale != oldDelegate.zoomScale ||
        satelliteImage != oldDelegate.satelliteImage ||
        pingProgress != oldDelegate.pingProgress;
  }
}

/// Longitude/latitude → canvas coordinate transformer.
///
/// Also exposes [offsetX], [offsetY], [projectedWidth], [projectedHeight]
/// for satellite texture mapping.
class _GeoTransform {
  _GeoTransform.fromBounds({
    required this.minLng,
    required this.maxLng,
    required this.minLat,
    required this.maxLat,
    required double canvasWidth,
    required double canvasHeight,
  }) {
    final lngRange = maxLng - minLng;
    final latRange = maxLat - minLat;
    final midLat = (minLat + maxLat) / 2;
    _aspectCorrection = math.cos(midLat * math.pi / 180);

    final effectiveLngRange = lngRange * _aspectCorrection;
    _scale = math.min(
      canvasWidth / effectiveLngRange,
      canvasHeight / latRange,
    );

    projectedWidth = effectiveLngRange * _scale;
    projectedHeight = latRange * _scale;
    offsetX = (canvasWidth - projectedWidth) / 2;
    offsetY = (canvasHeight - projectedHeight) / 2;
  }

  final double minLng, maxLng, minLat, maxLat;
  late final double _aspectCorrection;
  late final double _scale;
  late final double offsetX;
  late final double offsetY;
  late final double projectedWidth;
  late final double projectedHeight;

  Offset toCanvas(double lng, double lat) {
    final x = offsetX + ((lng - minLng) * _aspectCorrection) * _scale;
    final y = offsetY + ((maxLat - lat)) * _scale;
    return Offset(x, y);
  }
}
