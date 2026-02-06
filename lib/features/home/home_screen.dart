import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../game/flit_game.dart';
import '../play/play_screen.dart';

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
            // Game canvas (full screen)
            GameWidget(game: _game),

            // Menu overlay
            if (_isGameReady)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
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
                builder: (context) => const PlayScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MenuButton(
            label: 'Challenge',
            icon: Icons.people_rounded,
            onTap: () => _showComingSoon('Challenge mode'),
          ),
          const SizedBox(height: 12),
          _MenuButton(
            label: 'Leaderboard',
            icon: Icons.leaderboard_rounded,
            onTap: () => _showComingSoon('Leaderboards'),
          ),
        ],
      );

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming in future sprints!'),
        backgroundColor: FlitColors.backgroundMid,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
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
        color: isPrimary ? FlitColors.accent : FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isPrimary
                  ? null
                  : Border.all(color: FlitColors.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: FlitColors.textPrimary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
