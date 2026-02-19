import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';

/// Gameplay guide / how-to-play screen for Flit.
///
/// A scrollable reference that walks new players through every facet of the
/// game: the globe, missions, scoring, game modes, controls, and tips.
/// All visual illustrations are built with CustomPaint, Container decorations,
/// and Material icons — no external image assets are used.
class GameplayGuideScreen extends StatelessWidget {
  const GameplayGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundDark,
        foregroundColor: FlitColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: FlitColors.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.airplanemode_active_rounded,
              color: FlitColors.accent,
              size: 22,
            ),
            SizedBox(width: 8),
            Text(
              'How to Play',
              style: TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: FlitColors.cardBorder),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: const [
          _WelcomeSection(),
          SizedBox(height: 16),
          _GlobeSection(),
          SizedBox(height: 16),
          _MissionSection(),
          SizedBox(height: 16),
          _ScoringSection(),
          SizedBox(height: 16),
          _GameModesSection(),
          SizedBox(height: 16),
          _ControlsSection(),
          SizedBox(height: 16),
          _TipsSection(),
          SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared card shell
// ---------------------------------------------------------------------------

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FlitColors.cardBackground,
        border: Border.all(color: FlitColors.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body text helper
// ---------------------------------------------------------------------------

class _BodyText extends StatelessWidget {
  const _BodyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: FlitColors.textSecondary,
        fontSize: 14,
        height: 1.5,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Welcome
// ---------------------------------------------------------------------------

class _WelcomeSection extends StatelessWidget {
  const _WelcomeSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3340), Color(0xFF1A2A32)],
        ),
        border: Border.all(color: FlitColors.accent.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Decorative plane + title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Mini globe + plane illustration
              SizedBox(
                width: 72,
                height: 72,
                child: CustomPaint(painter: _WelcomeGlobePainter()),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.airplanemode_active_rounded,
                          color: FlitColors.accent,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'FLIT',
                          style: TextStyle(
                            color: FlitColors.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'How to Play',
                      style: TextStyle(
                        color: FlitColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: FlitColors.cardBorder),
          const SizedBox(height: 16),
          const _BodyText(
            'Welcome, pilot. You are about to embark on a geography flight '
            'adventure around our planet. Fly your plane across the globe, read the clues, '
            'identify countries, and fly into their airspace — the faster you guess, '
            'the higher you score.',
          ),
          const SizedBox(height: 12),
          const _BodyText(
            'This guide covers everything you need to go from cadet to ace. '
            'Good luck up there.',
          ),
        ],
      ),
    );
  }
}

