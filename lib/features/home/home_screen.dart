import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../avatar/avatar_editor_screen.dart';
import '../daily/daily_challenge_screen.dart';
import '../debug/debug_screen.dart';
import '../friends/friends_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../license/license_screen.dart';
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
          _MenuButton(
            label: 'Play',
            icon: Icons.play_arrow_rounded,
            isPrimary: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const RegionSelectScreen(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _MenuButton(
            label: 'Practice',
            icon: Icons.school_rounded,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const PracticeScreen(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _MenuButton(
            label: 'Daily Challenge',
            icon: Icons.today_rounded,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const DailyChallengeScreen(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _MenuButton(
            label: 'Challenge',
            icon: Icons.people_rounded,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const FriendsScreen(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _MenuButton(
            label: 'Leaderboard',
            icon: Icons.leaderboard_rounded,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const LeaderboardScreen(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _MenuButton(
            label: 'Profile',
            icon: Icons.person_rounded,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const ProfileScreen(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _MenuButton(
            label: 'Avatar',
            icon: Icons.face_rounded,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const AvatarEditorScreen(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _MenuButton(
            label: 'Pilot License',
            icon: Icons.badge_rounded,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const LicenseScreen(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _MenuButton(
            label: 'Shop',
            icon: Icons.storefront_rounded,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const ShopScreen(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _MenuButton(
            label: 'Debug',
            icon: Icons.bug_report_rounded,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const DebugScreen(),
              ),
            ),
          ),
        ],
      );
}

/// Static decorative map background for the home screen.
/// No gameplay, no scrolling - just a subtle visual.
class _StaticMapBackground extends StatelessWidget {
  const _StaticMapBackground();

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _MapBackgroundPainter(),
        size: Size.infinite,
      );
}

class _MapBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Ocean gradient
    final oceanGradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          FlitColors.oceanDeep,
          FlitColors.ocean,
          FlitColors.oceanDeep,
        ],
        stops: const [0.0, 0.45, 1.0],
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
