import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/player.dart';
import '../../data/providers/account_provider.dart';
import '../../data/services/test_accounts.dart';

/// Debug screen for testing - switch accounts, add coins, etc.
class DebugScreen extends ConsumerWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountProvider);
    final notifier = ref.read(accountProvider.notifier);

    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: const Text('Debug / Test Mode'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current account info
          _SectionHeader(title: 'Current Account'),
          _AccountCard(
            player: state.currentPlayer,
            isSelected: true,
          ),
          const SizedBox(height: 24),

          // Switch accounts
          _SectionHeader(title: 'Switch Account'),
          const SizedBox(height: 8),
          ...TestAccounts.all.map(
            (player) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AccountCard(
                player: player,
                isSelected: state.currentPlayer.id == player.id,
                onTap: () => notifier.switchAccount(player),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Quick actions
          _SectionHeader(title: 'Quick Actions'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionChip(
                label: '+100 Coins',
                onTap: () => notifier.addCoins(100),
              ),
              _ActionChip(
                label: '+1000 Coins',
                onTap: () => notifier.addCoins(1000),
              ),
              _ActionChip(
                label: '+50 XP',
                onTap: () => notifier.addXp(50),
              ),
              _ActionChip(
                label: '+500 XP',
                onTap: () => notifier.addXp(500),
              ),
              _ActionChip(
                label: '+1 Game',
                onTap: () => notifier.incrementGamesPlayed(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FlitColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FlitColors.cardBorder),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Testing Guide',
                  style: TextStyle(
                    color: FlitColors.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '• Use Player 1 & Player 2 to test challenges\n'
                  '• God Account has all maps unlocked\n'
                  '• New Player simulates a fresh user\n'
                  '• Changes persist only for this session',
                  style: TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 14,
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            color: FlitColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      );
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.player,
    required this.isSelected,
    this.onTap,
  });

  final Player player;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: isSelected
            ? FlitColors.accent.withOpacity(0.2)
            : FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? FlitColors.accent : FlitColors.cardBorder,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: FlitColors.backgroundMid,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text(
                      player.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: FlitColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.name,
                        style: const TextStyle(
                          color: FlitColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Lv.${player.level} • ${player.coins} coins • ${player.gamesPlayed} games',
                        style: const TextStyle(
                          color: FlitColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Selected indicator
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: FlitColors.accent,
                  ),
              ],
            ),
          ),
        ),
      );
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
        label: Text(label),
        onPressed: onTap,
        backgroundColor: FlitColors.cardBackground,
        labelStyle: const TextStyle(color: FlitColors.textPrimary),
        side: const BorderSide(color: FlitColors.cardBorder),
      );
}
