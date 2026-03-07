import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart' hide Matrix4;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../map/region.dart';

/// State visual status during a quiz.
enum StateVisualStatus {
  /// Default — not yet answered.
  idle,

  /// Just answered correctly (flash green).
  correct,

  /// Just tapped incorrectly (flash red).
  wrong,

  /// Already answered (dimmed).
  completed,
}

/// Visual state for each state on the map.
class StateVisual {
  StateVisual({required this.area});

  final RegionalArea area;
  StateVisualStatus status = StateVisualStatus.idle;

  /// Timestamp when status last changed (for animation).
  DateTime? statusChangedAt;
}

/// Callback when a state is tapped.
typedef OnStateTapped = void Function(String stateCode);

/// Interactive USA map widget for Flight School quiz mode.
///
/// Renders all 50 states using polygon data from [RegionalData].
/// Features:
/// - CONUS (continental US) as the main view
/// - Alaska and Hawaii in inset boxes (bottom-left)
/// - Pinch-to-zoom and pan support
/// - Tap detection via point-in-polygon hit testing
/// - Visual feedback: green flash (correct), red flash (wrong), dim (completed)
class QuizMapWidget extends StatefulWidget {
  const QuizMapWidget({
    super.key,
    required this.stateVisuals,
    required this.onStateTapped,
    this.highlightCode,
    this.showLabels = true,
    this.eliminatedCodes = const {},
    this.correctCodes = const {},
  });

  /// Visual state for each US state.
  final Map<String, StateVisual> stateVisuals;

  /// Called when the player taps a state.
  final OnStateTapped onStateTapped;

  /// Optional state to highlight (e.g., for showing the correct answer).
  final String? highlightCode;

  /// Whether to show state code labels on the map.
  final bool showLabels;

  /// Codes that have been eliminated (hidden) during progressive hints.
  final Set<String> eliminatedCodes;

  /// Codes that were correctly guessed (shown in muted green).
  final Set<String> correctCodes;

  @override
  State<QuizMapWidget> createState() => _QuizMapWidgetState();
}

class _QuizMapWidgetState extends State<QuizMapWidget>
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
                  painter: _UsaMapPainter(
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
    final painter = _UsaMapPainter(
      stateVisuals: widget.stateVisuals,
      highlightCode: widget.highlightCode,
      pulseValue: 0,
      showLabels: widget.showLabels,
      eliminatedCodes: widget.eliminatedCodes,
      correctCodes: widget.correctCodes,
      zoomScale: 1.0,
      satelliteImage: _satelliteImage,
    );

    final code = painter.hitTestState(position, size);
    if (code != null) {
      widget.onStateTapped(code);
    }
  }
}

/// Paints the USA map with CONUS main view and AK/HI insets.
class _UsaMapPainter extends CustomPainter {
  _UsaMapPainter({
    required this.stateVisuals,
    required this.highlightCode,
    required this.pulseValue,
    this.showLabels = true,
    this.eliminatedCodes = const {},
    this.correctCodes = const {},
    this.zoomScale = 1.0,
    this.satelliteImage,
  });

  final Map<String, StateVisual> stateVisuals;
  final String? highlightCode;
  final double pulseValue;
  final bool showLabels;
  final Set<String> eliminatedCodes;
  final Set<String> correctCodes;
  final double zoomScale;
  final ui.Image? satelliteImage;

  // CONUS bounds (continental US)
  static const double _conusMinLng = -125.0;
  static const double _conusMaxLng = -66.0;
  static const double _conusMinLat = 24.0;
  static const double _conusMaxLat = 50.0;

  // Inset positions and scales (relative to canvas)
  static const double _insetSize = 0.18; // fraction of canvas width
  static const double _insetPadding = 0.02;

  // Alaska bounds
  static const double _akMinLng = -170.0;
  static const double _akMaxLng = -130.0;
  static const double _akMinLat = 54.0;
  static const double _akMaxLat = 72.0;

  // Hawaii bounds
  static const double _hiMinLng = -160.5;
  static const double _hiMaxLng = -154.5;
  static const double _hiMinLat = 18.5;
  static const double _hiMaxLat = 22.5;

