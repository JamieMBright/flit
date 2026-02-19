import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../flit_game.dart';

/// Renders a translucent dashed line from the plane to the current waymarker.
///
/// The line curves along the globe surface by interpolating intermediate
/// points along the great-circle path, then projecting each to screen space.
class WaylineRenderer extends Component with HasGameRef<FlitGame> {
  static const int _segments = 30;
  static const double _deg2rad = pi / 180;
  static const double _rad2deg = 180 / pi;

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

    final planePos = gameRef.worldPosition;
    final screenSize = gameRef.size;
    if (screenSize.x < 1 || screenSize.y < 1) return;

    // Draw navigation waymarker line (player-tapped destination).
    final waymarker = gameRef.waymarker;
    if (waymarker != null) {
      _drawWayline(
        canvas,
        planePos,
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
        planePos,
        hintTarget,
        FlitColors.textPrimary.withOpacity(0.35),
        dotOpacity: 0.5,
        isHint: true,
      );
    }
  }

  void _drawWayline(
    Canvas canvas,
    Vector2 planePos,
    Vector2 target,
    Color lineColor, {
    double dotOpacity = 0.7,
    bool isHint = false,
  }) {
    // Build screen points along the great-circle arc.
    // Include i=0 (plane origin) so the first point uses the same
    // projection coordinate system as all subsequent wayline points.
    final points = <Offset>[];
    for (var i = 0; i <= _segments; i++) {
      final t = i / _segments;
      final interp = _interpolateGreatCircle(planePos, target, t);
      final screen = gameRef.worldToScreenGlobe(interp);
      if (screen.x > -500) {
        points.add(Offset(screen.x, screen.y));
      }
    }

    if (points.isEmpty) return;

    // Offset the first point (the plane's globe-projected position) to
    // the nose of the aircraft. Because we use the projected position as
    // the base, the offset stays in the same coordinate system as the
    // rest of the wayline — no gap between coordinate spaces.
    final plane = gameRef.plane;
    final totalRotation = plane.visualHeading + plane.turnDirection * 0.4;
    const noseLength = 13.0; // ~16px nose offset * perspectiveScaleY(0.80)
    points[0] = Offset(
      points[0].dx + sin(totalRotation) * noseLength,
      points[0].dy - cos(totalRotation) * noseLength,
    );

    if (points.length < 2) return;

    // Draw translucent dashed line.
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = isHint ? 2.5 : 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    var drawn = 0.0;
    var dashOn = true;
    final onLen = isHint ? 12.0 : 8.0;
    final offLen = isHint ? 4.0 : 6.0;

    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final segLen = (b - a).distance;

      if (dashOn) {
        canvas.drawLine(a, b, paint);
      }

      drawn += segLen;
      if (dashOn && drawn >= onLen) {
        dashOn = false;
        drawn = 0;
      } else if (!dashOn && drawn >= offLen) {
        dashOn = true;
        drawn = 0;
      }
    }

    // Target dot — only draw if the actual target is visible (not occluded
    // by the globe). worldToScreen returns (-1000, -1000) for hidden points.
    final targetScreen = gameRef.worldToScreenGlobe(target);
    if (targetScreen.x > -500) {
      final markerPos = Offset(targetScreen.x, targetScreen.y);
      final dotColor = isHint ? FlitColors.textPrimary : FlitColors.accent;
      canvas.drawCircle(
        markerPos,
        6.0,
        Paint()..color = dotColor.withOpacity(dotOpacity),
      );
      canvas.drawCircle(
        markerPos,
        10.0,
        Paint()
          ..color = dotColor.withOpacity(dotOpacity * 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  /// Spherical linear interpolation between two (lng, lat) points.
  Vector2 _interpolateGreatCircle(Vector2 a, Vector2 b, double t) {
    final lat1 = a.y * _deg2rad;
    final lng1 = a.x * _deg2rad;
    final lat2 = b.y * _deg2rad;
    final lng2 = b.x * _deg2rad;

    final dLat = lat2 - lat1;
    final dLng = lng2 - lng1;
    final h =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(h), sqrt(1 - h));

    if (c < 1e-10) return a.clone();

    final sinC = sin(c);
    final aFrac = sin((1 - t) * c) / sinC;
    final bFrac = sin(t * c) / sinC;

    final x = aFrac * cos(lat1) * cos(lng1) + bFrac * cos(lat2) * cos(lng2);
    final y = aFrac * sin(lat1) + bFrac * sin(lat2);
    final z = aFrac * cos(lat1) * sin(lng1) + bFrac * cos(lat2) * sin(lng2);

    final lat = atan2(y, sqrt(x * x + z * z));
    final lng = atan2(z, x);

    return Vector2(lng * _rad2deg, lat * _rad2deg);
  }
}