/// Draws a tiny globe with a paper-plane silhouette arcing over it.
class _WelcomeGlobePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // Space background
    final spacePaint = Paint()
      ..shader = RadialGradient(
        colors: [FlitColors.ocean.withOpacity(0.4), FlitColors.space],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, spacePaint);

    // Globe gradient
    final globePaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.3),
        colors: [
          FlitColors.oceanHighlight,
          FlitColors.ocean,
          FlitColors.oceanDeep,
        ],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, globePaint);

    // Land masses (simple blobs)
    final landPaint = Paint()..color = FlitColors.landMass.withOpacity(0.85);
    canvas.drawOval(
      Rect.fromCenter(
        center: center + const Offset(-8, -6),
        width: 20,
        height: 14,
      ),
      landPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center + const Offset(10, 5),
        width: 14,
        height: 10,
      ),
      landPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center + const Offset(-4, 12),
        width: 10,
        height: 7,
      ),
      landPaint,
    );

    // Grid lines (latitude)
    final gridPaint = Paint()
      ..color = FlitColors.gridLine.withOpacity(0.5)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    for (int i = 1; i <= 2; i++) {
      final y = center.dy - (radius * 0.5 * i) / 2;
      final dy = y - center.dy;
      final hw = math.sqrt(math.max(0, radius * radius - dy * dy));
      canvas.drawLine(
        Offset(center.dx - hw, y),
        Offset(center.dx + hw, y),
        gridPaint,
      );
      final y2 = center.dy + (radius * 0.5 * i) / 2;
      final dy2 = y2 - center.dy;
      final hw2 = math.sqrt(math.max(0, radius * radius - dy2 * dy2));
      canvas.drawLine(
        Offset(center.dx - hw2, y2),
        Offset(center.dx + hw2, y2),
        gridPaint,
      );
    }

    // Rim glow
    final rimPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          FlitColors.atmosphereGlow.withOpacity(0.3),
        ],
        stops: const [0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius + 4))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius + 2, rimPaint);

    // Clip to circle for plane
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Paper plane icon path (simplified triangle silhouette)
    final planePaint = Paint()..color = FlitColors.planeBody;
    final planeCenter = center + const Offset(14, -16);
    final planePath = Path()
      ..moveTo(planeCenter.dx, planeCenter.dy - 6)
      ..lineTo(planeCenter.dx + 10, planeCenter.dy + 1)
      ..lineTo(planeCenter.dx + 2, planeCenter.dy + 2)
      ..lineTo(planeCenter.dx - 2, planeCenter.dy + 6)
      ..lineTo(planeCenter.dx - 1, planeCenter.dy + 1)
      ..close();
    canvas.drawPath(planePath, planePaint);

    // Contrail dots
    final contrailPaint = Paint()..color = FlitColors.contrail.withOpacity(0.5);
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(
        planeCenter + Offset(-i * 3.5, i * 1.5),
        1.2 - i * 0.2,
        contrailPaint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// 2. The Globe
// ---------------------------------------------------------------------------

class _GlobeSection extends StatelessWidget {
  const _GlobeSection();

  @override
  Widget build(BuildContext context) {
    return _GuideCard(
      icon: Icons.public_rounded,
      iconColor: FlitColors.oceanHighlight,
      title: 'The Globe',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BodyText(
            'Flit renders a real satellite-textured 3D globe — the same one '
            'you see from orbit. Every ocean, landmass, and desert is exactly '
            'where it belongs.',
          ),
          const SizedBox(height: 16),
          // Globe illustration
          Center(
            child: SizedBox(
              width: 200,
              height: 120,
              child: CustomPaint(painter: _GlobeIllustrationPainter()),
            ),
          ),
          const SizedBox(height: 16),
          const _InteractionRow(
            icon: Icons.flight_rounded,
            iconColor: FlitColors.oceanHighlight,
            label: 'Steer your plane',
            description: 'Use the L/R turn buttons to fly in any direction.',
          ),
          const SizedBox(height: 8),
          const _InteractionRow(
            icon: Icons.height_rounded,
            iconColor: FlitColors.gold,
            label: 'Change altitude',
            description:
                'Toggle altitude to switch between globe view and ground level.',
          ),
          const SizedBox(height: 8),
          const _InteractionRow(
            icon: Icons.touch_app_rounded,
            iconColor: FlitColors.accent,
            label: 'Tap to set waypoint',
            description:
                'Tap the globe to set a waypoint — your plane auto-steers toward it.',
          ),
        ],
      ),
    );
  }
}

