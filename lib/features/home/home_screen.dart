import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../game/flit_game.dart';
import '../debug/debug_screen.dart';
import '../friends/friends_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../play/region_select_screen.dart';
import '../profile/profile_screen.dart';
import '../shop/shop_screen.dart';

/// Home screen with game canvas and menu overlay.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final FlitGame _game;
  bool _isGameReady = false;

  @override
  void initState() {
    super.initState();
    _game = FlitGame(
      onGameReady: () {
        if (mounted) {
          setState(() => _isGameReady = true);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Game canvas (full screen, auto-flying plane as background)
            GameWidget(game: _game),

            // Gradient overlay for readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    FlitColors.backgroundDark.withOpacity(0.3),
                    FlitColors.backgroundDark.withOpacity(0.0),
                    FlitColors.backgroundDark.withOpacity(0.7),
                  ],
                  stops: const [0.0, 0.3, 1.0],
                ),
              ),
            ),

            // Menu overlay
            if (_isGameReady)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Spacer(flex: 1),
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
                      Text(
                        'A GEOGRAPHICAL ADVENTURE',
                        style: TextStyle(
                          color: FlitColors.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 3,
                        ),
                      ),
                      const Spacer(flex: 2),
                      _buildMenuButtons(),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _buildMenuButtons() => Column(
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
            : FlitColors.cardBackground.withOpacity(0.8),
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
                  style: TextStyle(
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
