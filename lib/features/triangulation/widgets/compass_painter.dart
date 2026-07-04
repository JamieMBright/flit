import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/flit_colors.dart';

/// Converts a compass bearing (0 = N, clockwise, degrees) to a screen-space
/// unit vector (north = up).
Offset bearingToDirection(double bearingDeg) {
  final rad = bearingDeg * math.pi / 180.0;
  return Offset(math.sin(rad), -math.cos(rad));
}

/// Paints the Triangulation compass rose: a central mystery circle,
/// cardinal ticks, one solid arrow per starting clue, and a dashed
/// [FlitColors.error] arrow per wrong guess.
///
/// Info boxes at the arrow tips are Flutter widgets layered above this
/// painter (see TriangulationCompass); this painter draws only the rose
/// and the arrows so hit-testing and text stay in the widget tree.
class CompassPainter extends CustomPainter {
  CompassPainter({
    required this.clueBearingsDeg,
    required this.guessBearingsDeg,
    required this.circleRadiusFraction,
    required this.arrowEndFraction,
  });

  /// Bearings of the starting clue markers (solid arrows).
  final List<double> clueBearingsDeg;

  /// Bearings of wrong guesses (dashed red arrows).
  final List<double> guessBearingsDeg;

  /// Central circle radius as a fraction of the shortest side.
  final double circleRadiusFraction;

  /// Arrow tip radius as a fraction of the shortest side.
  final double arrowEndFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final side = math.min(size.width, size.height);
    final circleR = side * circleRadiusFraction;
    final arrowEnd = side * arrowEndFraction;

    _drawRose(canvas, center, circleR);

    for (final bearing in clueBearingsDeg) {
      _drawArrow(
        canvas,
        center,
        bearing,
        circleR,
        arrowEnd,
        color: FlitColors.textPrimary,
        dashed: false,
      );
    }
    for (final bearing in guessBearingsDeg) {
      _drawArrow(
        canvas,
        center,
        bearing,
        circleR,
        arrowEnd,
        color: FlitColors.error,
        dashed: true,
      );
    }
  }

  void _drawRose(Canvas canvas, Offset center, double circleR) {
    // Paper-toned disc with a double ring for the vintage-atlas feel.
    canvas.drawCircle(
      center,
      circleR,
      Paint()..color = FlitColors.backgroundLight,
    );
    canvas.drawCircle(
      center,
      circleR,
      Paint()
        ..color = FlitColors.textSecondary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    canvas.drawCircle(
      center,
      circleR - 5,
      Paint()
        ..color = FlitColors.textSecondary.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Cardinal ticks + letters just inside the ring.
    const cardinals = ['N', 'E', 'S', 'W'];
    for (var i = 0; i < 4; i++) {
      final dir = bearingToDirection(i * 90.0);
      final tickStart = center + dir * (circleR - 4);
      final tickEnd = center + dir * circleR;
      canvas.drawLine(
        tickStart,
        tickEnd,
        Paint()
          ..color = FlitColors.textSecondary
          ..strokeWidth = 2.0,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: cardinals[i],
          style: TextStyle(
            color: FlitColors.textSecondary.withOpacity(0.7),
            fontSize: circleR * 0.16,
            fontWeight: FontWeight.w600,
            // Roboto ships with MaterialApp on every platform; naming it
            // keeps TextPainter output consistent (and real in goldens).
            fontFamily: 'Roboto',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelPos = center + dir * (circleR - 12 - circleR * 0.1);
      tp.paint(
        canvas,
        labelPos - Offset(tp.width / 2, tp.height / 2),
      );
    }
  }

  void _drawArrow(
    Canvas canvas,
    Offset center,
    double bearingDeg,
    double fromR,
    double toR, {
    required Color color,
    required bool dashed,
  }) {
    final dir = bearingToDirection(bearingDeg);
    final start = center + dir * fromR;
    final end = center + dir * toR;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (dashed) {
      _drawDashedLine(canvas, start, end, paint);
    } else {
      canvas.drawLine(start, end, paint);
    }

    // Arrowhead: two short strokes angled back from the tip.
    final headLen = math.max(7.0, (toR - fromR) * 0.22);
    const headAngle = 0.46; // radians off the shaft
    final back = -dir;
    final left = _rotate(back, headAngle) * headLen;
    final right = _rotate(back, -headAngle) * headLen;
    canvas.drawLine(end, end + left, paint);
    canvas.drawLine(end, end + right, paint);
  }

  static Offset _rotate(Offset v, double rad) => Offset(
        v.dx * math.cos(rad) - v.dy * math.sin(rad),
        v.dx * math.sin(rad) + v.dy * math.cos(rad),
      );

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLen = 6.0;
    const gapLen = 4.0;
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashLen, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(CompassPainter old) =>
      !_listEquals(clueBearingsDeg, old.clueBearingsDeg) ||
      !_listEquals(guessBearingsDeg, old.guessBearingsDeg) ||
      circleRadiusFraction != old.circleRadiusFraction ||
      arrowEndFraction != old.arrowEndFraction;

  static bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
