import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../flit_game.dart';
import '../rendering/camera_state.dart';

/// The player's plane component.
///
/// Renders at a fixed screen position (set by FlitGame).
/// The world scrolls underneath - the plane doesn't move on screen.
/// Renders a more realistic, lo-fi top-down aircraft with shadow and detail.
class PlaneComponent extends PositionComponent with HasGameRef<FlitGame> {
  PlaneComponent({
    required this.onAltitudeChanged,
    this.colorScheme,
    this.wingSpan = 26.0,
    this.equippedPlaneId = 'plane_default',
  }) : super(
          size: Vector2(60, 60),
          anchor: Anchor.center,
        );

  final void Function(bool isHigh) onAltitudeChanged;

  /// Optional color scheme from equipped plane cosmetic.
  /// Keys: 'primary', 'secondary', 'detail' (ARGB ints).
  final Map<String, int>? colorScheme;

  /// Wing span in pixels for this aircraft.
  /// Determines both visual rendering and contrail positioning.
  final double wingSpan;

  /// ID of the equipped plane cosmetic (e.g., 'plane_paper', 'plane_jet').
  /// Determines which visual variant to render.
  final String equippedPlaneId;

  /// Current turning direction: -1 (left), 0 (straight), 1 (right)
  double _turnDirection = 0;

  /// Current altitude: true = high (fast), false = low (slow, detailed)
  bool _isHighAltitude = true;

  /// Continuous altitude value (0.0 = low, 1.0 = high).
  /// Used when altitude slider is enabled for gradual altitude control.
  double _continuousAltitude = 1.0;

  /// Visual heading set by the game (radians)
  double visualHeading = 0;

  /// Opacity for fade-in after game start (0.0 = invisible, 1.0 = fully visible).
  /// Prevents the plane from appearing to fly sideways during the camera snap.
  double _spawnOpacity = 1.0;

  /// Base speed at high altitude (world units per second).
  /// 36 units ≈ 3.6°/sec → crossing Europe (~36°) takes ~10 seconds.
  static const double highAltitudeSpeed = 36;

  /// Speed multiplier at low altitude
  static const double lowAltitudeSpeedMultiplier = 0.5;

  /// Turn rate in radians per second at high altitude.
  /// 2.2 gives sweeping arcs (~2.9s per full circle).
  /// At low altitude (half speed), turn rate doubles for tighter turns.
  static const double turnRate = 2.2;

  /// Get current turn rate based on speed.
  /// Lower speeds = tighter turning circles, higher speeds = wider arcs.
  double get currentTurnRate {
    final speedRatio = currentSpeed / highAltitudeSpeed;
    // Inverse relationship: slower speed = higher turn rate
    // At 50% speed (low altitude), turn rate is 2x (4.4 rad/s)
    // At 100% speed (high altitude), turn rate is 1x (2.2 rad/s)
    return turnRate / speedRatio.clamp(0.5, 1.0);
  }

  /// Maximum bank angle for visual effect (radians, ~75 degrees).
  /// At max bank, cos(1.3) ≈ 0.27 so contrails narrow to ~27% width,
  /// making them nearly touch at full turn.
  static const double _maxBankAngle = 1.3;

  /// Current visual bank angle (smoothed)
  double _currentBank = 0;

  /// Contrail particles (anchored to world positions).
  final List<ContrailParticle> contrails = [];

  /// Time accumulator for contrail spawning
  double _contrailTimer = 0;

  /// Base contrail spawn interval at high altitude.
  /// At low altitude, interval is scaled down so particles stay dense.
  static const double _contrailIntervalBase = 0.02;


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
  double get continuousAltitude => _continuousAltitude;

  double get currentSpeed =>
      highAltitudeSpeed *
      (_isHighAltitude ? 1.0 : lowAltitudeSpeedMultiplier) *
      fuelBoostMultiplier;

  /// Get current speed based on continuous altitude (0.0 = slowest, 1.0 = fastest).
  /// Interpolates between low altitude speed and high altitude speed.
  double get currentSpeedContinuous =>
      highAltitudeSpeed *
      (lowAltitudeSpeedMultiplier +
          _continuousAltitude * (1.0 - lowAltitudeSpeedMultiplier)) *
      fuelBoostMultiplier;

  @override
  void update(double dt) {
    super.update(dt);

    // Clamp to prevent infinite spinning from accumulated input.
    // releaseTurn() zeroes _turnDirection immediately on release,
    // so no exponential decay is needed — the heading stops changing
    // the moment the player lifts their finger.
    _turnDirection = _turnDirection.clamp(-1.0, 1.0);

    // Smooth bank angle: fast into turns, slow release for lingering contrail effect.
    // Positive _turnDirection = right turn → positive bank → right visual bank.
    final targetBank = _turnDirection * _maxBankAngle;
    final bankRate = targetBank.abs() > _currentBank.abs() ? 10.0 : 2.5;
    _currentBank += (targetBank - _currentBank) * min(1.0, dt * bankRate);

    // Smooth altitude transition using continuous altitude
    _altitudeTransition += (_continuousAltitude - _altitudeTransition) * min(1.0, dt * 3);

    // Spin propeller
    _propAngle += dt * 20;

    // Fade in after game start (0 → 1 over 0.5s)
    if (_spawnOpacity < 1.0) {
      _spawnOpacity = (_spawnOpacity + dt * 2.0).clamp(0.0, 1.0);
    }

    // Update contrails
    _updateContrails(dt);
  }

