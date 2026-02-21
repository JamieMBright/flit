import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_version.dart';
import '../../data/providers/account_provider.dart';
import '../../core/config/admin_config.dart';
import '../../core/theme/flit_colors.dart';
import '../admin/admin_screen.dart';
import '../daily/daily_challenge_screen.dart';
import '../friends/friends_screen.dart';
import '../guide/gameplay_guide_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../matchmaking/find_challenger_screen.dart';
import '../play/practice_screen.dart';
import '../play/region_select_screen.dart';
import '../profile/profile_screen.dart';
import '../shop/shop_screen.dart';

/// Home screen with animated map background and menu overlay.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
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
                // Version number
                const Text(
                  appVersion,
                  style: TextStyle(
                    color: FlitColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
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
        child: const Icon(Icons.flight, color: FlitColors.accent, size: 32),
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
      // Daily streak stats card
      const _DailyStreakCard(),
      const SizedBox(height: 10),
      // Primary PLAY button with glow
      _PlayButton(onTap: () => _showGameModes(context)),
      const SizedBox(height: 10),
      // Secondary buttons in a 2x2 grid for variety
      Row(
        children: [
          Expanded(
            child: _MenuTile(
              label: 'Leaderboard',
              icon: Icons.leaderboard_rounded,
              onTap: () => _navigateSafely(context, const LeaderboardScreen()),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MenuTile(
              label: 'Profile',
              icon: Icons.person_rounded,
              onTap: () => _navigateSafely(context, const ProfileScreen()),
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
              onTap: () => _navigateSafely(context, const ShopScreen()),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MenuTile(
              label: 'How to Play',
              icon: Icons.menu_book_rounded,
              onTap: () =>
                  _navigateSafely(context, const GameplayGuideScreen()),
            ),
          ),
        ],
      ),
      if (AdminConfig.isCurrentUserAdmin) ...[
        const SizedBox(height: 10),
        _MenuButton(
          label: 'Admin',
          icon: Icons.admin_panel_settings,
          onTap: () => _navigateSafely(context, const AdminScreen()),
        ),
      ],
    ],
  );

  /// Safely navigate to a new screen with error handling.
  Future<void> _navigateSafely(BuildContext context, Widget destination) async {
    try {
      if (!context.mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (context) => destination));
    } catch (e, stackTrace) {
      debugPrint('Navigation error: $e\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Something went wrong opening that screen. Please try again.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Close the bottom sheet and navigate to [destination].
  void _closeSheetAndNavigate(BuildContext sheetContext, Widget destination) {
    try {
      Navigator.of(sheetContext)
        ..pop()
        ..push(MaterialPageRoute<void>(builder: (_) => destination));
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
              onTap: () =>
                  _closeSheetAndNavigate(ctx, const RegionSelectScreen()),
            ),
            const SizedBox(height: 10),
            _GameModeCard(
              title: 'Training Sortie',
              subtitle: 'Practice without rank pressure',
              icon: Icons.school_rounded,
              onTap: () => _closeSheetAndNavigate(ctx, const PracticeScreen()),
            ),
            const SizedBox(height: 10),
            _GameModeCard(
              title: 'Daily Scramble',
              subtitle: "Today's challenge — compete for glory",
              icon: Icons.today_rounded,
              isHighlighted: true,
              onTap: () =>
                  _closeSheetAndNavigate(ctx, const DailyChallengeScreen()),
            ),
            const SizedBox(height: 10),
            _GameModeCard(
              title: 'Dogfight',
              subtitle: 'Challenge your friends head-to-head',
              icon: Icons.people_rounded,
              onTap: () => _closeSheetAndNavigate(ctx, const FriendsScreen()),
            ),
            const SizedBox(height: 10),
            _GameModeCard(
              title: 'Find a Challenger',
              subtitle: 'Matchmake against pilots at your level',
              icon: Icons.radar,
              onTap: () =>
                  _closeSheetAndNavigate(ctx, const FindChallengerScreen()),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Animated globe background ────────────────────────────────────────────

class _AnimatedMapBackground extends StatelessWidget {
  const _AnimatedMapBackground({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (context, child) => SizedBox.expand(
      child: CustomPaint(painter: _GlobeBackgroundPainter(animation.value)),
    ),
  );
}

class _GlobeBackgroundPainter extends CustomPainter {
  _GlobeBackgroundPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.isFinite) return;

    final w = size.width;
    final h = size.height;
    final rect = Rect.fromLTWH(0, 0, w, h);

    // ── Deep space background ──
    final spacePaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0.0, -0.3),
        radius: 1.4,
        colors: [Color(0xFF0D1F2D), FlitColors.space, Color(0xFF050D14)],
        stops: [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, spacePaint);

    // ── Starfield — varied sizes and brightness ──
    final starPaint = Paint();
    final rng = Random(42);
    for (var i = 0; i < 80; i++) {
      final x = rng.nextDouble() * w;
      final y = rng.nextDouble() * h;
      final brightness = 0.02 + 0.06 * sin(t * 2 * pi + i * 0.9);
      final radius = 0.4 + rng.nextDouble() * 1.0;
      starPaint.color = FlitColors.textPrimary.withOpacity(brightness);
      canvas.drawCircle(Offset(x, y), radius, starPaint);
    }
    // A few brighter stars
    for (var i = 0; i < 8; i++) {
      final x = rng.nextDouble() * w;
      final y = rng.nextDouble() * h;
      final brightness = 0.10 + 0.12 * sin(t * 2 * pi * 0.7 + i * 2.1);
      starPaint.color = FlitColors.textPrimary.withOpacity(brightness);
      canvas.drawCircle(Offset(x, y), 1.5, starPaint);
    }

    // ── Globe — a large circle in the upper-center ──
    final globeCx = w * 0.5;
    final globeCy = h * 0.32;
    final globeR = w * 0.42;
    final globeCenter = Offset(globeCx, globeCy);

    // Drop shadow below globe for 3D depth
    final dropShadow = Paint()
      ..color = const Color(0xFF000000).withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(globeCx + 4, globeCy + globeR * 0.95),
        width: globeR * 1.2,
        height: globeR * 0.15,
      ),
      dropShadow,
    );

    // Atmospheric glow around globe (soft outer ring)
    final atmosphereGlow = Paint()
      ..color = FlitColors.atmosphereGlow.withOpacity(0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32);
    canvas.drawCircle(globeCenter, globeR + 24, atmosphereGlow);

    // Secondary warm glow on the lit side
    final warmGlow = Paint()
      ..color = const Color(0xFF4488CC).withOpacity(0.04)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    canvas.drawCircle(
      Offset(globeCx - globeR * 0.2, globeCy - globeR * 0.2),
      globeR * 0.8,
      warmGlow,
    );

    // Globe ocean fill — 3D lit sphere with blobular organic feel
    final globeOcean = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        radius: 1.1,
        colors: [
          const Color(0xFF1A6B8A).withOpacity(0.65),
          FlitColors.ocean.withOpacity(0.55),
          FlitColors.oceanDeep.withOpacity(0.50),
          const Color(0xFF061520).withOpacity(0.55),
        ],
        stops: const [0.0, 0.3, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: globeCenter, radius: globeR));
    canvas.drawCircle(globeCenter, globeR, globeOcean);

    // Clip globe contents
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: globeCenter, radius: globeR)),
    );

    // ── 3D sphere shading — lit from upper-left ──
    // Dark shadow on lower-right gives depth
    final sphereShadow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.4, 0.5),
        radius: 0.9,
        colors: [Colors.transparent, const Color(0xFF000000).withOpacity(0.25)],
        stops: const [0.3, 1.0],
      ).createShader(Rect.fromCircle(center: globeCenter, radius: globeR));
    canvas.drawCircle(globeCenter, globeR, sphereShadow);

    // Specular highlight — bright spot upper-left
    final specular = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.45, -0.5),
        radius: 0.5,
        colors: [const Color(0xFF88CCFF).withOpacity(0.18), Colors.transparent],
      ).createShader(Rect.fromCircle(center: globeCenter, radius: globeR));
    canvas.drawCircle(globeCenter, globeR, specular);

    // Continent silhouettes on the globe
    final landPaint = Paint()..color = FlitColors.landMass.withOpacity(0.38);
    final coastPaint = Paint()
      ..color = FlitColors.coastline.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final coastGlow = Paint()
      ..color = FlitColors.oceanHighlight.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    void drawContinent(Path path) {
      canvas.drawPath(path, coastGlow);
      canvas.drawPath(path, landPaint);
      canvas.drawPath(path, coastPaint);
    }

    // Europe (relative to globe center)
    final europe = Path()
      ..moveTo(globeCx + globeR * 0.00, globeCy - globeR * 0.42)
      ..cubicTo(
        globeCx + globeR * 0.08,
        globeCy - globeR * 0.48,
        globeCx + globeR * 0.18,
        globeCy - globeR * 0.44,
        globeCx + globeR * 0.20,
        globeCy - globeR * 0.36,
      )
      ..cubicTo(
        globeCx + globeR * 0.22,
        globeCy - globeR * 0.28,
        globeCx + globeR * 0.16,
        globeCy - globeR * 0.22,
        globeCx + globeR * 0.10,
        globeCy - globeR * 0.18,
      )
      ..quadraticBezierTo(
        globeCx + globeR * 0.05,
        globeCy - globeR * 0.24,
        globeCx - globeR * 0.02,
        globeCy - globeR * 0.30,
      )
      ..close();
    drawContinent(europe);

    // Africa
    final africa = Path()
      ..moveTo(globeCx + globeR * 0.02, globeCy - globeR * 0.14)
      ..cubicTo(
        globeCx + globeR * 0.10,
        globeCy - globeR * 0.18,
        globeCx + globeR * 0.18,
        globeCy - globeR * 0.08,
        globeCx + globeR * 0.16,
        globeCy + globeR * 0.08,
      )
      ..cubicTo(
        globeCx + globeR * 0.14,
        globeCy + globeR * 0.22,
        globeCx + globeR * 0.06,
        globeCy + globeR * 0.32,
        globeCx - globeR * 0.02,
        globeCy + globeR * 0.24,
      )
      ..cubicTo(
        globeCx - globeR * 0.06,
        globeCy + globeR * 0.14,
        globeCx - globeR * 0.04,
        globeCy - globeR * 0.02,
        globeCx + globeR * 0.02,
        globeCy - globeR * 0.14,
      )
      ..close();
    drawContinent(africa);

    // North America (left side of globe)
    final nAmerica = Path()
      ..moveTo(globeCx - globeR * 0.50, globeCy - globeR * 0.38)
      ..cubicTo(
        globeCx - globeR * 0.40,
        globeCy - globeR * 0.48,
        globeCx - globeR * 0.24,
        globeCy - globeR * 0.44,
        globeCx - globeR * 0.18,
        globeCy - globeR * 0.34,
      )
      ..cubicTo(
        globeCx - globeR * 0.14,
        globeCy - globeR * 0.24,
        globeCx - globeR * 0.20,
        globeCy - globeR * 0.12,
        globeCx - globeR * 0.28,
        globeCy - globeR * 0.06,
      )
      ..quadraticBezierTo(
        globeCx - globeR * 0.36,
        globeCy - globeR * 0.10,
        globeCx - globeR * 0.44,
        globeCy - globeR * 0.18,
      )
      ..cubicTo(
        globeCx - globeR * 0.52,
        globeCy - globeR * 0.24,
        globeCx - globeR * 0.54,
        globeCy - globeR * 0.32,
        globeCx - globeR * 0.50,
        globeCy - globeR * 0.38,
      )
      ..close();
    drawContinent(nAmerica);

    // South America
    final sAmerica = Path()
      ..moveTo(globeCx - globeR * 0.22, globeCy + globeR * 0.02)
      ..cubicTo(
        globeCx - globeR * 0.16,
        globeCy - globeR * 0.04,
        globeCx - globeR * 0.10,
        globeCy + globeR * 0.04,
        globeCx - globeR * 0.12,
        globeCy + globeR * 0.18,
      )
      ..cubicTo(
        globeCx - globeR * 0.14,
        globeCy + globeR * 0.32,
        globeCx - globeR * 0.20,
        globeCy + globeR * 0.44,
        globeCx - globeR * 0.28,
        globeCy + globeR * 0.48,
      )
      ..quadraticBezierTo(
        globeCx - globeR * 0.30,
        globeCy + globeR * 0.38,
        globeCx - globeR * 0.26,
        globeCy + globeR * 0.18,
      )
      ..close();
    drawContinent(sAmerica);

    // Asia (right side of globe)
    final asia = Path()
      ..moveTo(globeCx + globeR * 0.22, globeCy - globeR * 0.46)
      ..cubicTo(
        globeCx + globeR * 0.36,
        globeCy - globeR * 0.50,
        globeCx + globeR * 0.52,
        globeCy - globeR * 0.42,
        globeCx + globeR * 0.56,
        globeCy - globeR * 0.28,
      )
      ..cubicTo(
        globeCx + globeR * 0.58,
        globeCy - globeR * 0.16,
        globeCx + globeR * 0.50,
        globeCy - globeR * 0.04,
        globeCx + globeR * 0.36,
        globeCy - globeR * 0.08,
      )
      ..cubicTo(
        globeCx + globeR * 0.26,
        globeCy - globeR * 0.14,
        globeCx + globeR * 0.22,
        globeCy - globeR * 0.28,
        globeCx + globeR * 0.22,
        globeCy - globeR * 0.46,
      )
      ..close();
    drawContinent(asia);

    // Australia (lower-right of globe)
    final australia = Path()
      ..moveTo(globeCx + globeR * 0.38, globeCy + globeR * 0.18)
      ..cubicTo(
        globeCx + globeR * 0.46,
        globeCy + globeR * 0.14,
        globeCx + globeR * 0.56,
        globeCy + globeR * 0.20,
        globeCx + globeR * 0.54,
        globeCy + globeR * 0.32,
      )
      ..cubicTo(
        globeCx + globeR * 0.52,
        globeCy + globeR * 0.40,
        globeCx + globeR * 0.44,
        globeCy + globeR * 0.42,
        globeCx + globeR * 0.38,
        globeCy + globeR * 0.36,
      )
      ..cubicTo(
        globeCx + globeR * 0.34,
        globeCy + globeR * 0.30,
        globeCx + globeR * 0.34,
        globeCy + globeR * 0.22,
        globeCx + globeR * 0.38,
        globeCy + globeR * 0.18,
      )
      ..close();
    drawContinent(australia);

    // City lights (golden dots twinkling on continents)
    final cityPaint = Paint();
    const cities = [
      // Europe
      [0.06, -0.32], [0.10, -0.28], [0.14, -0.34],
      // Africa
      [0.06, 0.00], [0.10, 0.12], [0.02, 0.18],
      // N. America
      [-0.30, -0.30], [-0.24, -0.22], [-0.36, -0.26],
      // S. America
      [-0.16, 0.14], [-0.22, 0.30],
      // Asia
      [0.36, -0.36], [0.44, -0.24], [0.50, -0.16], [0.30, -0.20],
      // Australia
      [0.46, 0.28], [0.42, 0.34],
    ];
    for (var i = 0; i < cities.length; i++) {
      final cx = globeCx + globeR * cities[i][0];
      final cy = globeCy + globeR * cities[i][1];
      final twinkle = 0.12 + 0.22 * sin(t * 2 * pi * 1.5 + i * 1.4);
      cityPaint.color = FlitColors.gold.withOpacity(twinkle);
      canvas.drawCircle(Offset(cx, cy), 1.5, cityPaint);
    }

    canvas.restore(); // End globe clip

    // ── Atmospheric rim highlight ──
    // Bright edge on the sunlit side (upper-left)
    final rimPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.3),
        radius: 1.0,
        colors: [
          Colors.transparent,
          Colors.transparent,
          FlitColors.atmosphereGlow.withOpacity(0.12),
          Colors.transparent,
        ],
        stops: const [0.0, 0.88, 0.96, 1.0],
      ).createShader(Rect.fromCircle(center: globeCenter, radius: globeR + 2));
    canvas.drawCircle(globeCenter, globeR + 2, rimPaint);

    // Globe edge (subtle ring)
    final edgePaint = Paint()
      ..color = FlitColors.oceanHighlight.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(globeCenter, globeR, edgePaint);

    // ── Animated flight arc across the globe ──
    _drawFlightArc(canvas, size, globeCenter, globeR);

    // ── Compass rose in bottom corner ──
    _drawCompassRose(canvas, size);

    // ── Overlay gradient for text readability ──
    final overlayGradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          FlitColors.space.withOpacity(0.4),
          Colors.transparent,
          FlitColors.space.withOpacity(0.85),
        ],
        stops: const [0.0, 0.25, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, overlayGradient);
  }

  void _drawFlightArc(
    Canvas canvas,
    Size size,
    Offset globeCenter,
    double globeR,
  ) {
    // Flight path arcs from one continent to another
    final pathPaint = Paint()
      ..color = FlitColors.accent.withOpacity(0.20)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Arc from N. America to Europe
    final path = Path()
      ..moveTo(globeCenter.dx - globeR * 0.30, globeCenter.dy - globeR * 0.26)
      ..cubicTo(
        globeCenter.dx - globeR * 0.10,
        globeCenter.dy - globeR * 0.60,
        globeCenter.dx + globeR * 0.10,
        globeCenter.dy - globeR * 0.58,
        globeCenter.dx + globeR * 0.12,
        globeCenter.dy - globeR * 0.30,
      );

    // Draw dashed path
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      final totalLength = metric.length;
      const dashLen = 6.0;
      const gapLen = 5.0;
      var distance = (t * totalLength * 0.4) % (dashLen + gapLen);
      while (distance < totalLength) {
        final start = distance;
        final end = (distance + dashLen).clamp(0.0, totalLength);
        final extracted = metric.extractPath(start, end);
        canvas.drawPath(extracted, pathPaint);
        distance += dashLen + gapLen;
      }

      // Animated plane dot
      final planePos = t % 1.0;
      final tangent = metric.getTangentForOffset(metric.length * planePos);
      if (tangent != null) {
        // Glow behind plane
        final glowPaint = Paint()
          ..color = FlitColors.accent.withOpacity(0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(tangent.position, 6, glowPaint);

        // Plane dot
        final planePaint = Paint()..color = FlitColors.accent.withOpacity(0.8);
        canvas.drawCircle(tangent.position, 3, planePaint);

        // Contrail
        final trailLen = metric.length * 0.08;
        final trailStart = (metric.length * planePos - trailLen).clamp(
          0.0,
          metric.length,
        );
        final trail = metric.extractPath(trailStart, metric.length * planePos);
        final trailPaint = Paint()
          ..color = FlitColors.contrail.withOpacity(0.12)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(trail, trailPaint);
      }
    }

    // Second fainter arc: Europe to Asia
    final path2 = Path()
      ..moveTo(globeCenter.dx + globeR * 0.14, globeCenter.dy - globeR * 0.28)
      ..cubicTo(
        globeCenter.dx + globeR * 0.24,
        globeCenter.dy - globeR * 0.50,
        globeCenter.dx + globeR * 0.44,
        globeCenter.dy - globeR * 0.48,
        globeCenter.dx + globeR * 0.46,
        globeCenter.dy - globeR * 0.22,
      );

    final path2Paint = Paint()
      ..color = FlitColors.gold.withOpacity(0.10)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final metric in path2.computeMetrics()) {
      final totalLength = metric.length;
      const dashLen = 5.0;
      const gapLen = 4.0;
      var distance =
          (t * totalLength * 0.25 + totalLength * 0.5) % (dashLen + gapLen);
      while (distance < totalLength) {
        final start = distance;
        final end = (distance + dashLen).clamp(0.0, totalLength);
        canvas.drawPath(metric.extractPath(start, end), path2Paint);
        distance += dashLen + gapLen;
      }
    }
  }

  void _drawCompassRose(Canvas canvas, Size size) {
    final cx = size.width * 0.88;
    final cy = size.height * 0.86;
    const r = 16.0;
    final paint = Paint()
      ..color = FlitColors.gold.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    canvas.drawCircle(Offset(cx, cy), r, paint);

    final linePaint = Paint()
      ..color = FlitColors.gold.withOpacity(0.15)
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r), linePaint);
    canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy), linePaint);
    const d = r * 0.55;
    canvas.drawLine(Offset(cx - d, cy - d), Offset(cx + d, cy + d), linePaint);
    canvas.drawLine(Offset(cx + d, cy - d), Offset(cx - d, cy + d), linePaint);

    // North arrow
    final northPaint = Paint()
      ..color = FlitColors.accent.withOpacity(0.25)
      ..style = PaintingStyle.fill;
    final northArrow = Path()
      ..moveTo(cx, cy - r - 1)
      ..lineTo(cx - 2.5, cy - r + 4)
      ..lineTo(cx + 2.5, cy - r + 4)
      ..close();
    canvas.drawPath(northArrow, northPaint);
  }

  @override
  bool shouldRepaint(covariant _GlobeBackgroundPainter oldDelegate) =>
      oldDelegate.t != t;
}

