import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/avatar_config.dart';
import '../flit_game.dart';

/// Renders the player's companion creature flying behind and slightly to the
/// side of the plane. The companion follows the plane with a slight delay,
/// creating a charming sidekick effect.
///
/// Padlocked companions (not yet unlocked) are not rendered.
class CompanionRenderer extends Component with HasGameRef<FlitGame> {
  CompanionRenderer({required this.companionType});

  final AvatarCompanion companionType;

  /// Trail of recent plane world positions — the companion follows this
  /// path with a delay, creating a smooth trailing effect.
  final List<Vector2> _trailPositions = [];
  final List<double> _trailHeadings = [];

  /// How many frames of delay the companion has behind the plane.
  static const int _trailDelay = 15;

  /// Animation phase for wing flapping.
  double _flapPhase = 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.isInLaunchIntro) return;

    if (companionType == AvatarCompanion.none) return;

    // Record plane position with a trailing buffer.
    _trailPositions.add(gameRef.worldPosition.clone());
    _trailHeadings.add(gameRef.heading);

    // Keep only the last N positions.
    while (_trailPositions.length > _trailDelay + 1) {
      _trailPositions.removeAt(0);
      _trailHeadings.removeAt(0);
    }

    // Animate wing flap.
    _flapPhase += dt * 8.0;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (gameRef.isInLaunchIntro) return;

    if (companionType == AvatarCompanion.none) return;
    if (_trailPositions.length < _trailDelay) return;

    // Use the delayed position for the companion.
    final delayedPos = _trailPositions.first;
    final delayedHeading = _trailHeadings.first;

    // Project to screen.
    final screenPos = gameRef.worldToScreen(delayedPos);
    if (screenPos.x < -500) return; // behind camera

    // Offset slightly to the right and up from the plane's trail position.
    final offsetX = screenPos.x + 20;
    final offsetY = screenPos.y - 10;

    canvas.save();
    canvas.translate(offsetX, offsetY);

    // Rotate to match the plane heading relative to camera.
    final visualHeading = delayedHeading - gameRef.heading;
    canvas.rotate(visualHeading);

    _renderCompanion(canvas);

    canvas.restore();
  }

  void _renderCompanion(Canvas canvas) {
    final flapOffset = sin(_flapPhase) * 3.0;

    switch (companionType) {
      case AvatarCompanion.none:
        break;
      case AvatarCompanion.sparrow:
        _renderBird(canvas, flapOffset, FlitColors.textSecondary, 8);
      case AvatarCompanion.eagle:
        _renderEagle(canvas, flapOffset);
      case AvatarCompanion.parrot:
        _renderBird(canvas, flapOffset, const Color(0xFF00CC44), 10);
      case AvatarCompanion.phoenix:
        _renderPhoenix(canvas, flapOffset);
      case AvatarCompanion.dragon:
        _renderDragon(canvas, flapOffset);
    }
  }

  /// Sparrow — small, nimble brown bird with quick flapping wings.
  void _renderBird(Canvas canvas, double flapOffset, Color color, double size) {
    final bodyPaint = Paint()..color = color;
    final wingPaint = Paint()..color = color.withOpacity(0.8);
    final bellyPaint = Paint()
      ..color = Color.lerp(color, const Color(0xFFFFFFFF), 0.4)!;

    // Body (tapered ellipse for streamlined look).
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: size, height: size * 0.5),
      bodyPaint,
    );

    // Lighter belly.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, size * 0.05),
        width: size * 0.6,
        height: size * 0.25,
      ),
      bellyPaint,
    );

    // Left wing with feathered edge.
    final leftWing = Path()
      ..moveTo(-size * 0.25, 0)
      ..quadraticBezierTo(
        -size * 0.7,
        flapOffset - size * 0.5,
        -size * 0.9,
        flapOffset - size * 0.3,
      )
      ..lineTo(-size * 0.75, flapOffset - size * 0.15)
      ..lineTo(-size * 0.6, flapOffset - size * 0.25)
      ..lineTo(-size * 0.1, -size * 0.05)
      ..close();
    canvas.drawPath(leftWing, wingPaint);

    // Right wing.
    final rightWing = Path()
      ..moveTo(size * 0.25, 0)
      ..quadraticBezierTo(
        size * 0.7,
        flapOffset - size * 0.5,
        size * 0.9,
        flapOffset - size * 0.3,
      )
      ..lineTo(size * 0.75, flapOffset - size * 0.15)
      ..lineTo(size * 0.6, flapOffset - size * 0.25)
      ..lineTo(size * 0.1, -size * 0.05)
      ..close();
    canvas.drawPath(rightWing, wingPaint);

    // Tail feathers.
    final tail = Path()
      ..moveTo(-size * 0.1, size * 0.2)
      ..lineTo(-size * 0.15, size * 0.5)
      ..lineTo(0, size * 0.4)
      ..lineTo(size * 0.15, size * 0.5)
      ..lineTo(size * 0.1, size * 0.2)
      ..close();
    canvas.drawPath(tail, wingPaint);

    // Head.
    canvas.drawCircle(Offset(0, -size * 0.3), size * 0.18, bodyPaint);

    // Eye.
    canvas.drawCircle(
      Offset(0, -size * 0.32),
      size * 0.06,
      Paint()..color = const Color(0xFF111111),
    );

    // Beak.
    final beak = Path()
      ..moveTo(0, -size * 0.45)
      ..lineTo(-size * 0.06, -size * 0.38)
      ..lineTo(size * 0.06, -size * 0.38)
      ..close();
    canvas.drawPath(beak, Paint()..color = const Color(0xFFFFAA00));
  }

  /// Eagle — majestic Pidgeot-inspired raptor with crest and broad wingspan.
  void _renderEagle(Canvas canvas, double flapOffset) {
    const size = 14.0;
    final bodyPaint = Paint()..color = const Color(0xFF8B4513);
    final creamPaint = Paint()..color = const Color(0xFFFAE7B5);
    final wingPaint = Paint()..color = const Color(0xFF6B3410).withOpacity(0.9);
    final crestPaint = Paint()..color = const Color(0xFFCC2222);

    // Body.
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: size, height: size * 0.5),
      bodyPaint,
    );

    // Cream chest plumage.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, 0.5),
        width: size * 0.55,
        height: size * 0.3,
      ),
      creamPaint,
    );

    // Broad left wing with layered feathers.
    final leftWing = Path()
      ..moveTo(-size * 0.3, 0)
      ..quadraticBezierTo(
        -size * 0.8,
        flapOffset - size * 0.6,
        -size * 1.1,
        flapOffset - size * 0.2,
      )
      ..lineTo(-size * 0.95, flapOffset - size * 0.05)
      ..lineTo(-size * 0.8, flapOffset - size * 0.15)
      ..lineTo(-size * 0.65, flapOffset)
      ..lineTo(-size * 0.1, -size * 0.05)
      ..close();
    canvas.drawPath(leftWing, wingPaint);

    // Broad right wing.
    final rightWing = Path()
      ..moveTo(size * 0.3, 0)
      ..quadraticBezierTo(
        size * 0.8,
        flapOffset - size * 0.6,
        size * 1.1,
        flapOffset - size * 0.2,
      )
      ..lineTo(size * 0.95, flapOffset - size * 0.05)
      ..lineTo(size * 0.8, flapOffset - size * 0.15)
      ..lineTo(size * 0.65, flapOffset)
      ..lineTo(size * 0.1, -size * 0.05)
      ..close();
    canvas.drawPath(rightWing, wingPaint);

    // Fan tail.
    final tail = Path()
      ..moveTo(-size * 0.15, size * 0.2)
      ..lineTo(-size * 0.25, size * 0.65)
      ..lineTo(-size * 0.1, size * 0.55)
      ..lineTo(0, size * 0.7)
      ..lineTo(size * 0.1, size * 0.55)
      ..lineTo(size * 0.25, size * 0.65)
      ..lineTo(size * 0.15, size * 0.2)
      ..close();
    canvas.drawPath(tail, creamPaint);

    // Head.
    canvas.drawCircle(const Offset(0, -size * 0.32), size * 0.22, creamPaint);

    // Red-and-gold crest plumage (swept back like Pidgeot).
    final crest = Path()
      ..moveTo(0, -size * 0.52)
      ..quadraticBezierTo(-size * 0.15, -size * 0.65, -size * 0.3, -size * 0.75)
      ..lineTo(-size * 0.1, -size * 0.5)
      ..quadraticBezierTo(size * 0.05, -size * 0.7, size * 0.25, -size * 0.8)
      ..lineTo(size * 0.05, -size * 0.5)
      ..close();
    canvas.drawPath(crest, crestPaint);
    // Gold crest highlights.
    final crestGold = Path()
      ..moveTo(0, -size * 0.5)
      ..lineTo(-size * 0.08, -size * 0.65)
      ..lineTo(size * 0.05, -size * 0.55)
      ..close();
    canvas.drawPath(crestGold, Paint()..color = const Color(0xFFFFCC00));

    // Sharp eyes.
    canvas.drawCircle(
      const Offset(-2, -size * 0.34),
      1.8,
      Paint()..color = const Color(0xFFFF3300),
    );
    canvas.drawCircle(
      const Offset(2, -size * 0.34),
      1.8,
      Paint()..color = const Color(0xFFFF3300),
    );
    canvas.drawCircle(
      const Offset(-2, -size * 0.34),
      0.8,
      Paint()..color = const Color(0xFF000000),
    );
    canvas.drawCircle(
      const Offset(2, -size * 0.34),
      0.8,
      Paint()..color = const Color(0xFF000000),
    );

    // Hooked beak.
    final beak = Path()
      ..moveTo(0, -size * 0.5)
      ..lineTo(-size * 0.06, -size * 0.42)
      ..lineTo(0, -size * 0.35)
      ..lineTo(size * 0.06, -size * 0.42)
      ..close();
    canvas.drawPath(beak, Paint()..color = const Color(0xFFFF8800));
  }

  /// Phoenix — blazing bird with trailing fire particles.
  void _renderPhoenix(Canvas canvas, double flapOffset) {
    const size = 13.0;
    final bodyPaint = Paint()..color = const Color(0xFFFF6600);
    final wingPaint = Paint()
      ..color = const Color(0xFFFF4400).withOpacity(0.85);
    final goldPaint = Paint()..color = const Color(0xFFFFDD00);

    // Fire glow aura.
    canvas.drawCircle(
      Offset.zero,
      size * 0.8,
      Paint()
        ..color = const Color(0xFFFF4400).withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Body.
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: size, height: size * 0.45),
      bodyPaint,
    );

    // Golden belly shimmer.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, 0.5),
        width: size * 0.5,
        height: size * 0.2,
      ),
      goldPaint,
    );

    // Flame wings.
    final leftWing = Path()
      ..moveTo(-size * 0.3, 0)
      ..quadraticBezierTo(
        -size * 0.8,
        flapOffset - size * 0.55,
        -size * 1.0,
        flapOffset - size * 0.2,
      )
      ..lineTo(-size * 0.85, flapOffset)
      ..lineTo(-size * 0.7, flapOffset - size * 0.1)
      ..lineTo(-size * 0.5, flapOffset + size * 0.1)
      ..lineTo(-size * 0.1, -size * 0.05)
      ..close();
    canvas.drawPath(leftWing, wingPaint);

    final rightWing = Path()
      ..moveTo(size * 0.3, 0)
      ..quadraticBezierTo(
        size * 0.8,
        flapOffset - size * 0.55,
        size * 1.0,
        flapOffset - size * 0.2,
      )
      ..lineTo(size * 0.85, flapOffset)
      ..lineTo(size * 0.7, flapOffset - size * 0.1)
      ..lineTo(size * 0.5, flapOffset + size * 0.1)
      ..lineTo(size * 0.1, -size * 0.05)
      ..close();
    canvas.drawPath(rightWing, wingPaint);

    // Flame tail.
    final tail = Path()
      ..moveTo(-size * 0.1, size * 0.2)
      ..lineTo(-size * 0.2, size * 0.8)
      ..lineTo(-size * 0.05, size * 0.6)
      ..lineTo(0, size * 0.9)
      ..lineTo(size * 0.05, size * 0.6)
      ..lineTo(size * 0.2, size * 0.8)
      ..lineTo(size * 0.1, size * 0.2)
      ..close();
    canvas.drawPath(tail, goldPaint);
    // Inner tail glow.
    canvas.drawPath(
      tail,
      Paint()
        ..color = const Color(0xFFFF8800).withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Head.
    canvas.drawCircle(const Offset(0, -size * 0.3), size * 0.2, bodyPaint);
    // Crown crest.
    final crest = Path()
      ..moveTo(0, -size * 0.5)
      ..lineTo(-size * 0.1, -size * 0.7)
      ..lineTo(0, -size * 0.55)
      ..lineTo(size * 0.1, -size * 0.7)
      ..lineTo(0, -size * 0.5)
      ..close();
    canvas.drawPath(crest, goldPaint);

    // Eyes.
    canvas.drawCircle(
      const Offset(-1.5, -size * 0.32),
      1.5,
      Paint()..color = const Color(0xFFFFFF00),
    );
    canvas.drawCircle(
      const Offset(1.5, -size * 0.32),
      1.5,
      Paint()..color = const Color(0xFFFFFF00),
    );
  }

  /// Dragon — fierce Charizard-inspired fire dragon with massive wings.
  void _renderDragon(Canvas canvas, double flapOffset) {
    const size = 16.0;
    final bodyPaint = Paint()..color = const Color(0xFFE85D04);
    final bellyPaint = Paint()..color = const Color(0xFFFFCC66);
    final wingPaint = Paint()
      ..color = const Color(0xFF1B998B).withOpacity(0.85);
    final wingInnerPaint = Paint()
      ..color = const Color(0xFF3DCCC7).withOpacity(0.6);

    // Fire breath glow.
    canvas.drawCircle(
      const Offset(0, -size * 0.7),
      size * 0.35,
      Paint()
        ..color = const Color(0xFFFF4400).withOpacity(0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Muscular body.
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: size, height: size * 0.55),
      bodyPaint,
    );

    // Pale belly scales.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, 1),
        width: size * 0.55,
        height: size * 0.35,
      ),
      bellyPaint,
    );

    // Large bat-like left wing with membrane detail.
    final leftWing = Path()
      ..moveTo(-size * 0.35, -1)
      ..lineTo(-size * 0.9, flapOffset - size * 0.7)
      ..lineTo(-size * 0.7, flapOffset - size * 0.3)
      ..lineTo(-size * 1.1, flapOffset - size * 0.5)
      ..lineTo(-size * 0.85, flapOffset - size * 0.15)
      ..lineTo(-size * 1.0, flapOffset - size * 0.2)
      ..lineTo(-size * 0.6, flapOffset + size * 0.05)
      ..lineTo(-size * 0.15, -size * 0.05)
      ..close();
    canvas.drawPath(leftWing, wingPaint);
    // Wing membrane inner.
    final leftInner = Path()
      ..moveTo(-size * 0.35, -1)
      ..lineTo(-size * 0.7, flapOffset - size * 0.3)
      ..lineTo(-size * 0.6, flapOffset + size * 0.05)
      ..lineTo(-size * 0.15, -size * 0.05)
      ..close();
    canvas.drawPath(leftInner, wingInnerPaint);

    // Large bat-like right wing.
    final rightWing = Path()
      ..moveTo(size * 0.35, -1)
      ..lineTo(size * 0.9, flapOffset - size * 0.7)
      ..lineTo(size * 0.7, flapOffset - size * 0.3)
      ..lineTo(size * 1.1, flapOffset - size * 0.5)
      ..lineTo(size * 0.85, flapOffset - size * 0.15)
      ..lineTo(size * 1.0, flapOffset - size * 0.2)
      ..lineTo(size * 0.6, flapOffset + size * 0.05)
      ..lineTo(size * 0.15, -size * 0.05)
      ..close();
    canvas.drawPath(rightWing, wingPaint);
    final rightInner = Path()
      ..moveTo(size * 0.35, -1)
      ..lineTo(size * 0.7, flapOffset - size * 0.3)
      ..lineTo(size * 0.6, flapOffset + size * 0.05)
      ..lineTo(size * 0.15, -size * 0.05)
      ..close();
    canvas.drawPath(rightInner, wingInnerPaint);

    // Flame-tipped tail.
    final tail = Path()
      ..moveTo(0, size * 0.25)
      ..quadraticBezierTo(-size * 0.15, size * 0.6, -size * 0.1, size * 0.9)
      ..lineTo(0, size * 0.75)
      ..lineTo(size * 0.1, size * 0.9)
      ..quadraticBezierTo(size * 0.15, size * 0.6, 0, size * 0.25)
      ..close();
    canvas.drawPath(tail, bodyPaint);
    // Flame tip.
    final flameTip = Path()
      ..moveTo(-size * 0.1, size * 0.85)
      ..lineTo(-size * 0.15, size * 1.1)
      ..lineTo(0, size * 1.0)
      ..lineTo(size * 0.15, size * 1.1)
      ..lineTo(size * 0.1, size * 0.85)
      ..close();
    canvas.drawPath(flameTip, Paint()..color = const Color(0xFFFF6600));
    canvas.drawPath(
      flameTip,
      Paint()
        ..color = const Color(0xFFFFAA00).withOpacity(0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Head with horns.
    canvas.drawCircle(const Offset(0, -size * 0.35), size * 0.22, bodyPaint);
    // Left horn.
    final leftHorn = Path()
      ..moveTo(-size * 0.12, -size * 0.52)
      ..lineTo(-size * 0.25, -size * 0.75)
      ..lineTo(-size * 0.05, -size * 0.55)
      ..close();
    canvas.drawPath(leftHorn, Paint()..color = const Color(0xFF553300));
    // Right horn.
    final rightHorn = Path()
      ..moveTo(size * 0.12, -size * 0.52)
      ..lineTo(size * 0.25, -size * 0.75)
      ..lineTo(size * 0.05, -size * 0.55)
      ..close();
    canvas.drawPath(rightHorn, Paint()..color = const Color(0xFF553300));

    // Fierce eyes.
    canvas.drawCircle(
      const Offset(-2.5, -size * 0.38),
      2.0,
      Paint()..color = const Color(0xFFFFDD00),
    );
    canvas.drawCircle(
      const Offset(2.5, -size * 0.38),
      2.0,
      Paint()..color = const Color(0xFFFFDD00),
    );
    canvas.drawCircle(
      const Offset(-2.5, -size * 0.38),
      0.8,
      Paint()..color = const Color(0xFF000000),
    );
    canvas.drawCircle(
      const Offset(2.5, -size * 0.38),
      0.8,
      Paint()..color = const Color(0xFF000000),
    );

    // Snout / nostrils.
    canvas.drawCircle(
      const Offset(-1.5, -size * 0.5),
      0.8,
      Paint()..color = const Color(0xFF333333),
    );
    canvas.drawCircle(
      const Offset(1.5, -size * 0.5),
      0.8,
      Paint()..color = const Color(0xFF333333),
    );
  }
}
