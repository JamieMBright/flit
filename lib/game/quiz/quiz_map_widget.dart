import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

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
/// - Tap detection via point-in-polygon hit testing
/// - Visual feedback: green flash (correct), red flash (wrong), dim (completed)
class QuizMapWidget extends StatefulWidget {
  const QuizMapWidget({
    super.key,
    required this.stateVisuals,
    required this.onStateTapped,
    this.highlightCode,
  });

  /// Visual state for each US state.
  final Map<String, StateVisual> stateVisuals;

  /// Called when the player taps a state.
  final OnStateTapped onStateTapped;

  /// Optional state to highlight (e.g., for showing the correct answer).
  final String? highlightCode;

  @override
  State<QuizMapWidget> createState() => _QuizMapWidgetState();
}

class _QuizMapWidgetState extends State<QuizMapWidget>
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
                painter: _UsaMapPainter(
                  stateVisuals: widget.stateVisuals,
                  highlightCode: widget.highlightCode,
                  pulseValue: _pulseController.value,
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _handleTap(Offset position, Size size) {
    final painter = _UsaMapPainter(
      stateVisuals: widget.stateVisuals,
      highlightCode: widget.highlightCode,
      pulseValue: 0,
    );

    final code = painter.hitTest(position, size);
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
  });

  final Map<String, StateVisual> stateVisuals;
  final String? highlightCode;
  final double pulseValue;

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

    // Draw state borders for CONUS
    for (final area in areas) {
      if (area.code == 'AK' || area.code == 'HI') continue;
      _drawStateBorder(canvas, size, area, _conusTransform(size));
    }

    // Draw borders for insets
    if (akArea != null) {
      _drawStateBorder(canvas, size, akArea, _akTransform(size));
    }
    if (hiArea != null) {
      _drawStateBorder(canvas, size, hiArea, _hiTransform(size));
    }

    // Draw state labels for larger states
    for (final area in areas) {
      if (area.code == 'AK' || area.code == 'HI') continue;
      _drawStateLabel(canvas, size, area, _conusTransform(size));
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

    return _GeoTransform(
      minLng: _conusMinLng,
      maxLng: _conusMaxLng,
      minLat: _conusMinLat,
      maxLat: _conusMaxLat,
      offsetX: padX,
      offsetY: padY,
      width: drawW,
      height: mainH,
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

    final visual = stateVisuals[area.code];
    final status = visual?.status ?? StateVisualStatus.idle;
    final isHighlighted = highlightCode == area.code;

    final path = _buildStatePath(area.points, transform);
    final fillColor = _getFillColor(status, isHighlighted);

    canvas.drawPath(path, Paint()..color = fillColor);
  }

  void _drawStateBorder(
    Canvas canvas,
    Size size,
    RegionalArea area,
    _GeoTransform transform,
  ) {
    if (area.points.isEmpty) return;
    final path = _buildStatePath(area.points, transform);

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF3A5A6A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
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

  Color _getFillColor(StateVisualStatus status, bool isHighlighted) {
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
  String? hitTest(Offset position, Size size) {
    final areas = RegionalData.getAreas(GameRegion.usStates);

    // Check Alaska inset first (on top)
    final akRect = _akInsetRect(size);
    if (akRect.contains(position)) {
      final akArea = areas.where((a) => a.code == 'AK').firstOrNull;
      if (akArea != null) {
        final transform = _akTransform(size);
        if (_pointInPolygon(position, akArea.points, transform)) {
          return 'AK';
        }
      }
      return null; // Tapped in AK box but not on the state
    }

    // Check Hawaii inset
    final hiRect = _hiInsetRect(size);
    if (hiRect.contains(position)) {
      final hiArea = areas.where((a) => a.code == 'HI').firstOrNull;
      if (hiArea != null) {
        final transform = _hiTransform(size);
        if (_pointInPolygon(position, hiArea.points, transform)) {
          return 'HI';
        }
      }
      return null;
    }

    // Check CONUS states
    final transform = _conusTransform(size);
    for (final area in areas) {
      if (area.code == 'AK' || area.code == 'HI') continue;
      if (_pointInPolygon(position, area.points, transform)) {
        return area.code;
      }
    }

    return null;
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
