import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/avatar_config.dart';

/// Debug screen that renders every companion creature side-by-side at large
/// scale with animated wing flapping.
///
/// Intended for visual QA — screenshot this screen and share it to iterate
/// on companion shapes without hunting them down in-game.
///
/// Only accessible via the admin Design Preview section.
class CompanionPreviewScreen extends StatefulWidget {
  const CompanionPreviewScreen({super.key});

  @override
  State<CompanionPreviewScreen> createState() => _CompanionPreviewScreenState();
}

class _CompanionPreviewScreenState extends State<CompanionPreviewScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  /// Companions to display (skip `none`).
  static final _companions = AvatarCompanion.values
      .where((c) => c != AvatarCompanion.none)
      .toList();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: FlitColors.backgroundDark,
    appBar: AppBar(
      backgroundColor: FlitColors.cardBackground,
      title: const Text(
        'Companion Preview',
        style: TextStyle(color: FlitColors.textPrimary),
      ),
      iconTheme: const IconThemeData(color: FlitColors.textPrimary),
    ),
    body: AnimatedBuilder(
      animation: _animController,
      builder: (context, _) => GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _companions.length,
        itemBuilder: (context, index) {
          final companion = _companions[index];
          return _CompanionCard(
            companion: companion,
            flapPhase: _animController.value * 2 * pi * 2,
            breathPhase: _animController.value * 2 * pi * 1.4,
          );
        },
      ),
    ),
  );
}

class _CompanionCard extends StatelessWidget {
  const _CompanionCard({
    required this.companion,
    required this.flapPhase,
    required this.breathPhase,
  });

  final AvatarCompanion companion;
  final double flapPhase;
  final double breathPhase;

