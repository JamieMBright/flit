import 'package:flutter/material.dart';

import '../../data/providers/account_provider.dart';
import '../../data/services/champion_service.dart';
import '../../game/economy/consumables.dart';
import '../theme/flit_colors.dart';

/// Shared UI for the consumables economy: item icons/colors, active-effect
/// timer chips, and the SUPPLY DROP / DAILY CHAMPION celebration dialogs.

/// Icon for a consumable item.
IconData consumableIcon(ConsumableType type) => switch (type) {
      ConsumableType.refuelCanister => Icons.local_gas_station,
      ConsumableType.licensePolish => Icons.auto_awesome,
      ConsumableType.goldSurge => Icons.monetization_on,
      ConsumableType.xpSurge => Icons.trending_up,
    };

/// Accent color for a consumable item.
Color consumableColor(ConsumableType type) => switch (type) {
      ConsumableType.refuelCanister => FlitColors.accent,
      ConsumableType.licensePolish => const Color(0xFF9B59B6),
      ConsumableType.goldSurge => FlitColors.gold,
      ConsumableType.xpSurge => const Color(0xFF4A90D9),
    };

/// Compact remaining-time label, e.g. "23h 59m" or "42m".
String formatEffectRemaining(Duration d) {
  if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
  if (d.inMinutes >= 1) return '${d.inMinutes}m';
  return '<1m';
}

/// Small badge chip for one active timed effect ("2x GOLD · 42m").
class ActiveEffectChip extends StatelessWidget {
  const ActiveEffectChip({
    super.key,
    required this.type,
    required this.remaining,
    this.compact = false,
  });

  final ConsumableType type;
  final Duration remaining;

  /// Compact = icon + time only (for tight HUD spots).
  final bool compact;

  String get _label => switch (type) {
        ConsumableType.licensePolish => '+$licensePolishStatBonus STATS',
        ConsumableType.goldSurge => '2x GOLD',
        ConsumableType.xpSurge => '2x XP',
        ConsumableType.refuelCanister => '',
      };

  @override
  Widget build(BuildContext context) {
    final color = consumableColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(consumableIcon(type), size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            compact
                ? formatEffectRemaining(remaining)
                : '$_label · ${formatEffectRemaining(remaining)}',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Row of chips for every effect active at [now]. Renders nothing when no
/// effects are running — safe to drop anywhere earnings/XP are shown.
class ActiveEffectsRow extends StatelessWidget {
  const ActiveEffectsRow({
    super.key,
    required this.effects,
    this.compact = false,
  });

  final ActiveEffects effects;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final active = effects.activeAt(now);
    if (active.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final type in active)
          ActiveEffectChip(
            type: type,
            remaining: effects.remaining(type, now),
            compact: compact,
          ),
      ],
    );
  }
}

/// Claim any daily-champion rewards owed for yesterday's boards and
/// celebrate them. Called on app open and when leaderboards are viewed
/// (ChampionService guards to one check per UTC day per session; the RPC
/// itself is idempotent). Degrades silently when the RPC isn't deployed.
Future<void> checkAndCelebrateDailyChampion(
  BuildContext context,
  AccountNotifier notifier,
) async {
  final rewards = await ChampionService.instance.checkAndClaimYesterday();
  if (rewards.isEmpty || !context.mounted) return;
  for (final reward in rewards) {
    notifier.grantConsumable(reward.reward);
    await showDailyChampionDialog(context, reward);
    if (!context.mounted) return;
  }
}

/// Celebration dialog for a rare post-game supply drop.
Future<void> showSupplyDropDialog(BuildContext context, ConsumableType type) {
  return _showRewardDialog(
    context,
    banner: 'SUPPLY DROP',
    bannerIcon: Icons.inventory_2,
    bannerColor: FlitColors.accent,
    subtitle: 'Rare drop for a strong flight!',
    type: type,
  );
}

/// Celebration dialog for winning yesterday's daily board.
Future<void> showDailyChampionDialog(
  BuildContext context,
  ChampionReward reward,
) {
  return _showRewardDialog(
    context,
    banner: 'DAILY CHAMPION',
    bannerIcon: Icons.emoji_events,
    bannerColor: FlitColors.gold,
    subtitle: 'You topped the ${reward.boardLabel} board on ${reward.date}!',
    type: reward.reward,
  );
}

Future<void> _showRewardDialog(
  BuildContext context, {
  required String banner,
  required IconData bannerIcon,
  required Color bannerColor,
  required String subtitle,
  required ConsumableType type,
}) {
  final itemColor = consumableColor(type);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: FlitColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(bannerIcon, color: bannerColor, size: 22),
          const SizedBox(width: 8),
          Text(
            banner,
            style: TextStyle(
              color: bannerColor,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: itemColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: itemColor, width: 2),
            ),
            child: Icon(consumableIcon(type), color: itemColor, size: 36),
          ),
          const SizedBox(height: 12),
          Text(
            type.displayName,
            style: const TextStyle(
              color: FlitColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            type.effectLabel,
            textAlign: TextAlign.center,
            style: TextStyle(color: itemColor, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: bannerColor,
              foregroundColor: FlitColors.backgroundDark,
            ),
            child: const Text(
              'Claimed!',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    ),
  );
}