  // Northeast inset bounds (zoomed view of small NE states)
  static const double _neMinLng = -80.0;
  static const double _neMaxLng = -66.5;
  static const double _neMinLat = 38.5;
  static const double _neMaxLat = 47.5;

  // States shown in the NE inset
  static const _neStateCodes = {
    'CT',
    'DE',
    'MA',
    'MD',
    'ME',
    'NH',
    'NJ',
    'NY',
    'PA',
    'RI',
    'VT',
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Draw background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF1A2A32),
    );

    final areas = RegionalData.getAreas(GameRegion.usStates);

    // Draw CONUS states
    for (final area in areas) {
      if (area.code == 'AK' || area.code == 'HI') continue;
      _drawState(canvas, size, area, _conusTransform(size));
    }

    // Draw Alaska inset
    _drawInsetBox(canvas, size, 'Alaska', _akInsetRect(size));
    final akArea = areas.where((a) => a.code == 'AK').firstOrNull;
    if (akArea != null) {
      _drawState(canvas, size, akArea, _akTransform(size));
    }

    // Draw Hawaii inset
    _drawInsetBox(canvas, size, 'Hawaii', _hiInsetRect(size));
    final hiArea = areas.where((a) => a.code == 'HI').firstOrNull;
    if (hiArea != null) {
      _drawState(canvas, size, hiArea, _hiTransform(size));
    }

    // Draw Northeast inset (zoomed view of small NE states)
    final neRect = _neInsetRect(size);
    _drawInsetBox(canvas, size, 'Northeast', neRect);
    final neTransform = _neTransform(size);
    for (final area in areas) {
      if (!_neStateCodes.contains(area.code)) continue;
      _drawState(canvas, size, area, neTransform);
    }

    // Draw clean borders — single pass with anti-aliased strokes.
    // Divide strokeWidth by zoom scale so borders stay visually constant.
    final borderPaint = Paint()
      ..color = const Color(0xFF1A2A32).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / zoomScale
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    for (final area in areas) {
      if (area.code == 'AK' || area.code == 'HI') continue;
      if (eliminatedCodes.contains(area.code)) continue;
      final path = _buildStatePath(area.points, _conusTransform(size));
      canvas.drawPath(path, borderPaint);
    }

    // Draw borders for insets
    if (akArea != null && !eliminatedCodes.contains('AK')) {
      final path = _buildStatePath(akArea.points, _akTransform(size));
      canvas.drawPath(path, borderPaint);
    }
    if (hiArea != null && !eliminatedCodes.contains('HI')) {
      final path = _buildStatePath(hiArea.points, _hiTransform(size));
      canvas.drawPath(path, borderPaint);
    }
    // NE inset borders
    for (final area in areas) {
      if (!_neStateCodes.contains(area.code)) continue;
      if (eliminatedCodes.contains(area.code)) continue;
      final path = _buildStatePath(area.points, neTransform);
      canvas.drawPath(path, borderPaint);
    }

    // Draw state labels for larger states (only when enabled)
    if (showLabels) {
      for (final area in areas) {
        if (area.code == 'AK' || area.code == 'HI') continue;
        if (eliminatedCodes.contains(area.code)) continue;
        _drawStateLabel(canvas, size, area, _conusTransform(size));
      }
      // NE inset labels
      for (final area in areas) {
        if (!_neStateCodes.contains(area.code)) continue;
        if (eliminatedCodes.contains(area.code)) continue;
        _drawStateLabel(canvas, size, area, neTransform);
      }
    }
  }

  /// Convert lng/lat to canvas coordinates for CONUS.
  _GeoTransform _conusTransform(Size size) {
    // Add some padding
    final padX = size.width * 0.04;
    final padY = size.height * 0.06;
    final drawW = size.width - padX * 2;
    final drawH = size.height - padY * 2;

    // Reserve bottom space for insets
    final mainH = drawH * 0.78;

    // Correct aspect ratio for latitude distortion.
    // At ~37N (mid-CONUS), cos(37) ≈ 0.799
    const lngSpan = _conusMaxLng - _conusMinLng; // 59 degrees
    const latSpan = _conusMaxLat - _conusMinLat; // 26 degrees
    // cos(37°) ≈ 0.799
    const cosLat = 0.799;
    final geoAspect = (lngSpan * cosLat) / latSpan;
    final canvasAspect = drawW / mainH;

    double usedW, usedH;
    if (geoAspect > canvasAspect) {
      usedW = drawW;
      usedH = drawW / geoAspect;
    } else {
      usedH = mainH;
      usedW = mainH * geoAspect;
    }

    final offsetX = padX + (drawW - usedW) / 2;
    final offsetY = padY + (mainH - usedH) / 2;

    return _GeoTransform(
      minLng: _conusMinLng,
      maxLng: _conusMaxLng,
      minLat: _conusMinLat,
      maxLat: _conusMaxLat,
      offsetX: offsetX,
      offsetY: offsetY,
      width: usedW,
      height: usedH,
    );
  }

  Rect _akInsetRect(Size size) {
    final insetW = size.width * _insetSize;
    final insetH = insetW * 0.75;
    final left = size.width * _insetPadding;
    final top = size.height - insetH - size.height * _insetPadding;
    return Rect.fromLTWH(left, top, insetW, insetH);
  }

  Rect _hiInsetRect(Size size) {
    final insetW = size.width * _insetSize;
    final insetH = insetW * 0.55;
    final akRect = _akInsetRect(size);
    final left = akRect.right + size.width * _insetPadding;
    final top = size.height - insetH - size.height * _insetPadding;
    return Rect.fromLTWH(left, top, insetW, insetH);
  }

  _GeoTransform _akTransform(Size size) {
    final rect = _akInsetRect(size);
    final pad = rect.width * 0.08;
    return _GeoTransform(
      minLng: _akMinLng,
      maxLng: _akMaxLng,
      minLat: _akMinLat,
      maxLat: _akMaxLat,
      offsetX: rect.left + pad,
      offsetY: rect.top + pad,
      width: rect.width - pad * 2,
      height: rect.height - pad * 2,
    );
  }

  _GeoTransform _hiTransform(Size size) {
    final rect = _hiInsetRect(size);
    final pad = rect.width * 0.08;
    return _GeoTransform(
      minLng: _hiMinLng,
      maxLng: _hiMaxLng,
      minLat: _hiMinLat,
      maxLat: _hiMaxLat,
      offsetX: rect.left + pad,
      offsetY: rect.top + pad,
      width: rect.width - pad * 2,
      height: rect.height - pad * 2,
    );
  }

  Rect _neInsetRect(Size size) {
    final insetW = size.width * 0.28;
    final insetH = insetW * 0.75;
    final right = size.width - size.width * _insetPadding;
    final top = size.height - insetH - size.height * _insetPadding;
    return Rect.fromLTWH(right - insetW, top, insetW, insetH);
  }

  _GeoTransform _neTransform(Size size) {
    final rect = _neInsetRect(size);
    final pad = rect.width * 0.06;
    return _GeoTransform(
      minLng: _neMinLng,
      maxLng: _neMaxLng,
      minLat: _neMinLat,
      maxLat: _neMaxLat,
      offsetX: rect.left + pad,
      offsetY: rect.top + pad,
      width: rect.width - pad * 2,
      height: rect.height - pad * 2,
    );
  }

  void _drawInsetBox(Canvas canvas, Size size, String label, Rect rect) {
    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()..color = const Color(0xFF1E3340),
    );
    // Border
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()
        ..color = const Color(0xFF3A5A6A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Label
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFF8AA0B0),
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(rect.left + 6, rect.top + 4));
  }

  void _drawState(
    Canvas canvas,
    Size size,
    RegionalArea area,
    _GeoTransform transform,
  ) {
    if (area.points.isEmpty) return;

    // Hidden (eliminated) states
    if (eliminatedCodes.contains(area.code)) return;

    final visual = stateVisuals[area.code];
    final status = visual?.status ?? StateVisualStatus.idle;
    final isHighlighted = highlightCode == area.code;
    final isCorrectlyGuessed = correctCodes.contains(area.code);

    final path = _buildStatePath(area.points, transform);

    // Reveal satellite imagery for correctly guessed states
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
  void _drawSatelliteFill(
    Canvas canvas,
    Path path,
    _GeoTransform transform,
  ) {
    final img = satelliteImage!;

    // Map geographic bounds to satellite image pixels (equirectangular).
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
    canvas.clipPath(path);
    canvas.drawImageRect(
      img,
      srcRect,
      dstRect,
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();
  }

  void _drawStateLabel(
    Canvas canvas,
    Size size,
    RegionalArea area,
    _GeoTransform transform,
  ) {
    // Only label states that are large enough
    final centroid = _centroid(area.points);
    final pos = transform.toCanvas(centroid.x, centroid.y);

    // Skip if label would be off-screen
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
          fontSize: 8,
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
      // Pulsing highlight for showing the correct answer
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

  Path _buildStatePath(List<Vector2> points, _GeoTransform transform) {
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

  /// Hit test: returns the state code at the given canvas position, or null.
  String? hitTestState(Offset position, Size size) {
    final areas = RegionalData.getAreas(GameRegion.usStates);

    // Check Alaska inset — tapping anywhere in the box counts as Alaska
    final akRect = _akInsetRect(size);
    if (akRect.contains(position)) {
      if (!eliminatedCodes.contains('AK')) return 'AK';
      return null;
    }

    // Check Hawaii inset — tapping anywhere in the box counts as Hawaii
    final hiRect = _hiInsetRect(size);
    if (hiRect.contains(position)) {
      if (!eliminatedCodes.contains('HI')) return 'HI';
      return null;
    }

    // Check NE inset — hit-test individual states within the inset
    final neRect = _neInsetRect(size);
    if (neRect.contains(position)) {
      final neTransform = _neTransform(size);
      final neMatches = <String>[];
      for (final area in areas) {
        if (!_neStateCodes.contains(area.code)) continue;
        if (eliminatedCodes.contains(area.code)) continue;
        if (_hitTestPolygons(position, area, neTransform)) {
          neMatches.add(area.code);
        }
      }
      if (neMatches.length == 1) return neMatches.first;
      if (neMatches.length > 1) {
        String? best;
        var bestDist = double.infinity;
        for (final code in neMatches) {
          final area = areas.firstWhere((a) => a.code == code);
          final centroid = _canvasCentroid(area.points, neTransform);
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
      // Tapped in NE box but not on a state — fall through to CONUS check
    }

    // Check CONUS states — collect all matches to handle border overlaps.
    final transform = _conusTransform(size);
    final matches = <String>[];
    for (final area in areas) {
      if (area.code == 'AK' || area.code == 'HI') continue;
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
  /// Multi-polygon states (e.g. Michigan with upper/lower peninsulas, Hawaii
  /// islands) must test each ring separately. Using the flat `points` list
  /// creates a single malformed polygon connecting all rings.
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
    return _pointInPolygon(point, area.points, transform);
  }

  /// Point-in-polygon test using ray casting algorithm.
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
  bool shouldRepaint(covariant _UsaMapPainter oldDelegate) {
    return oldDelegate.highlightCode != highlightCode ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.eliminatedCodes != eliminatedCodes ||
        oldDelegate.correctCodes != correctCodes ||
        true; // Always repaint for status changes
  }
}

/// Transforms geographic coordinates (lng/lat) to canvas coordinates.
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

  /// Convert longitude/latitude to canvas x/y.
  Offset toCanvas(double lng, double lat) {
    final x = offsetX + ((lng - minLng) / (maxLng - minLng)) * width;
    // Flip Y axis (latitude increases upward, canvas Y increases downward)
    final y = offsetY + ((maxLat - lat) / (maxLat - minLat)) * height;
    return Offset(x, y);
  }

  /// Convert canvas x/y back to longitude/latitude.
  Vector2 fromCanvas(Offset point) {
    final lng = minLng + ((point.dx - offsetX) / width) * (maxLng - minLng);
    final lat = maxLat - ((point.dy - offsetY) / height) * (maxLat - minLat);
    return Vector2(lng, lat);
  }
}
