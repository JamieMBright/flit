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
    // Target screen position — skip if occluded (worldToScreen returns
    // (-1000, -1000) for points hidden behind the globe).
    final targetScreen = gameRef.worldToScreenGlobe(target);
    if (targetScreen.x <= -500) return;

    // Start at the plane's fixed screen position (50% x, 80% y).
    final planeScreen = gameRef.plane.position;
    final startOffset = Offset(planeScreen.x, planeScreen.y);
    final endOffset = Offset(targetScreen.x, targetScreen.y);

    // Draw a straight line from beneath the plane to the target.
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = isHint ? 2.5 : 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawLine(startOffset, endOffset, paint);

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
}
