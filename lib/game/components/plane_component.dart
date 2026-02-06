import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';

/// The player's plane component.
///
/// Renders at a fixed screen position (set by FlitGame).
/// The world scrolls underneath - the plane doesn't move on screen.
/// Renders a more realistic, lo-fi top-down aircraft with shadow and detail.
class PlaneComponent extends PositionComponent with HasGameRef {
  PlaneComponent({
    required this.onAltitudeChanged,
  }) : super(
          size: Vector2(60, 60),
          anchor: Anchor.center,
        );

  final void Function(bool isHigh) onAltitudeChanged;

  /// Current turning direction: -1 (left), 0 (straight), 1 (right)
  double _turnDirection = 0;

  /// Current altitude: true = high (fast), false = low (slow, detailed)
  bool _isHighAltitude = true;

  /// Visual heading set by the game (radians)
  double visualHeading = 0;

  /// Base speed at high altitude (world units per second)
  static const double highAltitudeSpeed = 200;

  /// Speed multiplier at low altitude
  static const double lowAltitudeSpeedMultiplier = 0.5;

  /// Turn rate in radians per second
  static const double turnRate = 2.0;

  /// Maximum bank angle for visual effect
  static const double _maxBankAngle = 0.35;

  /// Current visual bank angle (smoothed)
  double _currentBank = 0;

  /// Contrail particles (rendered in world space by WorldMap)
  final List<ContrailParticle> contrails = [];

  /// Time accumulator for contrail spawning
  double _contrailTimer = 0;

  /// Contrail spawn interval
  static const double _contrailInterval = 0.04;

  /// Altitude transition progress (0 = low, 1 = high)
  double _altitudeTransition = 1.0;

  /// Propeller spin angle
  double _propAngle = 0;

  /// Fuel boost multiplier from pilot license (solo play only, 1.0 = no boost).
  double fuelBoostMultiplier = 1.0;

  bool get isHighAltitude => _isHighAltitude;
  double get turnDirection => _turnDirection;

  double get currentSpeed =>
      highAltitudeSpeed *
      (_isHighAltitude ? 1.0 : lowAltitudeSpeedMultiplier) *
      fuelBoostMultiplier;

  @override
  void update(double dt) {
    super.update(dt);

    // Smooth bank angle
    final targetBank = _turnDirection * _maxBankAngle;
    _currentBank += (targetBank - _currentBank) * min(1.0, dt * 8);

    // Smooth altitude transition
    final targetAlt = _isHighAltitude ? 1.0 : 0.0;
    _altitudeTransition += (targetAlt - _altitudeTransition) * min(1.0, dt * 3);

    // Spin propeller
    _propAngle += dt * 20;

    // Update contrails
    _updateContrails(dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);

    // Rotate to face heading (adjusted so "up" on screen = forward)
    canvas.rotate(visualHeading + pi / 2);

    // Apply bank tilt
    canvas.scale(1.0 - _currentBank.abs() * 0.1, 1.0);

    // Draw shadow (offset based on altitude)
    final shadowOffset = 3.0 + _altitudeTransition * 5.0;
    _renderPlaneShadow(canvas, shadowOffset);

    // Draw the aircraft
    _renderPlane(canvas);

    canvas.restore();
  }

