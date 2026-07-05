import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/models/avatar_config.dart';

/// Shared painter for the player's companion creatures.
///
/// Single source of truth used by both the in-game
/// [CompanionRenderer] component and the debug
/// `CompanionPreviewScreen` (per the shared-layer rule in CLAUDE.md).
///
/// Every companion is drawn in a TRUE TOP-DOWN view, as seen from the
/// camera above: the beak/snout extends beyond the head along the flight
/// direction (-Y), wings span +/-X, and the tail trails behind (+Y).
/// No front-view faces, no blush, no eye whites — at most two small
/// side dots for eyes. Shapes are solid fills with a subtle ~1px darker
/// outline (no blurred aura glows or soft shadows, which left dirty
/// halos over light terrain).
class CompanionArt {
  CompanionArt._();

  /// Base size unit for each species (roughly half the body length in px).
  ///
  /// These are the FIXED SCREEN-SPACE sizes used in game. They are
  /// deliberately ~2x the legacy values so the smallest companion never
  /// renders as an unreadable ~15px dot at gameplay zoom.
  static double sizeOf(AvatarCompanion type) => switch (type) {
        AvatarCompanion.none => 0,
        AvatarCompanion.pidgey => 14,
        AvatarCompanion.sparrow => 16,
        AvatarCompanion.eagle => 26,
        AvatarCompanion.parrot => 20,
        AvatarCompanion.phoenix => 24,
        AvatarCompanion.dragon => 28,
        AvatarCompanion.charizard => 32,
      };

  /// Approximate overall footprint (diameter) of the drawn art, used by
  /// preview screens to fit the companion inside a card. Species with
  /// long tails/streamers/flames need a larger multiple of [sizeOf].
  static double footprintOf(AvatarCompanion type) {
    final mult = switch (type) {
      AvatarCompanion.none => 0.0,
      AvatarCompanion.pidgey => 2.4,
      AvatarCompanion.sparrow => 2.6,
      AvatarCompanion.eagle => 3.0,
      AvatarCompanion.parrot => 3.4,
      AvatarCompanion.phoenix => 3.8,
      AvatarCompanion.dragon => 3.8,
      AvatarCompanion.charizard => 3.8,
    };
    return sizeOf(type) * mult;
  }

  /// Paint [type] centred at the canvas origin, flight direction -Y.
  ///
  /// [flapPhase] drives the wing-beat; [breathPhase] drives flame
  /// flicker on the fire species. Both are free-running radians.
  static void paint(
    Canvas canvas,
    AvatarCompanion type, {
    double flapPhase = 0.0,
    double breathPhase = 0.0,
  }) {
    final flap = sin(flapPhase);
    switch (type) {
      case AvatarCompanion.none:
        break;
      case AvatarCompanion.pidgey:
        _paintPidgey(canvas, flap);
      case AvatarCompanion.sparrow:
        _paintSparrow(canvas, flap);
      case AvatarCompanion.eagle:
        _paintEagle(canvas, flap);
      case AvatarCompanion.parrot:
        _paintParrot(canvas, flap);
      case AvatarCompanion.phoenix:
        _paintPhoenix(canvas, flap, breathPhase);
      case AvatarCompanion.dragon:
        _paintDragon(canvas, flap, breathPhase);
      case AvatarCompanion.charizard:
        _paintCharizard(canvas, flap, breathPhase);
    }
  }

  // ─── Shared helpers ─────────────────────────────────────────────────