/// Draws a larger globe with visible latitude/longitude grid and land blobs.
class _GlobeIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;

    // Space ring
    final bgPaint = Paint()
      ..color = FlitColors.space.withOpacity(0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius + 8, bgPaint);

    // Ocean fill
    final oceanPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.25, -0.35),
        colors: [
          FlitColors.oceanShallow,
          FlitColors.ocean,
          FlitColors.oceanDeep,
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, oceanPaint);

    // Clip to circle
    canvas.save();
    final clipPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.clipPath(clipPath);

    // Latitude lines
    final latPaint = Paint()
      ..color = const Color(0x20F0E8DC)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (final frac in [-0.65, -0.35, 0.0, 0.35, 0.65]) {
      final y = center.dy + frac * radius;
      final dy = y - center.dy;
      final halfW = math.sqrt(math.max(0.0, radius * radius - dy * dy));
      // Ellipse to simulate perspective
      final rect = Rect.fromCenter(
        center: Offset(center.dx, y),
        width: halfW * 2,
        height: halfW * 0.3,
      );
      canvas.drawOval(rect, latPaint);
    }

    // Longitude lines (vertical arcs via path)
    final lonPaint = Paint()
      ..color = const Color(0x18F0E8DC)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 6; i++) {
      final angle = (i / 6) * math.pi;
      final path = Path();
      // Draw half-ellipse for each longitude
      final rect = Rect.fromCenter(
        center: center,
        width: radius * 2 * math.sin(angle).abs().clamp(0.1, 1.0) * 0.6 + 1,
        height: radius * 2,
      );
      path.addOval(rect);
      canvas.drawPath(path, lonPaint);
    }

    // Land masses — stylised blobs
    final landPaint = Paint()..color = FlitColors.landMass.withOpacity(0.8);
    final landHighPaint = Paint()
      ..color = FlitColors.landMassHighlight.withOpacity(0.5);

    // Americas
    _drawLandBlob(
      canvas,
      center + Offset(-radius * 0.45, -radius * 0.1),
      18,
      28,
      landPaint,
    );
    _drawLandBlob(
      canvas,
      center + Offset(-radius * 0.5, radius * 0.35),
      12,
      18,
      landPaint,
    );
    // Europe/Africa
    _drawLandBlob(
      canvas,
      center + Offset(radius * 0.05, -radius * 0.2),
      14,
      20,
      landPaint,
    );
    _drawLandBlob(
      canvas,
      center + Offset(radius * 0.08, radius * 0.2),
      13,
      24,
      landPaint,
    );
    // Asia
    _drawLandBlob(
      canvas,
      center + Offset(radius * 0.35, -radius * 0.25),
      26,
      18,
      landPaint,
    );
    // Australia
    _drawLandBlob(
      canvas,
      center + Offset(radius * 0.42, radius * 0.38),
      14,
      10,
      landHighPaint,
    );

    // Snow caps
    final snowPaint = Paint()..color = FlitColors.landSnow.withOpacity(0.6);
    _drawLandBlob(canvas, center + Offset(0, -radius * 0.85), 20, 6, snowPaint);
    _drawLandBlob(canvas, center + Offset(0, radius * 0.88), 28, 7, snowPaint);

    canvas.restore();

    // Atmosphere rim
    final rimPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          FlitColors.atmosphereGlow.withOpacity(0.45),
          FlitColors.atmosphereGlow.withOpacity(0.0),
        ],
        stops: const [0.7, 0.88, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius + 10))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, radius + 2, rimPaint);

    // Specular highlight
    final specPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.5, -0.5),
        colors: [Colors.white.withOpacity(0.18), Colors.transparent],
        stops: const [0.0, 0.6],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, specPaint);

    // Labels
    final labelStyle = TextStyle(
      color: FlitColors.textMuted.withOpacity(0.7),
      fontSize: 9,
      letterSpacing: 0.5,
    );
    _drawLabel(canvas, 'FLY', center + Offset(-radius - 28, 0), labelStyle);
    _drawLabel(canvas, 'ALT', center + Offset(radius + 28, 0), labelStyle);

    // Arrow hints
    final arrowPaint = Paint()
      ..color = FlitColors.textMuted.withOpacity(0.4)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    // Left arrow
    canvas.drawLine(
      center + Offset(-radius - 2, 0),
      center + Offset(-radius - 18, 0),
      arrowPaint,
    );
    // Right arrow
    canvas.drawLine(
      center + Offset(radius + 2, 0),
      center + Offset(radius + 18, 0),
      arrowPaint,
    );
  }

  void _drawLandBlob(
    Canvas canvas,
    Offset center,
    double w,
    double h,
    Paint paint,
  ) {
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: w.toDouble(),
        height: h.toDouble(),
      ),
      paint,
    );
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset position,
    TextStyle style,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, position - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InteractionRow extends StatelessWidget {
  const _InteractionRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.description,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  color: FlitColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Your Mission
// ---------------------------------------------------------------------------

class _MissionSection extends StatelessWidget {
  const _MissionSection();

  @override
  Widget build(BuildContext context) {
    return const _GuideCard(
      icon: Icons.location_searching_rounded,
      iconColor: FlitColors.accent,
      title: 'Your Mission',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BodyText(
            'Each round drops you over a mystery country. A set of clues '
            'trickles in, each one narrowing down the answer. Your job: '
            'identify the country before the clues run out.',
          ),
          SizedBox(height: 16),
          // Clue card illustration
          _ClueCardIllustration(),
          SizedBox(height: 16),
          _BodyText(
            'Clues range from geographic (hemisphere, coastline, climate) '
            'to cultural (language, flag colours, famous landmarks). '
            'The first clue is always vague — the last is almost a giveaway. '
            'Strike early for maximum points.',
          ),
        ],
      ),
    );
  }
}

