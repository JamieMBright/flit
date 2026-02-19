import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/services/game_settings.dart';
import '../../core/theme/flit_colors.dart';
import '../flit_game.dart';
import '../rendering/camera_state.dart';
import '../rendering/plane_renderer.dart';

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
  }) : super(size: Vector2(60, 60), anchor: Anchor.center);

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

  /// Speed multiplier at low altitude. 0.2 = 20% of high altitude speed.
  /// At medium flight speed: 36 × 0.2 × 0.6 = 4.3 units/s (~0.4°/s).
  static const double lowAltitudeSpeedMultiplier = 0.2;

  /// Turn rate in radians per second at high altitude.
  /// 2.2 gives sweeping arcs (~2.9s per full circle).
  /// At low altitude (half speed), turn rate doubles for tighter turns.
  static const double turnRate = 2.2;

  /// Get current turn rate based on speed.
  /// Lower speeds = tighter turning circles, higher speeds = wider arcs.
  double get currentTurnRate {
    final speedRatio = currentSpeed / highAltitudeSpeed;
    // Apply turn sensitivity setting (default 0.5 → 1.0x multiplier).
    final sensitivity = GameSettings.instance.turnSensitivity;
    final sensitivityScale = sensitivity / 0.5;
    // Inverse relationship: slower speed = higher turn rate
    // At 50% speed (low altitude), turn rate is 2x (4.4 rad/s)
    // At 100% speed (high altitude), turn rate is 1x (2.2 rad/s)
    return turnRate * sensitivityScale / speedRatio.clamp(0.5, 1.0);
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
    _altitudeTransition +=
        (_continuousAltitude - _altitudeTransition) * min(1.0, dt * 3);

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
        Paint()
          ..color = Color.fromARGB(
            (_spawnOpacity * 255).round(),
            255,
            255,
            255,
          ),
      );
    }
    canvas.translate(size.x / 2, size.y / 2);

    // In flat map mode, scale the plane down so it fits the regional view.
    // The plane needs to be smaller since it's moving across the whole region.
    if (gameRef.isFlatMapMode) {
      canvas.scale(0.5);
    }

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
    PlaneRenderer.renderPlane(
      canvas: canvas,
      bankCos: bankCos,
      bankSin: bankSin,
      wingSpan: wingSpan,
      planeId: equippedPlaneId,
      colorScheme: colorScheme,
      propAngle: _propAngle,
    );
  }

  void _updateContrails(double dt) {
    // Don't spawn contrails during launch animation.
    if (gameRef.isInLaunchIntro) return;

    // Scale spawn rate with zoom: at low altitude (zoomed in), spawn
    // particles more frequently so the trail stays dense on screen.
    final zoomRatio =
        (gameRef.cameraDistance / CameraState.highAltitudeDistance).clamp(
          0.4,
          1.0,
        );
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
    final altScale =
        0.42 + _altitudeTransition * 0.35; // 0.42 low → 0.77 high (smooth)
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
      final lngW =
          lng0 +
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
      final lngF =
          lngW +
          atan2(
            sin(aftBearing) * sin(aftDist) * cosLatW,
            cos(aftDist) - sinLatW * sin(latF),
          );

      contrails.add(
        ContrailParticle(
          worldPosition: Vector2(lngF * _rad2deg, latF * _rad2deg),
          size: 0.6 + Random().nextDouble() * 0.4,
          isLeft: isLeft,
          maxLife: 6.0,
        ),
      );
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

  /// Make the plane immediately visible (used after launch positioning phase).
  void setVisible() {
    _spawnOpacity = 1.0;
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
