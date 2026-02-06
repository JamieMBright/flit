import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';

/// The player's bi-plane component.
/// Handles rendering, tilt animation, and contrails.
class PlaneComponent extends PositionComponent with HasGameRef {
  PlaneComponent({
    required this.onAltitudeChanged,
  }) : super(
          size: Vector2(40, 40),
          anchor: Anchor.center,
        );

  /// Callback when altitude changes
  final void Function(bool isHigh) onAltitudeChanged;

  /// Current turning direction: -1 (left), 0 (straight), 1 (right)
  double _turnDirection = 0;

  /// Current altitude: true = high (fast), false = low (slow, detailed)
  bool _isHighAltitude = true;

  /// Base speed at high altitude (pixels per second)
  static const double _highAltitudeSpeed = 300;

  /// Speed multiplier at low altitude
  static const double _lowAltitudeSpeedMultiplier = 0.5;

  /// Turn rate in radians per second
  static const double _turnRate = 2.5;

  /// Maximum tilt angle for visual effect
  static const double _maxTiltAngle = 0.4;

  /// Contrail particles
  final List<ContrailParticle> _contrails = [];

  /// Time accumulator for contrail spawning
  double _contrailTimer = 0;

  /// Contrail spawn interval
  static const double _contrailInterval = 0.03;

  bool get isHighAltitude => _isHighAltitude;

  double get currentSpeed =>
      _highAltitudeSpeed * (_isHighAltitude ? 1.0 : _lowAltitudeSpeedMultiplier);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Position at center of screen initially
    position = gameRef.size / 2;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Update rotation based on turn direction
    if (_turnDirection != 0) {
      angle += _turnDirection * _turnRate * dt;
    }

    // Move forward in the direction we're facing
    final direction = Vector2(cos(angle - pi / 2), sin(angle - pi / 2));
    position += direction * currentSpeed * dt;

    // Wrap around screen edges
    _wrapPosition();

    // Update contrails
    _updateContrails(dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Draw contrails first (behind plane)
    _renderContrails(canvas);

    // Draw the bi-plane
    _renderPlane(canvas);
  }

  void _renderPlane(Canvas canvas) {
    final paint = Paint()..color = FlitColors.planeBody;
    final accentPaint = Paint()..color = FlitColors.planeAccent;

    // Save canvas state for tilt effect
    canvas.save();

    // Apply visual tilt based on turn direction
    final tiltAngle = _turnDirection * _maxTiltAngle;
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(tiltAngle * 0.3); // Subtle roll effect
    canvas.translate(-size.x / 2, -size.y / 2);

    // Fuselage (body)
    final fuselageRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y / 2),
        width: 8,
        height: 28,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(fuselageRect, paint);

    // Wings
    final wingRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y / 2 - 2),
        width: 36,
        height: 6,
      ),
      const Radius.circular(2),
    );
    canvas.drawRRect(wingRect, paint);

    // Tail
    final tailRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y / 2 + 12),
        width: 16,
        height: 4,
      ),
      const Radius.circular(2),
    );
    canvas.drawRRect(tailRect, paint);

    // Accent stripe on fuselage
    final stripeRect = Rect.fromCenter(
      center: Offset(size.x / 2, size.y / 2 - 4),
      width: 6,
      height: 3,
    );
    canvas.drawRect(stripeRect, accentPaint);

    // Propeller (simple circle)
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2 - 14),
      3,
      accentPaint,
    );

    canvas.restore();
  }

  void _renderContrails(Canvas canvas) {
    for (final particle in _contrails) {
      final opacity = (particle.life / particle.maxLife).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = FlitColors.contrail.withOpacity(opacity * 0.6);

      canvas.drawCircle(
        Offset(
          particle.position.x - position.x + size.x / 2,
          particle.position.y - position.y + size.y / 2,
        ),
        particle.size * (0.5 + opacity * 0.5),
        paint,
      );
    }
  }

  void _updateContrails(double dt) {
    // Spawn new contrail particles
    _contrailTimer += dt;
    if (_contrailTimer >= _contrailInterval) {
      _contrailTimer = 0;
      _spawnContrailParticle();
    }

    // Update existing particles
    for (var i = _contrails.length - 1; i >= 0; i--) {
      _contrails[i].life -= dt;
      if (_contrails[i].life <= 0) {
        _contrails.removeAt(i);
      }
    }
  }

  void _spawnContrailParticle() {
    // Spawn from wing tips
    final leftWingOffset = Vector2(-16, 0);
    final rightWingOffset = Vector2(16, 0);

    // Rotate offsets by current angle
    final cosA = cos(angle);
    final sinA = sin(angle);

    final leftRotated = Vector2(
      leftWingOffset.x * cosA - leftWingOffset.y * sinA,
      leftWingOffset.x * sinA + leftWingOffset.y * cosA,
    );
    final rightRotated = Vector2(
      rightWingOffset.x * cosA - rightWingOffset.y * sinA,
      rightWingOffset.x * sinA + rightWingOffset.y * cosA,
    );

    _contrails.add(ContrailParticle(
      position: position + leftRotated,
      size: 3 + Random().nextDouble() * 2,
    ));
    _contrails.add(ContrailParticle(
      position: position + rightRotated,
      size: 3 + Random().nextDouble() * 2,
    ));
  }

  void _wrapPosition() {
    final screenSize = gameRef.size;

    if (position.x < -size.x) {
      position.x = screenSize.x + size.x;
    } else if (position.x > screenSize.x + size.x) {
      position.x = -size.x;
    }

    if (position.y < -size.y) {
      position.y = screenSize.y + size.y;
    } else if (position.y > screenSize.y + size.y) {
      position.y = -size.y;
    }
  }

  /// Set the turn direction: -1 (left), 0 (straight), 1 (right)
  void setTurnDirection(double direction) {
    _turnDirection = direction.clamp(-1, 1);
  }

  /// Toggle between high and low altitude
  void toggleAltitude() {
    _isHighAltitude = !_isHighAltitude;
    onAltitudeChanged(_isHighAltitude);
  }

  /// Set specific altitude
  void setAltitude({required bool high}) {
    if (_isHighAltitude != high) {
      _isHighAltitude = high;
      onAltitudeChanged(_isHighAltitude);
    }
  }
}

/// A single contrail particle
class ContrailParticle {
  ContrailParticle({
    required this.position,
    required this.size,
    this.maxLife = 0.8,
  }) : life = maxLife;

  final Vector2 position;
  final double size;
  final double maxLife;
  double life;
}