class _ClueCardIllustration extends StatelessWidget {
  const _ClueCardIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FlitColors.backgroundDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FlitColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.flag_rounded,
                color: FlitColors.accent,
                size: 16,
              ),
              const SizedBox(width: 6),
              const Text(
                'MISSION CLUES',
                style: TextStyle(
                  color: FlitColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: FlitColors.gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: FlitColors.gold.withOpacity(0.4)),
                ),
                child: const Text(
                  '3 / 5',
                  style: TextStyle(
                    color: FlitColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _ClueRow(
            number: 1,
            text: 'Located in the Northern Hemisphere',
            revealed: true,
          ),
          const SizedBox(height: 6),
          const _ClueRow(
            number: 2,
            text: 'Borders the Atlantic Ocean',
            revealed: true,
          ),
          const SizedBox(height: 6),
          const _ClueRow(
            number: 3,
            text: 'Has a monarchy as its government',
            revealed: true,
          ),
          const SizedBox(height: 6),
          const _ClueRow(number: 4, text: '???', revealed: false),
          const SizedBox(height: 6),
          const _ClueRow(number: 5, text: '???', revealed: false),
        ],
      ),
    );
  }
}

class _ClueRow extends StatelessWidget {
  const _ClueRow({
    required this.number,
    required this.text,
    required this.revealed,
  });

  final int number;
  final String text;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: revealed
                ? FlitColors.accent.withOpacity(0.2)
                : FlitColors.cardBorder.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                color: revealed ? FlitColors.accent : FlitColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: revealed ? FlitColors.textSecondary : FlitColors.textMuted,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ),
        if (revealed)
          const Icon(
            Icons.check_circle_outline_rounded,
            color: FlitColors.success,
            size: 14,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Scoring
// ---------------------------------------------------------------------------

class _ScoringSection extends StatelessWidget {
  const _ScoringSection();

  @override
  Widget build(BuildContext context) {
    return const _GuideCard(
      icon: Icons.military_tech_rounded,
      iconColor: FlitColors.gold,
      title: 'Scoring',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BodyText(
            'Speed and accuracy are rewarded. Every second in the air costs '
            'you points. Every extra clue you reveal shaves off your potential '
            'score. Guess wrong and face a distance penalty.',
          ),
          SizedBox(height: 16),
          // Step indicators
          _ScoringStep(
            step: 1,
            color: FlitColors.success,
            label: 'Correct Answer',
            detail: '+1000 base points',
            icon: Icons.check_rounded,
          ),
          SizedBox(height: 8),
          _ScoringStep(
            step: 2,
            color: FlitColors.gold,
            label: 'Speed Bonus',
            detail: 'Up to +500 pts for fast guesses',
            icon: Icons.bolt_rounded,
          ),
          SizedBox(height: 8),
          _ScoringStep(
            step: 3,
            color: FlitColors.oceanHighlight,
            label: 'Clue Penalty',
            detail: '-100 pts per clue revealed after the first',
            icon: Icons.remove_circle_outline_rounded,
          ),
          SizedBox(height: 8),
          _ScoringStep(
            step: 4,
            color: FlitColors.accent,
            label: 'Distance Penalty',
            detail: 'Wrong guess? Penalty scales to distance',
            icon: Icons.social_distance_rounded,
          ),
          SizedBox(height: 16),
          // Score bar illustration
          _ScoreBar(),
        ],
      ),
    );
  }
}

class _ScoringStep extends StatelessWidget {
  const _ScoringStep({
    required this.step,
    required this.color,
    required this.label,
    required this.detail,
    required this.icon,
  });