  @override
  Widget build(BuildContext context) {
    final price = AvatarConfig.companionPrice(companion);

    return Container(
      decoration: BoxDecoration(
        color: FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _tierColor(price), width: 1.5),
      ),
      child: Column(
        children: [
          // Companion rendering area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: CustomPaint(
                painter: _CompanionPreviewPainter(
                  companion: companion,
                  flapPhase: flapPhase,
                  breathPhase: breathPhase,
                ),
                size: Size.infinite,
              ),
            ),
          ),
          // Label area
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const BoxDecoration(
              color: FlitColors.backgroundMid,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _companionLabel(companion),
                  style: const TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${companion.name} · companion_${companion.name}',
                  style: const TextStyle(
                    color: FlitColors.textMuted,
                    fontSize: 10,
                  ),
                ),
                Text(
                  '${_tierLabel(price)} · $price coins',
                  style: TextStyle(
                    color: _tierColor(price),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _companionLabel(AvatarCompanion c) => switch (c) {
    AvatarCompanion.none => 'None',
    AvatarCompanion.pidgey => 'Pidgey',
    AvatarCompanion.sparrow => 'Sparrow',
    AvatarCompanion.eagle => 'Eagle',
    AvatarCompanion.parrot => 'Parrot',
    AvatarCompanion.phoenix => 'Phoenix',
    AvatarCompanion.dragon => 'Dragon',
    AvatarCompanion.charizard => 'Charizard',
  };

  static String _tierLabel(int price) {
    if (price >= 30000) return 'Legendary';
    if (price >= 8000) return 'Epic';
    if (price >= 2000) return 'Rare';
    if (price > 0) return 'Common';
    return 'Free';
  }

  static Color _tierColor(int price) {
    if (price >= 30000) return FlitColors.gold;
    if (price >= 8000) return const Color(0xFF9B59B6);
    if (price >= 2000) return FlitColors.oceanHighlight;
    return FlitColors.textSecondary;
  }
}

// =============================================================================
// Companion Preview Painter — animated procedural sprite rendering.
// =============================================================================

class _CompanionPreviewPainter extends CustomPainter {
  _CompanionPreviewPainter({
    required this.companion,
    required this.flapPhase,
    required this.breathPhase,
  });

  final AvatarCompanion companion;
  final double flapPhase;
  final double breathPhase;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.save();
    canvas.translate(cx, cy);

    final scale = size.shortestSide / 64;
    canvas.scale(scale);

    final flapOffset = sin(flapPhase) * 3.0;

    switch (companion) {
      case AvatarCompanion.none:
        break;
      case AvatarCompanion.pidgey:
        _paintPidgey(canvas, flapOffset);
      case AvatarCompanion.sparrow:
        _paintSparrow(canvas, flapOffset);
      case AvatarCompanion.eagle:
        _paintEagle(canvas, flapOffset);
      case AvatarCompanion.parrot:
        _paintParrot(canvas, flapOffset);
      case AvatarCompanion.phoenix:
        _paintPhoenix(canvas, flapOffset);
      case AvatarCompanion.dragon:
        _paintDragon(canvas, flapOffset);
      case AvatarCompanion.charizard:
        _paintCharizard(canvas, flapOffset);
    }

    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // Pidgey — Adorable chibi bird with rosy cheeks and big eyes.
  // ---------------------------------------------------------------------------
  void _paintPidgey(Canvas canvas, double flapOffset) {
    const s = 14.0;
    const brown = Color(0xFF9E7B5A);
    const cream = Color(0xFFF5E8D0);
    const darkBrown = Color(0xFF6B5238);

    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0.5, s * 0.22),
        width: s * 1.0,
        height: s * 0.3,
      ),
      Paint()
        ..color = const Color(0xFF000000).withOpacity(0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    _drawTailFeathers(canvas, s, darkBrown, 3, 0.35, 0.12);
    _drawWing(canvas, s, flapOffset, darkBrown.withOpacity(0.85), true, 0.7, 2);
    _drawWing(
      canvas,
      s,
      flapOffset,
      darkBrown.withOpacity(0.85),
      false,
      0.7,
      2,
    );
    _drawBody(canvas, s * 0.95, s * 0.6, brown, cream);

    canvas.drawCircle(
      const Offset(0, -s * 0.32),
      s * 0.28,
      Paint()..color = brown,
    );
    canvas.drawCircle(
      const Offset(0, -s * 0.28),
      s * 0.18,
      Paint()..color = cream,
    );
    canvas.drawCircle(
      const Offset(-s * 0.05, -s * 0.42),
      s * 0.08,
      Paint()..color = _lighten(brown, 0.15).withOpacity(0.5),
    );

    _drawEyes(
      canvas,
      const Offset(-s * 0.1, -s * 0.35),
      const Offset(s * 0.1, -s * 0.35),
      s * 0.07,
    );
    _drawBeak(
      canvas,
      const Offset(0, -s * 0.52),
      s * 0.15,
      const Color(0xFFE8962A),
    );

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
  // Sparrow — Sleek barn swallow with navy back, forked tail.
  // ---------------------------------------------------------------------------
  void _paintSparrow(Canvas canvas, double flapOffset) {
    const s = 16.0;
    const navy = Color(0xFF2C3E6B);
    const russet = Color(0xFFB85C38);
    const cream = Color(0xFFF0E6D4);

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
    canvas.drawPath(leftFork, Paint()..color = navy);
    canvas.drawPath(rightFork, Paint()..color = navy);

    _drawWing(canvas, s, flapOffset, navy.withOpacity(0.9), true, 0.85, 3);
    _drawWing(canvas, s, flapOffset, navy.withOpacity(0.9), false, 0.85, 3);
    _drawBody(canvas, s * 0.7, s * 0.5, navy, cream);

    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, -s * 0.05),
        width: s * 0.35,
        height: s * 0.15,
      ),
      Paint()..color = russet,
    );

    canvas.drawCircle(
      const Offset(0, -s * 0.28),
      s * 0.2,
      Paint()..color = navy,
    );
    canvas.drawCircle(
      const Offset(-s * 0.04, -s * 0.35),
      s * 0.06,
      Paint()..color = _lighten(navy, 0.15).withOpacity(0.4),
    );

