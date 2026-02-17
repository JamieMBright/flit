import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../daily/daily_challenge_screen.dart';
import '../debug/debug_screen.dart';
import '../friends/friends_screen.dart';
import '../guide/gameplay_guide_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../play/practice_screen.dart';
import '../play/region_select_screen.dart';
import '../profile/profile_screen.dart';
import '../shop/shop_screen.dart';

/// Home screen with animated map background and menu overlay.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Animated map background
            _AnimatedMapBackground(animation: _animController),

            // Menu overlay
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    // Title block with paper plane accent
                    _buildTitle(),
                    const Spacer(flex: 2),
                    _buildMenuButtons(context),
                    const Spacer(flex: 1),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildTitle() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Paper plane above title
          Transform.rotate(
            angle: -0.3,
            child: const Icon(
              Icons.flight,
              color: FlitColors.accent,
              size: 32,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'FLIT',
            style: TextStyle(
              color: FlitColors.textPrimary,
              fontSize: 56,
              fontWeight: FontWeight.w900,
              letterSpacing: 14,
              shadows: [
                Shadow(
                  color: Color(0x60000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Tagline with decorative dashes
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 1,
                color: FlitColors.gold.withOpacity(0.4),
              ),
              const SizedBox(width: 10),
              const Text(
                'A GEOGRAPHICAL ADVENTURE',
                style: TextStyle(
                  color: FlitColors.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 24,
                height: 1,
                color: FlitColors.gold.withOpacity(0.4),
              ),
            ],
          ),
        ],
      );

  Widget _buildMenuButtons(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Primary PLAY button with glow
          _PlayButton(
            onTap: () => _showGameModes(context),
          ),
          const SizedBox(height: 10),
          // Secondary buttons in a 2x2 grid for variety
          Row(
            children: [
              Expanded(
                child: _MenuTile(
                  label: 'Leaderboard',
                  icon: Icons.leaderboard_rounded,
                  onTap: () => _navigateSafely(
                    context,
                    const LeaderboardScreen(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MenuTile(
                  label: 'Profile',
                  icon: Icons.person_rounded,
                  onTap: () => _navigateSafely(
                    context,
                    const ProfileScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MenuTile(
                  label: 'Shop',
                  icon: Icons.storefront_rounded,
                  onTap: () => _navigateSafely(
                    context,
                    const ShopScreen(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MenuTile(
                  label: 'How to Play',
                  icon: Icons.menu_book_rounded,
                  onTap: () => _navigateSafely(
                    context,
                    const GameplayGuideScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _MenuButton(
            label: 'Debug',
            icon: Icons.bug_report_rounded,
            onTap: () => _navigateSafely(
              context,
              const DebugScreen(),
            ),
          ),
        ],
      );

  /// Safely navigate to a new screen with error handling.
  Future<void> _navigateSafely(
      BuildContext context, Widget destination) async {
    try {
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => destination,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Navigation error: $e\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Something went wrong opening that screen. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Close the bottom sheet and navigate to [destination].
  void _closeSheetAndNavigate(
    BuildContext sheetContext,
    Widget destination,
  ) {
    try {
      Navigator.of(sheetContext)
        ..pop()
        ..push(
          MaterialPageRoute<void>(builder: (_) => destination),
        );
    } catch (e, stackTrace) {
      debugPrint('Navigation error: $e\n$stackTrace');
    }
  }

  void _showGameModes(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: FlitColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'CHOOSE YOUR FLIGHT',
              style: TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 20),
            _GameModeCard(
              title: 'Free Flight',
              subtitle: 'Explore the world at your own pace',
              icon: Icons.flight_takeoff,
              onTap: () => _closeSheetAndNavigate(
                ctx,
                const RegionSelectScreen(),
              ),
            ),
            const SizedBox(height: 10),
            _GameModeCard(
              title: 'Training Sortie',
              subtitle: 'Practice without rank pressure',
              icon: Icons.school_rounded,
              onTap: () => _closeSheetAndNavigate(
                ctx,
                const PracticeScreen(),
              ),
            ),
            const SizedBox(height: 10),
            _GameModeCard(
              title: 'Daily Scramble',
              subtitle: "Today's challenge — compete for glory",
              icon: Icons.today_rounded,
              isHighlighted: true,
              onTap: () => _closeSheetAndNavigate(
                ctx,
                const DailyChallengeScreen(),
              ),
            ),
            const SizedBox(height: 10),
            _GameModeCard(
              title: 'Dogfight',
              subtitle: 'Challenge your friends head-to-head',
              icon: Icons.people_rounded,
              onTap: () => _closeSheetAndNavigate(
                ctx,
                const FriendsScreen(),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Animated map background ──────────────────────────────────────────────

class _AnimatedMapBackground extends StatelessWidget {
  const _AnimatedMapBackground({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: animation,
        builder: (context, child) => SizedBox.expand(
          child: CustomPaint(
            painter: _MapBackgroundPainter(animation.value),
          ),
        ),
      );
}

class _MapBackgroundPainter extends CustomPainter {
  _MapBackgroundPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.isFinite) return;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Ocean gradient — richer, with more depth
    final oceanGradient = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0.0, -0.2),
        radius: 1.2,
        colors: [
          FlitColors.ocean,
          FlitColors.oceanDeep,
          Color(0xFF0F2530),
        ],
        stops: [0.0, 0.6, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, oceanGradient);

    // Stars / dots scattered across the background
    final starPaint = Paint()..color = FlitColors.textPrimary;
    final rng = Random(42);
    for (var i = 0; i < 40; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      // Subtle twinkle based on animation
      final twinkle = 0.03 + 0.04 * sin(t * 2 * pi + i * 0.7);
      starPaint.color = FlitColors.textPrimary.withOpacity(twinkle);
      canvas.drawCircle(Offset(x, y), 1.0 + rng.nextDouble() * 0.5, starPaint);
    }

    // Latitude / longitude grid (curved to suggest a globe projection)
    final gridPaint = Paint()
      ..color = FlitColors.gridLine
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const gridCount = 10;
    for (var i = 1; i < gridCount; i++) {
      final y = size.height * i / gridCount;
      // Slightly curved horizontal lines
      final path = Path()
        ..moveTo(0, y)
        ..quadraticBezierTo(size.width / 2, y - 6 + 12 * (i / gridCount),
            size.width, y);
      canvas.drawPath(path, gridPaint);

      final x = size.width * i / gridCount;
      final vPath = Path()
        ..moveTo(x, 0)
        ..quadraticBezierTo(
            x - 4 + 8 * (i / gridCount), size.height / 2, x, size.height);
      canvas.drawPath(vPath, gridPaint);
    }

    // Continent silhouettes — more recognisable shapes with terrain layers
    final landPaint = Paint()..color = FlitColors.landMass.withOpacity(0.18);
    final terrainPaint = Paint()..color = FlitColors.landMass.withOpacity(0.10);
    final coastPaint = Paint()
      ..color = FlitColors.coastline.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final coastGlowPaint = Paint()
      ..color = FlitColors.oceanHighlight.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    // Europe + Mediterranean
    final europe = Path()
      ..moveTo(size.width * 0.47, size.height * 0.12)
      ..cubicTo(size.width * 0.50, size.height * 0.10, size.width * 0.55,
          size.height * 0.11, size.width * 0.56, size.height * 0.14)
      ..cubicTo(size.width * 0.57, size.height * 0.18, size.width * 0.54,
          size.height * 0.20, size.width * 0.52, size.height * 0.22)
      ..quadraticBezierTo(size.width * 0.55, size.height * 0.24,
          size.width * 0.53, size.height * 0.27)
      ..quadraticBezierTo(size.width * 0.50, size.height * 0.28,
          size.width * 0.48, size.height * 0.26)
      ..quadraticBezierTo(size.width * 0.45, size.height * 0.22,
          size.width * 0.44, size.height * 0.17)
      ..close();
    canvas.drawPath(europe, coastGlowPaint);
    canvas.drawPath(europe, landPaint);
    canvas.drawPath(europe, coastPaint);

    // Africa
    final africa = Path()
      ..moveTo(size.width * 0.47, size.height * 0.30)
      ..cubicTo(size.width * 0.52, size.height * 0.28, size.width * 0.55,
          size.height * 0.32, size.width * 0.54, size.height * 0.38)
      ..cubicTo(size.width * 0.56, size.height * 0.44, size.width * 0.54,
          size.height * 0.52, size.width * 0.51, size.height * 0.58)
      ..quadraticBezierTo(size.width * 0.49, size.height * 0.62,
          size.width * 0.47, size.height * 0.58)
      ..cubicTo(size.width * 0.44, size.height * 0.52, size.width * 0.43,
          size.height * 0.44, size.width * 0.44, size.height * 0.36)
      ..close();
    canvas.drawPath(africa, coastGlowPaint);
    canvas.drawPath(africa, landPaint);
    canvas.drawPath(africa, terrainPaint);
    canvas.drawPath(africa, coastPaint);

    // North America
    final northAmerica = Path()
      ..moveTo(size.width * 0.15, size.height * 0.12)
      ..cubicTo(size.width * 0.22, size.height * 0.08, size.width * 0.30,
          size.height * 0.10, size.width * 0.32, size.height * 0.14)
      ..cubicTo(size.width * 0.33, size.height * 0.18, size.width * 0.30,
          size.height * 0.24, size.width * 0.28, size.height * 0.28)
      ..quadraticBezierTo(size.width * 0.27, size.height * 0.32,
          size.width * 0.24, size.height * 0.34)
      ..quadraticBezierTo(size.width * 0.22, size.height * 0.30,
          size.width * 0.20, size.height * 0.28)
      ..cubicTo(size.width * 0.16, size.height * 0.24, size.width * 0.13,
          size.height * 0.20, size.width * 0.13, size.height * 0.16)
      ..close();
    canvas.drawPath(northAmerica, coastGlowPaint);
    canvas.drawPath(northAmerica, landPaint);
    canvas.drawPath(northAmerica, coastPaint);

    // South America
    final southAmerica = Path()
      ..moveTo(size.width * 0.26, size.height * 0.38)
      ..cubicTo(size.width * 0.29, size.height * 0.36, size.width * 0.30,
          size.height * 0.40, size.width * 0.29, size.height * 0.48)
      ..cubicTo(size.width * 0.28, size.height * 0.56, size.width * 0.26,
          size.height * 0.64, size.width * 0.23, size.height * 0.70)
      ..quadraticBezierTo(size.width * 0.21, size.height * 0.68,
          size.width * 0.21, size.height * 0.62)
      ..cubicTo(size.width * 0.20, size.height * 0.54, size.width * 0.22,
          size.height * 0.46, size.width * 0.24, size.height * 0.40)
      ..close();
    canvas.drawPath(southAmerica, coastGlowPaint);
    canvas.drawPath(southAmerica, landPaint);
    canvas.drawPath(southAmerica, terrainPaint);
    canvas.drawPath(southAmerica, coastPaint);

    // Asia
    final asia = Path()
      ..moveTo(size.width * 0.58, size.height * 0.10)
      ..cubicTo(size.width * 0.65, size.height * 0.08, size.width * 0.76,
          size.height * 0.10, size.width * 0.82, size.height * 0.16)
      ..cubicTo(size.width * 0.86, size.height * 0.20, size.width * 0.85,
          size.height * 0.28, size.width * 0.80, size.height * 0.34)
      ..cubicTo(size.width * 0.76, size.height * 0.38, size.width * 0.68,
          size.height * 0.40, size.width * 0.62, size.height * 0.36)
      ..cubicTo(size.width * 0.58, size.height * 0.30, size.width * 0.56,
          size.height * 0.22, size.width * 0.56, size.height * 0.15)
      ..close();
    canvas.drawPath(asia, coastGlowPaint);
    canvas.drawPath(asia, landPaint);
    canvas.drawPath(asia, terrainPaint);
    canvas.drawPath(asia, coastPaint);

    // Australia
    final australia = Path()
      ..moveTo(size.width * 0.74, size.height * 0.52)
      ..cubicTo(size.width * 0.78, size.height * 0.50, size.width * 0.84,
          size.height * 0.52, size.width * 0.86, size.height * 0.57)
      ..cubicTo(size.width * 0.87, size.height * 0.62, size.width * 0.84,
          size.height * 0.68, size.width * 0.80, size.height * 0.70)
      ..cubicTo(size.width * 0.76, size.height * 0.69, size.width * 0.73,
          size.height * 0.64, size.width * 0.73, size.height * 0.58)
      ..close();
    canvas.drawPath(australia, coastGlowPaint);
    canvas.drawPath(australia, landPaint);
    canvas.drawPath(australia, coastPaint);

    // City light dots on continents (animated twinkle)
    final cityLightPaint = Paint();
    const cityPositions = [
      // Europe
      [0.50, 0.18], [0.52, 0.20], [0.48, 0.16],
      // Africa
      [0.49, 0.36], [0.51, 0.42], [0.48, 0.48],
      // North America
      [0.22, 0.18], [0.26, 0.22], [0.28, 0.26],
      // South America
      [0.26, 0.48], [0.24, 0.56],
      // Asia
      [0.68, 0.20], [0.74, 0.24], [0.78, 0.28], [0.64, 0.32],
      // Australia
      [0.80, 0.62], [0.78, 0.58],
    ];
    for (var i = 0; i < cityPositions.length; i++) {
      final pos = cityPositions[i];
      final x = size.width * pos[0];
      final y = size.height * pos[1];
      final twinkle = 0.15 + 0.2 * sin(t * 2 * pi * 1.5 + i * 1.3);
      cityLightPaint.color = FlitColors.gold.withOpacity(twinkle);
      canvas.drawCircle(Offset(x, y), 1.5, cityLightPaint);
    }

    // Animated dashed flight path (arc across the screen)
    _drawFlightPath(canvas, size);

    // Compass rose in bottom corner
    _drawCompassRose(canvas, size);

    // Overlay gradient for text readability
    final overlayGradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          FlitColors.backgroundDark.withOpacity(0.5),
          FlitColors.backgroundDark.withOpacity(0.1),
          FlitColors.backgroundDark.withOpacity(0.7),
        ],
        stops: const [0.0, 0.3, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, overlayGradient);
  }

  void _drawFlightPath(Canvas canvas, Size size) {
    // Dashed arc flight path that slowly animates
    final pathPaint = Paint()
      ..color = FlitColors.accent.withOpacity(0.25)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.65)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.20,
        size.width * 0.65,
        size.height * 0.15,
        size.width * 0.88,
        size.height * 0.40,
      );

    // Draw dashed path
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      final totalLength = metric.length;
      const dashLen = 8.0;
      const gapLen = 6.0;
      var distance = (t * totalLength * 0.3) % (dashLen + gapLen);
      while (distance < totalLength) {
        final start = distance;
        final end = (distance + dashLen).clamp(0.0, totalLength);
        final extracted = metric.extractPath(start, end);
        canvas.drawPath(extracted, pathPaint);
        distance += dashLen + gapLen;
      }
    }

    // Animated plane dot at the path position
    final planePos = t % 1.0;
    for (final metric in pathMetrics) {
      final tangent = metric.getTangentForOffset(metric.length * planePos);
      if (tangent != null) {
        final planePaint = Paint()..color = FlitColors.accent.withOpacity(0.7);
        canvas.drawCircle(tangent.position, 4, planePaint);
        // Subtle contrail behind
        final contrailPaint = Paint()
          ..color = FlitColors.textPrimary.withOpacity(0.15);
        final contrailOffset = metric.length * planePos - 20;
        if (contrailOffset > 0) {
          final ct =
              metric.getTangentForOffset(contrailOffset.clamp(0, metric.length));
          if (ct != null) {
            canvas.drawLine(ct.position, tangent.position, contrailPaint);
          }
        }
      }
    }
  }

  void _drawCompassRose(Canvas canvas, Size size) {
    final cx = size.width * 0.88;
    final cy = size.height * 0.82;
    const r = 18.0;
    final paint = Paint()
      ..color = FlitColors.gold.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Outer circle
    canvas.drawCircle(Offset(cx, cy), r, paint);

    // Cardinal direction lines
    final linePaint = Paint()
      ..color = FlitColors.gold.withOpacity(0.2)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    // N-S
    canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r), linePaint);
    // E-W
    canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy), linePaint);
    // Diagonals
    const d = r * 0.6;
    canvas.drawLine(
        Offset(cx - d, cy - d), Offset(cx + d, cy + d), linePaint);
    canvas.drawLine(
        Offset(cx + d, cy - d), Offset(cx - d, cy + d), linePaint);

    // North arrow tip (brighter)
    final northPaint = Paint()
      ..color = FlitColors.accent.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    final northArrow = Path()
      ..moveTo(cx, cy - r - 2)
      ..lineTo(cx - 3, cy - r + 5)
      ..lineTo(cx + 3, cy - r + 5)
      ..close();
    canvas.drawPath(northArrow, northPaint);
  }

  @override
  bool shouldRepaint(covariant _MapBackgroundPainter oldDelegate) =>
      oldDelegate.t != t;
}

// ─── Menu widgets ─────────────────────────────────────────────────────────

/// Big PLAY button with a subtle glow effect.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: FlitColors.accent.withOpacity(0.25),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Material(
          color: FlitColors.accent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    color: FlitColors.textPrimary,
                    size: 28,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'PLAY',
                    style: TextStyle(
                      color: FlitColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Square-ish tile for secondary menu items (2x2 grid).
class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: FlitColors.cardBackground.withOpacity(0.85),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: FlitColors.cardBorder.withOpacity(0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: FlitColors.textSecondary, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      color: FlitColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Full-width menu button for lower-priority items.
class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: FlitColors.cardBackground.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: FlitColors.cardBorder.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: FlitColors.textMuted, size: 18),
                const SizedBox(width: 8),
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _GameModeCard extends StatelessWidget {
  const _GameModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isHighlighted = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) => Material(
        color: isHighlighted
            ? FlitColors.accent.withOpacity(0.15)
            : FlitColors.backgroundMid,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isHighlighted
                    ? FlitColors.accent.withOpacity(0.5)
                    : FlitColors.cardBorder,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? FlitColors.accent.withOpacity(0.2)
                        : FlitColors.backgroundDark.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: isHighlighted
                        ? FlitColors.accent
                        : FlitColors.textPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: FlitColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: FlitColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: FlitColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      );
}
