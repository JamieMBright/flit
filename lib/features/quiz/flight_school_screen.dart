import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/providers/account_provider.dart';
import '../../game/quiz/flight_school_level.dart';
import 'h2h_challenge_screen.dart';
import 'quiz_setup_screen.dart';

/// Flight School level selection screen.
///
/// Shows all available flight school levels (geographic regions) as cards
/// with progress tracking, grades, and unlock requirements.
/// Levels can be unlocked by reaching the required player level OR
/// by spending coins for early access.
class FlightSchoolScreen extends ConsumerStatefulWidget {
  const FlightSchoolScreen({super.key});

  @override
  ConsumerState<FlightSchoolScreen> createState() => _FlightSchoolScreenState();
}

class _FlightSchoolScreenState extends ConsumerState<FlightSchoolScreen> {
  @override
  Widget build(BuildContext context) {
    final accountState = ref.watch(accountProvider);
    final notifier = ref.read(accountProvider.notifier);
    final playerLevel = accountState.currentPlayer.level;
    final playerCoins = accountState.currentPlayer.coins;
    final progressMap = accountState.flightSchoolProgress;

    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: const Text(
          'Flight School',
          style: TextStyle(color: FlitColors.textPrimary),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: FlitColors.textPrimary),
        actions: [
          // Coin balance
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: FlitColors.gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.monetization_on,
                  color: FlitColors.gold,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  '$playerCoins',
                  style: const TextStyle(
                    color: FlitColors.gold,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const H2HChallengeScreen()),
        ),
        backgroundColor: FlitColors.accent,
        foregroundColor: FlitColors.textPrimary,
        icon: const Icon(Icons.sports_mma, size: 20),
        label: const Text(
          'H2H',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: flightSchoolLevels.length,
                itemBuilder: (context, index) {
                  final level = flightSchoolLevels[index];
                  final isUnlocked = notifier.isFlightSchoolLevelUnlocked(
                    level,
                  );
                  final progress =
                      progressMap[level.id] ?? const FlightSchoolProgress();
                  final canBuyEarly =
                      !isUnlocked &&
                      level.unlockCost > 0 &&
                      playerCoins >= level.unlockCost;

                  return _LevelCard(
                    level: level,
                    progress: progress,
                    isUnlocked: isUnlocked,
                    canBuyEarly: canBuyEarly,
                    playerLevel: playerLevel,
                    playerCoins: playerCoins,
                    onTap: isUnlocked ? () => _navigateToSetup(level) : null,
                    onBuy: canBuyEarly
                        ? () => _buyLevel(level, notifier)
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: const BoxDecoration(
      color: FlitColors.backgroundMid,
      border: Border(bottom: BorderSide(color: FlitColors.cardBorder)),
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FlitColors.gold.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.school, color: FlitColors.gold, size: 32),
        ),
        const SizedBox(height: 10),
        const Text(
          'Choose your training region',
          style: TextStyle(color: FlitColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 6),
        _buildOverallProgress(),
      ],
    ),
  );

  Widget _buildOverallProgress() {
    final progressMap = ref.watch(accountProvider).flightSchoolProgress;
    final completed = flightSchoolLevels.where((l) {
      final p = progressMap[l.id];
      return p != null && p.completions > 0;
    }).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: FlitColors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FlitColors.accent.withOpacity(0.25)),
      ),
      child: Text(
        '$completed / ${flightSchoolLevels.length} regions completed',
        style: const TextStyle(
          color: FlitColors.accent,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _navigateToSetup(FlightSchoolLevel level) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => QuizSetupScreen(level: level)),
    );
  }

  void _buyLevel(FlightSchoolLevel level, AccountNotifier notifier) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FlitColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: FlitColors.cardBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.lock_open, color: FlitColors.gold, size: 24),
            const SizedBox(width: 8),
            Text(
              'Unlock ${level.name}?',
              style: const TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unlock ${level.name} early for ${level.unlockCost} coins.',
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Or reach level ${level.requiredLevel} to unlock free.',
              style: const TextStyle(color: FlitColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: FlitColors.textMuted),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final success = notifier.unlockFlightSchoolLevel(
                level.id,
                level.unlockCost,
              );
              Navigator.of(ctx).pop();
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${level.name} unlocked!'),
                    backgroundColor: FlitColors.success,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Not enough coins'),
                    backgroundColor: FlitColors.error,
                  ),
                );
              }
            },
            icon: const Icon(Icons.monetization_on, size: 18),
            label: Text('${level.unlockCost} coins'),
            style: ElevatedButton.styleFrom(
              backgroundColor: FlitColors.gold,
              foregroundColor: FlitColors.backgroundDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.progress,
    required this.isUnlocked,
    required this.canBuyEarly,
    required this.playerLevel,
    required this.playerCoins,
    this.onTap,
    this.onBuy,
  });

  final FlightSchoolLevel level;
  final FlightSchoolProgress progress;
  final bool isUnlocked;
  final bool canBuyEarly;
  final int playerLevel;
  final int playerCoins;
  final VoidCallback? onTap;
  final VoidCallback? onBuy;

  static const _iconMap = <String, IconData>{
    'flag': Icons.flag,
    'castle': Icons.castle,
    'terrain': Icons.terrain,
    'temple_buddhist': Icons.temple_buddhist,
    'festival': Icons.festival,
    'grass': Icons.grass,
    'landscape': Icons.landscape,
    'beach_access': Icons.beach_access,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _iconMap[level.icon] ?? Icons.public;
    final grade = progress.grade;
    final gradeColor = _gradeColor(grade);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: isUnlocked ? onTap : (canBuyEarly ? onBuy : null),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isUnlocked
                    ? FlitColors.cardBorder
                    : canBuyEarly
                    ? FlitColors.gold.withOpacity(0.4)
                    : FlitColors.textMuted.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                // Region icon
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? FlitColors.accent.withOpacity(0.15)
                        : canBuyEarly
                        ? FlitColors.gold.withOpacity(0.1)
                        : FlitColors.backgroundMid,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: 26,
                      color: isUnlocked
                          ? FlitColors.accent
                          : canBuyEarly
                          ? FlitColors.gold
                          : FlitColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Level info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              level.name,
                              style: TextStyle(
                                color: isUnlocked
                                    ? FlitColors.textPrimary
                                    : canBuyEarly
                                    ? FlitColors.textSecondary
                                    : FlitColors.textMuted,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (progress.hasPlayed)
                            _GradeBadge(grade: grade, color: gradeColor),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        level.subtitle,
                        style: TextStyle(
                          color: isUnlocked
                              ? FlitColors.textSecondary
                              : FlitColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      if (isUnlocked && progress.hasPlayed) ...[
                        const SizedBox(height: 8),
                        _buildProgressRow(),
                      ],
                      if (!isUnlocked) ...[
                        const SizedBox(height: 6),
                        _buildLockInfo(),
                      ],
                    ],
                  ),
                ),

                // Chevron, buy button, or lock
                const SizedBox(width: 8),
                if (isUnlocked)
                  const Icon(
                    Icons.chevron_right,
                    color: FlitColors.textSecondary,
                    size: 22,
                  )
                else if (canBuyEarly)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: FlitColors.gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: FlitColors.gold.withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.monetization_on,
                          color: FlitColors.gold,
                          size: 14,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${level.unlockCost}',
                          style: const TextStyle(
                            color: FlitColors.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Icon(Icons.lock, color: FlitColors.textMuted, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockInfo() {
    final hasUnlockCost = level.unlockCost > 0;
    final canAfford = playerCoins >= level.unlockCost;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lock, size: 13, color: FlitColors.warning),
            const SizedBox(width: 4),
            Text(
              'Level ${level.requiredLevel} required',
              style: const TextStyle(
                color: FlitColors.warning,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (hasUnlockCost) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(
                Icons.monetization_on,
                size: 13,
                color: canAfford ? FlitColors.gold : FlitColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                canAfford
                    ? 'Tap to unlock for ${level.unlockCost} coins'
                    : '${level.unlockCost} coins to unlock early',
                style: TextStyle(
                  color: canAfford ? FlitColors.gold : FlitColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildProgressRow() {
    return Row(
      children: [
        _buildMiniStat(Icons.star, FlitColors.gold, '${progress.bestScore}'),
        const SizedBox(width: 12),
        _buildMiniStat(
          Icons.timer,
          FlitColors.accent,
          progress.bestTimeFormatted,
        ),
        const SizedBox(width: 12),
        _buildMiniStat(
          Icons.check_circle,
          FlitColors.success,
          '${progress.completions}/${progress.attempts}',
        ),
      ],
    );
  }

  Widget _buildMiniStat(IconData icon, Color color, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color.withOpacity(0.7)),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Color _gradeColor(String grade) {
    switch (grade) {
      case 'S':
        return FlitColors.gold;
      case 'A':
        return FlitColors.success;
      case 'B':
        return const Color(0xFF6AB4E8);
      case 'C':
        return FlitColors.textSecondary;
      case 'D':
        return FlitColors.warning;
      case 'F':
        return FlitColors.error;
      default:
        return FlitColors.textMuted;
    }
  }
}

class _GradeBadge extends StatelessWidget {
  const _GradeBadge({required this.grade, required this.color});

  final String grade;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.15),
        border: Border.all(color: color, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        grade,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
