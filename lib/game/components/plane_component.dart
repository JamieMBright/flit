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

  /// Base speed at high altitude (world units per second).
  /// 36 units ≈ 3.6°/sec → crossing Europe (~36°) takes ~10 seconds.
  static const double highAltitudeSpeed = 36;

  /// Speed multiplier at low altitude
  static const double lowAltitudeSpeedMultiplier = 0.5;

  /// Turn rate in radians per second.
  /// 4.0 allows a full circle in ~1.6s — tight enough for U-turns.
  static const double turnRate = 4.0;

  /// Maximum bank angle for visual effect (radians, ~40 degrees).
  static const double _maxBankAngle = 0.7;

  /// How fast the turn decays when the player releases (per-second rate).
  /// Higher = faster decay. 3.0 means ~0.3 seconds to coast to stop.
  static const double _turnDecayRate = 3.0;

  /// Current visual bank angle (smoothed)
  double _currentBank = 0;

  /// Contrail particles (anchored to world positions).
  final List<ContrailParticle> contrails = [];

  /// Time accumulator for contrail spawning
  double _contrailTimer = 0;

  /// Contrail spawn interval
  static const double _contrailInterval = 0.04;

  /// World position set by FlitGame each frame (lng, lat degrees).
  Vector2 worldPos = Vector2.zero();

  /// World heading set by FlitGame each frame (radians, math convention).
  double worldHeading = 0;

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

    // Rotate to face heading. Camera up vector is the heading direction,
    // so visualHeading=0 means the plane faces "up" on screen (forward).
    canvas.rotate(visualHeading);

    // --- 3D banking perspective ---
    // cos(bank) foreshortens the horizontal axis; sin(bank) gives the
    // vertical shift that simulates seeing the plane from behind/above.
    final bankCos = cos(_currentBank); // 1.0 = level, ~0.76 at max bank
    final bankSin = sin(_currentBank); // signed, shows roll direction

    // Draw shadow (offset based on altitude, shifted by bank)
    final shadowOffset = 3.0 + _altitudeTransition * 5.0;
    _renderPlaneShadow(canvas, shadowOffset, bankCos);

    // Draw the aircraft with 3D perspective
    _renderPlane(canvas, bankCos, bankSin);

    canvas.restore();
  }

  void _renderPlaneShadow(Canvas canvas, double offset, double bankCos) {
    final shadowPaint = Paint()
      ..color = FlitColors.planeShadow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.save();
    canvas.translate(offset, offset);

    // Shadow foreshortens with bank too
    final shadowSpan = 44.0 * bankCos.abs();
    final fuselage = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 8, height: 34),
      const Radius.circular(4),
    );
    canvas.drawRRect(fuselage, shadowPaint);

    final wings = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, 2), width: shadowSpan, height: 7),
      const Radius.circular(2),
    );
    canvas.drawRRect(wings, shadowPaint);

    canvas.restore();
  }

  void _renderPlane(Canvas canvas, double bankCos, double bankSin) {
    final primary = colorScheme != null
        ? Color(colorScheme!['primary'] ?? 0xFFF5F0E0)
        : FlitColors.planeBody;
    final secondary = colorScheme != null
        ? Color(colorScheme!['secondary'] ?? 0xFFC0392B)
        : FlitColors.planeAccent;
    final detail = colorScheme != null
        ? Color(colorScheme!['detail'] ?? 0xFF8B4513)
        : FlitColors.planeWing;

    // Darken/lighten colors based on bank for 3D shading.
    // Bank left (negative) = left wing lit, right wing shadowed.
    // Bank right (positive) = right wing lit, left wing shadowed.
    final shade = bankSin; // -1..+1

    Color darken(Color c, double amount) {
      final f = (1.0 - amount).clamp(0.0, 1.0);
      return Color.fromARGB(
        c.alpha,
        (c.red * f).round(),
        (c.green * f).round(),
        (c.blue * f).round(),
      );
    }

    Color lighten(Color c, double amount) {
      final f = amount.clamp(0.0, 1.0);
      return Color.fromARGB(
        c.alpha,
        (c.red + (255 - c.red) * f * 0.3).round(),
        (c.green + (255 - c.green) * f * 0.3).round(),
        (c.blue + (255 - c.blue) * f * 0.3).round(),
      );
    }

    // Banking left (shade < 0): left wing is "up" (lit), right wing "down" (dark)
    // Banking right (shade > 0): right wing is "up" (lit), left wing "down" (dark)
    final leftWingColor = shade < 0 ? lighten(detail, -shade) : darken(detail, shade * 0.4);
    final rightWingColor = shade > 0 ? lighten(detail, shade) : darken(detail, -shade * 0.4);
    final bodyPaint = Paint()..color = primary;
    final accentPaint = Paint()..color = secondary;
    final highlightPaint = Paint()..color = FlitColors.planeHighlight;

    // Underside color — visible when banked
    final undersidePaint = Paint()..color = darken(primary, 0.35);

    // 3D foreshortening: wing span scales with cos(bank)
    final wingSpan = 26.0 * bankCos.abs();
    // Wing vertical shift: the dipping wing moves down on screen
    final wingDip = bankSin * 4.0;

    // --- Underside strip (visible when significantly banked) ---
    final bankAbs = bankSin.abs();
    if (bankAbs > 0.15) {
      final undersideWidth = 6.0 * bankAbs;
      final undersideX = bankSin > 0 ? -undersideWidth / 2 : undersideWidth / 2;
      final undersidePath = Path()
        ..moveTo(undersideX - undersideWidth / 2, -12)
        ..quadraticBezierTo(
          undersideX - undersideWidth / 2 - 1, 0,
          undersideX - undersideWidth / 2, 14,
        )
        ..lineTo(undersideX + undersideWidth / 2, 14)
        ..quadraticBezierTo(
          undersideX + undersideWidth / 2 + 1, 0,
          undersideX + undersideWidth / 2, -12,
        )
        ..close();
      canvas.drawPath(undersidePath, undersidePaint);
    }

    // --- Tail assembly ---
    final tailSpan = 10.0 * bankCos.abs();
    final tailPath = Path()
      ..moveTo(-tailSpan, 14 + wingDip * 0.3)
      ..quadraticBezierTo(-tailSpan - 2, 16, -tailSpan, 18)
      ..lineTo(tailSpan, 18 - wingDip * 0.3)
      ..quadraticBezierTo(tailSpan + 2, 16, tailSpan, 14 - wingDip * 0.3)
      ..close();
    canvas.drawPath(tailPath, Paint()..color = darken(detail, 0.1));

    // Vertical fin — slightly rotated with bank
    final finPath = Path()
      ..moveTo(bankSin * 2, 11)
      ..quadraticBezierTo(-4 + bankSin * 3, 15, -2 + bankSin * 2, 18)
      ..lineTo(2 + bankSin * 2, 18)
      ..quadraticBezierTo(4 + bankSin * 3, 15, bankSin * 2, 11)
      ..close();
    canvas.drawPath(finPath, accentPaint);

    // --- Main wings (3D: asymmetric span and dip) ---
    // Left wing — length and dip depend on bank
    final leftSpan = wingSpan + bankSin * 8; // grows when banking right
    final leftDip = wingDip;
    final leftWing = Path()
      ..moveTo(-4, -1 + leftDip * 0.2)
      ..quadraticBezierTo(-leftSpan * 0.5, 0 + leftDip * 0.5, -leftSpan, 2 + leftDip)
      ..quadraticBezierTo(-leftSpan - 1, 4 + leftDip, -leftSpan + 2, 5 + leftDip)
      ..lineTo(-4, 3 + leftDip * 0.2)
      ..close();
    canvas.drawPath(leftWing, Paint()..color = leftWingColor);

    // Left wing highlight
    if (shade <= 0) {
      canvas.drawPath(
        Path()
          ..moveTo(-4, -0.5 + leftDip * 0.2)
          ..quadraticBezierTo(
            -leftSpan * 0.4, 0.5 + leftDip * 0.3,
            -leftSpan * 0.8, 2.5 + leftDip * 0.8,
          )
          ..lineTo(-leftSpan * 0.8, 3.5 + leftDip * 0.8)
          ..quadraticBezierTo(
            -leftSpan * 0.4, 1.5 + leftDip * 0.3,
            -4, 1 + leftDip * 0.2,
          )
          ..close(),
        highlightPaint,
      );
    }

    // Right wing
    final rightSpan = wingSpan - bankSin * 8; // grows when banking left
    final rightDip = -wingDip;
    final rightWing = Path()
      ..moveTo(4, -1 + rightDip * 0.2)
      ..quadraticBezierTo(rightSpan * 0.5, 0 + rightDip * 0.5, rightSpan, 2 + rightDip)
      ..quadraticBezierTo(rightSpan + 1, 4 + rightDip, rightSpan - 2, 5 + rightDip)
      ..lineTo(4, 3 + rightDip * 0.2)
      ..close();
    canvas.drawPath(rightWing, Paint()..color = rightWingColor);

    // Right wing highlight
    if (shade >= 0) {
      canvas.drawPath(
        Path()
          ..moveTo(4, -0.5 + rightDip * 0.2)
          ..quadraticBezierTo(
            rightSpan * 0.4, 0.5 + rightDip * 0.3,
            rightSpan * 0.8, 2.5 + rightDip * 0.8,
          )
          ..lineTo(rightSpan * 0.8, 3.5 + rightDip * 0.8)
          ..quadraticBezierTo(
            rightSpan * 0.4, 1.5 + rightDip * 0.3,
            4, 1 + rightDip * 0.2,
          )
          ..close(),
        highlightPaint,
      );
    }

    // --- Fuselage (3D: slight shift with bank) ---
    final bodyShift = bankSin * 1.5;
    final fuselagePath = Path()
      ..moveTo(bodyShift, -16)
      ..quadraticBezierTo(5 + bodyShift, -12, 5 + bodyShift, -2)
      ..quadraticBezierTo(4 + bodyShift, 10, 3 + bodyShift, 16)
      ..quadraticBezierTo(bodyShift, 18, -3 + bodyShift, 16)
      ..quadraticBezierTo(-4 + bodyShift, 10, -5 + bodyShift, -2)
      ..quadraticBezierTo(-5 + bodyShift, -12, bodyShift, -16)
      ..close();
    canvas.drawPath(fuselagePath, bodyPaint);

    // Fuselage highlight (center streak, offset with bank)
    final highlightStreak = Path()
      ..moveTo(bodyShift - 0.5, -14)
      ..quadraticBezierTo(2.5 + bodyShift, -8, 2 + bodyShift, 0)
      ..lineTo(1 + bodyShift, 10)
      ..lineTo(-1 + bodyShift, 10)
      ..lineTo(-2 + bodyShift, 0)
      ..quadraticBezierTo(-2.5 + bodyShift, -8, bodyShift - 0.5, -14)
      ..close();
    canvas.drawPath(highlightStreak, highlightPaint);

    // Accent stripe
    final stripe = Path()
      ..moveTo(-3 + bodyShift, -4)
      ..lineTo(3 + bodyShift, -4)
      ..lineTo(3 + bodyShift, 2)
      ..lineTo(-3 + bodyShift, 2)
      ..close();
    canvas.drawPath(stripe, accentPaint);

    // Cockpit
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bodyShift, -9),
        width: 5,
        height: 6,
      ),
      Paint()..color = const Color(0xFF4A90B8),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-0.5 + bodyShift, -10),
        width: 2,
        height: 3,
      ),
      Paint()..color = const Color(0xFF8CC8E8),
    );

    // --- Engine / Nose cone ---
    canvas.drawCircle(
      Offset(bodyShift, -16),
      3.0,
      Paint()..color = const Color(0xFF888888),
    );
    canvas.drawCircle(
      Offset(bodyShift, -16),
      1.5,
      Paint()..color = const Color(0xFF555555),
    );

    // Propeller blur disc
    final propDiscPaint = Paint()
      ..color = FlitColors.planeBody.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(bodyShift, -17), 8, propDiscPaint);

    // Propeller blades
    final bladePaint = Paint()
      ..color = const Color(0xFF666666).withOpacity(0.8)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    const bladeLen = 7.0;
    for (var i = 0; i < 2; i++) {
      final a = _propAngle + i * pi;
      canvas.drawLine(
        Offset(bodyShift + cos(a) * bladeLen, -17 + sin(a) * bladeLen),
        Offset(bodyShift - cos(a) * bladeLen, -17 - sin(a) * bladeLen),
        bladePaint,
      );
    }

    // Wing tip navigation lights (positioned at actual wing tips)
    canvas.drawCircle(
      Offset(-leftSpan + 1, 3.5 + leftDip),
      1.8,
      accentPaint,
    );
    canvas.drawCircle(
      Offset(rightSpan - 1, 3.5 + rightDip),
      1.8,
      Paint()..color = FlitColors.success,
    );
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

  /// Degrees-to-radians.
  static const double _deg2rad = pi / 180;

  /// Radians-to-degrees.
  static const double _rad2deg = 180 / pi;

  void _spawnContrailParticle() {
    // Compute wing-tip world positions using great-circle offset from
    // the plane's current world position. The wing tips are ~0.15° away
    // perpendicular to heading (left and right).
    final lat0 = worldPos.y * _deg2rad;
    final lng0 = worldPos.x * _deg2rad;
    // Navigation bearing: heading + π/2 converts math convention to nav.
    final navBearing = worldHeading + pi / 2;

    // Perpendicular bearings for left/right wing tips.
    final leftBearing = navBearing - pi / 2; // 90° left of heading
    final rightBearing = navBearing + pi / 2; // 90° right of heading

    // Slightly behind the plane (small offset aft along heading).
    final aftBearing = navBearing + pi;
    const wingDist = 0.03 * _deg2rad; // ~0.03° lateral (tighter to plane)
    const aftDist = 0.015 * _deg2rad; // ~0.015° behind

    for (final bearing in [leftBearing, rightBearing]) {
      // Combine lateral offset with slight aft offset.
      final sinLat0 = sin(lat0);
      final cosLat0 = cos(lat0);

      // Wing-tip lateral position.
      final latW = asin(
        (sinLat0 * cos(wingDist) + cosLat0 * sin(wingDist) * cos(bearing))
            .clamp(-1.0, 1.0),
      );
      final lngW = lng0 +
          atan2(
            sin(bearing) * sin(wingDist) * cosLat0,
            cos(wingDist) - sinLat0 * sin(latW),
          );

      // Nudge aft from wing-tip position.
      final sinLatW = sin(latW);
      final cosLatW = cos(latW);
      final latF = asin(
        (sinLatW * cos(aftDist) + cosLatW * sin(aftDist) * cos(aftBearing))
            .clamp(-1.0, 1.0),
      );
      final lngF = lngW +
          atan2(
            sin(aftBearing) * sin(aftDist) * cosLatW,
            cos(aftDist) - sinLatW * sin(latF),
          );

      contrails.add(ContrailParticle(
        worldPosition: Vector2(lngF * _rad2deg, latF * _rad2deg),
        size: 0.6 + Random().nextDouble() * 0.4,
        maxLife: 6.0,
      ));
    }
  }

  /// Set turn direction from active input (drag or keyboard).
  void setTurnDirection(double direction) {
    _turnDirection = direction.clamp(-1, 1);
    _isDragging = true;
  }

  /// Called when the player lifts their finger — plane coasts to straight.
  /// Turn direction decays smoothly rather than snapping to zero.
  void releaseTurn() {
    _isDragging = false;
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

/// A single contrail particle anchored to a world position.
class ContrailParticle {
  ContrailParticle({
    required this.worldPosition,
    required this.size,
    this.maxLife = 4.0,
  }) : life = maxLife;

  /// World-space position (x = longitude, y = latitude) in degrees.
  /// The particle stays fixed on the map as the plane moves away.
  final Vector2 worldPosition;
  final double size;
  final double maxLife;
  double life;
}
