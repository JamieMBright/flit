import 'dart:ui' as ui;

import 'package:flame/components.dart' hide Matrix4;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../map/region.dart';
import 'border_smoothing.dart';
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
    this.excludedCodes = const {},
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

  /// Codes excluded from the quiz (grayed out, non-interactive).
  final Set<String> excludedCodes;

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
                    excludedCodes: widget.excludedCodes,
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
      excludedCodes: widget.excludedCodes,
      zoomScale: scale,
      satelliteImage: _satelliteImage,
    );

    final code = painter.hitTestArea(position, size);
    if (code != null && !widget.excludedCodes.contains(code)) {
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
    this.excludedCodes = const {},
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
  final Set<String> excludedCodes;
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

    // Background landmass fill: draw unsmoothed composite of all areas in the
    // idle fill color. This covers gaps between Chaikin-smoothed polygons so
    // the dark ocean background never peeks through between counties.
    final bgPath = Path();
    for (final area in areas) {
      if (eliminatedCodes.contains(area.code)) continue;
      if (excludedCodes.contains(area.code)) continue;
      bgPath.addPath(
          _buildRawPath(area.points, transform, polygons: area.polygons),
          Offset.zero);
    }
    canvas.drawPath(bgPath, Paint()..color = const Color(0xFF2A4A5A));

    // Draw fills
    for (final area in areas) {
      _drawArea(canvas, size, area, transform);
    }

    // Draw clean borders (subtle, single pass).
    // Divide strokeWidth by zoom scale so borders stay visually constant.
    final borderPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / zoomScale
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Green border for correctly guessed areas.
    final correctBorderPaint = Paint()
      ..color = const Color(0xFF2ECC71)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 / zoomScale
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    for (final area in areas) {
      if (eliminatedCodes.contains(area.code)) continue;
      final path = _buildPath(area.points, transform, polygons: area.polygons);
      final isCorrect = correctCodes.contains(area.code) ||
          stateVisuals[area.code]?.status == StateVisualStatus.correct;
      canvas.drawPath(path, isCorrect ? correctBorderPaint : borderPaint);
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
        if (_isTinyArea(area, transform, size)) continue;
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

    final path = _buildPath(area.points, transform, polygons: area.polygons);

    // Excluded countries: draw very dim, non-interactive.
    if (excludedCodes.contains(area.code)) {
      canvas.drawPath(
        path,
        Paint()..color = const Color(0xFF1A2A32).withValues(alpha: 0.6),
      );
      return;
    }

    final visual = stateVisuals[area.code];
    final status = visual?.status ?? StateVisualStatus.idle;
    final isHighlighted = highlightCode == area.code;
    final isCorrectlyGuessed = correctCodes.contains(area.code);

    // Reveal satellite imagery for correctly guessed countries
    if ((isCorrectlyGuessed || status == StateVisualStatus.correct) &&
        satelliteImage != null) {
      _drawSatelliteFill(canvas, path, transform, size);
    } else {
      final fillColor =
          _getFillColor(status, isHighlighted, isCorrectlyGuessed);
      canvas.drawPath(path, Paint()..color = fillColor);
    }
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
      transform.width,
      transform.height,
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

    // Scale font inversely with zoom so labels don't get enormous when zoomed.
    // Show full name when zoomed in enough, otherwise fall back to code.
    final fontSize = 7.0 / zoomScale;
    if (fontSize < 0.5) return; // Too tiny to render at this zoom

    // Use full country name — more helpful than 2-letter ISO codes.
    final labelText = area.name;

    final textPainter = TextPainter(
      text: TextSpan(
        text: labelText,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
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

  /// Build an unsmoothed path (no Chaikin) for background landmass fill.
  static Path _buildRawPath(List<Vector2> points, _GeoTransform transform,
      {List<List<Vector2>>? polygons}) {
    final path = Path();
    if (polygons != null && polygons.isNotEmpty) {
      for (final ring in polygons) {
        if (ring.isEmpty) continue;
        if (_crossesAntimeridian(ring)) continue;
        final first = transform.toCanvas(ring.first.x, ring.first.y);
        path.moveTo(first.dx, first.dy);
        for (var i = 1; i < ring.length; i++) {
          final pt = transform.toCanvas(ring[i].x, ring[i].y);
          path.lineTo(pt.dx, pt.dy);
        }
        path.close();
      }
      return path;
    }
    if (points.isEmpty) return path;
    final first = transform.toCanvas(points.first.x, points.first.y);
    path.moveTo(first.dx, first.dy);
    for (var i = 1; i < points.length; i++) {
      final pt = transform.toCanvas(points[i].x, points[i].y);
      path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    return path;
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
        // Skip rings that individually cross the antimeridian — they would
        // draw a line across the entire map on an equirectangular projection.
        if (_crossesAntimeridian(ring)) continue;
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

    // Fallback: single flat list of points.
    if (points.isEmpty) return path;
    final canvasPoints = <Offset>[];
    for (final pt in points) {
      canvasPoints.add(transform.toCanvas(pt.x, pt.y));
    }
    final smoothed = chaikinSmooth(canvasPoints, 2);
    if (smoothed.isEmpty) return path;
    path.moveTo(smoothed.first.dx, smoothed.first.dy);
    for (var i = 1; i < smoothed.length; i++) {
      path.lineTo(smoothed[i].dx, smoothed[i].dy);
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

  /// Area codes that always get an expanded hit target and marker,
  /// regardless of polygon size (island micro-states, city-states, etc.).
  /// Uses the shared set from border_smoothing.dart for consistency.
  static const Set<String> _alwaysTinyCodes = alwaysTinyCodes;

  /// Whether an area's polygon footprint on canvas is too small to tap.
  bool _isTinyArea(RegionalArea area, _GeoTransform transform, Size size) {
    // Force-tiny for known micro-states regardless of zoom.
    if (_alwaysTinyCodes.contains(area.code)) return true;
    if (area.points.length < 3) return true;

    // For antimeridian-crossing countries, compute the bounding box from
    // only the polygon rings that don't individually cross the antimeridian.
    // This avoids a map-spanning bbox while still rendering the bulk of the
    // country (mainland Russia, mainland USA, etc.) at full size.
    if (_crossesAntimeridian(area.points)) {
      final rings = area.polygons;
      if (rings == null || rings.isEmpty) return true;
      var minX = double.infinity, maxX = -double.infinity;
      var minY = double.infinity, maxY = -double.infinity;
      var hasValidRing = false;
      for (final ring in rings) {
        if (ring.isEmpty || _crossesAntimeridian(ring)) continue;
        hasValidRing = true;
        for (final p in ring) {
          final cp = transform.toCanvas(p.x, p.y);
          if (cp.dx < minX) minX = cp.dx;
          if (cp.dx > maxX) maxX = cp.dx;
          if (cp.dy < minY) minY = cp.dy;
          if (cp.dy > maxY) maxY = cp.dy;
        }
      }
      if (!hasValidRing) return true;
      final w = (maxX - minX) * zoomScale;
      final h = (maxY - minY) * zoomScale;
      return w < _tinyThreshold && h < _tinyThreshold;
    }

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

  /// Detect if a set of points crosses the antimeridian (±180° longitude).
  static bool _crossesAntimeridian(List<Vector2> points) {
    if (points.isEmpty) return false;
    var minLng = double.infinity, maxLng = -double.infinity;
    for (final p in points) {
      if (p.x < minLng) minLng = p.x;
      if (p.x > maxLng) maxLng = p.x;
    }
    return (maxLng - minLng) > 180.0;
  }

  /// Compute the bounding box of a tiny area's points on canvas, expanded
  /// to a minimum visible size and returned as a rounded rectangle.
  RRect _tinyAreaRRect(
    RegionalArea area,
    _GeoTransform transform,
  ) {
    final points = area.points;
    if (points.isEmpty) {
      final centroid = _centroid(points);
      final pos = transform.toCanvas(centroid.x, centroid.y);
      final r = _markerRadius / zoomScale;
      return RRect.fromRectAndRadius(
        Rect.fromCircle(center: pos, radius: r),
        Radius.circular(r),
      );
    }

    // For antimeridian-crossing countries, use the largest polygon ring
    // centroid to avoid map-spanning markers.
    if (_crossesAntimeridian(points)) {
      final centroid = _centroidLargestRing(area, transform);
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
    // Ensure minimum size and add padding.
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

  /// Compute canvas-space centroid from the largest polygon ring.
  Offset _centroidLargestRing(RegionalArea area, _GeoTransform transform) {
    final rings = area.polygons;
    if (rings == null || rings.isEmpty) {
      final c = _centroid(area.points);
      return transform.toCanvas(c.x, c.y);
    }
    var largest = rings[0];
    for (final ring in rings) {
      if (ring.length > largest.length) largest = ring;
    }
    if (largest.isEmpty) return Offset.zero;
    var cx = 0.0;
    var cy = 0.0;
    for (final p in largest) {
      final cp = transform.toCanvas(p.x, p.y);
      cx += cp.dx;
      cy += cp.dy;
    }
    return Offset(cx / largest.length, cy / largest.length);
  }

  /// Draw a visible labeled marker for a tiny area (microstate / small island).
  void _drawTinyMarker(
    Canvas canvas,
    Size size,
    RegionalArea area,
    _GeoTransform transform,
  ) {
    final rrect = _tinyAreaRRect(area, transform);
    final center = rrect.center;
    if (center.dx < 0 ||
        center.dx > size.width ||
        center.dy < 0 ||
        center.dy > size.height) {
      return;
    }

    final visual = stateVisuals[area.code];
    final status = visual?.status ?? StateVisualStatus.idle;
    final isHighlighted = highlightCode == area.code;
    final isCorrectlyGuessed = correctCodes.contains(area.code);

    // Background fill — transparent for idle, filled for active states.
    final bool hasActiveFill = isHighlighted ||
        isCorrectlyGuessed ||
        status == StateVisualStatus.correct ||
        status == StateVisualStatus.wrong;

    if (hasActiveFill) {
      if ((isCorrectlyGuessed || status == StateVisualStatus.correct) &&
          satelliteImage != null) {
        // Clip Blue Marble satellite texture to the rounded polygon.
        _drawSatelliteRRect(canvas, rrect, transform);
      } else {
        Color fillColor;
        if (isHighlighted) {
          final opacity = 0.6 + 0.3 * pulseValue;
          fillColor = Color.fromRGBO(232, 122, 90, opacity);
        } else {
          fillColor = const Color(0xFFAA3333);
        }
        canvas.drawRRect(rrect, Paint()..color = fillColor);
      }
    }

    // Dashed border ring as a rounded rectangle.
    final isCorrect = isCorrectlyGuessed || status == StateVisualStatus.correct;
    final borderPaint = Paint()
      ..color = isCorrect
          ? const Color(0xFF2ECC71)
          : hasActiveFill
              ? const Color(0xFFFFFFFF)
              : const Color(0xFF3D5570)
      ..style = PaintingStyle.stroke
      ..strokeWidth =
          (isCorrect ? 2.0 : (hasActiveFill ? 1.0 : 0.6)) / zoomScale;
    // Draw dashed rounded rect by using a path with dash effect.
    final rrectPath = Path()..addRRect(rrect);
    _drawDashedPath(canvas, rrectPath, borderPaint, 16);

    // Label — only when difficulty enables labels.
    if (showLabels) {
      final fontSize = 6.0 / zoomScale;
      if (fontSize < 0.5) return; // Don't render label at extreme zoom
      final tp = TextPainter(
        text: TextSpan(
          text: area.name,
          style: TextStyle(
            color: const Color(0xFFE0F0FF),
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
      );
    }
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

  /// Draw the Blue Marble satellite texture clipped to a rounded rectangle
  /// for tiny areas.
  void _drawSatelliteRRect(
    Canvas canvas,
    RRect rrect,
    _GeoTransform transform,
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
      transform.width,
      transform.height,
    );

    canvas.save();
    canvas.clipPath(clipPath);
    canvas.drawImageRect(
      img,
      srcRect,
      dstRect,
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();
  }

  String? hitTestArea(Offset position, Size size) {
    final areas = RegionalData.getAreas(region);
    final transform = _regionTransform(size);

    // First pass: check tiny area markers (expanded rounded rect hit targets).
    // These take priority because they're drawn on top.
    for (final area in areas) {
      if (eliminatedCodes.contains(area.code)) continue;
      if (_isTinyArea(area, transform, size)) {
        final rrect = _tinyAreaRRect(area, transform);
        // Inflate the hit target slightly for easier tapping.
        final inflated = rrect.inflate(4.0 / zoomScale);
        if (inflated.contains(position)) {
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
