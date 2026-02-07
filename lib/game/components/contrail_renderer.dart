import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../flit_game.dart';

/// Renders contrail particles as a Flame overlay component.
///
/// Contrails are anchored to world positions (lat/lng). Each frame,
/// particles are projected from world space onto the screen so they
/// stay fixed on the map as the plane flies away — creating a trailing
/// ribbon effect.
class ContrailRenderer extends Component with HasGameRef<FlitGame> {
  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final plane = gameRef.plane;

    for (final particle in plane.contrails) {
      final opacity = (particle.life / particle.maxLife).clamp(0.0, 1.0);
      if (opacity < 0.01) continue;

      // Project world position to screen.
      final screenPos = gameRef.worldToScreen(particle.worldPosition);

      final paint = Paint()
        ..color = FlitColors.contrail.withOpacity(opacity * 0.5);

      canvas.drawCircle(
        Offset(screenPos.x, screenPos.y),
        particle.size * (0.3 + opacity * 0.7),
        paint,
      );
    }
  }
}
