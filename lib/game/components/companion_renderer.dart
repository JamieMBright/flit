import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../data/models/avatar_config.dart';
import '../flit_game.dart';
import '../rendering/watercolor_style.dart';

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

  void _renderCompanion(Canvas canvas) {
    final flapOffset = sin(_flapPhase) * 3.0;

    switch (companionType) {
      case AvatarCompanion.none:
        break;
      case AvatarCompanion.pidgey:
        _renderPidgey(canvas, flapOffset);
      case AvatarCompanion.sparrow:
        _renderSparrow(canvas, flapOffset);
      case AvatarCompanion.eagle:
        _renderEagle(canvas, flapOffset);
      case AvatarCompanion.parrot:
        _renderParrot(canvas, flapOffset);
      case AvatarCompanion.phoenix:
        _renderPhoenix(canvas, flapOffset);
      case AvatarCompanion.dragon:
        _renderDragon(canvas, flapOffset);
      case AvatarCompanion.charizard:
        _renderCharizard(canvas, flapOffset);
    }
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  /// Draw a smooth wing using cubic bezier curves with feathered tips.
  /// Uses watercolour wash fills for soft, organic-looking wings.
  void _drawWing({
    required Canvas canvas,
    required double size,
    required double flapOffset,
    required Paint paint,
    required bool isLeft,
    double spread = 0.9,
    int featherCount = 3,
    Paint? tipPaint,
  }) {
    final sign = isLeft ? -1.0 : 1.0;
    final wing = Path()
      ..moveTo(sign * size * 0.2, 0)
      ..cubicTo(
        sign * size * 0.5,
        flapOffset - size * 0.3,
        sign * size * 0.75,
        flapOffset - size * 0.55,
        sign * size * spread,
        flapOffset - size * 0.2,
      );

    // Feathered trailing edge.
    final featherStep = size * 0.15;
    for (var i = 0; i < featherCount; i++) {
      final fx = sign * (size * spread - (i + 1) * featherStep * 0.6);
      final fy = flapOffset - size * 0.2 + (i + 1) * featherStep * 0.4;
      wing.lineTo(fx, fy);
      // Small notch between feathers.
      if (i < featherCount - 1) {
        wing.lineTo(
          sign *
              (size * spread -
                  (i + 1) * featherStep * 0.6 -
                  featherStep * 0.15),
          fy - featherStep * 0.1,
        );
      }
    }

    wing
      ..lineTo(sign * size * 0.1, size * 0.05)
      ..close();

    // Watercolour wash instead of solid fill.
    WatercolorStyle.washFill(canvas, wing, paint.color,
        seed: '${isLeft ? "L" : "R"}wing');
    WatercolorStyle.wetEdge(canvas, wing, paint.color, opacity: 0.2);

    // Optional wing tip accent.
    if (tipPaint != null) {
      final tip = Path()
        ..moveTo(sign * size * (spread - 0.15), flapOffset - size * 0.35)
        ..cubicTo(
          sign * size * (spread - 0.05),
          flapOffset - size * 0.3,
          sign * size * spread,
          flapOffset - size * 0.25,
          sign * size * spread,
          flapOffset - size * 0.2,
        )
        ..lineTo(sign * size * (spread - 0.12), flapOffset - size * 0.12)
        ..close();
      WatercolorStyle.washFill(canvas, tip, tipPaint.color, seed: 'tip');
    }
  }

  /// Draw a layered body with watercolour washes for soft, organic depth.
  void _drawBody({
    required Canvas canvas,
    required double width,
    required double height,
    required Color baseColor,
    required Color bellyColor,
    Offset center = Offset.zero,
  }) {
    // Soft shadow under body.
    final shadowPath = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(center.dx, center.dy + height * 0.08),
        width: width * 0.95,
        height: height * 0.6,
      ));
    WatercolorStyle.softShadow(canvas, shadowPath);

    // Main body — watercolour wash.
    final bodyPath = Path()
      ..addOval(Rect.fromCenter(center: center, width: width, height: height));
    WatercolorStyle.washFill(canvas, bodyPath, baseColor, seed: 'body');
    WatercolorStyle.wetEdge(canvas, bodyPath, baseColor, opacity: 0.18);

    // Belly highlight — softer wash.
    final bellyPath = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(center.dx, center.dy + height * 0.06),
        width: width * 0.6,
        height: height * 0.45,
      ));
    WatercolorStyle.washFill(canvas, bellyPath, bellyColor,
        seed: 'belly', opacity: 0.25);

    // Top highlight — soft light wash.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - height * 0.12),
        width: width * 0.35,
        height: height * 0.15,
      ),
      Paint()
        ..color = _lighten(baseColor, 0.2).withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
  }

  /// Draw cute round eyes with highlight dot.
  void _drawEyes({
    required Canvas canvas,
    required Offset leftCenter,
    required Offset rightCenter,
    required double radius,
    Color irisColor = const Color(0xFF1A1A2E),
    Color highlightColor = const Color(0xFFFFFFFF),
    bool fierce = false,
  }) {
    for (final center in [leftCenter, rightCenter]) {
      if (fierce) {
        // Fierce: narrower, angled eye shape.
        final eye = Path()
          ..addOval(
            Rect.fromCenter(
              center: center,
              width: radius * 2.4,
              height: radius * 1.6,
            ),
          );
        canvas.drawPath(eye, Paint()..color = irisColor);
        // Glint.
        canvas.drawCircle(
          Offset(center.dx - radius * 0.3, center.dy - radius * 0.2),
          radius * 0.3,
          Paint()..color = highlightColor.withOpacity(0.7),
        );
      } else {
        // Cute: round with big highlight.
        // White of eye.
        canvas.drawCircle(
          center,
          radius * 1.2,
          Paint()..color = const Color(0xFFF8F4F0),
        );
        // Iris.
        canvas.drawCircle(center, radius, Paint()..color = irisColor);
        // Highlight dot (upper-left for light direction).
        canvas.drawCircle(
          Offset(center.dx - radius * 0.35, center.dy - radius * 0.35),
          radius * 0.35,
          Paint()..color = highlightColor,
        );
      }
    }
  }

  /// Draw a beak with upper and lower mandible.
  void _drawBeak({
    required Canvas canvas,
    required Offset tip,
    required double size,
    Color color = const Color(0xFFE8962A),
    bool hooked = false,
  }) {
    final upperBeak = Path()..moveTo(tip.dx, tip.dy);
    if (hooked) {
      upperBeak
        ..quadraticBezierTo(
          tip.dx - size * 0.5,
          tip.dy + size * 0.3,
          tip.dx - size * 0.3,
          tip.dy + size * 0.7,
        )
        ..quadraticBezierTo(
          tip.dx,
          tip.dy + size * 0.5,
          tip.dx + size * 0.3,
          tip.dy + size * 0.7,
        )
        ..quadraticBezierTo(
          tip.dx + size * 0.5,
          tip.dy + size * 0.3,
          tip.dx,
          tip.dy,
        );
    } else {
      upperBeak
        ..lineTo(tip.dx - size * 0.35, tip.dy + size * 0.5)
        ..quadraticBezierTo(
          tip.dx,
          tip.dy + size * 0.65,
          tip.dx + size * 0.35,
          tip.dy + size * 0.5,
        )
        ..close();
    }
    WatercolorStyle.washFill(canvas, upperBeak, color, seed: 'beak');
    // Lower mandible (darker).
    final lower = Path()
      ..moveTo(tip.dx - size * 0.25, tip.dy + size * 0.45)
      ..quadraticBezierTo(
        tip.dx,
        tip.dy + size * 0.7,
        tip.dx + size * 0.25,
        tip.dy + size * 0.45,
      )
      ..close();
    WatercolorStyle.washFill(canvas, lower, _darken(color, 0.2),
        seed: 'beak_lo');
  }

  /// Draw a stylized tail with separated feathers.
  void _drawTailFeathers({
    required Canvas canvas,
    required double size,
    required Color color,
    int count = 3,
    double length = 0.5,
    double splay = 0.15,
  }) {
    for (var i = 0; i < count; i++) {
      final t = (i - (count - 1) / 2.0) / max(count - 1, 1);
      final feather = Path()
        ..moveTo(t * size * splay * 0.5, size * 0.2)
        ..quadraticBezierTo(
          t * size * splay * 1.5,
          size * (0.2 + length * 0.5),
          t * size * splay,
          size * (0.2 + length),
        )
        ..quadraticBezierTo(
          t * size * splay * 0.8,
          size * (0.2 + length * 0.4),
          t * size * splay * 0.3,
          size * 0.2,
        )
        ..close();
      // Alternate slightly lighter/darker for depth.
      final featherColor = i.isEven ? color : _darken(color, 0.1);
      WatercolorStyle.washFill(canvas, feather, featherColor, seed: 'tail$i');
    }
  }

  Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  // ---------------------------------------------------------------------------
  // Pidgey — Adorable tiny round bird. Big head, small body, chibi proportions.
  // Inspired by house sparrow / flappy bird aesthetic.
  // ---------------------------------------------------------------------------
  void _renderPidgey(Canvas canvas, double flapOffset) {
    const s = 7.0;
    const brown = Color(0xFF9E7B5A);
    const cream = Color(0xFFF5E8D0);
    const darkBrown = Color(0xFF6B5238);

    // Soft watercolour drop shadow.
    WatercolorStyle.softShadow(
      canvas,
      Path()
        ..addOval(Rect.fromCenter(
          center: const Offset(0.5, 1.5),
          width: s * 1.0,
          height: s * 0.3,
        )),
    );

    // Tail feathers (behind body).
    _drawTailFeathers(
      canvas: canvas,
      size: s,
      color: darkBrown,
      count: 3,
      length: 0.35,
      splay: 0.12,
    );

    // Wings (behind body).
    _drawWing(
      canvas: canvas,
      size: s,
      flapOffset: flapOffset,
      paint: Paint()..color = darkBrown.withOpacity(0.85),
      isLeft: true,
      spread: 0.7,
      featherCount: 2,
    );
    _drawWing(
      canvas: canvas,
      size: s,
      flapOffset: flapOffset,
      paint: Paint()..color = darkBrown.withOpacity(0.85),
      isLeft: false,
      spread: 0.7,
      featherCount: 2,
    );

    // Pudgy body.
    _drawBody(
      canvas: canvas,
      width: s * 0.95,
      height: s * 0.6,
      baseColor: brown,
      bellyColor: cream,
    );

    // Round head — watercolour wash (oversized for cuteness).
    final headPath = Path()
      ..addOval(Rect.fromCircle(
          center: const Offset(0, -s * 0.32), radius: s * 0.28));
    WatercolorStyle.washFill(canvas, headPath, brown, seed: 'pidgey_head');
    WatercolorStyle.wetEdge(canvas, headPath, brown, opacity: 0.15);
    // Cream face wash.
    final facePath = Path()
      ..addOval(Rect.fromCircle(
          center: const Offset(0, -s * 0.28), radius: s * 0.18));
    WatercolorStyle.washFill(canvas, facePath, cream, seed: 'pidgey_face');
    // Head highlight — soft glow.
    canvas.drawCircle(
      const Offset(-s * 0.05, -s * 0.42),
      s * 0.08,
      Paint()
        ..color = _lighten(brown, 0.15).withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );

    // Big cute eyes.
    _drawEyes(
      canvas: canvas,
      leftCenter: const Offset(-s * 0.1, -s * 0.35),
      rightCenter: const Offset(s * 0.1, -s * 0.35),
      radius: s * 0.07,
    );

    // Tiny beak.
    _drawBeak(
      canvas: canvas,
      tip: const Offset(0, -s * 0.52),
      size: s * 0.15,
      color: const Color(0xFFE8962A),
    );

    // Rosy cheeks for extra cuteness.
    canvas.drawCircle(
      const Offset(-s * 0.15, -s * 0.26),
      s * 0.05,
      Paint()..color = const Color(0xFFE88080).withOpacity(0.35),
    );
    canvas.drawCircle(
      const Offset(s * 0.15, -s * 0.26),
      s * 0.05,
      Paint()..color = const Color(0xFFE88080).withOpacity(0.35),
    );
  }

  // ---------------------------------------------------------------------------
  // Sparrow — Sleek barn swallow silhouette. Streamlined, fast-looking.
  // Navy-blue back, cream belly, forked tail.
  // ---------------------------------------------------------------------------
  void _renderSparrow(Canvas canvas, double flapOffset) {
    const s = 9.0;
    const navy = Color(0xFF2C3E6B);
    const russet = Color(0xFFB85C38);
    const cream = Color(0xFFF0E6D4);

    // Forked tail (drawn first, behind body).
    final leftFork = Path()
      ..moveTo(-s * 0.05, s * 0.2)
      ..quadraticBezierTo(-s * 0.2, s * 0.55, -s * 0.18, s * 0.7)
      ..quadraticBezierTo(-s * 0.12, s * 0.5, -s * 0.02, s * 0.35)
      ..close();
    final rightFork = Path()
      ..moveTo(s * 0.05, s * 0.2)
      ..quadraticBezierTo(s * 0.2, s * 0.55, s * 0.18, s * 0.7)
      ..quadraticBezierTo(s * 0.12, s * 0.5, s * 0.02, s * 0.35)
      ..close();
    WatercolorStyle.washFill(canvas, leftFork, navy, seed: 'sparrow_lf');
    WatercolorStyle.washFill(canvas, rightFork, navy, seed: 'sparrow_rf');

    // Long swept wings.
    _drawWing(
      canvas: canvas,
      size: s,
      flapOffset: flapOffset,
      paint: Paint()..color = navy.withOpacity(0.9),
      isLeft: true,
      spread: 0.95,
      featherCount: 4,
      tipPaint: Paint()..color = const Color(0xFF1A2A4D),
    );
    _drawWing(
      canvas: canvas,
      size: s,
      flapOffset: flapOffset,
      paint: Paint()..color = navy.withOpacity(0.9),
      isLeft: false,
      spread: 0.95,
      featherCount: 4,
      tipPaint: Paint()..color = const Color(0xFF1A2A4D),
    );

    // Streamlined body.
    _drawBody(
      canvas: canvas,
      width: s * 0.8,
      height: s * 0.45,
      baseColor: navy,
      bellyColor: cream,
    );

    // Small neat head — watercolour wash.
    final headPath = Path()
      ..addOval(Rect.fromCircle(
          center: const Offset(0, -s * 0.28), radius: s * 0.18));
    WatercolorStyle.washFill(canvas, headPath, navy, seed: 'sparrow_head');
    WatercolorStyle.wetEdge(canvas, headPath, navy, opacity: 0.15);
    // Russet throat patch — wash.
    final throatPath = Path()
      ..addOval(Rect.fromCenter(
        center: const Offset(0, -s * 0.2),
        width: s * 0.2,
        height: s * 0.12,
      ));
    WatercolorStyle.washFill(canvas, throatPath, russet,
        seed: 'sparrow_throat');

    // Sharp eyes.
    _drawEyes(
      canvas: canvas,
      leftCenter: const Offset(-s * 0.07, -s * 0.31),
      rightCenter: const Offset(s * 0.07, -s * 0.31),
      radius: s * 0.04,
      irisColor: const Color(0xFF111122),
    );

    // Small pointed beak.
    _drawBeak(
      canvas: canvas,
      tip: const Offset(0, -s * 0.44),
      size: s * 0.12,
      color: const Color(0xFF2A2A2A),
    );
  }

  // ---------------------------------------------------------------------------
  // Eagle — Majestic golden raptor. Broad soaring wings, white head,
  // hooked beak. Inspired by bald eagle / Ghibli hawk.
  // ---------------------------------------------------------------------------
  void _renderEagle(Canvas canvas, double flapOffset) {
    const s = 15.0;
    const darkBrown = Color(0xFF4A3222);
    const goldenBrown = Color(0xFF8B6B3A);
    const white = Color(0xFFF5F0E8);
    const gold = Color(0xFFD4A030);

    // Broad fanned tail.
    _drawTailFeathers(
      canvas: canvas,
      size: s,
      color: darkBrown,
      count: 5,
      length: 0.45,
      splay: 0.2,
    );

    // Massive soaring wings — broader spread, more feathers.
    for (final isLeft in [true, false]) {
      final sign = isLeft ? -1.0 : 1.0;
      // Wing shadow layer.
      final shadowWing = Path()
        ..moveTo(sign * s * 0.25, s * 0.02)
        ..cubicTo(
          sign * s * 0.6,
          flapOffset - s * 0.25 + 1,
          sign * s * 0.9,
          flapOffset - s * 0.5 + 1,
          sign * s * 1.15,
          flapOffset - s * 0.15 + 1,
        )
        ..lineTo(sign * s * 0.15, s * 0.08)
        ..close();
      canvas.drawPath(
        shadowWing,
        Paint()..color = const Color(0xFF2A1A10).withOpacity(0.3),
      );

      // Main wing.
      _drawWing(
        canvas: canvas,
        size: s,
        flapOffset: flapOffset,
        paint: Paint()..color = goldenBrown.withOpacity(0.9),
        isLeft: isLeft,
        spread: 1.15,
        featherCount: 5,
        tipPaint: Paint()..color = darkBrown,
      );

      // Wing bar pattern (lighter stripe across secondaries).
      final bar = Path()
        ..moveTo(sign * s * 0.4, flapOffset - s * 0.2)
        ..lineTo(sign * s * 0.8, flapOffset - s * 0.32)
        ..lineTo(sign * s * 0.82, flapOffset - s * 0.27)
        ..lineTo(sign * s * 0.42, flapOffset - s * 0.15)
        ..close();
      canvas.drawPath(bar, Paint()..color = gold.withOpacity(0.3));
    }

    // Powerful body.
    _drawBody(
      canvas: canvas,
      width: s * 0.85,
      height: s * 0.5,
      baseColor: goldenBrown,
      bellyColor: const Color(0xFFE8D8B8),
    );

    // White head (bald eagle style) — watercolour wash.
    final eagleHeadPath = Path()
      ..addOval(Rect.fromCircle(
          center: const Offset(0, -s * 0.32), radius: s * 0.22));
    WatercolorStyle.washFill(canvas, eagleHeadPath, white, seed: 'eagle_head');
    WatercolorStyle.wetEdge(canvas, eagleHeadPath, white, opacity: 0.12);
    // Subtle head shadow wash.
    final eagleFacePath = Path()
      ..addOval(Rect.fromCircle(
          center: const Offset(0, -s * 0.28), radius: s * 0.18));
    WatercolorStyle.washFill(canvas, eagleFacePath, const Color(0xFFE8E0D0),
        seed: 'eagle_face');

    // Fierce piercing eyes.
    _drawEyes(
      canvas: canvas,
      leftCenter: const Offset(-s * 0.08, -s * 0.34),
      rightCenter: const Offset(s * 0.08, -s * 0.34),
      radius: s * 0.04,
      irisColor: const Color(0xFFCC8800),
      fierce: true,
    );

    // Prominent hooked beak.
    _drawBeak(
      canvas: canvas,
      tip: const Offset(0, -s * 0.52),
      size: s * 0.18,
      color: const Color(0xFFE8A820),
      hooked: true,
    );

    // Brow ridge (gives fierce expression).
    canvas.drawLine(
      const Offset(-s * 0.14, -s * 0.38),
      const Offset(-s * 0.03, -s * 0.36),
      Paint()
        ..color = const Color(0xFFD0C8B8)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(s * 0.14, -s * 0.38),
      const Offset(s * 0.03, -s * 0.36),
      Paint()
        ..color = const Color(0xFFD0C8B8)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
  }

  // ---------------------------------------------------------------------------
  // Parrot — Vivid scarlet macaw. Red body, blue/green/gold wings,
  // long elegant tail streamers. Eye-catching tropical bird.
  // ---------------------------------------------------------------------------
  void _renderParrot(Canvas canvas, double flapOffset) {
    const s = 11.0;
    const scarlet = Color(0xFFDD2828);
    const royalBlue = Color(0xFF1845A0);
    const emerald = Color(0xFF22AA44);
    const gold = Color(0xFFFFCC22);
    const white = Color(0xFFF8F4F0);

    // Long tail streamers (drawn behind everything).
    for (var i = 0; i < 3; i++) {
      final colors = [royalBlue, scarlet, emerald];
      final offsets = [-0.08, 0.0, 0.08];
      final lengths = [0.85, 0.95, 0.8];
      final streamer = Path()
        ..moveTo(s * offsets[i], s * 0.2)
        ..cubicTo(
          s * offsets[i] * 2,
          s * 0.5,
          s * offsets[i] * 0.5,
          s * 0.7,
          s * offsets[i] * 1.5,
          s * lengths[i],
        )
        ..quadraticBezierTo(
          s * offsets[i],
          s * (lengths[i] - 0.1),
          s * offsets[i] * 0.5,
          s * 0.2,
        )
        ..close();
      WatercolorStyle.washFill(canvas, streamer, colors[i].withOpacity(0.85),
          seed: 'parrot_s$i');
    }

    // Wings — multicolored like a real macaw.
    for (final isLeft in [true, false]) {
      // Blue base wing.
      _drawWing(
        canvas: canvas,
        size: s,
        flapOffset: flapOffset,
        paint: Paint()..color = royalBlue.withOpacity(0.9),
        isLeft: isLeft,
        spread: 0.85,
        featherCount: 3,
        tipPaint: Paint()..color = const Color(0xFF0D2D6B),
      );
      // Green secondary band.
      final sign = isLeft ? -1.0 : 1.0;
      final greenBand = Path()
        ..moveTo(sign * s * 0.25, flapOffset * 0.3 - s * 0.05)
        ..lineTo(sign * s * 0.55, flapOffset - s * 0.25)
        ..lineTo(sign * s * 0.58, flapOffset - s * 0.18)
        ..lineTo(sign * s * 0.28, flapOffset * 0.3 + s * 0.02)
        ..close();
      WatercolorStyle.washFill(canvas, greenBand, emerald.withOpacity(0.7),
          seed: 'parrot_gb');
      // Gold covert stripe.
      final goldStripe = Path()
        ..moveTo(sign * s * 0.2, flapOffset * 0.2)
        ..lineTo(sign * s * 0.45, flapOffset - s * 0.12)
        ..lineTo(sign * s * 0.47, flapOffset - s * 0.08)
        ..lineTo(sign * s * 0.22, flapOffset * 0.2 + s * 0.04)
        ..close();
      WatercolorStyle.washFill(canvas, goldStripe, gold.withOpacity(0.5),
          seed: 'parrot_gs');
    }

    // Scarlet body.
    _drawBody(
      canvas: canvas,
      width: s * 0.8,
      height: s * 0.48,
      baseColor: scarlet,
      bellyColor: const Color(0xFFEE5555),
    );

    // Round head — watercolour.
    final parrotHeadPath = Path()
      ..addOval(
          Rect.fromCircle(center: const Offset(0, -s * 0.3), radius: s * 0.2));
    WatercolorStyle.washFill(canvas, parrotHeadPath, scarlet, seed: 'parrot_h');
    WatercolorStyle.wetEdge(canvas, parrotHeadPath, scarlet, opacity: 0.15);
    // Head highlight.
    canvas.drawCircle(
      const Offset(-s * 0.04, -s * 0.38),
      s * 0.06,
      Paint()
        ..color = _lighten(scarlet, 0.15).withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );

    // White eye patches (bare skin like real macaw).
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(-s * 0.09, -s * 0.3),
        width: s * 0.12,
        height: s * 0.14,
      ),
      Paint()..color = white.withOpacity(0.85),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(s * 0.09, -s * 0.3),
        width: s * 0.12,
        height: s * 0.14,
      ),
      Paint()..color = white.withOpacity(0.85),
    );

    // Eyes.
    _drawEyes(
      canvas: canvas,
      leftCenter: const Offset(-s * 0.09, -s * 0.31),
      rightCenter: const Offset(s * 0.09, -s * 0.31),
      radius: s * 0.04,
      irisColor: const Color(0xFF222222),
    );

    // Curved parrot beak (large, prominent).
    final upperBeak = Path()
      ..moveTo(0, -s * 0.42)
      ..cubicTo(-s * 0.1, -s * 0.48, -s * 0.08, -s * 0.56, 0, -s * 0.58)
      ..cubicTo(s * 0.08, -s * 0.56, s * 0.1, -s * 0.48, 0, -s * 0.42);
    canvas.drawPath(upperBeak, Paint()..color = const Color(0xFF1A1A1A));
    // Lower mandible.
    final lowerBeak = Path()
      ..moveTo(-s * 0.04, -s * 0.42)
      ..quadraticBezierTo(0, -s * 0.46, s * 0.04, -s * 0.42)
      ..quadraticBezierTo(0, -s * 0.39, -s * 0.04, -s * 0.42);
    canvas.drawPath(lowerBeak, Paint()..color = const Color(0xFF333333));
    // Beak highlight.
    canvas.drawCircle(
      const Offset(s * 0.01, -s * 0.52),
      s * 0.015,
      Paint()..color = const Color(0xFF555555),
    );
  }

  // ---------------------------------------------------------------------------
  // Phoenix — Ethereal mythical fire bird. Luminous orange-gold body,
  // flame feather crest, trailing fire particles, warm aura glow.
  // ---------------------------------------------------------------------------
  void _renderPhoenix(Canvas canvas, double flapOffset) {
    const s = 14.0;
    final breathPulse = sin(_breathPhase) * 0.15 + 0.85;
    const deepOrange = Color(0xFFE85D04);
    const brightOrange = Color(0xFFFF8C22);
    const gold = Color(0xFFFFCC00);
    const paleGold = Color(0xFFFFE888);
    const crimson = Color(0xFFCC1100);

    // Outer warm aura (pulses gently) — watercolour radial glow.
    WatercolorStyle.auraGlow(
      canvas,
      Offset.zero,
      s * 0.9 * breathPulse,
      const Color(0xFFFF6600),
      opacity: 0.10 * breathPulse,
    );
    // Inner bright glow.
    WatercolorStyle.auraGlow(
      canvas,
      const Offset(0, -s * 0.1),
      s * 0.5 * breathPulse,
      gold,
      opacity: 0.14 * breathPulse,
    );

    // Flame tail — multiple flickering tongues.
    for (var i = 0; i < 5; i++) {
      final t = (i - 2) * 0.06;
      final flicker = sin(_breathPhase * 2 + i * 1.2) * s * 0.05;
      final tongue = Path()
        ..moveTo(s * t, s * 0.2)
        ..cubicTo(
          s * t + flicker,
          s * 0.5,
          s * t * 2 - flicker,
          s * 0.7,
          s * t * 1.5 + flicker,
          s * (0.75 + i * 0.06),
        )
        ..quadraticBezierTo(s * t, s * (0.6 + i * 0.03), s * t * 0.5, s * 0.2)
        ..close();
      final tongueColors = [crimson, deepOrange, gold, brightOrange, crimson];
      WatercolorStyle.washFill(canvas, tongue, tongueColors[i].withOpacity(0.7),
          seed: 'phx_t$i');
    }
    // Tail glow.
    canvas.drawCircle(
      const Offset(0, s * 0.6),
      s * 0.25,
      Paint()
        ..color = gold.withOpacity(0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Flame wings.
    for (final isLeft in [true, false]) {
      final sign = isLeft ? -1.0 : 1.0;

      // Wing glow.
      final glowWing = Path()
        ..moveTo(sign * s * 0.15, 0)
        ..cubicTo(
          sign * s * 0.5,
          flapOffset - s * 0.3,
          sign * s * 0.8,
          flapOffset - s * 0.55,
          sign * s * 1.05,
          flapOffset - s * 0.15,
        )
        ..lineTo(sign * s * 0.1, s * 0.05)
        ..close();
      canvas.drawPath(
        glowWing,
        Paint()
          ..color = gold.withOpacity(0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // Main wing.
      _drawWing(
        canvas: canvas,
        size: s,
        flapOffset: flapOffset,
        paint: Paint()..color = deepOrange.withOpacity(0.85),
        isLeft: isLeft,
        spread: 1.05,
        featherCount: 4,
        tipPaint: Paint()..color = crimson.withOpacity(0.8),
      );

      // Gold inner wing shimmer.
      final shimmer = Path()
        ..moveTo(sign * s * 0.2, 0)
        ..cubicTo(
          sign * s * 0.4,
          flapOffset - s * 0.15,
          sign * s * 0.55,
          flapOffset - s * 0.25,
          sign * s * 0.65,
          flapOffset - s * 0.1,
        )
        ..lineTo(sign * s * 0.1, s * 0.02)
        ..close();
      canvas.drawPath(shimmer, Paint()..color = gold.withOpacity(0.3));
    }

    // Luminous body.
    _drawBody(
      canvas: canvas,
      width: s * 0.75,
      height: s * 0.42,
      baseColor: deepOrange,
      bellyColor: paleGold,
    );
    // Body inner glow.
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: s * 0.5, height: s * 0.25),
      Paint()
        ..color = gold.withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Elegant head — watercolour wash.
    final phxHeadPath = Path()
      ..addOval(Rect.fromCircle(
          center: const Offset(0, -s * 0.28), radius: s * 0.18));
    WatercolorStyle.washFill(canvas, phxHeadPath, brightOrange,
        seed: 'phx_head');
    // Head glow.
    WatercolorStyle.auraGlow(
      canvas,
      const Offset(0, -s * 0.28),
      s * 0.12,
      gold,
      opacity: 0.22,
    );

    // Crown crest — three flame plumes.
    for (var i = 0; i < 3; i++) {
      final offX = (i - 1) * s * 0.08;
      final plumeLengths = [s * 0.28, s * 0.35, s * 0.25];
      final plumeColors = [crimson, gold, deepOrange];
      final flicker = sin(_breathPhase * 3 + i * 1.5) * s * 0.02;
      final plume = Path()
        ..moveTo(offX, -s * 0.42)
        ..quadraticBezierTo(
          offX + flicker,
          -s * 0.42 - plumeLengths[i] * 0.6,
          offX * 0.5 + flicker,
          -s * 0.42 - plumeLengths[i],
        )
        ..quadraticBezierTo(
          offX - flicker,
          -s * 0.42 - plumeLengths[i] * 0.4,
          offX,
          -s * 0.42,
        )
        ..close();
      canvas.drawPath(plume, Paint()..color = plumeColors[i].withOpacity(0.8));
    }

    // Bright glowing eyes.
    _drawEyes(
      canvas: canvas,
      leftCenter: const Offset(-s * 0.07, -s * 0.3),
      rightCenter: const Offset(s * 0.07, -s * 0.3),
      radius: s * 0.035,
      irisColor: const Color(0xFFFFDD00),
      highlightColor: const Color(0xFFFFFFFF),
    );

    // Small elegant beak.
    _drawBeak(
      canvas: canvas,
      tip: const Offset(0, -s * 0.44),
      size: s * 0.1,
      color: const Color(0xFFCC6600),
    );
  }

  // ---------------------------------------------------------------------------
  // Dragon — Classic western wyvern. Muscular body, bat-like membrane wings
  // with visible finger bones, horned head, spined ridgeback, fire tail tip.
  // ---------------------------------------------------------------------------
  void _renderDragon(Canvas canvas, double flapOffset) {
    const s = 17.0;
    final breathPulse = sin(_breathPhase) * 0.1 + 0.9;
    const forestGreen = Color(0xFF2D6B3F);
    const darkGreen = Color(0xFF1A4228);
    const paleGreen = Color(0xFFA8D8A0);
    const amber = Color(0xFFE8A820);
    const hornColor = Color(0xFF5C4A32);

    // Fire breath glow near mouth — watercolour radial glow.
    WatercolorStyle.auraGlow(
      canvas,
      const Offset(0, -s * 0.65),
      s * 0.2 * breathPulse,
      const Color(0xFFFF6600),
      opacity: 0.14 * breathPulse,
    );

    // Spined tail with flame tip.
    final tail = Path()
      ..moveTo(0, s * 0.25)
      ..cubicTo(-s * 0.08, s * 0.5, -s * 0.15, s * 0.7, -s * 0.08, s * 0.95)
      ..lineTo(0, s * 0.88)
      ..lineTo(s * 0.08, s * 0.95)
      ..cubicTo(s * 0.15, s * 0.7, s * 0.08, s * 0.5, 0, s * 0.25)
      ..close();
    WatercolorStyle.washFill(canvas, tail, forestGreen, seed: 'drag_tail');
    // Tail spines.
    for (var i = 0; i < 3; i++) {
      final t = 0.35 + i * 0.2;
      final spineX = sin(t * 3) * s * 0.02;
      final spine = Path()
        ..moveTo(spineX - s * 0.02, s * t)
        ..lineTo(spineX - s * 0.06, s * t - s * 0.04)
        ..lineTo(spineX, s * t - s * 0.01)
        ..close();
      WatercolorStyle.washFill(canvas, spine, darkGreen, seed: 'drag_sp');
    }
    // Flame tail tip.
    final flameTip = Path()
      ..moveTo(-s * 0.1, s * 0.9)
      ..lineTo(-s * 0.12, s * 1.08)
      ..lineTo(0, s * 1.0)
      ..lineTo(s * 0.12, s * 1.08)
      ..lineTo(s * 0.1, s * 0.9)
      ..close();
    WatercolorStyle.washFill(canvas, flameTip, const Color(0xFFFF6600),
        seed: 'drag_flame');
    canvas.drawPath(
      flameTip,
      Paint()
        ..color = amber.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Bat-like membrane wings with finger bones.
    for (final isLeft in [true, false]) {
      final sign = isLeft ? -1.0 : 1.0;

      // Wing membrane (translucent).
      final membrane = Path()
        ..moveTo(sign * s * 0.3, -s * 0.05)
        // First finger.
        ..lineTo(sign * s * 0.95, flapOffset - s * 0.7)
        // Scallop between fingers.
        ..quadraticBezierTo(
          sign * s * 0.7,
          flapOffset - s * 0.3,
          sign * s * 0.75,
          flapOffset - s * 0.28,
        )
        // Second finger.
        ..lineTo(sign * s * 1.15, flapOffset - s * 0.45)
        // Scallop.
        ..quadraticBezierTo(
          sign * s * 0.85,
          flapOffset - s * 0.12,
          sign * s * 0.88,
          flapOffset - s * 0.08,
        )
        // Third finger.
        ..lineTo(sign * s * 1.05, flapOffset - s * 0.15)
        // Trailing edge.
        ..quadraticBezierTo(
          sign * s * 0.7,
          flapOffset + s * 0.05,
          sign * s * 0.15,
          s * 0.02,
        )
        ..close();
      WatercolorStyle.washFill(
          canvas, membrane, const Color(0xFF3D8B55).withOpacity(0.7),
          seed: 'drag_mem');

      // Wing membrane inner (lighter, translucent for membrane feel).
      WatercolorStyle.colorBleed(canvas, membrane, paleGreen, opacity: 0.1);

      // Finger bones (dark lines).
      final bonePaint = Paint()
        ..color = darkGreen.withOpacity(0.7)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      // Arm bone.
      canvas.drawLine(
        Offset(sign * s * 0.3, -s * 0.05),
        Offset(sign * s * 0.65, flapOffset - s * 0.35),
        bonePaint,
      );
      // First finger.
      canvas.drawLine(
        Offset(sign * s * 0.65, flapOffset - s * 0.35),
        Offset(sign * s * 0.95, flapOffset - s * 0.7),
        bonePaint,
      );
      // Second finger.
      canvas.drawLine(
        Offset(sign * s * 0.65, flapOffset - s * 0.35),
        Offset(sign * s * 1.15, flapOffset - s * 0.45),
        bonePaint,
      );
      // Third finger.
      canvas.drawLine(
        Offset(sign * s * 0.65, flapOffset - s * 0.35),
        Offset(sign * s * 1.05, flapOffset - s * 0.15),
        bonePaint,
      );

      // Wing claw at elbow joint.
      final claw = Path()
        ..moveTo(sign * s * 0.63, flapOffset - s * 0.35)
        ..lineTo(sign * s * 0.58, flapOffset - s * 0.42)
        ..lineTo(sign * s * 0.67, flapOffset - s * 0.37)
        ..close();
      WatercolorStyle.washFill(canvas, claw, hornColor, seed: 'claw');
    }

    // Muscular body with scale texture.
    _drawBody(
      canvas: canvas,
      width: s * 0.85,
      height: s * 0.52,
      baseColor: forestGreen,
      bellyColor: paleGreen,
    );
    // Scale pattern (subtle chevrons on belly).
    for (var i = 0; i < 4; i++) {
      final sy = -s * 0.08 + i * s * 0.06;
      canvas.drawLine(
        Offset(-s * 0.12, sy),
        Offset(0, sy + s * 0.02),
        Paint()
          ..color = darkGreen.withOpacity(0.2)
          ..strokeWidth = 0.6,
      );
      canvas.drawLine(
        Offset(0, sy + s * 0.02),
        Offset(s * 0.12, sy),
        Paint()
          ..color = darkGreen.withOpacity(0.2)
          ..strokeWidth = 0.6,
      );
    }

    // Dorsal spines along back.
    for (var i = 0; i < 4; i++) {
      final sx = -s * 0.02 + i * 0.01;
      final sy = -s * 0.15 + i * s * 0.1;
      final spine = Path()
        ..moveTo(sx - s * 0.015, sy)
        ..lineTo(sx, sy - s * 0.06)
        ..lineTo(sx + s * 0.015, sy)
        ..close();
      WatercolorStyle.washFill(canvas, spine, darkGreen, seed: 'drag_dsp');
    }

    // Powerful head.
    // Snout (elongated).
    final snout = Path()
      ..moveTo(-s * 0.12, -s * 0.32)
      ..quadraticBezierTo(0, -s * 0.55, s * 0.12, -s * 0.32)
      ..quadraticBezierTo(0, -s * 0.28, -s * 0.12, -s * 0.32);
    WatercolorStyle.washFill(canvas, snout, forestGreen, seed: 'drag_snout');
    // Head dome — watercolour.
    final dragHeadPath = Path()
      ..addOval(Rect.fromCircle(
          center: const Offset(0, -s * 0.34), radius: s * 0.18));
    WatercolorStyle.washFill(canvas, dragHeadPath, forestGreen,
        seed: 'drag_head');
    // Jaw underside (lighter).
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, -s * 0.3),
        width: s * 0.18,
        height: s * 0.08,
      ),
      Paint()..color = paleGreen.withOpacity(0.6),
    );

    // Horns.
    for (final sign in [-1.0, 1.0]) {
      final horn = Path()
        ..moveTo(sign * s * 0.1, -s * 0.46)
        ..cubicTo(
          sign * s * 0.18,
          -s * 0.58,
          sign * s * 0.22,
          -s * 0.68,
          sign * s * 0.16,
          -s * 0.72,
        )
        ..lineTo(sign * s * 0.08, -s * 0.5)
        ..close();
      WatercolorStyle.washFill(canvas, horn, hornColor, seed: 'drag_horn');
      // Horn highlight.
      canvas.drawLine(
        Offset(sign * s * 0.1, -s * 0.48),
        Offset(sign * s * 0.14, -s * 0.62),
        Paint()
          ..color = _lighten(hornColor, 0.2).withOpacity(0.5)
          ..strokeWidth = 0.8,
      );
    }

    // Fierce slit eyes.
    for (final sign in [-1.0, 1.0]) {
      // Eye glow.
      canvas.drawCircle(
        Offset(sign * s * 0.08, -s * 0.38),
        s * 0.04,
        Paint()
          ..color = amber.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      // Iris.
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(sign * s * 0.08, -s * 0.38),
          width: s * 0.06,
          height: s * 0.045,
        ),
        Paint()..color = amber,
      );
      // Slit pupil.
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(sign * s * 0.08, -s * 0.38),
          width: s * 0.015,
          height: s * 0.04,
        ),
        Paint()..color = const Color(0xFF111111),
      );
    }

    // Nostrils with smoke wisps.
    for (final sign in [-1.0, 1.0]) {
      canvas.drawCircle(
        Offset(sign * s * 0.04, -s * 0.5),
        s * 0.015,
        Paint()..color = darkGreen,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Charizard — Ultimate flame dragon. Bigger, more dramatic than Dragon.
  // Deep orange body, massive scalloped wings, prominent double horns,
  // blazing multi-layered tail flame, fiery aura with particle embers.
  // ---------------------------------------------------------------------------
  void _renderCharizard(Canvas canvas, double flapOffset) {
    const s = 21.0;
    final breathPulse = sin(_breathPhase) * 0.15 + 0.85;
    const deepOrange = Color(0xFFD85A10);
    const brightOrange = Color(0xFFFF8833);
    const paleYellow = Color(0xFFFFE8A0);
    const tealWing = Color(0xFF1B8B7A);
    const darkTeal = Color(0xFF0E5E52);
    const hornColor = Color(0xFF5C4432);
    const fireRed = Color(0xFFEE2200);
    const fireGold = Color(0xFFFFCC00);

    // Massive fiery aura (outer) — watercolour glow.
    WatercolorStyle.auraGlow(
      canvas,
      Offset.zero,
      s * 1.0 * breathPulse,
      const Color(0xFFFF4400),
      opacity: 0.08 * breathPulse,
    );
    // Inner warm glow.
    WatercolorStyle.auraGlow(
      canvas,
      const Offset(0, -s * 0.15),
      s * 0.55 * breathPulse,
      fireGold,
      opacity: 0.10 * breathPulse,
    );

    // Ember particles (small dots floating up from body).
    final rng = Random(42); // Fixed seed for consistent placement.
    for (var i = 0; i < 6; i++) {
      final phase = _breathPhase + i * 1.1;
      final t = (phase % 3.0) / 3.0; // 0..1 cycle
      final startX = (rng.nextDouble() - 0.5) * s * 0.5;
      final x = startX + sin(phase * 2) * s * 0.05;
      final y = -s * 0.2 - t * s * 0.5;
      final opacity = (1.0 - t) * 0.5;
      final emberSize = (1.0 - t) * s * 0.02 + s * 0.01;
      canvas.drawCircle(
        Offset(x, y),
        emberSize,
        Paint()
          ..color = (i.isEven ? fireGold : fireRed).withOpacity(opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }

    // Thick powerful tail with multi-layered flame.
    final tail = Path()
      ..moveTo(0, s * 0.25)
      ..cubicTo(-s * 0.1, s * 0.55, -s * 0.18, s * 0.75, -s * 0.1, s * 1.0)
      ..lineTo(0, s * 0.9)
      ..lineTo(s * 0.1, s * 1.0)
      ..cubicTo(s * 0.18, s * 0.75, s * 0.1, s * 0.55, 0, s * 0.25)
      ..close();
    WatercolorStyle.washFill(canvas, tail, deepOrange, seed: 'char_tail');
    // Tail belly stripe.
    final tailBelly = Path()
      ..moveTo(-s * 0.03, s * 0.3)
      ..cubicTo(-s * 0.04, s * 0.55, -s * 0.06, s * 0.75, -s * 0.03, s * 0.9)
      ..lineTo(s * 0.03, s * 0.9)
      ..cubicTo(s * 0.06, s * 0.75, s * 0.04, s * 0.55, s * 0.03, s * 0.3)
      ..close();
    WatercolorStyle.washFill(canvas, tailBelly, paleYellow,
        seed: 'char_tbelly', opacity: 0.25);

    // Massive tail flame.
    canvas.drawCircle(
      const Offset(0, s * 1.05),
      s * 0.18 * breathPulse,
      Paint()
        ..color = fireRed.withOpacity(0.25 * breathPulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // Outer flame.
    for (var i = 0; i < 5; i++) {
      final flicker = sin(_breathPhase * 2.5 + i * 1.3) * s * 0.02;
      final angle = (i - 2) * 0.25;
      final tipX = sin(angle) * s * 0.12 + flicker;
      final tipY = s * (1.05 + cos(angle).abs() * 0.2 + i * 0.02);
      final flame = Path()
        ..moveTo(tipX - s * 0.04, s * 0.95)
        ..quadraticBezierTo(
          tipX + flicker,
          tipY + s * 0.08,
          tipX,
          tipY + s * 0.15,
        )
        ..quadraticBezierTo(
          tipX - flicker,
          tipY + s * 0.08,
          tipX + s * 0.04,
          s * 0.95,
        )
        ..close();
      final flameColors = [
        fireRed,
        brightOrange,
        fireGold,
        brightOrange,
        fireRed,
      ];
      WatercolorStyle.washFill(canvas, flame, flameColors[i],
          seed: 'char_fl$i', opacity: 0.22);
    }
    // Bright core.
    final core = Path()
      ..moveTo(-s * 0.04, s * 1.0)
      ..lineTo(0, s * 1.18)
      ..lineTo(s * 0.04, s * 1.0)
      ..close();
    WatercolorStyle.washFill(canvas, core, const Color(0xFFFFEE88),
        seed: 'char_core', opacity: 0.25);

    // Massive bat-membrane wings with scalloped edges.
    for (final isLeft in [true, false]) {
      final sign = isLeft ? -1.0 : 1.0;

      // Wing shadow.
      final shadowWing = Path()
        ..moveTo(sign * s * 0.3, 1)
        ..cubicTo(
          sign * s * 0.7,
          flapOffset - s * 0.3 + 2,
          sign * s * 1.0,
          flapOffset - s * 0.6 + 2,
          sign * s * 1.3,
          flapOffset - s * 0.1 + 2,
        )
        ..lineTo(sign * s * 0.15, s * 0.08)
        ..close();
      canvas.drawPath(
        shadowWing,
        Paint()..color = const Color(0xFF000000).withOpacity(0.08),
      );

      // Wing membrane with 3 scalloped segments.
      final membrane = Path()..moveTo(sign * s * 0.3, -s * 0.08);
      // First finger to tip.
      membrane.lineTo(sign * s * 1.0, flapOffset - s * 0.8);
      // Scallop.
      membrane.quadraticBezierTo(
        sign * s * 0.78,
        flapOffset - s * 0.38,
        sign * s * 0.82,
        flapOffset - s * 0.35,
      );
      // Second finger.
      membrane.lineTo(sign * s * 1.3, flapOffset - s * 0.55);
      // Scallop.
      membrane.quadraticBezierTo(
        sign * s * 0.98,
        flapOffset - s * 0.18,
        sign * s * 1.0,
        flapOffset - s * 0.12,
      );
      // Third finger.
      membrane.lineTo(sign * s * 1.18, flapOffset - s * 0.18);
      // Trailing edge.
      membrane.quadraticBezierTo(
        sign * s * 0.75,
        flapOffset + s * 0.08,
        sign * s * 0.15,
        s * 0.05,
      );
      membrane.close();
      WatercolorStyle.washFill(canvas, membrane, tealWing.withOpacity(0.8),
          seed: 'char_mem');

      // Inner membrane (lighter, more translucent).
      final inner = Path()
        ..moveTo(sign * s * 0.35, -s * 0.05)
        ..lineTo(sign * s * 0.82, flapOffset - s * 0.35)
        ..lineTo(sign * s * 1.0, flapOffset - s * 0.12)
        ..quadraticBezierTo(
          sign * s * 0.6,
          flapOffset + s * 0.06,
          sign * s * 0.15,
          s * 0.03,
        )
        ..close();
      WatercolorStyle.washFill(canvas, inner, const Color(0xFF40C4B0),
          seed: 'char_inner', opacity: 0.15);
      WatercolorStyle.colorBleed(canvas, inner, const Color(0xFF40C4B0),
          opacity: 0.06);

      // Finger bones.
      final bonePaint = Paint()
        ..color = darkTeal.withOpacity(0.7)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      // Arm.
      canvas.drawLine(
        Offset(sign * s * 0.3, -s * 0.08),
        Offset(sign * s * 0.7, flapOffset - s * 0.4),
        bonePaint,
      );
      // First finger.
      canvas.drawLine(
        Offset(sign * s * 0.7, flapOffset - s * 0.4),
        Offset(sign * s * 1.0, flapOffset - s * 0.8),
        bonePaint,
      );
      // Second finger.
      canvas.drawLine(
        Offset(sign * s * 0.7, flapOffset - s * 0.4),
        Offset(sign * s * 1.3, flapOffset - s * 0.55),
        bonePaint,
      );
      // Third finger.
      canvas.drawLine(
        Offset(sign * s * 0.7, flapOffset - s * 0.4),
        Offset(sign * s * 1.18, flapOffset - s * 0.18),
        bonePaint,
      );

      // Wing claw.
      final claw = Path()
        ..moveTo(sign * s * 0.68, flapOffset - s * 0.4)
        ..lineTo(sign * s * 0.62, flapOffset - s * 0.48)
        ..lineTo(sign * s * 0.72, flapOffset - s * 0.42)
        ..close();
      WatercolorStyle.washFill(canvas, claw, hornColor, seed: 'claw');
    }

    // Powerful muscular body.
    _drawBody(
      canvas: canvas,
      width: s * 0.85,
      height: s * 0.52,
      baseColor: deepOrange,
      bellyColor: paleYellow,
    );
    // Scale chevrons on belly.
    for (var i = 0; i < 5; i++) {
      final sy = -s * 0.1 + i * s * 0.05;
      canvas.drawLine(
        Offset(-s * 0.14, sy),
        Offset(0, sy + s * 0.02),
        Paint()
          ..color = const Color(0xFFDDB870).withOpacity(0.25)
          ..strokeWidth = 0.6,
      );
      canvas.drawLine(
        Offset(0, sy + s * 0.02),
        Offset(s * 0.14, sy),
        Paint()
          ..color = const Color(0xFFDDB870).withOpacity(0.25)
          ..strokeWidth = 0.6,
      );
    }

    // Dorsal spines.
    for (var i = 0; i < 5; i++) {
      final sy = -s * 0.18 + i * s * 0.08;
      final spineHeight = s * 0.05 + (2 - (i - 2).abs()) * s * 0.01;
      final spine = Path()
        ..moveTo(-s * 0.018, sy)
        ..lineTo(0, sy - spineHeight)
        ..lineTo(s * 0.018, sy)
        ..close();
      WatercolorStyle.washFill(canvas, spine, _darken(deepOrange, 0.15),
          seed: 'char_sp');
    }

    // Powerful head with elongated snout.
    final snout = Path()
      ..moveTo(-s * 0.14, -s * 0.33)
      ..cubicTo(-s * 0.08, -s * 0.52, s * 0.08, -s * 0.52, s * 0.14, -s * 0.33)
      ..quadraticBezierTo(0, -s * 0.3, -s * 0.14, -s * 0.33);
    WatercolorStyle.washFill(canvas, snout, deepOrange, seed: 'char_snout');
    WatercolorStyle.wetEdge(canvas, snout, deepOrange, opacity: 0.15);
    // Head dome.
    final headDome = Path()
      ..addOval(Rect.fromCenter(
        center: const Offset(0, -s * 0.36),
        width: s * 0.4,
        height: s * 0.4,
      ));
    WatercolorStyle.washFill(canvas, headDome, deepOrange, seed: 'char_head');
    // Jaw underside.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, -s * 0.32),
        width: s * 0.2,
        height: s * 0.08,
      ),
      Paint()..color = paleYellow.withOpacity(0.5),
    );

    // Prominent double horns (outer long, inner short).
    for (final sign in [-1.0, 1.0]) {
      // Outer horn (long, swept).
      final outerHorn = Path()
        ..moveTo(sign * s * 0.12, -s * 0.5)
        ..cubicTo(
          sign * s * 0.2,
          -s * 0.62,
          sign * s * 0.28,
          -s * 0.75,
          sign * s * 0.22,
          -s * 0.82,
        )
        ..lineTo(sign * s * 0.08, -s * 0.54)
        ..close();
      WatercolorStyle.washFill(canvas, outerHorn, hornColor, seed: 'char_oh');
      // Horn highlight.
      canvas.drawLine(
        Offset(sign * s * 0.12, -s * 0.52),
        Offset(sign * s * 0.18, -s * 0.7),
        Paint()
          ..color = _lighten(hornColor, 0.2).withOpacity(0.5)
          ..strokeWidth = 1.0,
      );
      // Inner horn (shorter).
      final innerHorn = Path()
        ..moveTo(sign * s * 0.06, -s * 0.52)
        ..lineTo(sign * s * 0.1, -s * 0.66)
        ..lineTo(sign * s * 0.03, -s * 0.54)
        ..close();
      WatercolorStyle.washFill(canvas, innerHorn, _lighten(hornColor, 0.1),
          seed: 'char_ih');
    }

    // Fierce glowing slit eyes.
    for (final sign in [-1.0, 1.0]) {
      // Eye glow.
      canvas.drawCircle(
        Offset(sign * s * 0.08, -s * 0.4),
        s * 0.045,
        Paint()
          ..color = const Color(0xFFFFAA00).withOpacity(0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      // Iris.
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(sign * s * 0.08, -s * 0.4),
          width: s * 0.065,
          height: s * 0.05,
        ),
        Paint()..color = const Color(0xFFFFBB00),
      );
      // Slit pupil.
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(sign * s * 0.08, -s * 0.4),
          width: s * 0.015,
          height: s * 0.045,
        ),
        Paint()..color = const Color(0xFF111111),
      );
      // Eye highlight.
      canvas.drawCircle(
        Offset(sign * s * 0.065, -s * 0.41),
        s * 0.01,
        Paint()..color = const Color(0xFFFFFFFF).withOpacity(0.6),
      );
    }

    // Brow ridges (fierce expression).
    for (final sign in [-1.0, 1.0]) {
      canvas.drawLine(
        Offset(sign * s * 0.14, -s * 0.43),
        Offset(sign * s * 0.04, -s * 0.41),
        Paint()
          ..color = _darken(deepOrange, 0.2)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }

    // Open mouth with fire glow.
    final mouth = Path()
      ..moveTo(-s * 0.07, -s * 0.48)
      ..quadraticBezierTo(0, -s * 0.52, s * 0.07, -s * 0.48)
      ..quadraticBezierTo(0, -s * 0.46, -s * 0.07, -s * 0.48);
    WatercolorStyle.washFill(canvas, mouth, const Color(0xFFBB1100),
        seed: 'char_mouth');
    // Fire breath glow.
    canvas.drawCircle(
      const Offset(0, -s * 0.62),
      s * 0.1 * breathPulse,
      Paint()
        ..color = const Color(0xFFFF6600).withOpacity(0.15 * breathPulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Nostrils.
    for (final sign in [-1.0, 1.0]) {
      canvas.drawCircle(
        Offset(sign * s * 0.04, -s * 0.5),
        s * 0.012,
        Paint()..color = _darken(deepOrange, 0.3),
      );
    }
  }
}
