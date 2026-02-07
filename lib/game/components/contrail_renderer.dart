import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../flit_game.dart';

/// Renders contrail particles as a Flame overlay component.
///
/// This component draws contrails independently of the globe renderer,
/// ensuring they appear regardless of whether the shader or canvas
/// world map is active. Contrails trail from the plane's wing tips
/// and fade over their lifetime.
class ContrailRenderer extends Component with HasGameRef<FlitGame> {
  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final plane = gameRef.plane;
    final planePos = plane.position;

    for (final particle in plane.contrails) {
      final opacity = (particle.life / particle.maxLife).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = FlitColors.contrail.withOpacity(opacity * 0.5);

      final pos = planePos.toOffset() + particle.screenOffset.toOffset();
      canvas.drawCircle(pos, particle.size * (0.3 + opacity * 0.7), paint);
    }
  }
}
