import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/player.dart';

/// Profile screen showing player stats and settings.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // Placeholder player - will be replaced with actual user data
  static final _player = Player(
    id: 'user-1',
    username: 'FlitPilot',
    displayName: 'Flit Pilot',
    level: 5,
    xp: 320,
    coins: 1250,
    gamesPlayed: 42,
    bestTime: const Duration(seconds: 14, milliseconds: 230),
    createdAt: DateTime.now().subtract(const Duration(days: 30)),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: FlitColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: FlitColors.backgroundMid,
          title: const Text('Profile'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                // TODO: Open settings
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Avatar and name
              _ProfileHeader(player: _player),
              const SizedBox(height: 24),
              // Level progress
              _LevelProgress(player: _player),
              const SizedBox(height: 24),
              // Stats grid
              _StatsGrid(player: _player),
              const SizedBox(height: 24),
              // Actions
              _ProfileActions(),
            ],
          ),
        ),
      );
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          // Avatar
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: FlitColors.accent,
              shape: BoxShape.circle,
              border: Border.all(
                color: FlitColors.cardBorder,
                width: 3,
              ),
            ),
            child: Center(
              child: Text(
                player.name[0].toUpperCase(),
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Name
          Text(
            player.name,
            style: const TextStyle(
              color: FlitColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          // Username
          Text(
            '@${player.username}',
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      );
}

class _LevelProgress extends StatelessWidget {
  const _LevelProgress({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlitColors.cardBorder),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Level ${player.level}',
                  style: const TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${player.xp} / ${player.xpForNextLevel} XP',
                  style: const TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: player.levelProgress,
                backgroundColor: FlitColors.backgroundMid,
                valueColor: const AlwaysStoppedAnimation<Color>(FlitColors.accent),
                minHeight: 8,
              ),
            ),
          ],
        ),
      );
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final bestTime = player.bestTime;
    final bestTimeText = bestTime != null
        ? '${bestTime.inSeconds}.${(bestTime.inMilliseconds % 1000) ~/ 10}s'
        : '--';

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.monetization_on,
            iconColor: FlitColors.warning,
            value: player.coins.toString(),
            label: 'Coins',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.games,
            iconColor: FlitColors.accent,
            value: player.gamesPlayed.toString(),
            label: 'Games',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.timer,
            iconColor: FlitColors.success,
            value: bestTimeText,
            label: 'Best Time',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlitColors.cardBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: FlitColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
}

class _ProfileActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ActionButton(
            icon: Icons.edit,
            label: 'Edit Profile',
            onTap: () {
              // TODO: Edit profile
            },
          ),
          const SizedBox(height: 12),
          _ActionButton(
            icon: Icons.history,
            label: 'Game History',
            onTap: () {
              // TODO: Show history
            },
          ),
          const SizedBox(height: 12),
          _ActionButton(
            icon: Icons.logout,
            label: 'Sign Out',
            isDestructive: true,
            onTap: () {
              // TODO: Sign out
            },
          ),
        ],
      );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) => Material(
        color: FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FlitColors.cardBorder),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isDestructive ? FlitColors.error : FlitColors.textSecondary,
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    color: isDestructive ? FlitColors.error : FlitColors.textPrimary,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right,
                  color: FlitColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      );
}