    _drawEyes(
      canvas,
      const Offset(-s * 0.08, -s * 0.3),
      const Offset(s * 0.08, -s * 0.3),
      s * 0.045,
      irisColor: const Color(0xFF0D0D1A),
    );
    _drawBeak(
      canvas,
      const Offset(0, -s * 0.46),
      s * 0.12,
      const Color(0xFF3A3A3A),
    );
  }

  // ---------------------------------------------------------------------------
  // Eagle — Majestic golden raptor with white head.
  // ---------------------------------------------------------------------------
  void _paintEagle(Canvas canvas, double flapOffset) {
    const s = 18.0;
    const golden = Color(0xFFC49A3C);
    const darkGold = Color(0xFF8B6914);
    const white = Color(0xFFF8F6F0);

    _drawTailFeathers(canvas, s, darkGold, 5, 0.4, 0.16);

    _drawWing(
      canvas,
      s,
      flapOffset,
      golden.withOpacity(0.9),
      true,
      0.95,
      4,
      tipColor: _lighten(golden, 0.15),
    );
    _drawWing(
      canvas,
      s,
      flapOffset,
      golden.withOpacity(0.9),
      false,
      0.95,
      4,
      tipColor: _lighten(golden, 0.15),
    );

    _drawBody(canvas, s * 0.75, s * 0.55, golden, _lighten(golden, 0.2));

    canvas.drawCircle(
      const Offset(0, -s * 0.3),
      s * 0.22,
      Paint()..color = white,
    );
    canvas.drawCircle(
      const Offset(-s * 0.04, -s * 0.38),
      s * 0.07,
      Paint()..color = _lighten(white, 0.1).withOpacity(0.5),
    );

    _drawEyes(
      canvas,
      const Offset(-s * 0.08, -s * 0.32),
      const Offset(s * 0.08, -s * 0.32),
      s * 0.05,
      fierce: true,
      irisColor: const Color(0xFF4A3000),
    );
    _drawBeak(
      canvas,
      const Offset(0, -s * 0.5),
      s * 0.18,
      const Color(0xFFD4A520),
      hooked: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Parrot — Vivid scarlet macaw with multicolor wings.
  // ---------------------------------------------------------------------------
  void _paintParrot(Canvas canvas, double flapOffset) {
    const s = 16.0;
    const scarlet = Color(0xFFE23636);
    const blue = Color(0xFF2E7DBA);
    const green = Color(0xFF36A84A);
    const gold = Color(0xFFE8C83A);

    // Tail streamers.
    for (var i = -1; i <= 1; i++) {
      final streamer = Path()
        ..moveTo(i * s * 0.06, s * 0.2)
        ..quadraticBezierTo(i * s * 0.15, s * 0.6, i * s * 0.08, s * 0.85)
        ..quadraticBezierTo(i * s * 0.04, s * 0.6, i * s * 0.02, s * 0.25)
        ..close();
      final c = [scarlet, blue, green][i + 1];
      canvas.drawPath(streamer, Paint()..color = c.withOpacity(0.8));
    }

    _drawWing(
      canvas,
      s,
      flapOffset,
      blue.withOpacity(0.9),
      true,
      0.85,
      3,
      tipColor: green,
    );
    _drawWing(
      canvas,
      s,
      flapOffset,
      blue.withOpacity(0.9),
      false,
      0.85,
      3,
      tipColor: green,
    );

    _drawBody(canvas, s * 0.7, s * 0.5, scarlet, gold.withOpacity(0.5));

    canvas.drawCircle(
      const Offset(0, -s * 0.28),
      s * 0.22,
      Paint()..color = scarlet,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, -s * 0.25),
        width: s * 0.3,
        height: s * 0.2,
      ),
      Paint()..color = const Color(0xFFF8F4F0),
    );
    canvas.drawCircle(
      const Offset(-s * 0.04, -s * 0.36),
      s * 0.06,
      Paint()..color = _lighten(scarlet, 0.15).withOpacity(0.4),
    );

    _drawEyes(
      canvas,
      const Offset(-s * 0.08, -s * 0.28),
      const Offset(s * 0.08, -s * 0.28),
      s * 0.05,
    );
    _drawBeak(
      canvas,
      const Offset(0, -s * 0.48),
      s * 0.16,
      const Color(0xFF2A2A2A),
      hooked: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Phoenix — Golden fire creature with flame wings and streamer tail.
  // ---------------------------------------------------------------------------
  void _paintPhoenix(Canvas canvas, double flapOffset) {
    const s = 18.0;
    const goldenOrange = Color(0xFFE8962A);
    const flameRed = Color(0xFFE84C2A);
    const flameYellow = Color(0xFFFFD93D);

    // Flame tail streamers.
    final breathScale = 0.9 + sin(breathPhase) * 0.1;
    for (var i = -2; i <= 2; i++) {
      final streamer = Path()
        ..moveTo(i * s * 0.05, s * 0.15)
        ..quadraticBezierTo(
          i * s * 0.12,
          s * 0.5 * breathScale,
          i * s * 0.06,
          s * 0.8 * breathScale,
        )
        ..quadraticBezierTo(i * s * 0.03, s * 0.4, i * s * 0.01, s * 0.2)
        ..close();
      final t = (i + 2) / 4.0;
      final c = Color.lerp(flameRed, flameYellow, t)!;
      canvas.drawPath(streamer, Paint()..color = c.withOpacity(0.7));
    }

    _drawWing(
      canvas,
      s,
      flapOffset,
      goldenOrange.withOpacity(0.9),
      true,
      0.95,
      4,
      tipColor: flameRed,
    );
    _drawWing(
      canvas,
      s,
      flapOffset,
      goldenOrange.withOpacity(0.9),
      false,
      0.95,
      4,
      tipColor: flameRed,
    );

    _drawBody(canvas, s * 0.7, s * 0.5, goldenOrange, flameYellow);

    canvas.drawCircle(
      const Offset(0, -s * 0.3),
      s * 0.22,
      Paint()..color = goldenOrange,
    );
    canvas.drawCircle(
      const Offset(-s * 0.04, -s * 0.38),
      s * 0.06,
      Paint()..color = flameYellow.withOpacity(0.4),
    );

    _drawEyes(
      canvas,
      const Offset(-s * 0.08, -s * 0.32),
      const Offset(s * 0.08, -s * 0.32),
      s * 0.05,
      fierce: true,
      irisColor: const Color(0xFFB84000),
    );
    _drawBeak(
      canvas,
      const Offset(0, -s * 0.5),
      s * 0.15,
      const Color(0xFFCCA020),
      hooked: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Dragon — Scaled mythical beast with large wings and sinuous tail.
  // ---------------------------------------------------------------------------
  void _paintDragon(Canvas canvas, double flapOffset) {
    const s = 20.0;
    const purple = Color(0xFF6B3FA0);
    const teal = Color(0xFF2FA08B);
    const darkPurple = Color(0xFF3D1F5E);

    // Sinuous tail.
    final tail = Path()
      ..moveTo(0, s * 0.2)
      ..cubicTo(-s * 0.1, s * 0.5, s * 0.15, s * 0.7, -s * 0.05, s * 0.9)
      ..cubicTo(-s * 0.08, s * 0.75, s * 0.08, s * 0.5, 0, s * 0.25)
      ..close();
    canvas.drawPath(tail, Paint()..color = darkPurple);

    // Scaled wings.
    _drawWing(
      canvas,
      s,
      flapOffset,
      purple.withOpacity(0.85),
      true,
      1.0,
      4,
      tipColor: teal,
    );
    _drawWing(
      canvas,
      s,
      flapOffset,
      purple.withOpacity(0.85),
      false,
      1.0,
      4,
      tipColor: teal,
    );

    // Wing membrane highlights.
    for (final isLeft in [true, false]) {
      final sign = isLeft ? -1.0 : 1.0;
      canvas.drawLine(
        Offset(sign * s * 0.3, flapOffset - s * 0.15),
        Offset(sign * s * 0.8, flapOffset - s * 0.08),
        Paint()
          ..color = teal.withOpacity(0.3)
          ..strokeWidth = 1.2,
      );
    }

    _drawBody(canvas, s * 0.65, s * 0.5, purple, teal.withOpacity(0.4));

    // Scales pattern on body.
    for (var row = 0; row < 3; row++) {
      for (var col = -1; col <= 1; col++) {
        canvas.drawCircle(
          Offset(col * s * 0.08, -s * 0.05 + row * s * 0.07),
          s * 0.025,
          Paint()..color = teal.withOpacity(0.25),
        );
      }
    }

    canvas.drawCircle(
      const Offset(0, -s * 0.28),
      s * 0.2,
      Paint()..color = purple,
    );
    canvas.drawCircle(
      const Offset(-s * 0.04, -s * 0.36),
      s * 0.06,
      Paint()..color = _lighten(purple, 0.15).withOpacity(0.4),
    );

    _drawEyes(
      canvas,
      const Offset(-s * 0.08, -s * 0.3),
      const Offset(s * 0.08, -s * 0.3),
      s * 0.05,
      fierce: true,
      irisColor: const Color(0xFF40E0D0),
    );

    // Horns.
    for (final sign in [-1.0, 1.0]) {
      final horn = Path()
        ..moveTo(sign * s * 0.1, -s * 0.38)
        ..quadraticBezierTo(
          sign * s * 0.18,
          -s * 0.55,
          sign * s * 0.12,
          -s * 0.6,
        )
        ..quadraticBezierTo(
          sign * s * 0.08,
          -s * 0.5,
          sign * s * 0.08,
          -s * 0.38,
        )
        ..close();
      canvas.drawPath(horn, Paint()..color = darkPurple);
    }

    // Fire breath effect.
    final breathScale = 0.8 + sin(breathPhase) * 0.2;
    final flame = Path()
      ..moveTo(0, -s * 0.45)
      ..quadraticBezierTo(
        -s * 0.06,
        -s * (0.55 + 0.1 * breathScale),
        0,
        -s * 0.7 * breathScale,
      )
      ..quadraticBezierTo(
        s * 0.06,
        -s * (0.55 + 0.1 * breathScale),
        0,
        -s * 0.45,
      )
      ..close();
    canvas.drawPath(flame, Paint()..color = teal.withOpacity(0.5));
  }

  // ---------------------------------------------------------------------------
  // Charizard — Fast flying beast with orange body and blue wings.
  // ---------------------------------------------------------------------------
  void _paintCharizard(Canvas canvas, double flapOffset) {
    const s = 20.0;
    const orange = Color(0xFFE87040);
    const blue = Color(0xFF3A7BD5);
    const cream = Color(0xFFF5DEB3);
    const darkOrange = Color(0xFFC04020);

    // Tail with flame tip.
    final tail = Path()
      ..moveTo(0, s * 0.2)
      ..quadraticBezierTo(-s * 0.08, s * 0.55, -s * 0.05, s * 0.7)
      ..quadraticBezierTo(s * 0.02, s * 0.55, 0, s * 0.25)
      ..close();
    canvas.drawPath(tail, Paint()..color = darkOrange);

    final breathScale = 0.8 + sin(breathPhase) * 0.2;
    final flameTip = Path()
      ..moveTo(-s * 0.05, s * 0.65)
      ..quadraticBezierTo(
        -s * 0.1,
        s * 0.8 * breathScale,
        -s * 0.02,
        s * 0.9 * breathScale,
      )
      ..quadraticBezierTo(s * 0.05, s * 0.8 * breathScale, -s * 0.02, s * 0.65)
      ..close();
    canvas.drawPath(
      flameTip,
      Paint()..color = const Color(0xFFFFAA30).withOpacity(0.8),
    );

    _drawWing(
      canvas,
      s,
      flapOffset,
      blue.withOpacity(0.9),
      true,
      1.0,
      4,
      tipColor: _lighten(blue, 0.15),
    );
    _drawWing(
      canvas,
      s,
      flapOffset,
      blue.withOpacity(0.9),
      false,
      1.0,
      4,
      tipColor: _lighten(blue, 0.15),
    );

    _drawBody(canvas, s * 0.65, s * 0.5, orange, cream);

    canvas.drawCircle(
      const Offset(0, -s * 0.28),
      s * 0.2,
      Paint()..color = orange,
    );
    canvas.drawCircle(
      const Offset(-s * 0.04, -s * 0.36),
      s * 0.06,
      Paint()..color = _lighten(orange, 0.15).withOpacity(0.4),
    );

    _drawEyes(
      canvas,
      const Offset(-s * 0.08, -s * 0.3),
      const Offset(s * 0.08, -s * 0.3),
      s * 0.05,
      fierce: true,
      irisColor: const Color(0xFF1A3A80),
    );
    _drawBeak(
      canvas,
      const Offset(0, -s * 0.45),
      s * 0.12,
      const Color(0xFF3A3A3A),
    );

    // Pointed ear spikes.
    for (final sign in [-1.0, 1.0]) {
      final spike = Path()
        ..moveTo(sign * s * 0.12, -s * 0.35)
        ..lineTo(sign * s * 0.2, -s * 0.52)
        ..lineTo(sign * s * 0.1, -s * 0.38)
        ..close();
      canvas.drawPath(spike, Paint()..color = darkOrange);
    }
  }

  // ---------------------------------------------------------------------------
  // Shared drawing helpers
  // ---------------------------------------------------------------------------

  void _drawWing(
    Canvas canvas,
    double size,
    double flapOffset,
    Color color,
    bool isLeft,
    double spread,
    int featherCount, {
    Color? tipColor,
  }) {
    final sign = isLeft ? -1.0 : 1.0;
    final paint = Paint()..color = color;
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

    final featherStep = size * 0.15;
    for (var i = 0; i < featherCount; i++) {
      final fx = sign * (size * spread - (i + 1) * featherStep * 0.6);
      final fy = flapOffset - size * 0.2 + (i + 1) * featherStep * 0.4;
      wing.lineTo(fx, fy);
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
    canvas.drawPath(wing, paint);

    if (tipColor != null) {
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
      canvas.drawPath(tip, Paint()..color = tipColor);
    }
  }

  void _drawBody(
    Canvas canvas,
    double width,
    double height,
    Color baseColor,
    Color bellyColor,
  ) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, height * 0.08),
        width: width * 0.95,
        height: height * 0.6,
      ),
      Paint()..color = _darken(baseColor, 0.3),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: width, height: height),
      Paint()..color = baseColor,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, height * 0.06),
        width: width * 0.6,
        height: height * 0.45,
      ),
      Paint()..color = bellyColor,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, -height * 0.12),
        width: width * 0.35,
        height: height * 0.15,
      ),
      Paint()..color = _lighten(baseColor, 0.2).withOpacity(0.4),
    );
  }

  void _drawEyes(
    Canvas canvas,
    Offset leftCenter,
    Offset rightCenter,
    double radius, {
    Color irisColor = const Color(0xFF1A1A2E),
    bool fierce = false,
  }) {
    for (final center in [leftCenter, rightCenter]) {
      if (fierce) {
        final eye = Path()
          ..addOval(
            Rect.fromCenter(
              center: center,
              width: radius * 2.4,
              height: radius * 1.6,
            ),
          );
        canvas.drawPath(eye, Paint()..color = irisColor);
        canvas.drawCircle(
          Offset(center.dx - radius * 0.3, center.dy - radius * 0.2),
          radius * 0.3,
          Paint()..color = const Color(0xFFFFFFFF).withOpacity(0.7),
        );
      } else {
        canvas.drawCircle(
          center,
          radius * 1.2,
          Paint()..color = const Color(0xFFF8F4F0),
        );
        canvas.drawCircle(center, radius, Paint()..color = irisColor);
        canvas.drawCircle(
          Offset(center.dx - radius * 0.35, center.dy - radius * 0.35),
          radius * 0.35,
          Paint()..color = const Color(0xFFFFFFFF),
        );
      }
    }
  }

  void _drawBeak(
    Canvas canvas,
    Offset tip,
    double size,
    Color color, {
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
    canvas.drawPath(upperBeak, Paint()..color = color);
    final lower = Path()
      ..moveTo(tip.dx - size * 0.25, tip.dy + size * 0.45)
      ..quadraticBezierTo(
        tip.dx,
        tip.dy + size * 0.7,
        tip.dx + size * 0.25,
        tip.dy + size * 0.45,
      )
      ..close();
    canvas.drawPath(lower, Paint()..color = _darken(color, 0.2));
  }

  void _drawTailFeathers(
    Canvas canvas,
    double size,
    Color color,
    int count,
    double length,
    double splay,
  ) {
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
      final featherColor = i.isEven ? color : _darken(color, 0.1);
      canvas.drawPath(feather, Paint()..color = featherColor);
    }
  }

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

  @override
  bool shouldRepaint(covariant _CompanionPreviewPainter old) =>
      companion != old.companion ||
      flapPhase != old.flapPhase ||
      breathPhase != old.breathPhase;
}