  final int step;
  final Color color;
  final String label;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Step number badge
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Center(
            child: Text(
              '$step',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label  ',
                  style: const TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: detail,
                  style: const TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FlitColors.backgroundDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FlitColors.cardBorder),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SCORE BREAKDOWN',
            style: TextStyle(
              color: FlitColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 10),
          _ScoreBarRow(
            label: 'Base',
            value: 1000,
            max: 1500,
            color: FlitColors.success,
          ),
          SizedBox(height: 6),
          _ScoreBarRow(
            label: 'Speed',
            value: 380,
            max: 500,
            color: FlitColors.gold,
          ),
          SizedBox(height: 6),
          _ScoreBarRow(
            label: 'Clues',
            value: -200,
            max: 500,
            color: FlitColors.accent,
          ),
          SizedBox(height: 10),
          Divider(color: FlitColors.cardBorder, height: 1),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL',
                style: TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '1,180 pts',
                style: TextStyle(
                  color: FlitColors.gold,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreBarRow extends StatelessWidget {
  const _ScoreBarRow({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  final String label;
  final int value;
  final int max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isNegative = value < 0;
    final fraction = (value.abs() / max).clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: const TextStyle(color: FlitColors.textMuted, fontSize: 11),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Stack(
              children: [
                Container(
                  height: 8,
                  color: FlitColors.cardBorder.withOpacity(0.4),
                ),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(height: 8, color: color.withOpacity(0.7)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 54,
          child: Text(
            '${isNegative ? '-' : '+'}${value.abs()}',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Game Modes
// ---------------------------------------------------------------------------

class _GameModesSection extends StatelessWidget {
  const _GameModesSection();

  static const List<_GameModeData> _modes = [
    _GameModeData(
      icon: Icons.flight_takeoff_rounded,
      iconColor: FlitColors.oceanHighlight,
      name: 'Free Flight',
      tagline: 'No pressure. Just explore.',
      description:
          'Fly wherever you like, identify countries at your own pace, '
          'and learn the globe with no timer and no score pressure.',
    ),
    _GameModeData(
      icon: Icons.school_rounded,
      iconColor: FlitColors.success,
      name: 'Training Sortie',
      tagline: 'Learn the ropes.',
      description:
          'Guided missions with hints and slower pacing. Perfect for '
          'building your geographic knowledge before going competitive.',
    ),
    _GameModeData(
      icon: Icons.calendar_today_rounded,
      iconColor: FlitColors.gold,
      name: 'Daily Scramble',
      tagline: 'One shot. Every day.',
      description:
          'A fresh set of five countries every day, the same for every '
          'player on Earth. Compare your score on the global leaderboard.',
    ),
    _GameModeData(
      icon: Icons.sports_esports_rounded,
      iconColor: FlitColors.accent,
      name: 'Dogfight',
      tagline: 'Head-to-head geography.',
      description:
          'Race a friend or a random opponent to identify the same country '
          'first. First correct answer wins the round. Best of five.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _GuideCard(
      icon: Icons.grid_view_rounded,
      iconColor: FlitColors.accent,
      title: 'Game Modes',
      child: Column(
        children: _modes
            .map(
              (mode) => Padding(
                padding: EdgeInsets.only(bottom: mode == _modes.last ? 0 : 12),
                child: _GameModeCard(data: mode),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _GameModeData {
  const _GameModeData({
    required this.icon,
    required this.iconColor,
    required this.name,
    required this.tagline,
    required this.description,
  });

  final IconData icon;
  final Color iconColor;
  final String name;
  final String tagline;
  final String description;
}

class _GameModeCard extends StatelessWidget {
  const _GameModeCard({required this.data});

  final _GameModeData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FlitColors.backgroundDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: data.iconColor.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: data.iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: data.iconColor.withOpacity(0.3)),
            ),
            child: Icon(data.icon, color: data.iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      data.name,
                      style: const TextStyle(
                        color: FlitColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      data.tagline,
                      style: const TextStyle(
                        color: FlitColors.textMuted,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  data.description,
                  style: const TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6. Controls
// ---------------------------------------------------------------------------

class _ControlsSection extends StatelessWidget {
  const _ControlsSection();

  @override
  Widget build(BuildContext context) {
    return const _GuideCard(
      icon: Icons.gamepad_rounded,
      iconColor: FlitColors.landMassHighlight,
      title: 'Controls',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BodyText(
            'Flit is designed for touchscreens but also works with mouse '
            'and trackpad.',
          ),
          SizedBox(height: 16),
          // Controls diagram
          _ControlsDiagram(),
          SizedBox(height: 16),
          _ControlRow(
            gesture: 'L/R turn buttons',
            icon: Icons.swap_horiz_rounded,
            effect: 'Steer the plane left or right',
          ),
          SizedBox(height: 8),
          _ControlRow(
            gesture: 'Altitude toggle',
            icon: Icons.height_rounded,
            effect: 'Switch between high and low altitude',
          ),
          SizedBox(height: 8),
          _ControlRow(
            gesture: 'Single tap',
            icon: Icons.ads_click_rounded,
            effect: 'Set a navigation waypoint on the globe',
          ),
          SizedBox(height: 8),
          _ControlRow(
            gesture: 'Speed selector',
            icon: Icons.speed_rounded,
            effect: 'Choose slow, medium, or fast flight',
          ),
          SizedBox(height: 20),
          _BodyText('Keyboard shortcuts (desktop & web):'),
          SizedBox(height: 12),
          _ControlRow(
            gesture: '\u2190 / \u2192  Arrow keys',
            icon: Icons.keyboard_rounded,
            effect: 'Steer the plane left or right',
          ),
          SizedBox(height: 8),
          _ControlRow(
            gesture: '\u2191 / \u2193  Arrow keys',
            icon: Icons.keyboard_rounded,
            effect: 'Switch between high and low altitude',
          ),
          SizedBox(height: 8),
          _ControlRow(
            gesture: 'Space bar',
            icon: Icons.space_bar_rounded,
            effect: 'Toggle altitude (same as \u2191/\u2193)',
          ),
          SizedBox(height: 8),
          _ControlRow(
            gesture: '1 / 2 / 3  keys',
            icon: Icons.looks_3_rounded,
            effect: 'Set flight speed: slow, medium, or fast',
          ),
        ],
      ),
    );
  }
}

class _ControlsDiagram extends StatelessWidget {
  const _ControlsDiagram();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: FlitColors.backgroundDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FlitColors.cardBorder),
      ),
      child: CustomPaint(painter: _ControlsDiagramPainter()),
    );
  }
}

class _ControlsDiagramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Draw three gesture zones side by side
    final third = size.width / 3;
    final cy = size.height / 2;

    // --- Zone 1: Drag ---
    final zone1cx = third * 0.5;
    _drawGestureCircle(
      canvas,
      Offset(zone1cx, cy - 8),
      18,
      FlitColors.oceanHighlight,
    );
    // Arrow right
    _drawArrow(
      canvas,
      Offset(zone1cx, cy - 8),
      Offset(zone1cx + 26, cy - 8),
      FlitColors.oceanHighlight,
    );
    _drawLabel(canvas, 'STEER', Offset(zone1cx, cy + 22), FlitColors.textMuted);

    // --- Zone 2: Altitude ---
    final zone2cx = third * 1.5;
    _drawGestureCircle(canvas, Offset(zone2cx, cy - 8), 18, FlitColors.gold);
    // Up/down arrow
    final altPaint = Paint()
      ..color = FlitColors.gold.withOpacity(0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(zone2cx, cy - 20),
      Offset(zone2cx, cy + 4),
      altPaint,
    );
    _drawLabel(canvas, 'ALT', Offset(zone2cx, cy + 22), FlitColors.textMuted);

    // --- Zone 3: Tap ---
    final zone3cx = third * 2.5;
    _drawGestureCircle(canvas, Offset(zone3cx, cy - 8), 18, FlitColors.accent);
    // Ripple rings
    final ripplePaint = Paint()
      ..color = FlitColors.accent.withOpacity(0.3)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(zone3cx, cy - 8), 26, ripplePaint);
    canvas.drawCircle(
      Offset(zone3cx, cy - 8),
      34,
      ripplePaint..color = FlitColors.accent.withOpacity(0.15),
    );
    _drawLabel(canvas, 'TAP', Offset(zone3cx, cy + 22), FlitColors.textMuted);

    // Dividers
    final divPaint = Paint()
      ..color = FlitColors.cardBorder.withOpacity(0.5)
      ..strokeWidth = 0.5;
    canvas.drawLine(
      Offset(third, 12),
      Offset(third, size.height - 12),
      divPaint,
    );
    canvas.drawLine(
      Offset(third * 2, 12),
      Offset(third * 2, size.height - 12),
      divPaint,
    );
  }

  void _drawGestureCircle(Canvas canvas, Offset center, double r, Color color) {
    final paint = Paint()..color = color.withOpacity(0.25);
    canvas.drawCircle(center, r, paint);
    final borderPaint = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, r, borderPaint);
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Color color) {
    final paint = Paint()
      ..color = color.withOpacity(0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(from, to, paint);
    // Arrowhead
    final dir = (to - from);
    final len = dir.distance;
    final unit = Offset(dir.dx / len, dir.dy / len);
    final perp = Offset(-unit.dy, unit.dx);
    final arrowPaint = Paint()..color = color.withOpacity(0.7);
    final arrowPath = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(
        to.dx - unit.dx * 6 + perp.dx * 4,
        to.dy - unit.dy * 6 + perp.dy * 4,
      )
      ..lineTo(
        to.dx - unit.dx * 6 - perp.dx * 4,
        to.dy - unit.dy * 6 - perp.dy * 4,
      )
      ..close();
    canvas.drawPath(arrowPath, arrowPaint);
  }

  void _drawLabel(Canvas canvas, String text, Offset position, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, position - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({
    required this.gesture,
    required this.icon,
    required this.effect,
  });

  final String gesture;
  final IconData icon;
  final String effect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: FlitColors.landMassHighlight, size: 18),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: Text(
            gesture,
            style: const TextStyle(
              color: FlitColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Text(
          '→',
          style: TextStyle(color: FlitColors.textMuted, fontSize: 12),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            effect,
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 7. Tips
// ---------------------------------------------------------------------------

class _TipsSection extends StatelessWidget {
  const _TipsSection();

  static const List<_TipData> _tips = [
    _TipData(
      icon: Icons.horizontal_rule_rounded,
      color: FlitColors.oceanHighlight,
      title: 'Use latitude lines',
      body:
          'The grid lines on the globe mark parallels. Countries near the '
          'equator are tropical; those near the poles are arctic or sub-arctic.',
    ),
    _TipData(
      icon: Icons.landscape_rounded,
      color: FlitColors.landMassHighlight,
      title: 'Look for landmarks',
      body:
          'Large rivers, desert colours, island chains, and distinctive '
          'coastlines can identify a country even before you read the clues.',
    ),
    _TipData(
      icon: Icons.read_more_rounded,
      color: FlitColors.gold,
      title: 'Read all visible clues',
      body:
          'Don\'t guess on the first clue alone. Even two clues can '
          'dramatically narrow down the answer and save you a wrong-guess penalty.',
    ),
    _TipData(
      icon: Icons.bolt_rounded,
      color: FlitColors.accent,
      title: 'Balance speed and accuracy',
      body:
          'A wrong guess hurts more than a slow right one. If you\'re '
          'unsure, reveal one more clue rather than gambling on a guess.',
    ),
    _TipData(
      icon: Icons.map_rounded,
      color: FlitColors.atmosphereGlow,
      title: 'Study the globe in Free Flight',
      body:
          'Spend time in Free Flight mode exploring regions you find '
          'tricky. Geography is a skill — practice pays off in Daily Scramble.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _GuideCard(
      icon: Icons.tips_and_updates_rounded,
      iconColor: FlitColors.gold,
      title: 'Tips & Tricks',
      child: Column(
        children: List.generate(
          _tips.length,
          (i) => Padding(
            padding: EdgeInsets.only(bottom: i < _tips.length - 1 ? 12 : 0),
            child: _TipCard(data: _tips[i], index: i),
          ),
        ),
      ),
    );
  }
}

class _TipData {
  const _TipData({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.data, required this.index});

  final _TipData data;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Number + icon stack
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: data.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: data.color.withOpacity(0.3)),
              ),
              child: Icon(data.icon, color: data.color, size: 18),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.title,
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                data.body,
                style: const TextStyle(
                  color: FlitColors.textSecondary,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