  void _renderPlaneShadow(Canvas canvas, double offset) {
    final shadowPaint = Paint()
      ..color = FlitColors.planeShadow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.save();
    canvas.translate(offset, offset);

    // Simplified shadow shape
    final fuselage = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 8, height: 34),
      const Radius.circular(4),
    );
    canvas.drawRRect(fuselage, shadowPaint);

    final wings = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, 2), width: 44, height: 7),
      const Radius.circular(2),
    );
    canvas.drawRRect(wings, shadowPaint);

    canvas.restore();
  }

  void _renderPlane(Canvas canvas) {
    final bodyPaint = Paint()..color = FlitColors.planeBody;
    final wingPaint = Paint()..color = FlitColors.planeWing;
    final accentPaint = Paint()..color = FlitColors.planeAccent;
    final outlinePaint = Paint()
      ..color = FlitColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // --- Tail assembly ---
    // Horizontal stabiliser
    final tailWing = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, 15), width: 20, height: 4),
      const Radius.circular(2),
    );
    canvas.drawRRect(tailWing, wingPaint);
    canvas.drawRRect(tailWing, outlinePaint);

    // Vertical stabiliser (fin)
    final finPath = Path()
      ..moveTo(0, 12)
      ..lineTo(-3, 17)
      ..lineTo(3, 17)
      ..close();
    canvas.drawPath(finPath, accentPaint);

    // --- Fuselage ---
    final fuselage = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 8, height: 34),
      const Radius.circular(4),
    );
    canvas.drawRRect(fuselage, bodyPaint);
    canvas.drawRRect(fuselage, outlinePaint);

    // Fuselage accent stripe
    final stripe = Rect.fromCenter(
      center: const Offset(0, -2),
      width: 6,
      height: 12,
    );
    canvas.drawRect(stripe, accentPaint);

    // Cockpit windshield
    final cockpitPath = Path()
      ..moveTo(-2.5, -8)
      ..lineTo(0, -12)
      ..lineTo(2.5, -8)
      ..close();
    canvas.drawPath(
      cockpitPath,
      Paint()..color = FlitColors.oceanShallow,
    );

    // --- Main wings ---
    // Wing shape - slightly swept
    final leftWing = Path()
      ..moveTo(-3, 0)
      ..lineTo(-24, 3)
      ..lineTo(-22, 6)
      ..lineTo(-3, 4)
      ..close();
    canvas.drawPath(leftWing, wingPaint);
    canvas.drawPath(leftWing, outlinePaint);

    final rightWing = Path()
      ..moveTo(3, 0)
      ..lineTo(24, 3)
      ..lineTo(22, 6)
      ..lineTo(3, 4)
      ..close();
    canvas.drawPath(rightWing, wingPaint);
    canvas.drawPath(rightWing, outlinePaint);

    // Wing tip accents
    canvas.drawCircle(const Offset(-23, 4.5), 1.5, accentPaint);
    canvas.drawCircle(const Offset(23, 4.5), 1.5, accentPaint);

    // --- Engine nacelle / Nose ---
    canvas.drawCircle(
      const Offset(0, -15),
      3.5,
      Paint()..color = FlitColors.textMuted,
    );

    // Propeller disc (spinning blur)
    final propPaint = Paint()
      ..color = FlitColors.planeBody.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(const Offset(0, -16), 5, propPaint);

    // Propeller blades
    final bladePaint = Paint()
      ..color = FlitColors.textMuted.withOpacity(0.7)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final bladeLen = 5.0;
    for (var i = 0; i < 2; i++) {
      final a = _propAngle + i * pi;
      canvas.drawLine(
        Offset(0 + cos(a) * bladeLen, -16 + sin(a) * bladeLen),
        Offset(0 - cos(a) * bladeLen, -16 - sin(a) * bladeLen),
        bladePaint,
      );
    }
  }

  void _updateContrails(double dt) {
    _contrailTimer += dt;
    if (_contrailTimer >= _contrailInterval) {
      _contrailTimer = 0;
      _spawnContrailParticle();
    }

    for (var i = contrails.length - 1; i >= 0; i--) {
      contrails[i].life -= dt;
      if (contrails[i].life <= 0) {
        contrails.removeAt(i);
      }
    }
  }

  void _spawnContrailParticle() {
    // Contrails spawn from wing tips in world space
    // The game will convert these to world coordinates
    final leftOffset = Vector2(-20, 4);
    final rightOffset = Vector2(20, 4);

    // Rotate by visual heading
    final cosA = cos(visualHeading + pi / 2);
    final sinA = sin(visualHeading + pi / 2);

    final leftRotated = Vector2(
      leftOffset.x * cosA - leftOffset.y * sinA,
      leftOffset.x * sinA + leftOffset.y * cosA,
    );
    final rightRotated = Vector2(
      rightOffset.x * cosA - rightOffset.y * sinA,
      rightOffset.x * sinA + rightOffset.y * cosA,
    );

    // Store as screen-relative offset from plane center
    contrails.add(ContrailParticle(
      screenOffset: leftRotated,
      size: 2 + Random().nextDouble() * 1.5,
    ));
    contrails.add(ContrailParticle(
      screenOffset: rightRotated,
      size: 2 + Random().nextDouble() * 1.5,
    ));
  }

  void setTurnDirection(double direction) {
    _turnDirection = direction.clamp(-1, 1);
  }

  void toggleAltitude() {
    _isHighAltitude = !_isHighAltitude;
    onAltitudeChanged(_isHighAltitude);
  }

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
    required this.screenOffset,
    required this.size,
    this.maxLife = 1.0,
  }) : life = maxLife;

  /// Offset from the plane's screen position when spawned
  final Vector2 screenOffset;
  final double size;
  final double maxLife;
  double life;
}