// ─── Daily streak card ─────────────────────────────────────────────────────

class _DailyStreakCard extends ConsumerWidget {
  const _DailyStreakCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(dailyStreakProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: FlitColors.cardBackground.withOpacity(0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: streak.currentStreak > 0
              ? FlitColors.gold.withOpacity(0.5)
              : FlitColors.cardBorder.withOpacity(0.5),
        ),
      ),
      child: streak.currentStreak > 0
          ? Row(
              children: [
                // Fire + streak count
                const Text(
                  '\u{1F525}', // fire emoji
                  style: TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${streak.currentStreak} day streak',
                        style: const TextStyle(
                          color: FlitColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Best: ${streak.longestStreak}  \u2022  ${streak.totalCompleted} dailies played',
                        style: const TextStyle(
                          color: FlitColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Streak badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: FlitColors.gold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '\u{1F525} ${streak.currentStreak}',
                    style: const TextStyle(
                      color: FlitColors.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.today_rounded,
                  color: FlitColors.textMuted,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'Play the daily to start your streak!',
                  style: TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
    );
  }
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
          border: Border.all(color: FlitColors.cardBorder.withOpacity(0.5)),
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
          border: Border.all(color: FlitColors.cardBorder.withOpacity(0.3)),
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
            const Icon(Icons.chevron_right, color: FlitColors.textMuted),
          ],
        ),
      ),
    ),
  );
}