  static Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  static Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  /// Solid fill + subtle darker outline — the shared mark-making style.
  static void _fill(
    Canvas canvas,
    Path path,
    Color color, {
    double outlineWidth = 1.0,
    double outlineDarken = 0.18,
  }) {
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = _darken(color, outlineDarken).withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = outlineWidth
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// Two tiny top-down eye dots on either side of the head.
  static void _eyeDots(Canvas canvas, double x, double y, double r) {
    final paint = Paint()..color = const Color(0xFF20180F);
    canvas.drawCircle(Offset(-x, y), r, paint);
    canvas.drawCircle(Offset(x, y), r, paint);
  }

  /// A straight, forward-pointing beak wedge. [baseY] sits inside the
  /// head; [tipY] extends beyond it along the flight direction.
  static void _beak(
    Canvas canvas,
    double halfWidth,
    double baseY,
    double tipY,
    Color color,
  ) {
    final path = Path()
      ..moveTo(-halfWidth, baseY)
      ..quadraticBezierTo(0, tipY - (baseY - tipY) * 0.12, 0, tipY)
      ..quadraticBezierTo(0, tipY - (baseY - tipY) * 0.12, halfWidth, baseY)
      ..close();
    _fill(canvas, path, color, outlineWidth: 0.7);
  }

  /// Mirrors [build] for the left (-1) and right (+1) wing, drawing the
  /// resulting paths with [draw].
  static void _mirrored(void Function(double sign) draw) {
    draw(-1);
    draw(1);
  }

  /// A three-tongue flame pointing along +[dir] (unit-ish vector), used
  /// for dragon/charizard tail tips. Flickers with [phase].
  static void _tailFlame(
    Canvas canvas,
    Offset tip,
    double size,
    double phase, {
    Color outer = const Color(0xFFE8641E),
    Color core = const Color(0xFFFFC93C),
  }) {
    final flick = sin(phase * 2.1) * size * 0.10;
    final flame = Path()
      // Left tongue.
      ..moveTo(tip.dx - size * 0.34, tip.dy - size * 0.10)
      ..quadraticBezierTo(
        tip.dx - size * 0.52,
        tip.dy + size * 0.28,
        tip.dx - size * 0.30 + flick,
        tip.dy + size * 0.52,
      )
      ..quadraticBezierTo(
        tip.dx - size * 0.16,
        tip.dy + size * 0.34,
        tip.dx - size * 0.12,
        tip.dy + size * 0.42,
      )
      // Centre tongue (longest).
      ..quadraticBezierTo(
        tip.dx - size * 0.06 - flick,
        tip.dy + size * 0.80,
        tip.dx + size * 0.02,
        tip.dy + size * 0.98,
      )
      ..quadraticBezierTo(
        tip.dx + size * 0.12,
        tip.dy + size * 0.50,
        tip.dx + size * 0.15,
        tip.dy + size * 0.40,
      )
      // Right tongue.
      ..quadraticBezierTo(
        tip.dx + size * 0.34 - flick,
        tip.dy + size * 0.58,
        tip.dx + size * 0.38,
        tip.dy + size * 0.30,
      )
      ..quadraticBezierTo(
        tip.dx + size * 0.40,
        tip.dy + size * 0.02,
        tip.dx + size * 0.30,
        tip.dy - size * 0.12,
      )
      ..close();
    _fill(canvas, flame, outer, outlineWidth: 0.8, outlineDarken: 0.12);
    // Hot core.
    final corePath = Path()
      ..moveTo(tip.dx - size * 0.10, tip.dy)
      ..quadraticBezierTo(
        tip.dx - size * 0.14,
        tip.dy + size * 0.30,
        tip.dx + size * 0.00 + flick * 0.5,
        tip.dy + size * 0.58,
      )
      ..quadraticBezierTo(
        tip.dx + size * 0.16,
        tip.dy + size * 0.26,
        tip.dx + size * 0.12,
        tip.dy - size * 0.02,
      )
      ..close();
    canvas.drawPath(corePath, Paint()..color = core);
  }

  // ─── Pidgey — plump little garden bird ──────────────────────────────
  //
  // Silhouette: chubby round body, short ROUNDED paddle wings, small
  // three-feather fan tail. Reads as "cute and small" purely from shape.
  static void _paintPidgey(Canvas canvas, double flap) {
    const s = 14.0;
    const brown = Color(0xFF9E7B5A);
    const darkBrown = Color(0xFF6B5238);
    const cream = Color(0xFFF0E2C8);

    // Tail — three short rounded feathers fanning behind.
    for (var i = -1; i <= 1; i++) {
      final angle = i * 0.42;
      final dirX = sin(angle);
      final dirY = cos(angle);
      final tipX = dirX * s * 0.62;
      final tipY = s * 0.30 + dirY * s * 0.48;
      final perpX = dirY * s * 0.09;
      final perpY = -dirX * s * 0.09;
      final feather = Path()
        ..moveTo(-perpX, s * 0.30 - perpY)
        ..quadraticBezierTo(
          tipX - perpX * 1.2,
          tipY - perpY * 1.2,
          tipX,
          tipY,
        )
        ..quadraticBezierTo(
          tipX + perpX * 1.2,
          tipY + perpY * 1.2,
          perpX,
          s * 0.30 + perpY,
        )
        ..close();
      _fill(canvas, feather, i == 0 ? darkBrown : _lighten(darkBrown, 0.06),
          outlineWidth: 0.8);
    }

    // Wings — stubby rounded paddles (clearly wings, not arms).
    final dy = flap * s * 0.14;
    _mirrored((sign) {
      final wing = Path()
        ..moveTo(sign * s * 0.22, -s * 0.18)
        ..cubicTo(
          sign * s * 0.62,
          -s * 0.34 + dy,
          sign * s * 1.06,
          -s * 0.26 + dy,
          sign * s * 1.08,
          s * 0.02 + dy,
        )
        ..cubicTo(
          sign * s * 1.02,
          s * 0.26 + dy,
          sign * s * 0.62,
          s * 0.32,
          sign * s * 0.24,
          s * 0.22,
        )
        ..close();
      _fill(canvas, wing, brown);
      // Cream wing-bar arc near the tip.
      final bar = Path()
        ..moveTo(sign * s * 0.72, -s * 0.24 + dy)
        ..quadraticBezierTo(
          sign * s * 0.94,
          -s * 0.16 + dy,
          sign * s * 0.96,
          s * 0.06 + dy,
        );
      canvas.drawPath(
        bar,
        Paint()
          ..color = cream.withOpacity(0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.09
          ..strokeCap = StrokeCap.round,
      );
    });

    // Plump body.
    final body = Path()
      ..addOval(Rect.fromCenter(
        center: const Offset(0, s * 0.02),
        width: s * 0.92,
        height: s * 1.04,
      ));
    _fill(canvas, body, _lighten(brown, 0.05));
    // Lighter mantle down the back.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, s * 0.10),
        width: s * 0.46,
        height: s * 0.62,
      ),
      Paint()..color = _lighten(brown, 0.14).withOpacity(0.8),
    );

    // Head — merges into the body, slightly forward.
    final head = Path()
      ..addOval(Rect.fromCircle(
        center: const Offset(0, -s * 0.44),
        radius: s * 0.36,
      ));
    _fill(canvas, head, _lighten(brown, 0.08));

    // Beak pokes out BEYOND the head, along flight direction.
    _beak(canvas, s * 0.09, -s * 0.70, -s * 0.94, const Color(0xFFE8962A));

    // Two tiny side eyes.
    _eyeDots(canvas, s * 0.16, -s * 0.52, s * 0.05);
  }

