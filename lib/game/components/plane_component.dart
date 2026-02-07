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
    this.colorScheme,
  }) : super(
          size: Vector2(60, 60),
          anchor: Anchor.center,
        );

  final void Function(bool isHigh) onAltitudeChanged;

  /// Optional color scheme from equipped plane cosmetic.
  /// Keys: 'primary', 'secondary', 'detail' (ARGB ints).
  final Map<String, int>? colorScheme;

  /// Current turning direction: -1 (left), 0 (straight), 1 (right)
  double _turnDirection = 0;

  /// Whether the player is actively dragging (vs. coasting).
  bool _isDragging = false;

  /// Current altitude: true = high (fast), false = low (slow, detailed)
  bool _isHighAltitude = true;

  /// Visual heading set by the game (radians)
  double visualHeading = 0;

  /// Base speed at high altitude (world units per second)
  static const double highAltitudeSpeed = 200;

  /// Speed multiplier at low altitude
  static const double lowAltitudeSpeedMultiplier = 0.5;

  /// Turn rate in radians per second
  static const double turnRate = 2.5;

  /// Maximum bank angle for visual effect
  static const double _maxBankAngle = 0.35;

  /// How fast the turn decays when the player releases (per-second rate).
  /// Higher = faster decay. 5.0 means ~0.2 seconds to coast to stop.
  static const double _turnDecayRate = 5.0;

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

    // Decay turn direction when not actively dragging (dt-based)
    if (!_isDragging) {
      // Exponential decay: multiply by e^(-rate * dt) each frame
      _turnDirection *= exp(-_turnDecayRate * dt);
      // Snap to zero when close enough to avoid endless micro-turns
      if (_turnDirection.abs() < 0.01) _turnDirection = 0;
    }
    // Clamp to prevent infinite spinning from accumulated input
    _turnDirection = _turnDirection.clamp(-1.0, 1.0);

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
    final primary = colorScheme != null
        ? Color(colorScheme!['primary'] ?? 0xFFF5F0E0)
        : FlitColors.planeBody;
    final secondary = colorScheme != null
        ? Color(colorScheme!['secondary'] ?? 0xFFC0392B)
        : FlitColors.planeAccent;
    final detail = colorScheme != null
        ? Color(colorScheme!['detail'] ?? 0xFF8B4513)
        : FlitColors.planeWing;

    final bodyPaint = Paint()..color = primary;
    final wingPaint = Paint()..color = detail;
    final accentPaint = Paint()..color = secondary;
    final highlightPaint = Paint()..color = FlitColors.planeHighlight;

    // --- Tail assembly ---
    // Horizontal stabiliser — smooth ellipse
    final tailPath = Path()
      ..moveTo(-10, 14)
      ..quadraticBezierTo(-12, 16, -10, 18)
      ..lineTo(10, 18)
      ..quadraticBezierTo(12, 16, 10, 14)
      ..close();
    canvas.drawPath(tailPath, wingPaint);

    // Vertical fin
    final finPath = Path()
      ..moveTo(0, 11)
      ..quadraticBezierTo(-4, 15, -2, 18)
      ..lineTo(2, 18)
      ..quadraticBezierTo(4, 15, 0, 11)
      ..close();
    canvas.drawPath(finPath, accentPaint);

    // --- Main wings --- (smooth, tapered)
    final leftWing = Path()
      ..moveTo(-4, -1)
      ..quadraticBezierTo(-14, 0, -26, 2)
      ..quadraticBezierTo(-27, 4, -24, 5)
      ..lineTo(-4, 3)
      ..close();
    canvas.drawPath(leftWing, wingPaint);
    // Wing highlight
    canvas.drawPath(
      Path()
        ..moveTo(-4, -0.5)
        ..quadraticBezierTo(-12, 0.5, -22, 2.5)
        ..lineTo(-22, 3.5)
        ..quadraticBezierTo(-12, 1.5, -4, 1)
        ..close(),
      highlightPaint,
    );

    final rightWing = Path()
      ..moveTo(4, -1)
      ..quadraticBezierTo(14, 0, 26, 2)
      ..quadraticBezierTo(27, 4, 24, 5)
      ..lineTo(4, 3)
      ..close();
    canvas.drawPath(rightWing, wingPaint);
    canvas.drawPath(
      Path()
        ..moveTo(4, -0.5)
        ..quadraticBezierTo(12, 0.5, 22, 2.5)
        ..lineTo(22, 3.5)
        ..quadraticBezierTo(12, 1.5, 4, 1)
        ..close(),
      highlightPaint,
    );

    // --- Fuselage --- (smooth, tapered)
    final fuselagePath = Path()
      ..moveTo(0, -16)
      ..quadraticBezierTo(5, -12, 5, -2)
      ..quadraticBezierTo(4, 10, 3, 16)
      ..quadraticBezierTo(0, 18, -3, 16)
      ..quadraticBezierTo(-4, 10, -5, -2)
      ..quadraticBezierTo(-5, -12, 0, -16)
      ..close();
    canvas.drawPath(fuselagePath, bodyPaint);

    // Fuselage highlight (center streak)
    final highlightStreak = Path()
      ..moveTo(0, -14)
      ..quadraticBezierTo(2.5, -8, 2, 0)
      ..lineTo(1, 10)
      ..lineTo(-1, 10)
      ..lineTo(-2, 0)
      ..quadraticBezierTo(-2.5, -8, 0, -14)
      ..close();
    canvas.drawPath(highlightStreak, highlightPaint);

    // Accent stripe
    final stripe = Path()
      ..moveTo(-3, -4)
      ..lineTo(3, -4)
      ..lineTo(3, 2)
      ..lineTo(-3, 2)
      ..close();
    canvas.drawPath(stripe, accentPaint);

    // Cockpit
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -9), width: 5, height: 6),
      Paint()..color = const Color(0xFF4A90B8),
    );
    // Cockpit glint
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-0.5, -10), width: 2, height: 3),
      Paint()..color = const Color(0xFF8CC8E8),
    );

    // --- Engine / Nose cone ---
    canvas.drawCircle(
      const Offset(0, -16),
      3.0,
      Paint()..color = const Color(0xFF888888),
    );
    canvas.drawCircle(
      const Offset(0, -16),
      1.5,
      Paint()..color = const Color(0xFF555555),
    );

    // Propeller blur disc
    final propDiscPaint = Paint()
      ..color = FlitColors.planeBody.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(0, -17), 8, propDiscPaint);

    // Propeller blades
    final bladePaint = Paint()
      ..color = const Color(0xFF666666).withOpacity(0.8)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    const bladeLen = 7.0;
    for (var i = 0; i < 2; i++) {
      final a = _propAngle + i * pi;
      canvas.drawLine(
        Offset(cos(a) * bladeLen, -17 + sin(a) * bladeLen),
        Offset(-cos(a) * bladeLen, -17 - sin(a) * bladeLen),
        bladePaint,
      );
    }

    // Wing tip accents (navigation lights)
    canvas.drawCircle(const Offset(-25, 3.5), 1.8, accentPaint);
    canvas.drawCircle(
        const Offset(25, 3.5), 1.8, Paint()..color = FlitColors.success);
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

  /// Set turn direction from active input (drag or keyboard).
  void setTurnDirection(double direction) {
    _turnDirection = direction.clamp(-1, 1);
    _isDragging = true;
  }

  /// Called when the player lifts their finger — plane coasts to straight.
  void releaseTurn() {
    _isDragging = false;
    // _turnDirection will decay in update()
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
    this.maxLife = 4.0,
  }) : life = maxLife;

  /// Offset from the plane's screen position when spawned
  final Vector2 screenOffset;
  final double size;
  final double maxLife;
  double life;
}
