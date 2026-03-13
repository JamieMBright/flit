import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../rendering/watercolor_style.dart';

/// A single ink-burst particle with fixed properties determined at spawn time.
class _InkParticle {
  _InkParticle({
    required this.angle,
    required this.speed,
    required this.radius,
    required this.color,
    required this.birthT,
    required this.deathT,
    this.gravity = 0.0,
  });

  /// Direction of travel (radians).
  final double angle;

  /// Distance in pixels at t=1.
  final double speed;

  /// Base dot radius in pixels.
  final double radius;

  /// Tinted particle colour.
  final Color color;

  /// Controller value at which this particle begins moving (stagger).
  final double birthT;

  /// Controller value at which this particle has fully faded out.
  final double deathT;

  /// Downward acceleration in pixels — makes particles trickle down the screen.
  final double gravity;
}

/// [CustomPainter] that draws a watercolor ink-burst particle effect.
///
/// Each particle is rendered as a soft blurred under-wash plus a crisp core
/// dot, matching the layered wash pattern from [WatercolorStyle.washFill].
/// Particles are subject to gravity, causing them to arc upward then trickle
/// down the screen like sparks from a firework.
class _InkBurstPainter extends CustomPainter {
  _InkBurstPainter({
    required this.particles,
    required this.t,
    required this.origin,
  });

  final List<_InkParticle> particles;
  final double t;
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    // Central gold aura — fades during the first 30% of animation.
    if (t < 0.3) {
      final auraOpacity = 0.18 * (1.0 - t / 0.3);
      WatercolorStyle.auraGlow(
        canvas,
        origin,
        60,
        FlitColors.gold,
        opacity: auraOpacity,
      );
    }

    final washPaint = Paint();
    final corePaint = Paint();

    for (final p in particles) {
      if (t < p.birthT) continue;

      // Local progress for this particle (0→1).
      final tLocal = ((t - p.birthT) / (1.0 - p.birthT)).clamp(0.0, 1.0);

      // Ease-out: fast start, slow finish.
      final ease = 1.0 - pow(1.0 - tLocal, 2.5).toDouble();

      // Position — initial burst direction + gravity pulling downward.
      final dx = cos(p.angle) * p.speed * ease;
      final dy = sin(p.angle) * p.speed * ease + p.gravity * tLocal * tLocal;
      final pos = origin + Offset(dx, dy);

      // Opacity: full until deathT, then fade to 0.
      double opacity;
      if (t >= p.deathT) {
        opacity = ((1.0 - (t - p.deathT) / (1.0 - p.deathT))).clamp(0.0, 1.0);
      } else {
        opacity = 1.0;
      }
      if (opacity <= 0) continue;

      // Radius shrinks as particle falls (simulates sparks cooling).
      final r = p.radius * (0.5 + 0.5 * ease) * (0.6 + 0.4 * (1.0 - tLocal));

      // Under-wash: blurred circle at low opacity.
      washPaint
        ..color = p.color.withValues(alpha: opacity * 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.9);
      canvas.drawCircle(pos, r * 1.6, washPaint);

      // Core dot: crisp pigment.
      corePaint
        ..color = p.color.withValues(alpha: opacity * 0.85)
        ..maskFilter = null;
      canvas.drawCircle(pos, r, corePaint);
    }
  }

  @override
  bool shouldRepaint(_InkBurstPainter oldDelegate) => oldDelegate.t != t;
}

/// Transparent overlay widget that renders a watercolor ink-burst effect.
///
/// Use a [GlobalKey] to obtain the state and call [InkBurstOverlayState.trigger]
/// with the screen-space origin where the burst should appear.
///
/// Particles burst outward, then gravity pulls them downward so the effect
/// trickles down the screen like sparks from a firework.
class InkBurstOverlay extends StatefulWidget {
  const InkBurstOverlay({super.key});

  @override
  State<InkBurstOverlay> createState() => InkBurstOverlayState();
}

class InkBurstOverlayState extends State<InkBurstOverlay>
    with TickerProviderStateMixin {
  static const _particleCount = 36;
  static const _duration = Duration(milliseconds: 1400);

  static const _palette = [
    FlitColors.gold,
    FlitColors.success,
    FlitColors.accent,
  ];

  AnimationController? _controller;
  List<_InkParticle> _particles = const [];
  Offset _origin = Offset.zero;
  final Random _rng = Random();

  /// Fire the ink-burst effect at [origin] (in screen coordinates).
  void trigger(Offset origin) {
    // Reset if already animating.
    _controller?.stop();
    _controller?.dispose();

    _controller = AnimationController(vsync: this, duration: _duration);

    setState(() {
      _origin = origin;
      _particles = _spawnParticles(origin);
    });

    _controller!.forward().then((_) {
      if (mounted) {
        setState(() => _particles = const []);
      }
    });
  }

  List<_InkParticle> _spawnParticles(Offset origin) {
    return List.generate(_particleCount, (_) {
      final baseColor = _palette[_rng.nextInt(_palette.length)];
      // Slight colour variation for organic feel.
      final variation = (_rng.nextDouble() - 0.5) * 0.16; // ±0.08
      final color = variation > 0
          ? WatercolorStyle.lighten(baseColor, variation)
          : WatercolorStyle.darken(baseColor, -variation);

      // Bias angles upward (between -150° and -30° from horizontal)
      // so particles burst up, then gravity pulls them down.
      final angle = -pi * 0.17 + (_rng.nextDouble() - 0.5) * pi * 1.2;

      return _InkParticle(
        angle: angle,
        speed: 50 + _rng.nextDouble() * 160, // 50–210 px
        radius: 2.5 + _rng.nextDouble() * 5, // 2.5–7.5 px
        color: color,
        birthT: _rng.nextDouble() * 0.25,
        deathT: 0.55 + _rng.nextDouble() * 0.45,
        gravity: 200 + _rng.nextDouble() * 300, // 200–500 px downward pull
      );
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_particles.isEmpty || _controller == null) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller!,
        builder: (_, __) => CustomPaint(
          size: Size.infinite,
          painter: _InkBurstPainter(
            particles: _particles,
            t: _controller!.value,
            origin: _origin,
          ),
        ),
      ),
    );
  }
}
