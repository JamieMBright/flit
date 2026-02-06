import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/avatar_config.dart';

/// A lo-fi, pop-art avatar portrait drawn entirely on a [Canvas].
///
/// Pass an [AvatarConfig] to control every visual aspect of the character.
/// The widget sizes itself to [size] x [size] logical pixels and is safe
/// to use anywhere a square widget is expected (lists, cards, profiles).
class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    super.key,
    required this.config,
    this.size = 96,
  });

  /// The avatar configuration that drives every visual element.
  final AvatarConfig config;

  /// Width and height of the square avatar. Defaults to 96.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size.square(size),
        painter: _AvatarPainter(config: config),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _AvatarPainter extends CustomPainter {
  _AvatarPainter({required this.config});

  final AvatarConfig config;

  // ---- Skin palette ----
  static const Map<AvatarSkin, Color> _skinColors = {
    AvatarSkin.light: Color(0xFFFDE7C8),
    AvatarSkin.fair: Color(0xFFF5D0A9),
    AvatarSkin.medium: Color(0xFFD4A373),
    AvatarSkin.tan: Color(0xFFC08B5C),
    AvatarSkin.brown: Color(0xFF8D5524),
    AvatarSkin.dark: Color(0xFF5C3310),
  };

  // ---- Hair palette (derived from skin to look natural) ----
  static const Map<AvatarHair, Color> _hairColors = {
    AvatarHair.none: Color(0x00000000),
    AvatarHair.short: Color(0xFF3B2717),
    AvatarHair.medium: Color(0xFF5A3A1A),
    AvatarHair.long: Color(0xFF1A1A1A),
    AvatarHair.mohawk: Color(0xFFD4654A),
    AvatarHair.curly: Color(0xFF3B2717),
    AvatarHair.afro: Color(0xFF1A1A1A),
    AvatarHair.ponytail: Color(0xFF5A3A1A),
  };

  // ---- Outfit palette ----
  static const Map<AvatarOutfit, Color> _outfitColors = {
    AvatarOutfit.tshirt: Color(0xFF5C7A52), // landMass green
    AvatarOutfit.pilot: Color(0xFF2A5674), // ocean blue
    AvatarOutfit.suit: Color(0xFF1A2A32), // dark
    AvatarOutfit.leather: Color(0xFF5A3A1A), // brown leather
    AvatarOutfit.spacesuit: Color(0xFFF0E8DC), // off-white
    AvatarOutfit.captain: Color(0xFF1E3340), // navy
  };

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final double cx = s / 2;
    final double cy = s / 2;

    // Save canvas so we can clip to a circle.
    canvas.save();
    final circlePath = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: s / 2));
    canvas.clipPath(circlePath);

    // -- Background --
    _drawBackground(canvas, s, cx, cy);

    // -- Outfit (behind head) --
    _drawOutfit(canvas, s, cx, cy);

    // -- Neck --
    _drawNeck(canvas, s, cx, cy);

    // -- Face --
    _drawFace(canvas, s, cx, cy);

    // -- Eyes --
    _drawEyes(canvas, s, cx, cy);

    // -- Glasses (over eyes) --
    _drawGlasses(canvas, s, cx, cy);

    // -- Hair --
    _drawHair(canvas, s, cx, cy);

    // -- Hat (over hair) --
    _drawHat(canvas, s, cx, cy);

    // -- Accessory --
    _drawAccessory(canvas, s, cx, cy);

    canvas.restore();

    // -- Circular border --
    _drawBorder(canvas, s, cx, cy);
  }

  // ---------- Background ----------

  void _drawBackground(Canvas canvas, double s, double cx, double cy) {
    final paint = Paint()..color = FlitColors.backgroundDark;
    canvas.drawRect(Rect.fromLTWH(0, 0, s, s), paint);
  }

  // ---------- Neck ----------

  void _drawNeck(Canvas canvas, double s, double cx, double cy) {
    final paint = Paint()..color = _skinColors[config.skin]!;
    final neckW = s * 0.18;
    final neckH = s * 0.12;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, cy + s * 0.24),
        width: neckW,
        height: neckH,
      ),
      paint,
    );
  }

  // ---------- Face ----------

  void _drawFace(Canvas canvas, double s, double cx, double cy) {
    final paint = Paint()..color = _skinColors[config.skin]!;

    // Face center sits slightly above widget center.
    final faceCy = cy - s * 0.04;

    switch (config.face) {
      case AvatarFace.round:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, faceCy),
            width: s * 0.52,
            height: s * 0.52,
          ),
          paint,
        );
      case AvatarFace.oval:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, faceCy),
            width: s * 0.46,
            height: s * 0.56,
          ),
          paint,
        );
      case AvatarFace.square:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx, faceCy),
              width: s * 0.50,
              height: s * 0.50,
            ),
            Radius.circular(s * 0.06),
          ),
          paint,
        );
      case AvatarFace.heart:
        // Approximate heart-ish face: wider forehead, narrow chin.
        final path = Path()
          ..moveTo(cx, faceCy + s * 0.28)
          ..quadraticBezierTo(
              cx - s * 0.30, faceCy + s * 0.06, cx - s * 0.22, faceCy - s * 0.10)
          ..quadraticBezierTo(
              cx - s * 0.14, faceCy - s * 0.28, cx, faceCy - s * 0.20)
          ..quadraticBezierTo(
              cx + s * 0.14, faceCy - s * 0.28, cx + s * 0.22, faceCy - s * 0.10)
          ..quadraticBezierTo(
              cx + s * 0.30, faceCy + s * 0.06, cx, faceCy + s * 0.28)
          ..close();
        canvas.drawPath(path, paint);
      case AvatarFace.diamond:
        final path = Path()
          ..moveTo(cx, faceCy - s * 0.26)
          ..lineTo(cx + s * 0.24, faceCy)
          ..lineTo(cx, faceCy + s * 0.26)
          ..lineTo(cx - s * 0.24, faceCy)
          ..close();
        canvas.drawPath(path, paint);
    }

    // Subtle cheek blush for charm.
    final blush = Paint()
      ..color = const Color(0x18E88080)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(cx - s * 0.14, faceCy + s * 0.06), s * 0.06, blush);
    canvas.drawCircle(Offset(cx + s * 0.14, faceCy + s * 0.06), s * 0.06, blush);

    // Simple mouth - a small smile arc.
    final mouthPaint = Paint()
      ..color = _skinColors[config.skin] == _skinColors[AvatarSkin.dark]
          ? const Color(0xFF3A1E08)
          : const Color(0xFF8B4513)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.015
      ..strokeCap = StrokeCap.round;
    final mouthPath = Path()
      ..moveTo(cx - s * 0.06, faceCy + s * 0.10)
      ..quadraticBezierTo(cx, faceCy + s * 0.15, cx + s * 0.06, faceCy + s * 0.10);
    canvas.drawPath(mouthPath, mouthPaint);
  }

  // ---------- Eyes ----------

  void _drawEyes(Canvas canvas, double s, double cx, double cy) {
    final faceCy = cy - s * 0.04;
    final eyeY = faceCy - s * 0.04;
    final leftX = cx - s * 0.10;
    final rightX = cx + s * 0.10;

    final whitePaint = Paint()..color = const Color(0xFFF5F5F5);
    final pupilPaint = Paint()..color = const Color(0xFF1A1A1A);

    switch (config.eyes) {
      case AvatarEyes.round:
        // White
        canvas.drawOval(
          Rect.fromCenter(center: Offset(leftX, eyeY), width: s * 0.10, height: s * 0.08),
          whitePaint,
        );
        canvas.drawOval(
          Rect.fromCenter(center: Offset(rightX, eyeY), width: s * 0.10, height: s * 0.08),
          whitePaint,
        );
        // Pupils
        canvas.drawCircle(Offset(leftX, eyeY), s * 0.025, pupilPaint);
        canvas.drawCircle(Offset(rightX, eyeY), s * 0.025, pupilPaint);

      case AvatarEyes.almond:
        for (final ex in [leftX, rightX]) {
          final path = Path()
            ..moveTo(ex - s * 0.06, eyeY)
            ..quadraticBezierTo(ex, eyeY - s * 0.05, ex + s * 0.06, eyeY)
            ..quadraticBezierTo(ex, eyeY + s * 0.03, ex - s * 0.06, eyeY)
            ..close();
          canvas.drawPath(path, whitePaint);
          canvas.drawCircle(Offset(ex, eyeY), s * 0.02, pupilPaint);
        }

      case AvatarEyes.wide:
        canvas.drawOval(
          Rect.fromCenter(center: Offset(leftX, eyeY), width: s * 0.12, height: s * 0.10),
          whitePaint,
        );
        canvas.drawOval(
          Rect.fromCenter(center: Offset(rightX, eyeY), width: s * 0.12, height: s * 0.10),
          whitePaint,
        );
        canvas.drawCircle(Offset(leftX, eyeY), s * 0.03, pupilPaint);
        canvas.drawCircle(Offset(rightX, eyeY), s * 0.03, pupilPaint);

      case AvatarEyes.narrow:
        final linePaint = Paint()
          ..color = const Color(0xFF1A1A1A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.018
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(leftX - s * 0.05, eyeY),
          Offset(leftX + s * 0.05, eyeY),
          linePaint,
        );
        canvas.drawLine(
          Offset(rightX - s * 0.05, eyeY),
          Offset(rightX + s * 0.05, eyeY),
          linePaint,
        );

      case AvatarEyes.wink:
        // Left eye open
        canvas.drawOval(
          Rect.fromCenter(center: Offset(leftX, eyeY), width: s * 0.10, height: s * 0.08),
          whitePaint,
        );
        canvas.drawCircle(Offset(leftX, eyeY), s * 0.025, pupilPaint);
        // Right eye winking (a small arc)
        final winkPaint = Paint()
          ..color = const Color(0xFF1A1A1A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.018
          ..strokeCap = StrokeCap.round;
        final winkPath = Path()
          ..moveTo(rightX - s * 0.05, eyeY)
          ..quadraticBezierTo(rightX, eyeY + s * 0.03, rightX + s * 0.05, eyeY);
        canvas.drawPath(winkPath, winkPaint);
    }
  }

  // ---------- Hair ----------

  void _drawHair(Canvas canvas, double s, double cx, double cy) {
    if (config.hair == AvatarHair.none) return;

    final paint = Paint()..color = _hairColors[config.hair]!;
    final faceCy = cy - s * 0.04;
    final topY = faceCy - s * 0.26;

    switch (config.hair) {
      case AvatarHair.none:
        break;

      case AvatarHair.short:
        // Flat cap of hair sitting on top of head.
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(cx, faceCy - s * 0.10),
            width: s * 0.56,
            height: s * 0.40,
          ),
          math.pi,
          math.pi,
          true,
          paint,
        );

      case AvatarHair.medium:
        // Slightly longer, covers ears.
        final path = Path()
          ..addArc(
            Rect.fromCenter(
              center: Offset(cx, faceCy - s * 0.08),
              width: s * 0.58,
              height: s * 0.44,
            ),
            math.pi,
            math.pi,
          )
          // Side hair
          ..addRect(Rect.fromLTWH(cx - s * 0.29, faceCy - s * 0.10, s * 0.07, s * 0.18))
          ..addRect(Rect.fromLTWH(cx + s * 0.22, faceCy - s * 0.10, s * 0.07, s * 0.18));
        canvas.drawPath(path, paint);

      case AvatarHair.long:
        // Flows down past the face.
        final path = Path()
          ..addArc(
            Rect.fromCenter(
              center: Offset(cx, faceCy - s * 0.08),
              width: s * 0.58,
              height: s * 0.44,
            ),
            math.pi,
            math.pi,
          )
          ..addRect(Rect.fromLTWH(cx - s * 0.29, faceCy - s * 0.10, s * 0.08, s * 0.36))
          ..addRect(Rect.fromLTWH(cx + s * 0.21, faceCy - s * 0.10, s * 0.08, s * 0.36));
        canvas.drawPath(path, paint);

      case AvatarHair.mohawk:
        // Tall strip on top.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx, topY - s * 0.08),
              width: s * 0.12,
              height: s * 0.24,
            ),
            Radius.circular(s * 0.04),
          ),
          paint,
        );

      case AvatarHair.curly:
        // A cluster of small circles around the top of the head.
        for (var angle = 0.0; angle < math.pi; angle += math.pi / 6) {
          final ox = cx + math.cos(angle + math.pi) * s * 0.24;
          final oy = faceCy - s * 0.14 + math.sin(angle + math.pi) * s * 0.16;
          canvas.drawCircle(Offset(ox, oy), s * 0.07, paint);
        }

      case AvatarHair.afro:
        // Big circle behind the head.
        canvas.drawCircle(
          Offset(cx, faceCy - s * 0.10),
          s * 0.36,
          paint,
        );

      case AvatarHair.ponytail:
        // Top hair + a tail going to the right.
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(cx, faceCy - s * 0.10),
            width: s * 0.56,
            height: s * 0.40,
          ),
          math.pi,
          math.pi,
          true,
          paint,
        );
        // Tail
        final tailPath = Path()
          ..moveTo(cx + s * 0.24, faceCy - s * 0.16)
          ..quadraticBezierTo(
              cx + s * 0.40, faceCy - s * 0.06, cx + s * 0.34, faceCy + s * 0.14)
          ..lineTo(cx + s * 0.28, faceCy + s * 0.12)
          ..quadraticBezierTo(
              cx + s * 0.34, faceCy - s * 0.02, cx + s * 0.20, faceCy - s * 0.12)
          ..close();
        canvas.drawPath(tailPath, paint);
    }
  }

  // ---------- Outfit ----------

  void _drawOutfit(Canvas canvas, double s, double cx, double cy) {
    final color = _outfitColors[config.outfit]!;
    final paint = Paint()..color = color;

    // Base torso shape (visible below the head as a collar/neckline).
    final bodyPath = Path()
      ..moveTo(cx - s * 0.38, s)
      ..lineTo(cx - s * 0.28, cy + s * 0.22)
      ..quadraticBezierTo(cx, cy + s * 0.16, cx + s * 0.28, cy + s * 0.22)
      ..lineTo(cx + s * 0.38, s)
      ..close();
    canvas.drawPath(bodyPath, paint);

    // Style-specific collar details.
    final detailPaint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.015;

    switch (config.outfit) {
      case AvatarOutfit.tshirt:
        // Simple round neckline - already drawn.
        break;

      case AvatarOutfit.pilot:
        // Lapels
        final lapelPaint = Paint()..color = FlitColors.gold;
        canvas.drawCircle(Offset(cx - s * 0.08, cy + s * 0.28), s * 0.02, lapelPaint);
        canvas.drawCircle(Offset(cx + s * 0.08, cy + s * 0.28), s * 0.02, lapelPaint);
        // Epaulette stripe
        canvas.drawLine(
          Offset(cx - s * 0.18, cy + s * 0.24),
          Offset(cx - s * 0.28, cy + s * 0.26),
          Paint()
            ..color = FlitColors.gold
            ..strokeWidth = s * 0.012
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(
          Offset(cx + s * 0.18, cy + s * 0.24),
          Offset(cx + s * 0.28, cy + s * 0.26),
          Paint()
            ..color = FlitColors.gold
            ..strokeWidth = s * 0.012
            ..strokeCap = StrokeCap.round,
        );

      case AvatarOutfit.suit:
        // V-shaped lapel.
        final lapel = Path()
          ..moveTo(cx - s * 0.04, cy + s * 0.18)
          ..lineTo(cx - s * 0.16, cy + s * 0.30)
          ..moveTo(cx + s * 0.04, cy + s * 0.18)
          ..lineTo(cx + s * 0.16, cy + s * 0.30);
        canvas.drawPath(
          lapel,
          Paint()
            ..color = FlitColors.textSecondary
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.015,
        );

      case AvatarOutfit.leather:
        // Diagonal zip line.
        canvas.drawLine(
          Offset(cx - s * 0.02, cy + s * 0.18),
          Offset(cx + s * 0.10, cy + s * 0.38),
          detailPaint..color = FlitColors.textMuted,
        );

      case AvatarOutfit.spacesuit:
        // Helmet ring around neck.
        canvas.drawCircle(
          Offset(cx, cy + s * 0.20),
          s * 0.14,
          Paint()
            ..color = const Color(0xFFB0B0B0)
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.02,
        );

      case AvatarOutfit.captain:
        // Double row of buttons.
        final btnPaint = Paint()..color = FlitColors.gold;
        for (var i = 0; i < 3; i++) {
          final y = cy + s * 0.24 + i * s * 0.06;
          canvas.drawCircle(Offset(cx - s * 0.05, y), s * 0.015, btnPaint);
          canvas.drawCircle(Offset(cx + s * 0.05, y), s * 0.015, btnPaint);
        }
    }
  }

  // ---------- Hat ----------

  void _drawHat(Canvas canvas, double s, double cx, double cy) {
    if (config.hat == AvatarHat.none) return;

    final faceCy = cy - s * 0.04;
    final topY = faceCy - s * 0.26;

    switch (config.hat) {
      case AvatarHat.none:
        break;

      case AvatarHat.cap:
        final paint = Paint()..color = FlitColors.accent;
        // Cap dome
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(cx, topY + s * 0.02),
            width: s * 0.52,
            height: s * 0.24,
          ),
          math.pi,
          math.pi,
          true,
          paint,
        );
        // Brim
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(cx + s * 0.06, topY + s * 0.02),
            width: s * 0.52,
            height: s * 0.04,
          ),
          paint,
        );

      case AvatarHat.aviator:
        final paint = Paint()..color = const Color(0xFF5A3A1A);
        // Leather cap
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(cx, topY + s * 0.04),
            width: s * 0.56,
            height: s * 0.28,
          ),
          math.pi,
          math.pi,
          true,
          paint,
        );
        // Ear flaps
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - s * 0.30, topY, s * 0.08, s * 0.18),
            Radius.circular(s * 0.03),
          ),
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx + s * 0.22, topY, s * 0.08, s * 0.18),
            Radius.circular(s * 0.03),
          ),
          paint,
        );
        // Goggles strap
        canvas.drawLine(
          Offset(cx - s * 0.26, topY + s * 0.06),
          Offset(cx + s * 0.26, topY + s * 0.06),
          Paint()
            ..color = FlitColors.gold
            ..strokeWidth = s * 0.012
            ..strokeCap = StrokeCap.round,
        );

      case AvatarHat.tophat:
        final paint = Paint()..color = const Color(0xFF1A1A1A);
        // Brim
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx, topY + s * 0.02),
              width: s * 0.54,
              height: s * 0.05,
            ),
            Radius.circular(s * 0.02),
          ),
          paint,
        );
        // Tall crown
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx, topY - s * 0.12),
              width: s * 0.34,
              height: s * 0.26,
            ),
            Radius.circular(s * 0.02),
          ),
          paint,
        );
        // Band
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(cx, topY),
            width: s * 0.34,
            height: s * 0.03,
          ),
          Paint()..color = FlitColors.accent,
        );

      case AvatarHat.crown:
        final paint = Paint()..color = FlitColors.gold;
        // Crown base
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(cx, topY + s * 0.02),
            width: s * 0.42,
            height: s * 0.06,
          ),
          paint,
        );
        // Crown points
        final crownPath = Path()
          ..moveTo(cx - s * 0.21, topY - s * 0.01)
          ..lineTo(cx - s * 0.16, topY - s * 0.12)
          ..lineTo(cx - s * 0.08, topY - s * 0.04)
          ..lineTo(cx, topY - s * 0.14)
          ..lineTo(cx + s * 0.08, topY - s * 0.04)
          ..lineTo(cx + s * 0.16, topY - s * 0.12)
          ..lineTo(cx + s * 0.21, topY - s * 0.01)
          ..close();
        canvas.drawPath(crownPath, paint);
        // Jewel
        canvas.drawCircle(
          Offset(cx, topY - s * 0.10),
          s * 0.02,
          Paint()..color = FlitColors.accent,
        );

      case AvatarHat.helmet:
        final paint = Paint()..color = const Color(0xFF606060);
        // Dome
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(cx, topY + s * 0.06),
            width: s * 0.60,
            height: s * 0.36,
          ),
          math.pi,
          math.pi,
          true,
          paint,
        );
        // Visor
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(cx, topY + s * 0.08),
            width: s * 0.50,
            height: s * 0.12,
          ),
          0,
          math.pi,
          true,
          Paint()..color = const Color(0x60000000),
        );
        // Center stripe
        canvas.drawLine(
          Offset(cx, topY - s * 0.10),
          Offset(cx, topY + s * 0.06),
          Paint()
            ..color = FlitColors.accent
            ..strokeWidth = s * 0.02
            ..strokeCap = StrokeCap.round,
        );
    }
  }

  // ---------- Glasses ----------

  void _drawGlasses(Canvas canvas, double s, double cx, double cy) {
    if (config.glasses == AvatarGlasses.none) return;

    final faceCy = cy - s * 0.04;
    final eyeY = faceCy - s * 0.04;
    final leftX = cx - s * 0.10;
    final rightX = cx + s * 0.10;

    final framePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.015
      ..strokeCap = StrokeCap.round;

    switch (config.glasses) {
      case AvatarGlasses.none:
        break;

      case AvatarGlasses.round:
        framePaint.color = const Color(0xFF1A1A1A);
        canvas.drawCircle(Offset(leftX, eyeY), s * 0.07, framePaint);
        canvas.drawCircle(Offset(rightX, eyeY), s * 0.07, framePaint);
        // Bridge
        canvas.drawLine(
          Offset(leftX + s * 0.07, eyeY),
          Offset(rightX - s * 0.07, eyeY),
          framePaint,
        );

      case AvatarGlasses.aviator:
        framePaint.color = FlitColors.gold;
        // Teardrop shape lenses
        for (final ex in [leftX, rightX]) {
          final lensPath = Path()
            ..addOval(Rect.fromCenter(
              center: Offset(ex, eyeY + s * 0.01),
              width: s * 0.14,
              height: s * 0.12,
            ));
          canvas.drawPath(lensPath, framePaint);
          // Tinted lens
          canvas.drawPath(
            lensPath,
            Paint()..color = const Color(0x30264050),
          );
        }
        // Bridge
        canvas.drawLine(
          Offset(leftX + s * 0.07, eyeY),
          Offset(rightX - s * 0.07, eyeY),
          framePaint,
        );

      case AvatarGlasses.monocle:
        framePaint.color = FlitColors.gold;
        canvas.drawCircle(Offset(rightX, eyeY), s * 0.08, framePaint);
        // Chain
        final chainPath = Path()
          ..moveTo(rightX, eyeY + s * 0.08)
          ..quadraticBezierTo(
              rightX + s * 0.04, eyeY + s * 0.20, cx, cy + s * 0.24);
        canvas.drawPath(chainPath, framePaint..strokeWidth = s * 0.008);

      case AvatarGlasses.futuristic:
        // Single visor band across both eyes
        final visorRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, eyeY),
            width: s * 0.40,
            height: s * 0.08,
          ),
          Radius.circular(s * 0.04),
        );
        canvas.drawRRect(
          visorRect,
          Paint()..color = const Color(0x804A90B8),
        );
        canvas.drawRRect(
          visorRect,
          Paint()
            ..color = FlitColors.oceanHighlight
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.012,
        );
    }
  }

  // ---------- Accessory ----------

  void _drawAccessory(Canvas canvas, double s, double cx, double cy) {
    if (config.accessory == AvatarAccessory.none) return;

    switch (config.accessory) {
      case AvatarAccessory.none:
        break;

      case AvatarAccessory.scarf:
        final paint = Paint()..color = FlitColors.accent;
        // Wrapped scarf around neck area
        final scarfPath = Path()
          ..moveTo(cx - s * 0.22, cy + s * 0.18)
          ..quadraticBezierTo(cx, cy + s * 0.22, cx + s * 0.22, cy + s * 0.18)
          ..lineTo(cx + s * 0.22, cy + s * 0.24)
          ..quadraticBezierTo(cx, cy + s * 0.28, cx - s * 0.22, cy + s * 0.24)
          ..close();
        canvas.drawPath(scarfPath, paint);
        // Hanging end
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx + s * 0.10, cy + s * 0.22, s * 0.08, s * 0.16),
            Radius.circular(s * 0.03),
          ),
          paint,
        );

      case AvatarAccessory.medal:
        // Ribbon
        final ribbonPaint = Paint()..color = FlitColors.accent;
        canvas.drawLine(
          Offset(cx, cy + s * 0.20),
          Offset(cx, cy + s * 0.34),
          ribbonPaint
            ..strokeWidth = s * 0.03
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
        // Medal circle
        canvas.drawCircle(
          Offset(cx, cy + s * 0.36),
          s * 0.05,
          Paint()..color = FlitColors.gold,
        );
        // Star on medal
        canvas.drawCircle(
          Offset(cx, cy + s * 0.36),
          s * 0.02,
          Paint()..color = FlitColors.goldLight,
        );

      case AvatarAccessory.earring:
        final paint = Paint()..color = FlitColors.gold;
        // Small hoop on left ear
        canvas.drawCircle(
          Offset(cx - s * 0.24, cy - s * 0.02),
          s * 0.025,
          paint,
        );
        // Dangling part
        canvas.drawCircle(
          Offset(cx - s * 0.24, cy + s * 0.02),
          s * 0.015,
          Paint()..color = FlitColors.goldLight,
        );

      case AvatarAccessory.goldChain:
        final chainPaint = Paint()
          ..color = FlitColors.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.015
          ..strokeCap = StrokeCap.round;
        // Chain arc across chest
        final chainPath = Path()
          ..moveTo(cx - s * 0.16, cy + s * 0.22)
          ..quadraticBezierTo(cx, cy + s * 0.32, cx + s * 0.16, cy + s * 0.22);
        canvas.drawPath(chainPath, chainPaint);
        // Pendant
        canvas.drawCircle(
          Offset(cx, cy + s * 0.30),
          s * 0.025,
          Paint()..color = FlitColors.gold,
        );

      case AvatarAccessory.parrot:
        // Small parrot sitting on the right shoulder
        final bodyPaint = Paint()..color = const Color(0xFF2ECC40);
        final beakPaint = Paint()..color = FlitColors.gold;
        final eyePaint = Paint()..color = const Color(0xFF1A1A1A);

        final px = cx + s * 0.26;
        final py = cy + s * 0.16;

        // Body
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(px, py),
            width: s * 0.10,
            height: s * 0.14,
          ),
          bodyPaint,
        );
        // Head
        canvas.drawCircle(Offset(px + s * 0.02, py - s * 0.06), s * 0.04, bodyPaint);
        // Eye
        canvas.drawCircle(Offset(px + s * 0.03, py - s * 0.07), s * 0.012, eyePaint);
        // Beak
        final beakPath = Path()
          ..moveTo(px + s * 0.06, py - s * 0.06)
          ..lineTo(px + s * 0.10, py - s * 0.05)
          ..lineTo(px + s * 0.06, py - s * 0.04)
          ..close();
        canvas.drawPath(beakPath, beakPaint);
        // Tail feather
        canvas.drawLine(
          Offset(px - s * 0.02, py + s * 0.06),
          Offset(px - s * 0.06, py + s * 0.14),
          Paint()
            ..color = FlitColors.accent
            ..strokeWidth = s * 0.015
            ..strokeCap = StrokeCap.round,
        );
    }
  }

  // ---------- Circular border ----------

  void _drawBorder(Canvas canvas, double s, double cx, double cy) {
    canvas.drawCircle(
      Offset(cx, cy),
      s / 2 - 1,
      Paint()
        ..color = FlitColors.cardBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.025,
    );
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter oldDelegate) =>
      config != oldDelegate.config;
}