  // ─── Sparrow — swept-wing barn swallow ──────────────────────────────
  //
  // Silhouette: scythe wings swept back to sharp points + a wide, deep
  // swallow tail-fork angled outward (unmistakably a tail, not legs).
  static void _paintSparrow(Canvas canvas, double flap) {
    const s = 16.0;
    const navy = Color(0xFF41578A);
    const darkNavy = Color(0xFF24345C);
    const russet = Color(0xFFB85C38);

    // Tail fork — two slim prongs diverging back and OUT.
    _mirrored((sign) {
      final prong = Path()
        ..moveTo(sign * s * 0.03, s * 0.30)
        ..quadraticBezierTo(
          sign * s * 0.22,
          s * 0.66,
          sign * s * 0.40,
          s * 1.06,
        )
        ..quadraticBezierTo(
          sign * s * 0.18,
          s * 0.82,
          sign * s * 0.13,
          s * 0.52,
        )
        ..lineTo(0, s * 0.34)
        ..close();
      _fill(canvas, prong, darkNavy, outlineWidth: 0.8);
    });

    // Scythe wings — long, pointed, swept back.
    final dy = flap * s * 0.16;
    _mirrored((sign) {
      final wing = Path()
        ..moveTo(sign * s * 0.12, -s * 0.20)
        // Leading edge: out and slightly forward, then sweeping back.
        ..cubicTo(
          sign * s * 0.55,
          -s * 0.42 + dy,
          sign * s * 0.95,
          -s * 0.30 + dy,
          sign * s * 1.18,
          s * 0.42 + dy * 0.6,
        )
        // Trailing edge: concave curve back to the body.
        ..cubicTo(
          sign * s * 0.80,
          s * 0.10 + dy * 0.5,
          sign * s * 0.45,
          s * 0.12,
          sign * s * 0.12,
          s * 0.16,
        )
        ..close();
      _fill(canvas, wing, navy);
      // Darker primary tip.
      final tip = Path()
        ..moveTo(sign * s * 0.88, -s * 0.06 + dy * 0.8)
        ..cubicTo(
          sign * s * 1.02,
          s * 0.06 + dy * 0.7,
          sign * s * 1.12,
          s * 0.24 + dy * 0.6,
          sign * s * 1.18,
          s * 0.42 + dy * 0.6,
        )
        ..cubicTo(
          sign * s * 1.00,
          s * 0.20 + dy * 0.6,
          sign * s * 0.90,
          s * 0.08 + dy * 0.7,
          sign * s * 0.80,
          s * 0.02 + dy * 0.8,
        )
        ..close();
      canvas.drawPath(tip, Paint()..color = darkNavy);
    });

    // Slim teardrop body.
    final body = Path()
      ..moveTo(0, -s * 0.58)
      ..cubicTo(s * 0.24, -s * 0.44, s * 0.24, -s * 0.10, s * 0.16, s * 0.16)
      ..quadraticBezierTo(s * 0.08, s * 0.40, 0, s * 0.44)
      ..quadraticBezierTo(-s * 0.08, s * 0.40, -s * 0.16, s * 0.16)
      ..cubicTo(-s * 0.24, -s * 0.10, -s * 0.24, -s * 0.44, 0, -s * 0.58)
      ..close();
    _fill(canvas, body, navy);
    // Lighter sheen down the back.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, -s * 0.10),
        width: s * 0.18,
        height: s * 0.52,
      ),
      Paint()..color = _lighten(navy, 0.10).withOpacity(0.9),
    );
    // Russet chin patch just behind the beak.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, -s * 0.44),
        width: s * 0.20,
        height: s * 0.14,
      ),
      Paint()..color = russet,
    );

    // Small sharp beak beyond the nose.
    _beak(canvas, s * 0.06, -s * 0.52, -s * 0.74, const Color(0xFF2A2A2A));

    // Tiny side eyes.
    _eyeDots(canvas, s * 0.11, -s * 0.38, s * 0.04);
  }

  // ─── Eagle — soaring raptor ─────────────────────────────────────────
  //
  // Silhouette: long rectangular plank wings with slotted "finger"
  // primaries, white FAN tail, white head with gold hooked beak.
  static void _paintEagle(Canvas canvas, double flap) {
    const s = 26.0;
    const darkBrown = Color(0xFF4A3626);
    const midBrown = Color(0xFF6E5238);
    const white = Color(0xFFF2EDE2);
    const gold = Color(0xFFE0A62D);

    // White fan tail — trapezoid fan with feather splits.
    final tail = Path()
      ..moveTo(-s * 0.12, s * 0.34)
      ..lineTo(-s * 0.34, s * 0.88)
      ..quadraticBezierTo(0, s * 1.02, s * 0.34, s * 0.88)
      ..lineTo(s * 0.12, s * 0.34)
      ..close();
    _fill(canvas, tail, white, outlineDarken: 0.22);
    for (var i = -1; i <= 1; i++) {
      canvas.drawLine(
        Offset(i * s * 0.05, s * 0.44),
        Offset(i * s * 0.17, s * 0.88),
        Paint()
          ..color = const Color(0xFFC9C2B2)
          ..strokeWidth = 0.9,
      );
    }

    // Plank wings with 5 slotted finger feathers.
    final dy = flap * s * 0.09;
    _mirrored((sign) {
      final wing = Path()
        ..moveTo(sign * s * 0.16, -s * 0.28)
        // Leading edge — nearly straight, slight forward bow.
        ..cubicTo(
          sign * s * 0.55,
          -s * 0.38 + dy,
          sign * s * 0.95,
          -s * 0.36 + dy,
          sign * s * 1.30,
          -s * 0.26 + dy,
        );
      // Finger feathers: 5 tapered tips with notches between.
      const tips = [
        Offset(1.38, -0.12),
        Offset(1.33, 0.02),
        Offset(1.24, 0.14),
        Offset(1.12, 0.24),
        Offset(0.98, 0.31),
      ];
      const notches = [
        Offset(1.22, -0.10),
        Offset(1.14, 0.02),
        Offset(1.04, 0.13),
        Offset(0.92, 0.21),
      ];
      for (var i = 0; i < tips.length; i++) {
        wing.lineTo(sign * s * tips[i].dx, s * tips[i].dy + dy);
        if (i < notches.length) {
          wing.lineTo(sign * s * notches[i].dx, s * notches[i].dy + dy);
        }
      }
      // Trailing edge — gentle concave back to the body.
      wing
        ..cubicTo(
          sign * s * 0.70,
          s * 0.34 + dy * 0.5,
          sign * s * 0.40,
          s * 0.30,
          sign * s * 0.16,
          s * 0.26,
        )
        ..close();
      _fill(canvas, wing, darkBrown, outlineWidth: 1.1);
      // Lighter covert band along the leading half.
      final coverts = Path()
        ..moveTo(sign * s * 0.20, -s * 0.24)
        ..cubicTo(
          sign * s * 0.55,
          -s * 0.33 + dy,
          sign * s * 0.95,
          -s * 0.31 + dy,
          sign * s * 1.22,
          -s * 0.22 + dy,
        )
        ..lineTo(sign * s * 1.16, -s * 0.10 + dy)
        ..cubicTo(
          sign * s * 0.90,
          -s * 0.18 + dy,
          sign * s * 0.55,
          -s * 0.20 + dy * 0.5,
          sign * s * 0.22,
          -s * 0.10,
        )
        ..close();
      canvas.drawPath(coverts, Paint()..color = midBrown.withOpacity(0.9));
    });

    // Broad body.
    final body = Path()
      ..addOval(Rect.fromCenter(
        center: const Offset(0, s * 0.02),
        width: s * 0.56,
        height: s * 0.98,
      ));
    _fill(canvas, body, darkBrown, outlineWidth: 1.1);

    // White head + neck, extending forward of the wings.
    final head = Path()
      ..moveTo(-s * 0.20, -s * 0.28)
      ..quadraticBezierTo(-s * 0.24, -s * 0.62, -s * 0.13, -s * 0.76)
      ..quadraticBezierTo(0, -s * 0.84, s * 0.13, -s * 0.76)
      ..quadraticBezierTo(s * 0.24, -s * 0.62, s * 0.20, -s * 0.28)
      ..quadraticBezierTo(0, -s * 0.20, -s * 0.20, -s * 0.28)
      ..close();
    _fill(canvas, head, white, outlineDarken: 0.22);

    // Gold hooked beak, tip curling beyond the head.
    final beak = Path()
      ..moveTo(-s * 0.08, -s * 0.74)
      ..quadraticBezierTo(-s * 0.06, -s * 0.90, 0, -s * 1.00)
      ..quadraticBezierTo(s * 0.07, -s * 0.92, s * 0.08, -s * 0.74)
      ..quadraticBezierTo(0, -s * 0.80, -s * 0.08, -s * 0.74)
      ..close();
    _fill(canvas, beak, gold, outlineWidth: 0.8);
    // Darker hook tip.
    canvas.drawCircle(
      const Offset(0, -s * 0.99),
      s * 0.035,
      Paint()..color = const Color(0xFF8A6212),
    );

    // Two small top-down eyes.
    _eyeDots(canvas, s * 0.11, -s * 0.62, s * 0.045);
  }

  // ─── Parrot — scarlet macaw ─────────────────────────────────────────
  //
  // Silhouette: oversized head with big black hooked beak + one long
  // red tail streamer. Blue flight feathers on rounded wings.
  static void _paintParrot(Canvas canvas, double flap) {
    const s = 20.0;
    const scarlet = Color(0xFFD93A2B);
    const royalBlue = Color(0xFF2450A8);
    const gold = Color(0xFFF0B429);

    // Long central tail streamer (signature) + two shorter blue sides.
    _mirrored((sign) {
      final side = Path()
        ..moveTo(sign * s * 0.05, s * 0.30)
        ..quadraticBezierTo(
          sign * s * 0.20,
          s * 0.66,
          sign * s * 0.17,
          s * 1.02,
        )
        ..quadraticBezierTo(
          sign * s * 0.06,
          s * 0.70,
          0,
          s * 0.36,
        )
        ..close();
      _fill(canvas, side, royalBlue, outlineWidth: 0.8);
    });
    final streamer = Path()
      ..moveTo(-s * 0.08, s * 0.28)
      ..quadraticBezierTo(-s * 0.06, s * 0.90, -s * 0.015, s * 1.52)
      ..quadraticBezierTo(0, s * 1.58, s * 0.015, s * 1.52)
      ..quadraticBezierTo(s * 0.06, s * 0.90, s * 0.08, s * 0.28)
      ..close();
    _fill(canvas, streamer, scarlet, outlineWidth: 0.8);

    // Rounded wings — scarlet shoulders, blue flight feathers.
    final dy = flap * s * 0.13;
    _mirrored((sign) {
      final wing = Path()
        ..moveTo(sign * s * 0.18, -s * 0.16)
        ..cubicTo(
          sign * s * 0.58,
          -s * 0.34 + dy,
          sign * s * 0.98,
          -s * 0.26 + dy,
          sign * s * 1.06,
          s * 0.02 + dy,
        )
        ..cubicTo(
          sign * s * 1.00,
          s * 0.30 + dy,
          sign * s * 0.60,
          s * 0.36,
          sign * s * 0.20,
          s * 0.24,
        )
        ..close();
      _fill(canvas, wing, scarlet);
      // Blue outer flight feathers (outer half only — red shoulder shows).
      final blues = Path()
        ..moveTo(sign * s * 0.74, -s * 0.28 + dy)
        ..cubicTo(
          sign * s * 0.96,
          -s * 0.22 + dy,
          sign * s * 1.05,
          -s * 0.06 + dy,
          sign * s * 1.06,
          s * 0.02 + dy,
        )
        ..cubicTo(
          sign * s * 1.00,
          s * 0.30 + dy,
          sign * s * 0.68,
          s * 0.34,
          sign * s * 0.56,
          s * 0.30,
        )
        ..quadraticBezierTo(
          sign * s * 0.76,
          s * 0.00 + dy * 0.5,
          sign * s * 0.74,
          -s * 0.28 + dy,
        )
        ..close();
      canvas.drawPath(blues, Paint()..color = royalBlue);
      // Bold gold band between red coverts and blue flight feathers.
      final band = Path()
        ..moveTo(sign * s * 0.66, -s * 0.28 + dy)
        ..quadraticBezierTo(
          sign * s * 0.70,
          s * 0.00 + dy * 0.5,
          sign * s * 0.52,
          s * 0.28,
        );
      canvas.drawPath(
        band,
        Paint()
          ..color = gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.09
          ..strokeCap = StrokeCap.round,
      );
    });

    // Body.
    final body = Path()
      ..addOval(Rect.fromCenter(
        center: const Offset(0, s * 0.00),
        width: s * 0.70,
        height: s * 0.92,
      ));
    _fill(canvas, body, scarlet);

    // Oversized head (macaw cue #1).
    final head = Path()
      ..addOval(Rect.fromCircle(
        center: const Offset(0, -s * 0.52),
        radius: s * 0.40,
      ));
    _fill(canvas, head, _lighten(scarlet, 0.04));

    // Big black hooked beak, extending well beyond the head (cue #2).
    final beak = Path()
      ..moveTo(-s * 0.13, -s * 0.82)
      ..quadraticBezierTo(-s * 0.12, -s * 1.06, 0, -s * 1.18)
      ..quadraticBezierTo(s * 0.11, -s * 1.08, s * 0.13, -s * 0.82)
      ..quadraticBezierTo(0, -s * 0.90, -s * 0.13, -s * 0.82)
      ..close();
    _fill(canvas, beak, const Color(0xFF26221E), outlineDarken: 0.0);
    // Pale cere line where beak meets head.
    canvas.drawLine(
      const Offset(-s * 0.11, -s * 0.83),
      const Offset(s * 0.11, -s * 0.83),
      Paint()
        ..color = const Color(0xFFE8DFD2).withOpacity(0.7)
        ..strokeWidth = 1.0,
    );

    // Side eyes.
    _eyeDots(canvas, s * 0.17, -s * 0.60, s * 0.05);
  }

  // ─── Phoenix — mythical fire bird ───────────────────────────────────
  //
  // Silhouette: flame-lick wings + three sinuous fire streamers trailing
  // behind. The trail is the signature — kept from the original design.
  static void _paintPhoenix(Canvas canvas, double flap, double breath) {
    const s = 24.0;
    const deepOrange = Color(0xFFE05A10);
    const brightOrange = Color(0xFFFF8C22);
    const gold = Color(0xFFFFC93C);
    const crimson = Color(0xFFB81F0E);

    // Three trailing flame streamers, flickering.
    final streamers = [
      (x: -0.24, len: 1.10, color: crimson),
      (x: 0.0, len: 1.55, color: deepOrange),
      (x: 0.24, len: 1.10, color: brightOrange),
    ];
    for (var i = 0; i < streamers.length; i++) {
      final st = streamers[i];
      final wave = sin(breath * 1.8 + i * 2.1) * s * 0.08;
      final path = Path()
        ..moveTo(s * st.x * 0.35 - s * 0.06, s * 0.26)
        ..cubicTo(
          s * st.x * 0.8 - s * 0.06 + wave,
          s * (0.30 + st.len * 0.35),
          s * st.x * 1.3 - s * 0.04 - wave,
          s * (0.30 + st.len * 0.7),
          s * st.x * 1.15 + wave * 0.6,
          s * (0.26 + st.len),
        )
        ..cubicTo(
          s * st.x * 1.5 - wave,
          s * (0.30 + st.len * 0.65),
          s * st.x * 1.0 + s * 0.06 + wave,
          s * (0.30 + st.len * 0.32),
          s * st.x * 0.35 + s * 0.06,
          s * 0.26,
        )
        ..close();
      _fill(canvas, path, st.color, outlineWidth: 0.8, outlineDarken: 0.10);
    }
    // Gold cores inside the centre streamer.
    final coreWave = sin(breath * 1.8 + 2.1) * s * 0.05;
    final core = Path()
      ..moveTo(-s * 0.035, s * 0.28)
      ..quadraticBezierTo(
        coreWave,
        s * 0.85,
        coreWave * 1.4,
        s * 1.30,
      )
      ..quadraticBezierTo(
        s * 0.05 + coreWave,
        s * 0.80,
        s * 0.035,
        s * 0.28,
      )
      ..close();
    canvas.drawPath(core, Paint()..color = gold.withOpacity(0.9));

    // Flame wings — swept, trailing edge broken into flame licks.
    final dy = flap * s * 0.13;
    _mirrored((sign) {
      final wing = Path()
        ..moveTo(sign * s * 0.14, -s * 0.22)
        ..cubicTo(
          sign * s * 0.55,
          -s * 0.48 + dy,
          sign * s * 0.95,
          -s * 0.46 + dy,
          sign * s * 1.22,
          -s * 0.24 + dy,
        )
        // Flame licks along the trailing edge, tips flicking outward.
        ..quadraticBezierTo(
          sign * s * 1.02,
          -s * 0.12 + dy,
          sign * s * 1.06,
          s * 0.10 + dy * 0.7,
        )
        ..quadraticBezierTo(
          sign * s * 0.86,
          s * 0.02 + dy * 0.6,
          sign * s * 0.76,
          s * 0.26 + dy * 0.4,
        )
        ..quadraticBezierTo(
          sign * s * 0.56,
          s * 0.12,
          sign * s * 0.42,
          s * 0.32,
        )
        ..quadraticBezierTo(
          sign * s * 0.26,
          s * 0.18,
          sign * s * 0.14,
          s * 0.20,
        )
        ..close();
      _fill(canvas, wing, deepOrange, outlineDarken: 0.12);
      // Gold inner band.
      final inner = Path()
        ..moveTo(sign * s * 0.18, -s * 0.16)
        ..cubicTo(
          sign * s * 0.50,
          -s * 0.36 + dy,
          sign * s * 0.85,
          -s * 0.34 + dy,
          sign * s * 1.06,
          -s * 0.20 + dy,
        )
        ..quadraticBezierTo(
          sign * s * 0.70,
          -s * 0.16 + dy * 0.5,
          sign * s * 0.30,
          s * 0.02,
        )
        ..close();
      canvas.drawPath(inner, Paint()..color = gold.withOpacity(0.75));
      // Crimson wing tip.
      final tipAccent = Path()
        ..moveTo(sign * s * 1.02, -s * 0.34 + dy)
        ..quadraticBezierTo(
          sign * s * 1.18,
          -s * 0.28 + dy,
          sign * s * 1.22,
          -s * 0.24 + dy,
        )
        ..quadraticBezierTo(
          sign * s * 1.08,
          -s * 0.14 + dy,
          sign * s * 1.00,
          -s * 0.16 + dy,
        )
        ..close();
      canvas.drawPath(tipAccent, Paint()..color = crimson.withOpacity(0.85));
    });

    // Slender body.
    final body = Path()
      ..moveTo(0, -s * 0.52)
      ..cubicTo(s * 0.22, -s * 0.36, s * 0.24, s * 0.02, s * 0.12, s * 0.30)
      ..quadraticBezierTo(0, s * 0.40, -s * 0.12, s * 0.30)
      ..cubicTo(-s * 0.24, s * 0.02, -s * 0.22, -s * 0.36, 0, -s * 0.52)
      ..close();
    _fill(canvas, body, brightOrange, outlineDarken: 0.14);
    // Pale gold core down the back.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, -s * 0.06),
        width: s * 0.16,
        height: s * 0.52,
      ),
      Paint()..color = const Color(0xFFFFE8A0).withOpacity(0.9),
    );

    // Two thin crest plumes trailing back alongside the body.
    _mirrored((sign) {
      final wave = sin(breath * 2.2) * s * 0.03;
      final plume = Path()
        ..moveTo(sign * s * 0.08, -s * 0.48)
        ..quadraticBezierTo(
          sign * s * 0.22 + wave,
          -s * 0.30,
          sign * s * 0.26 + wave,
          -s * 0.06,
        );
      canvas.drawPath(
        plume,
        Paint()
          ..color = gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.05
          ..strokeCap = StrokeCap.round,
      );
    });

    // Small gold beak beyond the head.
    _beak(canvas, s * 0.06, -s * 0.46, -s * 0.66, const Color(0xFFD98A12));

    // Side eyes.
    _eyeDots(canvas, s * 0.09, -s * 0.36, s * 0.035);
  }

  // ─── Dragon geometry shared with Charizard ──────────────────────────

  /// Draws one bat-style membrane wing. Bones are curved paths that
  /// TERMINATE at the membrane's scallop points; trailing edge scallops
  /// curve inward between them.
  static void _membraneWing(
    Canvas canvas,
    double sign,
    double s, {
    required Offset shoulder,
    required Offset wrist,
    required Offset tip,
    required Offset p2,
    required Offset p3,
    required Offset root,
    required Color membrane,
    required Color bone,
    required Color limb,
    double dy = 0,
    bool wristClaw = false,
  }) {
    Offset pt(Offset o, [double f = 1]) =>
        Offset(sign * s * o.dx, s * o.dy + dy * f);

    final sh = pt(shoulder, 0.2);
    final wr = pt(wrist);
    final tp = pt(tip);
    final m2 = pt(p2, 0.7);
    final m3 = pt(p3, 0.4);
    final rt = pt(root, 0.0);

    // Membrane outline: leading edge along arm + finger, then scalloped
    // trailing edge back to the body.
    final wing = Path()
      ..moveTo(sh.dx, sh.dy)
      // Arm: shoulder → wrist, bowed slightly forward.
      ..quadraticBezierTo(
        (sh.dx + wr.dx) / 2 + sign * s * 0.02,
        (sh.dy + wr.dy) / 2 - s * 0.10,
        wr.dx,
        wr.dy,
      )
      // Leading finger: wrist → wing tip.
      ..quadraticBezierTo(
        (wr.dx + tp.dx) / 2 + sign * s * 0.03,
        (wr.dy + tp.dy) / 2 - s * 0.08,
        tp.dx,
        tp.dy,
      )
      // Scallop 1: tip → p2 (concave toward body).
      ..quadraticBezierTo(
        (tp.dx + m2.dx) / 2 - sign * s * 0.14,
        (tp.dy + m2.dy) / 2 - s * 0.06,
        m2.dx,
        m2.dy,
      )
      // Scallop 2: p2 → p3.
      ..quadraticBezierTo(
        (m2.dx + m3.dx) / 2 - sign * s * 0.10,
        (m2.dy + m3.dy) / 2 - s * 0.05,
        m3.dx,
        m3.dy,
      )
      // Scallop 3: p3 → root.
      ..quadraticBezierTo(
        (m3.dx + rt.dx) / 2 - sign * s * 0.06,
        (m3.dy + rt.dy) / 2 - s * 0.04,
        rt.dx,
        rt.dy,
      )
      ..close();
    _fill(canvas, wing, membrane, outlineWidth: 1.1, outlineDarken: 0.22);

    // Bones: curved strokes from the wrist, ENDING at membrane points.
    final bonePaint = Paint()
      ..color = bone
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.05
      ..strokeCap = StrokeCap.round;
    for (final end in [m2, m3]) {
      final boneCurve = Path()
        ..moveTo(wr.dx, wr.dy)
        ..quadraticBezierTo(
          (wr.dx + end.dx) / 2 + sign * s * 0.04,
          (wr.dy + end.dy) / 2 - s * 0.04,
          end.dx,
          end.dy,
        );
      canvas.drawPath(boneCurve, bonePaint);
    }
    // Arm limb on top of the membrane (thicker, body-coloured).
    final arm = Path()
      ..moveTo(sh.dx, sh.dy)
      ..quadraticBezierTo(
        (sh.dx + wr.dx) / 2 + sign * s * 0.02,
        (sh.dy + wr.dy) / 2 - s * 0.09,
        wr.dx,
        wr.dy,
      );
    canvas.drawPath(
      arm,
      Paint()
        ..color = limb
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.09
        ..strokeCap = StrokeCap.round,
    );
    if (wristClaw) {
      final claw = Path()
        ..moveTo(wr.dx - sign * s * 0.03, wr.dy + s * 0.02)
        ..lineTo(wr.dx + sign * s * 0.05, wr.dy - s * 0.14)
        ..lineTo(wr.dx + sign * s * 0.08, wr.dy + s * 0.02)
        ..close();
      _fill(canvas, claw, const Color(0xFFE8DFD2), outlineWidth: 0.7);
    }
  }

  /// Draws a sinuous S-curve tail as a tapering ribbon, returning the
  /// tip position (where the flame goes).
  static Offset _sinuousTail(
    Canvas canvas,
    double s,
    Color color, {
    required double rootY,
    required double length,
    required double rootWidth,
    double sway = 1.0,
  }) {
    // Centreline: root → S bend → tip.
    final tipY = rootY + length;
    final tip = Offset(sway * s * 0.10, s * tipY);
    final tail = Path()
      ..moveTo(-s * rootWidth, s * rootY)
      // Left/outer side.
      ..cubicTo(
        -s * rootWidth * 0.6 + sway * s * 0.18,
        s * (rootY + length * 0.35),
        -s * rootWidth * 0.4 - sway * s * 0.20,
        s * (rootY + length * 0.72),
        tip.dx,
        tip.dy,
      )
      // Right/inner side back up.
      ..cubicTo(
        s * rootWidth * 0.3 - sway * s * 0.10,
        s * (rootY + length * 0.68),
        s * rootWidth * 0.5 + sway * s * 0.22,
        s * (rootY + length * 0.33),
        s * rootWidth,
        s * rootY,
      )
      ..close();
    _fill(canvas, tail, color, outlineDarken: 0.20);
    return tip;
  }

  // ─── Dragon — green forest wyvern ───────────────────────────────────
  //
  // Silhouette: curved bat membrane wings with scalloped trailing edge,
  // swept-back horns, sinuous S tail ending in a three-tongue flame.
  static void _paintDragon(Canvas canvas, double flap, double breath) {
    const s = 28.0;
    const bodyGreen = Color(0xFF3A7A48);
    const darkGreen = Color(0xFF1E4A2C);
    const membraneGreen = Color(0xFF5FA36A);
    const hornBone = Color(0xFFCBBFA4);

    // Sinuous tail with flame tip (drawn first, behind body).
    final tailTip = _sinuousTail(
      canvas,
      s,
      bodyGreen,
      rootY: 0.30,
      length: 0.95,
      rootWidth: 0.10,
      sway: 1.0,
    );
    _tailFlame(canvas, tailTip, s * 0.42, breath);

    // Membrane wings.
    final dy = flap * s * 0.10;
    _mirrored((sign) {
      _membraneWing(
        canvas,
        sign,
        s,
        shoulder: const Offset(0.18, -0.16),
        wrist: const Offset(0.72, -0.44),
        tip: const Offset(1.28, -0.52),
        p2: const Offset(1.02, 0.04),
        p3: const Offset(0.66, 0.30),
        root: const Offset(0.14, 0.26),
        membrane: membraneGreen,
        bone: darkGreen,
        limb: bodyGreen,
        dy: dy,
      );
    });

    // Slim body.
    final body = Path()
      ..addOval(Rect.fromCenter(
        center: const Offset(0, s * 0.00),
        width: s * 0.48,
        height: s * 0.94,
      ));
    _fill(canvas, body, bodyGreen, outlineWidth: 1.1);
    // Dorsal spines down the back.
    for (var i = 0; i < 4; i++) {
      final sy = -s * 0.22 + i * s * 0.16;
      final spine = Path()
        ..moveTo(-s * 0.045, sy)
        ..lineTo(0, sy - s * 0.07)
        ..lineTo(s * 0.045, sy)
        ..close();
      canvas.drawPath(spine, Paint()..color = darkGreen);
    }

    // Neck + head + snout as one continuous shape (no seam lines).
    const headY = -s * 0.58;
    final head = Path()
      ..moveTo(-s * 0.14, -s * 0.32)
      // Left side of neck up to the skull.
      ..cubicTo(
        -s * 0.17,
        headY + s * 0.10,
        -s * 0.19,
        headY - s * 0.02,
        -s * 0.13,
        headY - s * 0.12,
      )
      // Left side of snout to the nose tip.
      ..quadraticBezierTo(-s * 0.07, headY - s * 0.28, 0, headY - s * 0.34)
      // Right side mirrored.
      ..quadraticBezierTo(
          s * 0.07, headY - s * 0.28, s * 0.13, headY - s * 0.12)
      ..cubicTo(
        s * 0.19,
        headY - s * 0.02,
        s * 0.17,
        headY + s * 0.10,
        s * 0.14,
        -s * 0.32,
      )
      ..close();
    _fill(canvas, head, bodyGreen, outlineWidth: 1.0);
    // Lighter snout stripe.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, headY - s * 0.18),
        width: s * 0.10,
        height: s * 0.24,
      ),
      Paint()..color = _lighten(bodyGreen, 0.08),
    );

    // Horns — solid backswept spikes ON TOP of the skull, protruding
    // clearly beyond its silhouette.
    _mirrored((sign) {
      final horn = Path()
        ..moveTo(sign * s * 0.05, headY - s * 0.04)
        ..quadraticBezierTo(
          sign * s * 0.20,
          headY + s * 0.02,
          sign * s * 0.34,
          headY + s * 0.26,
        )
        ..lineTo(sign * s * 0.12, headY + s * 0.10)
        ..close();
      _fill(canvas, horn, hornBone, outlineWidth: 0.9, outlineDarken: 0.30);
    });

    // Small dark eye dots on the sides of the skull.
    _eyeDots(canvas, s * 0.10, headY - s * 0.10, s * 0.035);
  }

  // ─── Charizard — the flame lizard, legendary tier ───────────────────
  //
  // NOT a dragon recolour: bulkier build, broader teal membrane wings
  // with a wrist claw, longer blunt horns, thicker tail, bigger flame.
  static void _paintCharizard(Canvas canvas, double flap, double breath) {
    const s = 32.0;
    const orange = Color(0xFFE07020);
    const darkOrange = Color(0xFFA84E12);
    const teal = Color(0xFF2E8B8B);
    const darkTeal = Color(0xFF175C5C);
    const cream = Color(0xFFF2E3B8);

    // Thick sinuous tail, swaying opposite to the dragon's, with a big
    // three-tongue flame.
    final tailTip = _sinuousTail(
      canvas,
      s,
      orange,
      rootY: 0.32,
      length: 1.00,
      rootWidth: 0.13,
      sway: -1.0,
    );
    _tailFlame(canvas, tailTip, s * 0.52, breath + 1.3);

    // Broad teal membrane wings with wrist claws.
    final dy = flap * s * 0.10;
    _mirrored((sign) {
      _membraneWing(
        canvas,
        sign,
        s,
        shoulder: const Offset(0.24, -0.12),
        wrist: const Offset(0.66, -0.52),
        tip: const Offset(1.42, -0.30),
        p2: const Offset(1.08, 0.24),
        p3: const Offset(0.58, 0.40),
        root: const Offset(0.18, 0.30),
        membrane: teal,
        bone: darkTeal,
        limb: orange,
        dy: dy,
        wristClaw: true,
      );
    });

    // Bulky body (visibly wider than the dragon's).
    final body = Path()
      ..addOval(Rect.fromCenter(
        center: const Offset(0, s * 0.02),
        width: s * 0.66,
        height: s * 1.00,
      ));
    _fill(canvas, body, orange, outlineWidth: 1.2);
    // Darker shoulder shading.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, -s * 0.16),
        width: s * 0.52,
        height: s * 0.34,
      ),
      Paint()..color = darkOrange.withOpacity(0.35),
    );
    // Cream nape stripe hinting at the belly colour.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, s * 0.20),
        width: s * 0.24,
        height: s * 0.46,
      ),
      Paint()..color = cream.withOpacity(0.55),
    );

    // Neck + broad head + blunt snout as one continuous shape.
    const headY = -s * 0.56;
    final head = Path()
      ..moveTo(-s * 0.18, -s * 0.28)
      ..cubicTo(
        -s * 0.22,
        headY + s * 0.12,
        -s * 0.25,
        headY - s * 0.02,
        -s * 0.17,
        headY - s * 0.16,
      )
      ..quadraticBezierTo(-s * 0.10, headY - s * 0.34, 0, headY - s * 0.38)
      ..quadraticBezierTo(
          s * 0.10, headY - s * 0.34, s * 0.17, headY - s * 0.16)
      ..cubicTo(
        s * 0.25,
        headY - s * 0.02,
        s * 0.22,
        headY + s * 0.12,
        s * 0.18,
        -s * 0.28,
      )
      ..close();
    _fill(canvas, head, orange, outlineWidth: 1.1);
    // Lighter muzzle patch.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, headY - s * 0.22),
        width: s * 0.14,
        height: s * 0.24,
      ),
      Paint()..color = _lighten(orange, 0.08),
    );

    // Two LONG blunt horns sweeping far back (charizard cue), drawn ON
    // TOP of the skull and protruding well beyond it.
    _mirrored((sign) {
      final horn = Path()
        ..moveTo(sign * s * 0.06, headY - s * 0.06)
        ..quadraticBezierTo(
          sign * s * 0.26,
          headY + s * 0.04,
          sign * s * 0.42,
          headY + s * 0.36,
        )
        ..lineTo(sign * s * 0.15, headY + s * 0.12)
        ..close();
      _fill(canvas, horn, _darken(orange, 0.12),
          outlineWidth: 1.0, outlineDarken: 0.26);
    });

    // Eye dots.
    _eyeDots(canvas, s * 0.13, headY - s * 0.12, s * 0.04);
  }
}
