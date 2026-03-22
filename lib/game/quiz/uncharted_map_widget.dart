/// Map widget for the Uncharted game mode.
///
/// Renders all area outlines on a dark background. Revealed areas show
/// the Blue Marble satellite texture clipped to the country polygon.
/// Supports pinch-to-zoom and pan.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../map/country_data.dart';
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
    this.showUnrevealedLabels = false,
  });

  final GameRegion region;
  final Set<String> revealedCodes;

  /// The most recently revealed code — shown with a highlight animation.
  final String? lastRevealedCode;

  /// When true, labels show capital name with red dot + (country code).
  final bool capitalsMode;

  /// 0.0 = no ping, 0.0-1.0 = ping animation progress for unrevealed areas.
  final double pingProgress;

  /// When true, show faint name labels on unrevealed areas (easy mode).
  final bool showUnrevealedLabels;

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

  /// Cached smoothed paths keyed by area code.
  /// Rebuilt only when canvas size or region changes.
  Map<String, Path> _pathCache = {};
  _GeoTransform? _cachedTransform;
  Size? _cachedSize;

  @override
  void initState() {
    super.initState();
    _areas = _getFilteredAreas(widget.region);
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadSatelliteImage();
  }

  /// Get areas for the region. All areas in the candidate pool are rendered
  /// so that every guessable country is visible on the map.
  static List<RegionalArea> _getFilteredAreas(GameRegion region) {
    return RegionalData.getAreas(region);
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
      _areas = _getFilteredAreas(widget.region);
      _pathCache.clear();
      _cachedSize = null;
    }
  }

  @override
  void dispose() {
    _satelliteImage?.dispose();
    _flashController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  /// Build and cache paths for all areas. Only recomputes when size changes.
  void _ensurePathCache(Size size) {
    if (_cachedSize == size && _pathCache.isNotEmpty) return;
    _cachedSize = size;

    final bounds = widget.region.bounds;
    final transform = _GeoTransform.fromBounds(
      minLng: bounds[0],
      maxLng: bounds[2],
      minLat: bounds[1],
      maxLat: bounds[3],
      canvasWidth: size.width,
      canvasHeight: size.height,
    );
    _cachedTransform = transform;

    final newCache = <String, Path>{};
    for (final area in _areas) {
      newCache[area.code] = _buildAreaPath(area, transform);
    }
    _pathCache = newCache;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        // Build path cache outside the animation loop — only rebuilds on
        // layout size changes, not every animation frame.
        _ensurePathCache(size);

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
                size: size,
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
                  pathCache: _pathCache,
                  cachedTransform: _cachedTransform,
                  showUnrevealedLabels: widget.showUnrevealedLabels,
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

  /// Build a smoothed path for an area's polygons.
  static Path _buildAreaPath(RegionalArea area, _GeoTransform transform) {
    final path = Path();
    final rings = area.polygons ?? [area.points];
    for (final ring in rings) {
      if (ring.isEmpty) continue;
      // Skip rings that individually cross the antimeridian — they would
      // draw a line across the entire map on an equirectangular projection.
      if (_UnchartedMapPainter._crossesAntimeridian(ring)) continue;
      // Convert geo coordinates to canvas points.
      final canvasPoints = <Offset>[];
      for (final pt in ring) {
        canvasPoints.add(transform.toCanvas(pt.x, pt.y));
      }
      if (canvasPoints.isEmpty) continue;
      path.moveTo(canvasPoints.first.dx, canvasPoints.first.dy);
      for (var i = 1; i < canvasPoints.length; i++) {
        path.lineTo(canvasPoints[i].dx, canvasPoints[i].dy);
      }
      path.close();
    }
    return path;
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
    required this.pathCache,
    this.cachedTransform,
    this.showUnrevealedLabels = false,
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
  final Map<String, Path> pathCache;
  final _GeoTransform? cachedTransform;
  final bool showUnrevealedLabels;

  @override
  void paint(Canvas canvas, Size size) {
    // Background.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0D1B2A),
    );

    final transform = cachedTransform ??
        _GeoTransform.fromBounds(
          minLng: region.bounds[0],
          maxLng: region.bounds[2],
          minLat: region.bounds[1],
          maxLat: region.bounds[3],
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

    // Compute pulse alpha once (shared by all unrevealed areas).
    final bool hasPing = pingProgress > 0.0 && pingProgress < 1.0;
    final double pingAlpha = hasPing
        ? (pingProgress < 0.5 ? pingProgress * 2.0 : (1.0 - pingProgress) * 2.0)
            .clamp(0.0, 1.0)
        : 0.0;
    // Expanding ripple scale: 0→1 over the animation, used for ring expansion.
    final double pingRipple =
        hasPing ? Curves.easeOut.transform(pingProgress) : 0.0;

    // Three-pass rendering to prevent satellite fills from covering
    // neighbouring unrevealed outlines (e.g. Italy covering San Marino).
    //
    // Pass 1: Satellite fills only (revealed areas).
    // Pass 2: All outlines, markers, and ping effects (both revealed & unrevealed).
    // Pass 3: Labels on top.
    final revealedAreas = <RegionalArea>[];

    // ── Pass 1: Satellite fills ──
    for (final area in areas) {
      final path = pathCache[area.code];
      if (path == null) continue;

      final isRevealed = revealedCodes.contains(area.code);
      if (!isRevealed) continue;

      final isFlashing = area.code == lastRevealedCode && flashProgress < 1.0;
      final isTiny = _isTinyArea(area, transform);

      if (isTiny) {
        final rrect = _tinyAreaRRect(area, transform);
        if (isFlashing) {
          final revealAlpha =
              Curves.easeOut.transform(flashProgress).clamp(0.0, 1.0);
          if (satelliteImage != null && revealAlpha > 0.01) {
            _drawSatelliteRRect(canvas, rrect, transform, size,
                opacity: revealAlpha);
          }
        } else {
          if (satelliteImage != null) {
            _drawSatelliteRRect(canvas, rrect, transform, size);
          } else {
            canvas.drawRRect(
              rrect,
              Paint()..color = const Color(0xFF1B6B4A),
            );
          }
        }
      } else {
        if (isFlashing) {
          final revealAlpha =
              Curves.easeOut.transform(flashProgress).clamp(0.0, 1.0);
          if (satelliteImage != null && revealAlpha > 0.01) {
            _drawSatelliteFill(canvas, path, transform, size,
                opacity: revealAlpha);
          }
        } else {
          if (satelliteImage != null) {
            _drawSatelliteFill(canvas, path, transform, size);
          } else {
            canvas.drawPath(
              path,
              Paint()..color = const Color(0xFF1B6B4A),
            );
          }
        }
      }
      revealedAreas.add(area);
    }

    // ── Pass 2: Outlines, markers, and ping effects ──
    // Drawn AFTER all satellite fills so unrevealed outlines are always
    // visible on top of revealed neighbours' satellite imagery.
    for (final area in areas) {
      final path = pathCache[area.code];
      if (path == null) continue;

      final isRevealed = revealedCodes.contains(area.code);
      final isFlashing = area.code == lastRevealedCode && flashProgress < 1.0;
      final isTiny = _isTinyArea(area, transform);

      if (isRevealed) {
        if (isTiny) {
          final rrect = _tinyAreaRRect(area, transform);
          final rrectPath = Path()..addRRect(rrect);
          _drawDashedPath(canvas, rrectPath, revealedStroke, 16);
        } else {
          if (isFlashing) {
            final revealAlpha =
                Curves.easeOut.transform(flashProgress).clamp(0.0, 1.0);
            canvas.drawPath(
                path,
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.5 / zoomScale
                  ..strokeJoin = StrokeJoin.round
                  ..isAntiAlias = true
                  ..color = Color.fromRGBO(46, 204, 113, revealAlpha));
          } else {
            canvas.drawPath(path, revealedStroke);
          }
        }
      } else {
        // Unrevealed: outline always on top of any satellite fills.
        canvas.drawPath(path, outlinePaint);

        if (isTiny) {
          _drawTinyMarker(canvas, area, transform, pingAlpha, pingRipple);
        }

        if (hasPing && !isTiny) {
          // Bright amber fill over the polygon.
          canvas.drawPath(
            path,
            Paint()..color = Color.fromRGBO(255, 190, 80, pingAlpha * 0.55),
          );
          // Expanding glow stroke around the polygon edge.
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = (3.0 + pingRipple * 6.0) / zoomScale
              ..strokeJoin = StrokeJoin.round
              ..isAntiAlias = true
              ..color = Color.fromRGBO(255, 200, 80, pingAlpha * 0.7),
          );
        }
      }
    }

    // ── Pass 3: Labels ──
    for (final area in revealedAreas) {
      _drawLabel(canvas, area, transform);
    }

    // Unrevealed labels (easy mode) — faint, smaller text.
    if (showUnrevealedLabels) {
      for (final area in areas) {
        if (revealedCodes.contains(area.code)) continue;
        _drawUnrevealedLabel(canvas, area, transform);
      }
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
  bool _isTinyArea(RegionalArea area, _GeoTransform transform) {
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
  ///
  /// For antimeridian-crossing countries (points span > 180° longitude),
  /// uses the centroid of the largest polygon ring to avoid map-spanning
  /// markers.
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

    // For antimeridian-crossing countries, use the largest polygon ring
    // to compute a sensible marker position.
    if (_crossesAntimeridian(points)) {
      final centroid =
          _computeCentroidLargestRing(area, transform) ?? Offset.zero;
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
  ///
  /// When [pingAlpha] > 0, the marker pulses with an expanding ripple ring
  /// that extends well beyond the marker bounds so small islands are visible.
  void _drawTinyMarker(
    Canvas canvas,
    RegionalArea area,
    _GeoTransform transform,
    double pingAlpha,
    double pingRipple,
  ) {
    final rrect = _tinyAreaRRect(area, transform);
    final center = rrect.center;
    if (center.dx.isNaN || center.dy.isNaN) return;

    // Ping pulse: bright fill + expanding ripple ring beyond marker bounds.
    if (pingAlpha > 0.0) {
      // Bright fill on the marker itself.
      canvas.drawRRect(
        rrect,
        Paint()..color = Color.fromRGBO(255, 190, 80, pingAlpha * 0.6),
      );
      // Expanding circle ripple that extends beyond the marker.
      final baseRadius = math.max(rrect.width, rrect.height) * 0.5;
      final expandRadius = baseRadius + (20.0 + baseRadius) * pingRipple;
      canvas.drawCircle(
        center,
        expandRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (2.5 + pingRipple * 3.0) / zoomScale
          ..isAntiAlias = true
          ..color = Color.fromRGBO(255, 200, 80, pingAlpha * 0.8),
      );
      // Inner glow disc.
      canvas.drawCircle(
        center,
        expandRadius * 0.6,
        Paint()..color = Color.fromRGBO(255, 200, 80, pingAlpha * 0.15),
      );
    }

    // Faint dashed border ring as rounded rect — thin and subtle.
    final borderPaint = Paint()
      ..color = const Color(0xFF3D5570)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6 / zoomScale;
    final rrectPath = Path()..addRRect(rrect);
    _drawDashedPath(canvas, rrectPath, borderPaint, 16);
  }

  /// Draw the Blue Marble satellite texture clipped to a polygon path.
  ///
  /// Uses viewport-relative texture mapping: only the portion of the
  /// satellite image that corresponds to the visible viewport is sampled,
  /// and the polygon path is intersected with the canvas bounds first.
  void _drawSatelliteFill(
    Canvas canvas,
    Path path,
    _GeoTransform transform,
    Size canvasSize, {
    double opacity = 1.0,
  }) {
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
      Paint()
        ..filterQuality = FilterQuality.high
        ..color = Color.fromRGBO(255, 255, 255, opacity),
    );
    canvas.restore();
  }

  /// Draw the Blue Marble satellite texture clipped to a rounded rectangle
  /// for tiny areas.
  void _drawSatelliteRRect(
    Canvas canvas,
    RRect rrect,
    _GeoTransform transform,
    Size canvasSize, {
    double opacity = 1.0,
  }) {
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
      Paint()
        ..filterQuality = FilterQuality.high
        ..color = Color.fromRGBO(255, 255, 255, opacity),
    );
    canvas.restore();
  }

  void _drawLabel(Canvas canvas, RegionalArea area, _GeoTransform transform) {
    final centroid = _computeCentroid(area, transform);
    if (centroid == null) return;

    // Scale font size inversely with zoom so it doesn't get huge when zoomed.
    final fontSize = (10.0 / zoomScale).clamp(3.0, 14.0);

    if (capitalsMode && area.capital != null) {
      // Capitals mode: red dot at actual capital city coordinates.
      // Look up real lat/lon from CityData; fall back to polygon centroid.
      final capitalCity = CountryData.getCapital(area.code);
      final dotPos = capitalCity != null
          ? transform.toCanvas(capitalCity.location.x, capitalCity.location.y)
          : centroid;
      final dotRadius = (3.0 / zoomScale).clamp(1.0, 5.0);
      canvas.drawCircle(
        dotPos,
        dotRadius,
        Paint()..color = const Color(0xFFE74C3C),
      );
      canvas.drawCircle(
        dotPos,
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
        dotPos.dx + dotRadius + 3.0 / zoomScale,
        dotPos.dy - textPainter.height / 2,
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

  /// Draw a faint label for an unrevealed area (easy/labels mode).
  void _drawUnrevealedLabel(
      Canvas canvas, RegionalArea area, _GeoTransform transform) {
    final centroid = _computeCentroid(area, transform);
    if (centroid == null) return;

    final fontSize = (8.0 / zoomScale).clamp(2.5, 11.0);
    final textPainter = TextPainter(
      text: TextSpan(
        text: area.name,
        style: TextStyle(
          color: const Color(0x80AABBCC),
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          shadows: const [
            Shadow(color: Color(0xFF000000), blurRadius: 1),
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

  /// Compute centroid from all points (fine for most countries).
  Offset? _computeCentroid(RegionalArea area, _GeoTransform transform) {
    final points = area.points;
    if (points.isEmpty) return null;

    // For antimeridian-crossing countries, use the largest ring.
    if (_crossesAntimeridian(points)) {
      return _computeCentroidLargestRing(area, transform);
    }

    var cx = 0.0;
    var cy = 0.0;
    for (final p in points) {
      final canvasP = transform.toCanvas(p.x, p.y);
      cx += canvasP.dx;
      cy += canvasP.dy;
    }
    return Offset(cx / points.length, cy / points.length);
  }

  /// Compute centroid from only the largest polygon ring.
  /// Used for countries that span the antimeridian.
  Offset? _computeCentroidLargestRing(
      RegionalArea area, _GeoTransform transform) {
    final rings = area.polygons;
    if (rings == null || rings.isEmpty) return null;
    // Find the ring with the most vertices (main landmass).
    var largest = rings[0];
    for (final ring in rings) {
      if (ring.length > largest.length) largest = ring;
    }
    if (largest.isEmpty) return null;
    var cx = 0.0;
    var cy = 0.0;
    for (final p in largest) {
      final canvasP = transform.toCanvas(p.x, p.y);
      cx += canvasP.dx;
      cy += canvasP.dy;
    }
    return Offset(cx / largest.length, cy / largest.length);
  }

  @override
  bool shouldRepaint(_UnchartedMapPainter oldDelegate) {
    return revealedCodes.length != oldDelegate.revealedCodes.length ||
        lastRevealedCode != oldDelegate.lastRevealedCode ||
        flashProgress != oldDelegate.flashProgress ||
        zoomScale != oldDelegate.zoomScale ||
        satelliteImage != oldDelegate.satelliteImage ||
        pingProgress != oldDelegate.pingProgress ||
        showUnrevealedLabels != oldDelegate.showUnrevealedLabels;
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