  /// Vertical perspective scale to simulate the camera being above and behind
  /// the plane. Compresses the forward-backward (Y) axis to give the illusion
  /// of viewing the plane at an angle rather than straight top-down.
  /// 0.7 ≈ camera ~45° above the horizontal.
  static const double perspectiveScaleY = 0.7;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_spawnOpacity < 0.01) return; // Invisible during fade-in start

    canvas.save();
    if (_spawnOpacity < 1.0) {
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = Color.fromARGB((_spawnOpacity * 255).round(), 255, 255, 255),
      );
    }
    canvas.translate(size.x / 2, size.y / 2);

    // Rotate to face heading. Camera up vector is the heading direction,
    // so visualHeading=0 means the plane faces "up" on screen (forward).
    // Add a proportional yaw toward the turn direction so the nose, fuselage,
    // and entire plane body visibly point toward the turn. Uses smoothed
    // _currentBank for a gradual rotation that follows the wing banking.
    // Positive because positive _currentBank = right turn, and positive
    // canvas.rotate() = clockwise = yaw right on screen. At full bank → ~34°.
    final turnAdjustment = (_currentBank / _maxBankAngle) * 0.6;
    canvas.rotate(visualHeading + turnAdjustment);

    // Apply perspective foreshortening: the camera is above and behind the
    // plane, so the forward-backward dimension appears compressed.
    canvas.scale(1.0, perspectiveScaleY);

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
    if (_spawnOpacity < 1.0) {
      canvas.restore(); // Match saveLayer
    }
  }

  void _renderPlaneShadow(Canvas canvas, double offset, double bankCos) {
    final shadowPaint = Paint()
      ..color = FlitColors.planeShadow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.save();
    canvas.translate(offset, offset);

    // Shadow foreshortens with bank too
    final shadowSpan = (wingSpan * 1.7) * bankCos.abs();
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
    // Delegate to specific plane renderer based on equipped cosmetic
    switch (equippedPlaneId) {
      case 'plane_paper':
        _renderPaperPlane(canvas, bankCos, bankSin);
        break;
      case 'plane_jet':
      case 'plane_rocket':
      case 'plane_golden_jet':
        _renderJetPlane(canvas, bankCos, bankSin);
        break;
      case 'plane_stealth':
        _renderStealthPlane(canvas, bankCos, bankSin);
        break;
      case 'plane_red_baron':
        _renderTriplane(canvas, bankCos, bankSin);
        break;
      case 'plane_concorde_classic':
      case 'plane_diamond_concorde':
        _renderConcorde(canvas, bankCos, bankSin);
        break;
      case 'plane_seaplane':
        _renderSeaplane(canvas, bankCos, bankSin);
        break;
      case 'plane_bryanair':
      case 'plane_air_force_one':
        _renderAirliner(canvas, bankCos, bankSin);
        break;
      default:
        // Default bi-plane rendering (original code)
        _renderBiPlane(canvas, bankCos, bankSin);
        break;
    }
  }

  /// Original bi-plane rendering (default and most planes).
  void _renderBiPlane(Canvas canvas, double bankCos, double bankSin) {
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
    final shade = -bankSin; // Right turn (bankSin>0) → shade<0 → left lit, right dark

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
    final highlightPaint = Paint()..color = FlitColors.planeHighlight.withOpacity(0.35);

    // Underside color — visible when banked
    final undersidePaint = Paint()..color = darken(primary, 0.35);

    // 3D foreshortening: wing span scales with cos(bank)
    final dynamicWingSpan = wingSpan * bankCos.abs();
    // Wing vertical shift: the dipping wing moves down on screen
    final wingDip = -bankSin * 4.0;
    // Body lateral shift with bank
    final bodyShift = bankSin * 1.5;

    // --- Propeller (drawn first — behind everything else) ---
    final propDiscPaint = Paint()
      ..color = FlitColors.planeBody.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(bodyShift, -17), 8, propDiscPaint);

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

    // --- Main wings (stable base layer, not affected by roll) ---
    // Left wing — both wings foreshorten from bankCos, mild offset for depth.
    final leftSpan = dynamicWingSpan * (1.0 - bankSin.abs() * 0.15) + bankSin * 1.5;
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
    final rightSpan = dynamicWingSpan * (1.0 - bankSin.abs() * 0.15) - bankSin * 1.5;
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

    // --- Body group (underside + tail + fuselage roll together on top of wings) ---
    canvas.save();
    final rollScale = 0.55 + bankCos.abs() * 0.45; // 0.55 at max bank → 1.0 level
    canvas.translate(bodyShift, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-bodyShift, 0);

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
    final tailSpan = (wingSpan * 0.38) * bankCos.abs();
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

    // --- Fuselage ---
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
    canvas.restore(); // End body roll transform

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

  /// Paper plane rendering - simple, flat, triangular design.
  void _renderPaperPlane(Canvas canvas, double bankCos, double bankSin) {
    final primary = colorScheme != null
        ? Color(colorScheme!['primary'] ?? 0xFFF5F5F5)
        : const Color(0xFFF5F5F5); // Default white
    final secondary = colorScheme != null
        ? Color(colorScheme!['secondary'] ?? 0xFFE0E0E0)
        : const Color(0xFFE0E0E0);
    final detail = colorScheme != null
        ? Color(colorScheme!['detail'] ?? 0xFFCCCCCC)
        : const Color(0xFFCCCCCC);

    final shade = -bankSin; // Right turn (bankSin>0) → shade<0 → left lit, right dark
    final bodyShift = bankSin * 1.5;
    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = -bankSin * 4.0;

    // Triangular wings (simple flat design)
    final leftWingColor = shade < 0 ? primary : secondary;
    final rightWingColor = shade > 0 ? primary : secondary;

    // --- Triangular wings (stable base layer, not affected by roll) ---
    final leftSpan = dynamicWingSpan * (1.0 - bankSin.abs() * 0.15) + bankSin * 1.0;
    final leftWing = Path()
      ..moveTo(-2 + bodyShift, 0)
      ..lineTo(-leftSpan, 4 + wingDip)
      ..lineTo(-leftSpan + 3, 6 + wingDip)
      ..lineTo(-2 + bodyShift, 2)
      ..close();
    canvas.drawPath(leftWing, Paint()..color = leftWingColor);

    final rightSpan = dynamicWingSpan * (1.0 - bankSin.abs() * 0.15) - bankSin * 1.0;
    final rightWing = Path()
      ..moveTo(2 + bodyShift, 0)
      ..lineTo(rightSpan, 4 - wingDip)
      ..lineTo(rightSpan - 3, 6 - wingDip)
      ..lineTo(2 + bodyShift, 2)
      ..close();
    canvas.drawPath(rightWing, Paint()..color = rightWingColor);

    // --- Body group (fuselage rolls on top of wings) ---
    canvas.save();
    final rollScale = 0.55 + bankCos.abs() * 0.45;
    canvas.translate(bodyShift, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-bodyShift, 0);

    // Simple folded paper body
    final bodyPath = Path()
      ..moveTo(bodyShift, -18)
      ..lineTo(bodyShift + 3, -8)
      ..lineTo(bodyShift + 2, 14)
      ..lineTo(bodyShift, 16)
      ..lineTo(bodyShift - 2, 14)
      ..lineTo(bodyShift - 3, -8)
      ..close();
    canvas.drawPath(bodyPath, Paint()..color = primary);

    // Paper crease line (center fold)
    canvas.drawLine(
      Offset(bodyShift, -18),
      Offset(bodyShift, 16),
      Paint()
        ..color = detail
        ..strokeWidth = 1.0,
    );

    // Simple nose point
    canvas.drawCircle(
      Offset(bodyShift, -18),
      2.0,
      Paint()..color = secondary,
    );
    canvas.restore(); // End body roll transform
  }

  /// Jet/rocket plane rendering - sleek, narrow, swept-back wings.
  void _renderJetPlane(Canvas canvas, double bankCos, double bankSin) {
    final primary = colorScheme != null
        ? Color(colorScheme!['primary'] ?? 0xFFC0C0C0)
        : const Color(0xFFC0C0C0);
    final secondary = colorScheme != null
        ? Color(colorScheme!['secondary'] ?? 0xFF4A90B8)
        : const Color(0xFF4A90B8);
    final detail = colorScheme != null
        ? Color(colorScheme!['detail'] ?? 0xFF808080)
        : const Color(0xFF808080);

    final shade = -bankSin; // Right turn (bankSin>0) → shade<0 → left lit, right dark
    final bodyShift = bankSin * 1.5;
    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = -bankSin * 3.0;

    // Swept delta wings
    final leftWingColor = shade < 0 ? detail : Color.lerp(detail, Colors.black, 0.3)!;
    final rightWingColor = shade > 0 ? detail : Color.lerp(detail, Colors.black, 0.3)!;

    // --- Swept delta wings (stable base layer, not affected by roll) ---
    final leftSpan = dynamicWingSpan * 0.8 * (1.0 - bankSin.abs() * 0.15) + bankSin * 1.0;
    final leftWing = Path()
      ..moveTo(-3 + bodyShift, 2)
      ..lineTo(-leftSpan, 8 + wingDip)
      ..lineTo(-leftSpan + 4, 10 + wingDip)
      ..lineTo(-2 + bodyShift, 6)
      ..close();
    canvas.drawPath(leftWing, Paint()..color = leftWingColor);

    final rightSpan = dynamicWingSpan * 0.8 * (1.0 - bankSin.abs() * 0.15) - bankSin * 1.0;
    final rightWing = Path()
      ..moveTo(3 + bodyShift, 2)
      ..lineTo(rightSpan, 8 - wingDip)
      ..lineTo(rightSpan - 4, 10 - wingDip)
      ..lineTo(2 + bodyShift, 6)
      ..close();
    canvas.drawPath(rightWing, Paint()..color = rightWingColor);

    // --- Body group (fuselage rolls on top of wings) ---
    canvas.save();
    final rollScale = 0.55 + bankCos.abs() * 0.45;
    canvas.translate(bodyShift, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-bodyShift, 0);

    // Sleek fuselage (narrower than bi-plane)
    final fuselagePath = Path()
      ..moveTo(bodyShift, -18)
      ..quadraticBezierTo(3 + bodyShift, -14, 3 + bodyShift, -4)
      ..quadraticBezierTo(2.5 + bodyShift, 8, 2 + bodyShift, 15)
      ..lineTo(-2 + bodyShift, 15)
      ..quadraticBezierTo(-2.5 + bodyShift, 8, -3 + bodyShift, -4)
      ..quadraticBezierTo(-3 + bodyShift, -14, bodyShift, -18)
      ..close();
    canvas.drawPath(fuselagePath, Paint()..color = primary);

    // Canopy (cockpit glass)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bodyShift, -10),
        width: 4,
        height: 7,
      ),
      Paint()..color = const Color(0xFF4A90B8),
    );

    // Jet exhaust (glowing)
    if (equippedPlaneId == 'plane_rocket') {
      canvas.drawCircle(
        Offset(bodyShift, 15),
        3.0,
        Paint()..color = const Color(0xFFFF6600).withOpacity(0.8),
      );
    } else {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(bodyShift, 15),
          width: 4,
          height: 3,
        ),
        Paint()..color = const Color(0xFF555555),
      );
    }

    // Accent stripe
    canvas.drawLine(
      Offset(bodyShift - 1, -12),
      Offset(bodyShift - 1, 8),
      Paint()
        ..color = secondary
        ..strokeWidth = 2.0,
    );
    canvas.restore(); // End body roll transform
  }

  /// Stealth bomber rendering - wide flying wing design.
  void _renderStealthPlane(Canvas canvas, double bankCos, double bankSin) {
    final primary = colorScheme != null
        ? Color(colorScheme!['primary'] ?? 0xFF2A2A2A)
        : const Color(0xFF2A2A2A);
    final secondary = colorScheme != null
        ? Color(colorScheme!['secondary'] ?? 0xFF1A1A1A)
        : const Color(0xFF1A1A1A);
    final detail = colorScheme != null
        ? Color(colorScheme!['detail'] ?? 0xFF444444)
        : const Color(0xFF444444);

    final shade = -bankSin; // Right turn (bankSin>0) → shade<0 → left lit, right dark
    final bodyShift = bankSin * 1.0;
    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = -bankSin * 2.0;

    // Wide flying wing (stable base layer, not affected by roll)
    final leftWingColor = shade < 0 ? primary : secondary;
    final rightWingColor = shade > 0 ? primary : secondary;

    final leftSpan = dynamicWingSpan * 1.2 * (1.0 - bankSin.abs() * 0.15) + bankSin * 1.5;
    final leftWing = Path()
      ..moveTo(bodyShift, -16)
      ..quadraticBezierTo(-leftSpan * 0.4, -8 + wingDip * 0.3, -leftSpan, 4 + wingDip)
      ..lineTo(-leftSpan + 6, 8 + wingDip)
      ..quadraticBezierTo(-leftSpan * 0.3, 6 + wingDip * 0.5, bodyShift, 10)
      ..close();
    canvas.drawPath(leftWing, Paint()..color = leftWingColor);

    final rightSpan = dynamicWingSpan * 1.2 * (1.0 - bankSin.abs() * 0.15) - bankSin * 1.5;
    final rightWing = Path()
      ..moveTo(bodyShift, -16)
      ..quadraticBezierTo(rightSpan * 0.4, -8 - wingDip * 0.3, rightSpan, 4 - wingDip)
      ..lineTo(rightSpan - 6, 8 - wingDip)
      ..quadraticBezierTo(rightSpan * 0.3, 6 - wingDip * 0.5, bodyShift, 10)
      ..close();
    canvas.drawPath(rightWing, Paint()..color = rightWingColor);

    // --- Body group (center body + sawtooth + cockpit roll together on top of wings) ---
    canvas.save();
    final rollScale = 0.55 + bankCos.abs() * 0.45;
    canvas.translate(bodyShift, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-bodyShift, 0);

    // Center body section
    final centerBody = Path()
      ..moveTo(bodyShift - 4, -12)
      ..lineTo(bodyShift - 3, 8)
      ..lineTo(bodyShift + 3, 8)
      ..lineTo(bodyShift + 4, -12)
      ..close();
    canvas.drawPath(centerBody, Paint()..color = detail);

    // Sawtooth trailing edge (stealth feature)
    final sawtoothPaint = Paint()
      ..color = secondary
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final sawtoothPath = Path()
      ..moveTo(-leftSpan + 6, 8 + wingDip)
      ..lineTo(-leftSpan * 0.6, 9 + wingDip * 0.6)
      ..lineTo(-leftSpan * 0.3, 8 + wingDip * 0.4)
      ..lineTo(bodyShift - 3, 9)
      ..lineTo(bodyShift + 3, 9)
      ..lineTo(rightSpan * 0.3, 8 - wingDip * 0.4)
      ..lineTo(rightSpan * 0.6, 9 - wingDip * 0.6)
      ..lineTo(rightSpan - 6, 8 - wingDip);
    canvas.drawPath(sawtoothPath, sawtoothPaint);

    // Cockpit (barely visible)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bodyShift, -8),
        width: 3,
        height: 4,
      ),
      Paint()..color = const Color(0xFF333333),
    );
    canvas.restore(); // End body roll transform
  }

  /// Red Baron triplane - three stacked wings.
  void _renderTriplane(Canvas canvas, double bankCos, double bankSin) {
    final primary = colorScheme != null
        ? Color(colorScheme!['primary'] ?? 0xFFCC3333)
        : const Color(0xFFCC3333);
    final secondary = colorScheme != null
        ? Color(colorScheme!['secondary'] ?? 0xFF8B0000)
        : const Color(0xFF8B0000);
    final detail = colorScheme != null
        ? Color(colorScheme!['detail'] ?? 0xFF1A1A1A)
        : const Color(0xFF1A1A1A);

    final shade = -bankSin; // Right turn (bankSin>0) → shade<0 → left lit, right dark
    final bodyShift = bankSin * 1.5;
    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = -bankSin * 3.0;

    // Three stacked wings (iconic triplane design)
    final wingColor = shade < 0
        ? detail
        : Color.lerp(detail, Colors.black, 0.2)!;

    // --- Propeller (drawn first — behind everything else) ---
    final propDiscPaint = Paint()
      ..color = primary.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(bodyShift, -17), 7, propDiscPaint);
    final bladePaint = Paint()
      ..color = const Color(0xFF444444).withOpacity(0.8)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    const bladeLen = 6.0;
    for (var i = 0; i < 2; i++) {
      final a = _propAngle + i * pi;
      canvas.drawLine(
        Offset(bodyShift + cos(a) * bladeLen, -17 + sin(a) * bladeLen),
        Offset(bodyShift - cos(a) * bladeLen, -17 - sin(a) * bladeLen),
        bladePaint,
      );
    }

    // --- Three stacked wings (stable base layer, not affected by roll) ---
    // Top wing (smallest)
    final topSpan = dynamicWingSpan * 0.7;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, -6 + wingDip * 0.3),
          width: topSpan * 2,
          height: 5,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = wingColor,
    );

    // Middle wing
    final midSpan = dynamicWingSpan * 0.85;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, 0 + wingDip * 0.6),
          width: midSpan * 2,
          height: 5,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = wingColor,
    );

    // Bottom wing (largest)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, 6 + wingDip),
          width: dynamicWingSpan * 2,
          height: 5,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = wingColor,
    );

    // --- Body group (tail + fuselage + struts + cockpit + emblem roll together on top of wings) ---
    canvas.save();
    final rollScale = 0.55 + bankCos.abs() * 0.45;
    canvas.translate(bodyShift, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-bodyShift, 0);

    // Tail
    final tailPath = Path()
      ..moveTo(-4, 12)
      ..lineTo(-4, 16)
      ..lineTo(4, 16)
      ..lineTo(4, 12)
      ..close();
    canvas.drawPath(tailPath, Paint()..color = wingColor);

    // Fuselage
    final fuselagePath = Path()
      ..moveTo(bodyShift, -16)
      ..quadraticBezierTo(4 + bodyShift, -12, 4 + bodyShift, -2)
      ..quadraticBezierTo(3 + bodyShift, 10, 2 + bodyShift, 16)
      ..quadraticBezierTo(bodyShift, 17, -2 + bodyShift, 16)
      ..quadraticBezierTo(-3 + bodyShift, 10, -4 + bodyShift, -2)
      ..quadraticBezierTo(-4 + bodyShift, -12, bodyShift, -16)
      ..close();
    canvas.drawPath(fuselagePath, Paint()..color = primary);

    // Struts connecting wings
    final strutPaint = Paint()
      ..color = detail
      ..strokeWidth = 1.5;
    for (var x in [-dynamicWingSpan * 0.5, dynamicWingSpan * 0.5]) {
      canvas.drawLine(Offset(x, -4), Offset(x, 8 + wingDip * 0.5), strutPaint);
    }

    // Cockpit
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bodyShift, -8),
        width: 5,
        height: 6,
      ),
      Paint()..color = const Color(0xFF654321),
    );

    // Red Baron cross emblem
    canvas.drawLine(
      Offset(bodyShift - 3, 0),
      Offset(bodyShift + 3, 0),
      Paint()
        ..color = secondary
        ..strokeWidth = 2.5,
    );
    canvas.drawLine(
      Offset(bodyShift, -3),
      Offset(bodyShift, 3),
      Paint()
        ..color = secondary
        ..strokeWidth = 2.5,
    );
    canvas.restore(); // End body roll transform
  }

  /// Concorde supersonic - distinctive delta wing and drooping nose.
  void _renderConcorde(Canvas canvas, double bankCos, double bankSin) {
    final primary = colorScheme != null
        ? Color(colorScheme!['primary'] ?? 0xFFF5F5F5)
        : const Color(0xFFF5F5F5);
    final secondary = colorScheme != null
        ? Color(colorScheme!['secondary'] ?? 0xFF1A3A5C)
        : const Color(0xFF1A3A5C);
    final detail = colorScheme != null
        ? Color(colorScheme!['detail'] ?? 0xFFCC3333)
        : const Color(0xFFCC3333);

    final shade = -bankSin; // Right turn (bankSin>0) → shade<0 → left lit, right dark
    final bodyShift = bankSin * 1.0;
    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = -bankSin * 2.5;

    // --- Delta wing (stable base layer, not affected by roll) ---
    final leftWingColor = shade < 0 ? primary : Color.lerp(primary, Colors.grey, 0.2)!;
    final rightWingColor = shade > 0 ? primary : Color.lerp(primary, Colors.grey, 0.2)!;

    final leftSpan = dynamicWingSpan * 0.9 * (1.0 - bankSin.abs() * 0.15) + bankSin * 1.0;
    final leftWing = Path()
      ..moveTo(bodyShift - 2, -16)
      ..lineTo(-leftSpan, 10 + wingDip)
      ..lineTo(bodyShift - 2, 14)
      ..close();
    canvas.drawPath(leftWing, Paint()..color = leftWingColor);

    final rightSpan = dynamicWingSpan * 0.9 * (1.0 - bankSin.abs() * 0.15) - bankSin * 1.0;
    final rightWing = Path()
      ..moveTo(bodyShift + 2, -16)
      ..lineTo(rightSpan, 10 - wingDip)
      ..lineTo(bodyShift + 2, 14)
      ..close();
    canvas.drawPath(rightWing, Paint()..color = rightWingColor);

    // --- Body group (fuselage rolls on top of wings) ---
    canvas.save();
    final rollScale = 0.55 + bankCos.abs() * 0.45;
    canvas.translate(bodyShift, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-bodyShift, 0);

    // Central fuselage
    final fuselagePath = Path()
      ..moveTo(bodyShift, -18)
      ..quadraticBezierTo(3 + bodyShift, -10, 3 + bodyShift, 0)
      ..lineTo(2 + bodyShift, 14)
      ..lineTo(-2 + bodyShift, 14)
      ..lineTo(-3 + bodyShift, 0)
      ..quadraticBezierTo(-3 + bodyShift, -10, bodyShift, -18)
      ..close();
    canvas.drawPath(fuselagePath, Paint()..color = primary);

    // Drooping nose (Concorde's distinctive feature)
    canvas.drawLine(
      Offset(bodyShift, -18),
      Offset(bodyShift, -20),
      Paint()
        ..color = secondary
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );

    // Accent stripe
    canvas.drawLine(
      Offset(bodyShift, -16),
      Offset(bodyShift, 10),
      Paint()
        ..color = detail
        ..strokeWidth = 2.0,
    );

    // Cockpit windows
    for (var y in [-12.0, -10.0, -8.0]) {
      canvas.drawCircle(
        Offset(bodyShift, y),
        1.2,
        Paint()..color = const Color(0xFF4A90B8),
      );
    }
    canvas.restore(); // End body roll transform

    // Four jet engines (two on each side)
    for (var x in [-leftSpan * 0.4, -leftSpan * 0.6]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, 8 + wingDip * 0.5),
          width: 3,
          height: 4,
        ),
        Paint()..color = const Color(0xFF555555),
      );
    }
    for (var x in [rightSpan * 0.4, rightSpan * 0.6]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, 8 - wingDip * 0.5),
          width: 3,
          height: 4,
        ),
        Paint()..color = const Color(0xFF555555),
      );
    }
  }

  /// Seaplane with pontoons for water landing.
  void _renderSeaplane(Canvas canvas, double bankCos, double bankSin) {
    // Only extract the colors we actually use (detail for pontoons, secondary for struts).
    // The primary color and other variables are used by _renderBiPlane() which we delegate to.
    final secondary = colorScheme != null
        ? Color(colorScheme!['secondary'] ?? 0xFF2E8B57)
        : const Color(0xFF2E8B57);
    final detail = colorScheme != null
        ? Color(colorScheme!['detail'] ?? 0xFFF5F5F5)
        : const Color(0xFFF5F5F5);

    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = -bankSin * 4.0;

    // First render pontoons (below the plane)
    final pontoonPaint = Paint()..color = detail;
    final leftPontoon = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(-dynamicWingSpan * 0.5, 12 + wingDip),
        width: 6,
        height: 16,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(leftPontoon, pontoonPaint);

    final rightPontoon = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(dynamicWingSpan * 0.5, 12 - wingDip),
        width: 6,
        height: 16,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(rightPontoon, pontoonPaint);

    // Struts connecting pontoons to wings
    final strutPaint = Paint()
      ..color = secondary
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(-dynamicWingSpan * 0.5, 4 + wingDip * 0.7),
      Offset(-dynamicWingSpan * 0.5, 8 + wingDip),
      strutPaint,
    );
    canvas.drawLine(
      Offset(dynamicWingSpan * 0.5, 4 - wingDip * 0.7),
      Offset(dynamicWingSpan * 0.5, 8 - wingDip),
      strutPaint,
    );

    // Render the plane body using bi-plane style.
    // This is safe (no recursion) because _renderBiPlane() doesn't call back
    // to _renderPlane() - it's a leaf rendering method.
    _renderBiPlane(canvas, bankCos, bankSin);
  }

  /// Commercial airliner - wide body with swept wings.
  void _renderAirliner(Canvas canvas, double bankCos, double bankSin) {
    final primary = colorScheme != null
        ? Color(colorScheme!['primary'] ?? 0xFFF5F5F5)
        : const Color(0xFFF5F5F5);
    final secondary = colorScheme != null
        ? Color(colorScheme!['secondary'] ?? 0xFF003580)
        : const Color(0xFF003580);
    final detail = colorScheme != null
        ? Color(colorScheme!['detail'] ?? 0xFFFFCC00)
        : const Color(0xFFFFCC00);

    final shade = -bankSin; // Right turn (bankSin>0) → shade<0 → left lit, right dark
    final bodyShift = bankSin * 1.0;
    final dynamicWingSpan = wingSpan * bankCos.abs();
    final wingDip = -bankSin * 2.0;

    // --- Wide swept wings (stable base layer, not affected by roll) ---
    final leftWingColor = shade < 0
        ? detail
        : Color.lerp(detail, Colors.grey, 0.3)!;
    final rightWingColor = shade > 0
        ? detail
        : Color.lerp(detail, Colors.grey, 0.3)!;

    final leftSpan = dynamicWingSpan * 1.1 * (1.0 - bankSin.abs() * 0.15) + bankSin * 1.0;
    final leftWing = Path()
      ..moveTo(-6 + bodyShift, 0)
      ..quadraticBezierTo(-leftSpan * 0.5, 2 + wingDip * 0.5, -leftSpan, 6 + wingDip)
      ..lineTo(-leftSpan + 5, 8 + wingDip)
      ..quadraticBezierTo(-leftSpan * 0.4, 5 + wingDip * 0.5, -5 + bodyShift, 2)
      ..close();
    canvas.drawPath(leftWing, Paint()..color = leftWingColor);

    final rightSpan = dynamicWingSpan * 1.1 * (1.0 - bankSin.abs() * 0.15) - bankSin * 1.0;
    final rightWing = Path()
      ..moveTo(6 + bodyShift, 0)
      ..quadraticBezierTo(rightSpan * 0.5, 2 - wingDip * 0.5, rightSpan, 6 - wingDip)
      ..lineTo(rightSpan - 5, 8 - wingDip)
      ..quadraticBezierTo(rightSpan * 0.4, 5 - wingDip * 0.5, 5 + bodyShift, 2)
      ..close();
    canvas.drawPath(rightWing, Paint()..color = rightWingColor);

    // --- Body group (tail + fuselage roll together on top of wings) ---
    canvas.save();
    final rollScale = 0.55 + bankCos.abs() * 0.45;
    canvas.translate(bodyShift, 0);
    canvas.scale(rollScale, 1.0);
    canvas.translate(-bodyShift, 0);

    // Tail section
    final tailPath = Path()
      ..moveTo(-3, 14)
      ..lineTo(-2, 16)
      ..lineTo(2, 16)
      ..lineTo(3, 14)
      ..close();
    canvas.drawPath(tailPath, Paint()..color = detail);

    // Vertical stabilizer
    final finPath = Path()
      ..moveTo(bodyShift, 12)
      ..quadraticBezierTo(-2 + bodyShift, 14, bodyShift, 17)
      ..quadraticBezierTo(2 + bodyShift, 14, bodyShift, 12)
      ..close();
    canvas.drawPath(finPath, Paint()..color = secondary);

    // Wide fuselage (airliner body)
    final fuselagePath = Path()
      ..moveTo(bodyShift, -17)
      ..quadraticBezierTo(6 + bodyShift, -12, 6 + bodyShift, 0)
      ..quadraticBezierTo(5 + bodyShift, 10, 3 + bodyShift, 16)
      ..lineTo(-3 + bodyShift, 16)
      ..quadraticBezierTo(-5 + bodyShift, 10, -6 + bodyShift, 0)
      ..quadraticBezierTo(-6 + bodyShift, -12, bodyShift, -17)
      ..close();
    canvas.drawPath(fuselagePath, Paint()..color = primary);

    // Cockpit windows
    for (var y in [-13.0, -11.0, -9.0, -7.0]) {
      canvas.drawCircle(
        Offset(bodyShift + 2, y),
        0.8,
        Paint()..color = const Color(0xFF4A90B8),
      );
      canvas.drawCircle(
        Offset(bodyShift - 2, y),
        0.8,
        Paint()..color = const Color(0xFF4A90B8),
      );
    }

    // Airline stripe
    canvas.drawLine(
      Offset(bodyShift - 4, -8),
      Offset(bodyShift - 4, 12),
      Paint()
        ..color = secondary
        ..strokeWidth = 2.5,
    );
    canvas.restore(); // End body roll transform

    // Engines under wings
    for (var x in [-leftSpan * 0.4, -leftSpan * 0.7]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, 8 + wingDip * 0.6),
            width: 4,
            height: 7,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFF888888),
      );
    }
    for (var x in [rightSpan * 0.4, rightSpan * 0.7]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, 8 - wingDip * 0.6),
            width: 4,
            height: 7,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFF888888),
      );
    }
  }

  void _updateContrails(double dt) {
    // Scale spawn rate with zoom: at low altitude (zoomed in), spawn
    // particles more frequently so the trail stays dense on screen.
    final zoomRatio =
        (gameRef.cameraDistance / CameraState.highAltitudeDistance).clamp(0.4, 1.0);
    final interval = _contrailIntervalBase * zoomRatio;

    _contrailTimer += dt;
    if (_contrailTimer >= interval) {
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
    // Calculate banking for wing foreshortening (matches rendering methods).
    final bankCos = cos(_currentBank);
    final dynamicWingSpan = wingSpan * bankCos.abs();

    // Compute wing-tip world positions using great-circle offset from
    // the plane's current world position.
    // The wing span (in pixels) needs to be converted to degrees.
    // At closer camera (low altitude), each degree covers MORE pixels.
    const referenceDistance = CameraState.highAltitudeDistance;
    const pixelsPerDegreeAtReference = 12.0;
    final currentDistance = gameRef.cameraDistance;
    final pixelsPerDegree =
        pixelsPerDegreeAtReference * (referenceDistance / currentDistance);
    final pixelsToDegrees = 1.0 / pixelsPerDegree;
    // Altitude-dependent scale: at low altitude (zoomed in) the plane's pixel
    // size doesn't change but covers more world degrees, so contrails need a
    // tighter scale. At high altitude (zoomed out), slightly wider.
    final altScale = 0.42 + _altitudeTransition * 0.35; // 0.42 low → 0.77 high (smooth)
    final wingSpanDegrees = (dynamicWingSpan * altScale) * pixelsToDegrees;

    final lat0 = worldPos.y * _deg2rad;
    final lng0 = worldPos.x * _deg2rad;
    // Navigation bearing: heading + π/2 converts math convention to nav.
    final navBearing = worldHeading + pi / 2;

    // Perpendicular bearings for left/right wing tips.
    final leftBearing = navBearing - pi / 2; // 90° left of heading
    final rightBearing = navBearing + pi / 2; // 90° right of heading

    // Slightly behind the plane (small offset aft along heading).
    final aftBearing = navBearing + pi;
    final wingDist = wingSpanDegrees * 0.5 * _deg2rad;
    // Aft offset also scales with zoom so contrails stay near the plane.
    final aftDist = 1.5 * pixelsToDegrees * _deg2rad;

    var isLeft = true;
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
        isLeft: isLeft,
        maxLife: 6.0,
      ));
      isLeft = false;
    }
  }

  /// Set turn direction from active input (keyboard or button).
  void setTurnDirection(double direction) {
    _turnDirection = direction.clamp(-1, 1);
  }

  /// Steer toward a target turn direction (for waypoint auto-steering).
  /// Sets _turnDirection directly so that the bank animation in update()
  /// is clearly visible during waypoint turns.
  void steerToward(double target, double dt) {
    _turnDirection = target.clamp(-1.0, 1.0);
  }

  /// Called when the player releases input — plane stops turning immediately.
  /// Turn direction is zeroed so the heading stops changing, but the bank
  /// angle decays smoothly (via the 2.5 rate in update()) for a natural
  /// visual leveling-out of the wings.
  void releaseTurn() {
    _turnDirection = 0;
  }

  /// Immediately zero turn direction and bank — used when waymarker clears
  /// to prevent post-arrival drift.
  void snapStraight() {
    _turnDirection = 0;
    _currentBank = 0;
  }

  /// Start a fade-in from invisible. Called on game start so the plane
  /// doesn't appear to fly sideways during the camera snap.
  void fadeIn() {
    _spawnOpacity = 0.0;
  }

  void toggleAltitude() {
    _isHighAltitude = !_isHighAltitude;
    _continuousAltitude = _isHighAltitude ? 1.0 : 0.0;
    onAltitudeChanged(_isHighAltitude);
  }

  void setAltitude({required bool high}) {
    if (_isHighAltitude != high) {
      _isHighAltitude = high;
      _continuousAltitude = high ? 1.0 : 0.0;
      onAltitudeChanged(_isHighAltitude);
    }
  }

  /// Set continuous altitude value (0.0 = low, 1.0 = high).
  /// Updates both continuous value and binary high/low state.
  /// Threshold at 0.5: < 0.5 = low altitude, >= 0.5 = high altitude.
  void setContinuousAltitude(double value) {
    _continuousAltitude = value.clamp(0.0, 1.0);
    final newIsHigh = _continuousAltitude >= 0.5;
    if (_isHighAltitude != newIsHigh) {
      _isHighAltitude = newIsHigh;
      onAltitudeChanged(_isHighAltitude);
    }
  }
}

/// A single contrail particle anchored to a world position.
class ContrailParticle {
  ContrailParticle({
    required this.worldPosition,
    required this.size,
    required this.isLeft,
    this.maxLife = 4.0,
  }) : life = maxLife;

  /// World-space position (x = longitude, y = latitude) in degrees.
  /// The particle stays fixed on the map as the plane moves away.
  final Vector2 worldPosition;
  final double size;
  final double maxLife;

  /// Which wing trail this particle belongs to (for connected-line rendering).
  final bool isLeft;
  double life;
}
