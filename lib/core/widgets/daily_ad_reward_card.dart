import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/ad_config.dart';
import '../../data/providers/account_provider.dart';
import '../../data/providers/subscription_provider.dart';
import '../../data/services/ad_service.dart';
import '../../game/economy/consumables.dart';
import '../theme/flit_colors.dart';

/// Opt-in "Daily reward: watch an ad" affordance, shared by the home screen
/// and the shop SUPPLIES tab (per the "fix at the shared layer" rule).
///
/// Watching the rewarded ad grants coins OR a random consumable — reusing the
/// existing economy paths (`addCoins` / `grantConsumable`). Limited to once
/// per UTC day by [AdPlacement.rewardedDailyDrop]'s cap (enforced by
/// AdService). Hides itself entirely on web, for premium players, and once
/// today's drop has been claimed.
class DailyAdRewardCard extends ConsumerStatefulWidget {
  const DailyAdRewardCard({super.key});

  @override
  ConsumerState<DailyAdRewardCard> createState() => _DailyAdRewardCardState();
}

class _DailyAdRewardCardState extends ConsumerState<DailyAdRewardCard> {
  bool _busy = false;

  Future<void> _watch() async {
    if (_busy) return;
    setState(() => _busy = true);
    final adService = ref.read(adServiceProvider);
    final tier = ref.read(adTierProvider);
    final notifier = ref.read(accountProvider.notifier);
    try {
      final granted = await adService.showRewarded(
        context,
        AdPlacement.rewardedDailyDrop,
        tier: tier,
      );
      if (!granted || !mounted) return;
      final message = _grantReward(notifier);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: FlitColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      // Rebuild so the card hides now that today's drop is claimed.
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Grant coins or a random consumable; returns a celebration message.
  String _grantReward(AccountNotifier notifier) {
    final rng = Random();
    // ~50% coins, ~50% a random consumable — keeps the drop varied.
    if (rng.nextBool()) {
      final coins = notifier.addCoins(
        AdConfig.dailyDropCoins,
        applyBoost: false,
        source: 'ad_reward_daily_drop',
      );
      return 'Daily reward: +$coins coins!';
    }
    final type =
        ConsumableType.values[rng.nextInt(ConsumableType.values.length)];
    notifier.grantConsumable(type);
    return 'Daily reward: ${type.displayName}!';
  }

  @override
  Widget build(BuildContext context) {
    final adService = ref.watch(adServiceProvider);
    final tier = ref.watch(adTierProvider);
    if (!adService.canOfferRewarded(AdPlacement.rewardedDailyDrop, tier)) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: FlitColors.cardBackground.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FlitColors.accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard_rounded,
              color: FlitColors.accent, size: 24),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily reward',
                  style: TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Watch a short ad for coins or supplies',
                  style: TextStyle(
                    color: FlitColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _busy ? null : _watch,
            icon: const Icon(Icons.smart_display_outlined, size: 16),
            label: const Text('WATCH'),
            style: ElevatedButton.styleFrom(
              backgroundColor: FlitColors.accent,
              foregroundColor: FlitColors.textPrimary,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
