import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../data/models/avatar_config.dart';
import '../flit_game.dart';
import '../rendering/companion_art.dart';

/// Renders the player's companion creature flying behind and slightly to the
/// side of the plane. The companion follows the plane with a slight delay,
/// creating a charming sidekick effect.
///
/// Each companion is hand-drawn style procedural art with layered shading,
/// smooth bezier silhouettes, and subtle animation for an organic feel.
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

  /// Gentle bobbing phase (separate from flap for organic feel).
  double _bobPhase = 0;

  /// Breath/pulse phase for fire creatures.
  double _breathPhase = 0;

  // ---------------------------------------------------------------------------
  // Fuel-fetch animation state
  // ---------------------------------------------------------------------------

  /// Whether the companion is currently away fetching fuel.
  bool _isFetchingFuel = false;

  /// Progress through the fetch animation (0.0 = just departed, 1.0 = returned).
  double _fetchProgress = 0.0;

  /// Total duration of the fuel-fetch trip in seconds.
  static const double _fetchDuration = 3.5;

  /// Fuel restored by the companion per fetch (halved from 0.25 → 0.125,
  /// i.e. 12.5% of base tank — enough to help, not enough to exploit).
  static const double companionFuelGift = 0.125;

  /// Fuel threshold below which the companion will go fetch fuel.
  static const double _fetchThreshold = 0.20;

  /// Cooldown timer to prevent constant fetch loops.
  double _fetchCooldown = 0.0;

  /// Cooldown duration between fetch trips (seconds).
  static const double _fetchCooldownDuration = 15.0;

  /// Whether the companion is currently away fetching fuel.
  bool get isFetchingFuel => _isFetchingFuel;

  /// Trigger the companion to fly away and fetch fuel. Called by the game
  /// when fuel drops below threshold and the companion is idle.
  void startFuelFetch() {
    if (_isFetchingFuel || companionType == AvatarCompanion.none) return;
    if (_fetchCooldown > 0) return;
    _isFetchingFuel = true;
    _fetchProgress = 0.0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.isInLaunchIntro) return;

    if (companionType == AvatarCompanion.none) return;

    // Tick fetch cooldown.
    if (_fetchCooldown > 0) {
      _fetchCooldown = (_fetchCooldown - dt).clamp(0.0, _fetchCooldownDuration);
    }

    // Auto-trigger fuel fetch when fuel is low and companion is idle.
    if (!_isFetchingFuel &&
        _fetchCooldown <= 0 &&
        gameRef.fuelEnabled &&
        gameRef.fuel > 0 &&
        gameRef.fuel / gameRef.maxFuel < _fetchThreshold) {
      startFuelFetch();
    }

    // Animate fuel-fetch trip.
    if (_isFetchingFuel) {
      _fetchProgress += dt / _fetchDuration;
      if (_fetchProgress >= 1.0) {
        _isFetchingFuel = false;
        _fetchProgress = 0.0;
        _fetchCooldown = _fetchCooldownDuration;
        // Deliver fuel to the game.
        gameRef.companionRefuel(companionFuelGift);
      }
    }

    // Record plane position with a trailing buffer.
    _trailPositions.add(gameRef.worldPosition.clone());
    _trailHeadings.add(gameRef.heading);

    // Keep only the last N positions.
    while (_trailPositions.length > _trailDelay + 1) {
      _trailPositions.removeAt(0);
      _trailHeadings.removeAt(0);
    }

    // Animate wing flap (faster during fetch for urgency).
    final flapSpeed = _isFetchingFuel ? 14.0 : 8.0;
    _flapPhase += dt * flapSpeed;
    // Gentle bob at different frequency to avoid sync.
    _bobPhase += dt * 2.3;
    // Breath/pulse for fire creatures.
    _breathPhase += dt * 3.5;
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
    final bob = sin(_bobPhase) * 1.5;
    double offsetX = screenPos.x + 20;
    double offsetY = screenPos.y - 10 + bob;

    // During fuel-fetch, animate the companion flying away and returning.
    // Phase 0.0–0.3: fly off to the right and upward (departure)
    // Phase 0.3–0.7: off-screen (fetching)
    // Phase 0.7–1.0: fly back in from the right (return)
    double fetchOpacity = 1.0;
    double fetchScale = 1.0;
    if (_isFetchingFuel) {
      final p = _fetchProgress;
      if (p < 0.3) {
        // Departing — slide right and shrink.
        final t = p / 0.3;
        offsetX += t * 200;
        offsetY -= t * 80;
        fetchScale = 1.0 - t * 0.6;
        fetchOpacity = 1.0 - t;
      } else if (p < 0.7) {
        // Off-screen — don't render at all.
        fetchOpacity = 0.0;
      } else {
        // Returning — slide back in from the right.
        final t = (p - 0.7) / 0.3;
        offsetX += (1.0 - t) * 200;
        offsetY -= (1.0 - t) * 80;
        fetchScale = 0.4 + t * 0.6;
        fetchOpacity = t;
      }
    }

    if (fetchOpacity <= 0) return; // off-screen, skip rendering

    canvas.save();
    canvas.translate(offsetX, offsetY);
    if (fetchScale != 1.0) {
      canvas.scale(fetchScale);
    }

    // Rotate to match the companion's delayed heading relative to the camera.
    // Must use cameraHeading (not heading) to match the plane's own visual
    // rotation logic — the camera lags behind the heading during turns.
    // In flat-map mode, convert math convention to canvas (north-up) with +π/2.
    double visualHeading;
    if (gameRef.isFlatMapMode) {
      visualHeading = delayedHeading + pi / 2;
    } else {
      visualHeading = delayedHeading - gameRef.cameraHeading;
      while (visualHeading > pi) {
        visualHeading -= 2 * pi;
      }
      while (visualHeading < -pi) {
        visualHeading += 2 * pi;
      }
    }
    canvas.rotate(visualHeading);

    // Apply fetch opacity via save layer when partially transparent.
    if (fetchOpacity < 1.0) {
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(255, 255, 255, fetchOpacity),
      );
    }

    _renderCompanion(canvas);

    if (fetchOpacity < 1.0) {
      canvas.restore(); // pop the saveLayer
    }

    canvas.restore();
  }

  /// Paint the companion art via the shared [CompanionArt] painter —
  /// single source of truth also used by the debug preview screen.
  ///
  /// The art is drawn at a FIXED screen-space size per species (see
  /// [CompanionArt.sizeOf]) — deliberately ~2x the legacy sizes so the
  /// smallest companion never renders as an unreadable dot. Only the
  /// temporary fuel-fetch fly-away animation scales it down.
  void _renderCompanion(Canvas canvas) {
    CompanionArt.paint(
      canvas,
      companionType,
      flapPhase: _flapPhase,
      breathPhase: _breathPhase,
    );
  }
}
