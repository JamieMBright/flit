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
        _renderBird(canvas, flapOffset, const Color(0xFF8B4513), 12);
      case AvatarCompanion.parrot:
        _renderBird(canvas, flapOffset, const Color(0xFF00CC44), 10);
      case AvatarCompanion.phoenix:
        _renderPhoenix(canvas, flapOffset);
      case AvatarCompanion.dragon:
        _renderDragon(canvas, flapOffset);
    }
  }

  /// Generic bird shape — small body with flapping wings.
  void _renderBird(Canvas canvas, double flapOffset, Color color, double size) {
    final bodyPaint = Paint()..color = color;
    final wingPaint = Paint()..color = color.withOpacity(0.8);

    // Body (ellipse).
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: size, height: size * 0.5),
      bodyPaint,
    );

    // Left wing.
    final leftWing = Path()
      ..moveTo(-size * 0.3, 0)
      ..lineTo(-size * 0.8, flapOffset - size * 0.4)
      ..lineTo(-size * 0.1, -size * 0.1)
      ..close();
    canvas.drawPath(leftWing, wingPaint);

    // Right wing.
    final rightWing = Path()
      ..moveTo(size * 0.3, 0)
      ..lineTo(size * 0.8, flapOffset - size * 0.4)
      ..lineTo(size * 0.1, -size * 0.1)
      ..close();
    canvas.drawPath(rightWing, wingPaint);

    // Beak.
    canvas.drawCircle(
      Offset(0, -size * 0.35),
      size * 0.12,
      Paint()..color = const Color(0xFFFFCC00),
    );
  }

  /// Phoenix — fiery bird with glowing trail.
  void _renderPhoenix(Canvas canvas, double flapOffset) {
    _renderBird(canvas, flapOffset, const Color(0xFFFF6600), 12);

    // Fire glow effect.
    canvas.drawCircle(
      const Offset(0, 4),
      8,
      Paint()
        ..color = const Color(0xFFFF4400).withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  /// Dragon — larger creature with pointed wings and tail.
  void _renderDragon(Canvas canvas, double flapOffset) {
    final bodyPaint = Paint()..color = const Color(0xFF2E8B57);
    final wingPaint = Paint()..color = const Color(0xFF1A6B37).withOpacity(0.8);

    // Body.
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 16, height: 7),
      bodyPaint,
    );

    // Left wing (bat-like).
    final leftWing = Path()
      ..moveTo(-5, 0)
      ..lineTo(-14, flapOffset - 8)
      ..lineTo(-10, flapOffset - 3)
      ..lineTo(-7, flapOffset - 7)
      ..lineTo(-3, -1)
      ..close();
    canvas.drawPath(leftWing, wingPaint);

    // Right wing.
    final rightWing = Path()
      ..moveTo(5, 0)
      ..lineTo(14, flapOffset - 8)
      ..lineTo(10, flapOffset - 3)
      ..lineTo(7, flapOffset - 7)
      ..lineTo(3, -1)
      ..close();
    canvas.drawPath(rightWing, wingPaint);

    // Tail.
    final tail = Path()
      ..moveTo(0, 4)
      ..lineTo(-2, 12)
      ..lineTo(0, 10)
      ..lineTo(2, 12)
      ..close();
    canvas.drawPath(tail, bodyPaint);

    // Eyes.
    canvas.drawCircle(
      const Offset(-2, -3),
      1.5,
      Paint()..color = const Color(0xFFFFCC00),
    );
    canvas.drawCircle(
      const Offset(2, -3),
      1.5,
      Paint()..color = const Color(0xFFFFCC00),
    );
  }
}
