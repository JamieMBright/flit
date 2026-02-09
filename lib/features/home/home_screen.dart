import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../daily/daily_challenge_screen.dart';
import '../debug/debug_screen.dart';
import '../friends/friends_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../play/practice_screen.dart';
import '../play/region_select_screen.dart';
import '../profile/profile_screen.dart';
import '../shop/shop_screen.dart';

/// Home screen with static map background and menu overlay.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Static map background (no auto-flying plane)
            const _StaticMapBackground(),

            // Menu overlay
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    // Title
                    const Text(
                      'FLIT',
                      style: TextStyle(
                        color: FlitColors.textPrimary,
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'A GEOGRAPHICAL ADVENTURE',
                      style: TextStyle(
                        color: FlitColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 3,
                      ),
                    ),
                    const Spacer(flex: 3),
                    _buildMenuButtons(context),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildMenuButtons(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Primary PLAY button opens mode selection
          _MenuButton(
            label: 'Play',
            icon: Icons.play_arrow_rounded,
            isPrimary: true,
            onTap: () => _showGameModes(context),
          ),
          const SizedBox(height: 10),
          _MenuButton(
            label: 'Leaderboard',
            icon: Icons.leaderboard_rounded,
            onTap: () => _navigateSafely(
              context,
              const LeaderboardScreen(),
            ),
          ),
          const SizedBox(height: 10),
          _MenuButton(
            label: 'Profile',
            icon: Icons.person_rounded,
            onTap: () => _navigateSafely(
              context,
              const ProfileScreen(),
            ),
          ),
          const SizedBox(height: 10),
          _MenuButton(
            label: 'Shop',
            icon: Icons.storefront_rounded,
            onTap: () => _navigateSafely(
              context,
              const ShopScreen(),
            ),
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

  /// Close the bottom sheet and navigate to [destination].
  ///
  /// Uses the sheet's navigator to avoid context lifecycle issues on iOS PWA.
  /// The pop() and push() happen in the same event loop to prevent timing-based
  /// crashes on web platforms where delayed futures can race with sheet dismissal.
  void _closeSheetAndNavigate(
    BuildContext sheetContext,
    Widget destination,
  ) {
    // Pop the sheet and immediately push the destination route using the same
    // Navigator. This eliminates context validity issues and timing races that
    // occur on iOS PWA when using delayed futures with captured contexts.
    Navigator.of(sheetContext)
      ..pop()
      ..push(
        MaterialPageRoute<void>(builder: (_) => destination),
      );
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
                ctx, const RegionSelectScreen(),
              ),
            ),
            const SizedBox(height: 10),
            _GameModeCard(
              title: 'Training Sortie',
              subtitle: 'Practice without rank pressure',
              icon: Icons.school_rounded,
              onTap: () => _closeSheetAndNavigate(
                ctx, const PracticeScreen(),
              ),
            ),
            const SizedBox(height: 10),
            _GameModeCard(
              title: 'Daily Scramble',
              subtitle: 'Today\'s challenge — compete for glory',
              icon: Icons.today_rounded,
              isHighlighted: true,
              onTap: () => _closeSheetAndNavigate(
                ctx, const DailyChallengeScreen(),
              ),
            ),
            const SizedBox(height: 10),
            _GameModeCard(
              title: 'Dogfight',
              subtitle: 'Challenge your friends head-to-head',
              icon: Icons.people_rounded,
              onTap: () => _closeSheetAndNavigate(
                ctx, const FriendsScreen(),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Static decorative map background for the home screen.
/// No gameplay, no scrolling - just a subtle visual.
class _StaticMapBackground extends StatelessWidget {
  const _StaticMapBackground();

  @override
  Widget build(BuildContext context) => SizedBox.expand(
        child: CustomPaint(
          painter: _MapBackgroundPainter(),
        ),
      );
}

class _MapBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.isFinite) return;

    // Ocean gradient
    final oceanGradient = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          FlitColors.oceanDeep,
          FlitColors.ocean,
          FlitColors.oceanDeep,
        ],
        stops: [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), oceanGradient);

    // Subtle grid
    final gridPaint = Paint()
      ..color = FlitColors.gridLine
      ..strokeWidth = 0.5;

    const gridCount = 8;
    for (var i = 1; i < gridCount; i++) {
      final x = size.width * i / gridCount;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      final y = size.height * i / gridCount;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Decorative land masses (simplified continent silhouettes)
    final landPaint = Paint()..color = FlitColors.landMass.withOpacity(0.15);
    final borderPaint = Paint()
      ..color = FlitColors.border.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Europe/Africa blob
    final europe = Path()
      ..moveTo(size.width * 0.48, size.height * 0.15)
      ..quadraticBezierTo(
          size.width * 0.55, size.height * 0.18,
          size.width * 0.52, size.height * 0.28)
      ..quadraticBezierTo(
          size.width * 0.54, size.height * 0.35,
          size.width * 0.50, size.height * 0.55)
      ..quadraticBezierTo(
          size.width * 0.48, size.height * 0.60,
          size.width * 0.46, size.height * 0.50)
      ..quadraticBezierTo(
          size.width * 0.44, size.height * 0.30,
          size.width * 0.46, size.height * 0.20)
      ..close();
    canvas.drawPath(europe, landPaint);
    canvas.drawPath(europe, borderPaint);

    // Americas blob
    final americas = Path()
      ..moveTo(size.width * 0.22, size.height * 0.12)
      ..quadraticBezierTo(
          size.width * 0.28, size.height * 0.15,
          size.width * 0.26, size.height * 0.30)
      ..quadraticBezierTo(
          size.width * 0.28, size.height * 0.38,
          size.width * 0.24, size.height * 0.55)
      ..quadraticBezierTo(
          size.width * 0.22, size.height * 0.65,
          size.width * 0.20, size.height * 0.70)
      ..quadraticBezierTo(
          size.width * 0.18, size.height * 0.60,
          size.width * 0.17, size.height * 0.45)
      ..quadraticBezierTo(
          size.width * 0.16, size.height * 0.30,
          size.width * 0.19, size.height * 0.18)
      ..close();
    canvas.drawPath(americas, landPaint);
    canvas.drawPath(americas, borderPaint);

    // Asia blob
    final asia = Path()
      ..moveTo(size.width * 0.60, size.height * 0.12)
      ..quadraticBezierTo(
          size.width * 0.72, size.height * 0.15,
          size.width * 0.78, size.height * 0.22)
      ..quadraticBezierTo(
          size.width * 0.82, size.height * 0.30,
          size.width * 0.75, size.height * 0.38)
      ..quadraticBezierTo(
          size.width * 0.68, size.height * 0.42,
          size.width * 0.62, size.height * 0.35)
      ..quadraticBezierTo(
          size.width * 0.56, size.height * 0.25,
          size.width * 0.58, size.height * 0.15)
      ..close();
    canvas.drawPath(asia, landPaint);
    canvas.drawPath(asia, borderPaint);

    // Overlay gradient for text readability
    final overlayGradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          FlitColors.backgroundDark.withOpacity(0.4),
          FlitColors.backgroundDark.withOpacity(0.1),
          FlitColors.backgroundDark.withOpacity(0.6),
        ],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), overlayGradient);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) => Material(
        color: isPrimary
            ? FlitColors.accent
            : FlitColors.cardBackground.withOpacity(0.85),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: isPrimary
                  ? null
                  : Border.all(
                      color: FlitColors.cardBorder.withOpacity(0.5),
                    ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: FlitColors.textPrimary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
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
