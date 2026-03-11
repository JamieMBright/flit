import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../flit_game.dart';

/// Renders a straight line from the plane to the current waymarker / hint.
class WaylineRenderer extends Component with HasGameRef<FlitGame> {
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (gameRef.isInLaunchIntro) return;

    // In globe descent mode the visual display is an OSM tile map whose
    // Mercator projection doesn't match the globe shader projection used here.
    // Skip wayline rendering to avoid the dot drifting to a wrong position.
    // In flat map mode, always render waylines (the equirectangular projection
    // is consistent between the game canvas and the tile map underneath).
    if (!gameRef.isFlatMapMode && !gameRef.isHighAltitude) return;

    final screenSize = gameRef.size;
    if (screenSize.x < 1 || screenSize.y < 1) return;

    // Draw navigation waymarker line (player-tapped destination).
    final waymarker = gameRef.waymarker;
    if (waymarker != null) {
      _drawWayline(
        canvas,
        waymarker,
        FlitColors.accent.withOpacity(0.45),
        dotOpacity: 0.7,
      );
    }

    // Draw hint wayline (visual-only, doesn't steer).
    final hintTarget = gameRef.hintTarget;
    if (hintTarget != null) {
      _drawWayline(
        canvas,
        hintTarget,
        FlitColors.textPrimary.withOpacity(0.35),
        dotOpacity: 0.5,
        isHint: true,
      );
    }
  }

  void _drawWayline(
    Canvas canvas,
    Vector2 target,
    Color lineColor, {
    double dotOpacity = 0.7,
    bool isHint = false,
  }) {
    // Target screen position — worldToScreenGlobe returns (-1000, -1000)
    // for points hidden behind the globe.
    final targetScreen = gameRef.worldToScreenGlobe(target);
    final isOccluded = targetScreen.x <= -500;

    // For non-hint waymarkers, skip occluded targets as before.
    // For hint waylines, project a point on the visible globe edge so the
    // player still sees which direction to fly, even when the target is on
    // the far side of the globe.
    if (isOccluded && !isHint) return;

    final planeScreen = gameRef.plane.position;
    final startOffset = Offset(planeScreen.x, planeScreen.y);

    Offset endOffset;
    bool drawDot;

    if (isOccluded) {
      // Target is behind the globe — compute a directional edge point.
      // Interpolate along the great circle from the player toward the target
      // and find a point that is just visible on the globe's edge.
      endOffset = _edgeProjection(target);
      if (endOffset.dx <= -500) return; // fallback: still can't project
      drawDot = false; // no dot — just the directional line
    } else {
      endOffset = Offset(targetScreen.x, targetScreen.y);
      drawDot = true;
    }

    // Draw a straight line from beneath the plane to the target (or edge).
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = isHint ? 2.5 : 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawLine(startOffset, endOffset, paint);

    if (!drawDot) {
      // Draw an arrow chevron at the edge to indicate direction.
      _drawEdgeChevron(canvas, startOffset, endOffset, lineColor);
      return;
    }

    // Target dot.
    final dotColor = isHint ? FlitColors.textPrimary : FlitColors.accent;
    canvas.drawCircle(
      endOffset,
      6.0,
      Paint()..color = dotColor.withOpacity(dotOpacity),
    );
    canvas.drawCircle(
      endOffset,
      10.0,
      Paint()
        ..color = dotColor.withOpacity(dotOpacity * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  /// Find a point along the great circle from the player to [target] that
  /// sits just inside the visible hemisphere. We binary-search between the
  /// player position and the target for the furthest visible point.
  Offset _edgeProjection(Vector2 target) {
    final playerPos = gameRef.worldPosition;
    // Binary search: find the furthest fraction along the great circle
    // interpolation that still projects to a visible screen point.
    double lo = 0.0;
    double hi = 1.0;
    Vector2 bestScreen = Vector2(-1000, -1000);

    for (int i = 0; i < 12; i++) {
      final mid = (lo + hi) / 2;
      final interp = _greatCircleInterpolate(playerPos, target, mid);
      final screen = gameRef.worldToScreenGlobe(interp);
      if (screen.x > -500) {
        lo = mid;
        bestScreen = screen;
      } else {
        hi = mid;
      }
    }

    return Offset(bestScreen.x, bestScreen.y);
  }

  /// Spherical linear interpolation between two lat/lng points.
  Vector2 _greatCircleInterpolate(Vector2 from, Vector2 to, double t) {
    const d2r = math.pi / 180;
    const r2d = 180 / math.pi;

    final lat1 = from.y * d2r;
    final lng1 = from.x * d2r;
    final lat2 = to.y * d2r;
    final lng2 = to.x * d2r;

    // Convert to Cartesian on unit sphere.
    final ax = math.cos(lat1) * math.cos(lng1);
    final ay = math.sin(lat1);
    final az = math.cos(lat1) * math.sin(lng1);

    final bx = math.cos(lat2) * math.cos(lng2);
    final by = math.sin(lat2);
    final bz = math.cos(lat2) * math.sin(lng2);

    // Angle between the two points.
    var dot = ax * bx + ay * by + az * bz;
    dot = dot.clamp(-1.0, 1.0);
    final omega = math.acos(dot);

    // If points are nearly identical or antipodal, fall back to linear.
    if (omega.abs() < 1e-6) {
      return Vector2(
        from.x + (to.x - from.x) * t,
        from.y + (to.y - from.y) * t,
      );
    }

    final sinOmega = math.sin(omega);
    final a = math.sin((1 - t) * omega) / sinOmega;
    final b = math.sin(t * omega) / sinOmega;

    final ix = a * ax + b * bx;
    final iy = a * ay + b * by;
    final iz = a * az + b * bz;

    final lat = math.asin(iy.clamp(-1.0, 1.0)) * r2d;
    final lng = math.atan2(iz, ix) * r2d;

    return Vector2(lng, lat);
  }

  /// Draw a small chevron (arrow head) at the line's end to indicate that
  /// the target continues beyond the visible globe edge.
  void _drawEdgeChevron(
    Canvas canvas,
    Offset start,
    Offset end,
    Color color,
  ) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) return;

    final ux = dx / len;
    final uy = dy / len;

    const chevronSize = 8.0;
    const chevronAngle = 0.5; // ~28 degrees

    final cosA = math.cos(chevronAngle);
    final sinA = math.sin(chevronAngle);

    final left = Offset(
      end.dx - chevronSize * (ux * cosA + uy * sinA),
      end.dy - chevronSize * (uy * cosA - ux * sinA),
    );
    final right = Offset(
      end.dx - chevronSize * (ux * cosA - uy * sinA),
      end.dy - chevronSize * (uy * cosA + ux * sinA),
    );

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(left, end, paint);
    canvas.drawLine(right, end, paint);
  }
}
