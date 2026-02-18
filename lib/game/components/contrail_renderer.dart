import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../flit_game.dart';
import 'plane_component.dart';

/// Renders contrail particles as connected line segments.
///
/// Contrails are anchored to world positions (lat/lng). Each frame,
/// particles are projected from world space onto the screen so they
/// stay fixed on the map as the plane flies away — creating a trailing
/// ribbon effect. Particles are separated by wing side (left/right) and
/// drawn as continuous lines that fade with age.
///
/// Contrail color is driven by the equipped cosmetic's [primaryColor] and
/// [secondaryColor]. When both are set the trail lerps between them; when
/// only primary is set a single color is used; the default falls back to
/// [FlitColors.contrail].
class ContrailRenderer extends Component with HasGameRef<FlitGame> {
  ContrailRenderer({this.primaryColor, this.secondaryColor});

  /// Primary contrail color from equipped cosmetic.
  final Color? primaryColor;

  /// Secondary contrail color from equipped cosmetic (lerped from primary).
  final Color? secondaryColor;
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (gameRef.isInLaunchIntro) return;

    final plane = gameRef.plane;
    final particles = plane.contrails;
    if (particles.isEmpty) return;

    // Separate particles by side and sort by descending life (newest first).
    final left = <ContrailParticle>[];
    final right = <ContrailParticle>[];
    for (final p in particles) {
      if (p.life <= 0) continue;
      if (p.isLeft) {
        left.add(p);
      } else {
        right.add(p);
      }
    }

    _drawTrail(canvas, left);
    _drawTrail(canvas, right);
  }

  void _drawTrail(Canvas canvas, List<ContrailParticle> trail) {
    if (trail.length < 2) return;

    // Sort by life descending (newest = highest life first) so we draw
    // from the wing tip backward.
    trail.sort((a, b) => b.life.compareTo(a.life));

    // Draw line segments between consecutive particles, fading with age.
    for (var i = 0; i < trail.length - 1; i++) {
      final a = trail[i];
      final b = trail[i + 1];

      final opacityA = (a.life / a.maxLife).clamp(0.0, 1.0);
      final opacityB = (b.life / b.maxLife).clamp(0.0, 1.0);
      if (opacityA < 0.01 && opacityB < 0.01) continue;

      final screenA = gameRef.worldToScreen(a.worldPosition);
      final screenB = gameRef.worldToScreen(b.worldPosition);

      // Skip if either point is on the far side of the globe.
      if (screenA.x < -500 || screenB.x < -500) continue;

      // Skip segments that are too long (wrapping artifacts).
      final dx = screenA.x - screenB.x;
      final dy = screenA.y - screenB.y;
      if (dx * dx + dy * dy > 10000) continue; // > 100px apart

      // Use the average opacity for this segment and fade the stroke width.
      final opacity = (opacityA + opacityB) * 0.5;
      final t = 1.0 - opacity; // 0 = fresh (primary), 1 = old (secondary)
      final baseColor = primaryColor ?? FlitColors.contrail;
      final trailColor = secondaryColor != null
          ? Color.lerp(baseColor, secondaryColor!, t)!
          : baseColor;
      final paint = Paint()
        ..color = trailColor.withOpacity(opacity * 0.7)
        ..strokeWidth = 1.2 + opacity * 0.8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(screenA.x, screenA.y),
        Offset(screenB.x, screenB.y),
        paint,
      );
    }
  }
}
