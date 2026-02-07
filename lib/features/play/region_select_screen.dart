import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/cosmetic.dart';
import '../../data/providers/account_provider.dart';
import '../../game/map/region.dart';
import 'play_screen.dart';

/// Screen for selecting which region to play.
class RegionSelectScreen extends ConsumerWidget {
  const RegionSelectScreen({super.key});

  /// Coin cost to unlock each region tier.
  static int unlockCost(GameRegion region) {
    switch (region) {
      case GameRegion.world:
        return 0; // Always unlocked
      case GameRegion.usStates:
        return 500; // Level 3
      case GameRegion.ukCounties:
        return 1000; // Level 5
      case GameRegion.caribbean:
        return 2000; // Level 7
      case GameRegion.ireland:
        return 5000; // Level 10
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountState = ref.watch(accountProvider);
    final playerLevel = accountState.currentPlayer.level;
    final coins = accountState.currentPlayer.coins;

    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: const Text('Select Region'),
        centerTitle: true,
        actions: [
          // Coin balance display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: FlitColors.gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.monetization_on,
                  color: FlitColors.gold,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  coins.toString(),
                  style: const TextStyle(
                    color: FlitColors.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: GameRegion.values.length,
        itemBuilder: (context, index) {
          final region = GameRegion.values[index];
          final isUnlockedByLevel = playerLevel >= region.requiredLevel;
          final isUnlockedByPurchase =
              accountState.unlockedRegions.contains(region.name);
          final isUnlocked = isUnlockedByLevel || isUnlockedByPurchase;
          final cost = unlockCost(region);
          final canAfford = coins >= cost && cost > 0;

          return _RegionCard(
            region: region,
            isUnlocked: isUnlocked,
            playerLevel: playerLevel,
            unlockCost: cost,
            canBuy: !isUnlocked && canAfford,
            onTap: isUnlocked
                ? () {
                    final planeId = ref.read(equippedPlaneIdProvider);
                    final planeColors = CosmeticCatalog.getById(planeId)?.colorScheme;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (context) => PlayScreen(
                          region: region,
                          planeColorScheme: planeColors,
                          equippedPlaneId: planeId,
                        ),
                      ),
                    );
                  }
                : null,
            onBuy: (!isUnlocked && canAfford)
                ? () => _showUnlockDialog(context, ref, region, cost)
                : null,
          );
        },
      ),
    );
  }

  void _showUnlockDialog(
    BuildContext scaffoldContext,
    WidgetRef ref,
    GameRegion region,
    int cost,
  ) {
    showDialog<void>(
      context: scaffoldContext,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: FlitColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Unlock ${region.displayName}?',
          style: const TextStyle(color: FlitColors.textPrimary),
        ),
        content: Row(
          children: [
            const Icon(Icons.monetization_on, color: FlitColors.gold),
            const SizedBox(width: 8),
            Text(
              '$cost coins',
              style: const TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: FlitColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final success =
                  ref.read(accountProvider.notifier).unlockRegion(region, cost);
              Navigator.of(dialogContext).pop();
              if (success) {
                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                  SnackBar(
                    content: Text('${region.displayName} unlocked!'),
                    backgroundColor: FlitColors.success,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: FlitColors.accent,
              foregroundColor: FlitColors.textPrimary,
            ),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }
}

class _RegionCard extends StatelessWidget {
  const _RegionCard({
    required this.region,
    required this.isUnlocked,
    required this.playerLevel,
    required this.unlockCost,
    required this.canBuy,
    this.onTap,
    this.onBuy,
  });

  final GameRegion region;
  final bool isUnlocked;
  final int playerLevel;
  final int unlockCost;
  final bool canBuy;
  final VoidCallback? onTap;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isUnlocked
                      ? FlitColors.cardBorder
                      : FlitColors.textMuted,
                ),
              ),
              child: Row(
                children: [
                  // Region icon
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: isUnlocked
                          ? FlitColors.accent.withOpacity(0.2)
                          : FlitColors.backgroundMid,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        _getRegionIcon(region),
                        size: 32,
                        color: isUnlocked
                            ? FlitColors.accent
                            : FlitColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Region info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          region.displayName,
                          style: TextStyle(
                            color: isUnlocked
                                ? FlitColors.textPrimary
                                : FlitColors.textMuted,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          region.description,
                          style: TextStyle(
                            color: isUnlocked
                                ? FlitColors.textSecondary
                                : FlitColors.textMuted,
                            fontSize: 14,
                          ),
                        ),
                        if (!isUnlocked) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.lock,
                                size: 14,
                                color: FlitColors.warning,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Unlocks at Level ${region.requiredLevel}',
                                style: const TextStyle(
                                  color: FlitColors.warning,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          if (canBuy) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: onBuy,
                                icon: const Icon(
                                  Icons.monetization_on,
                                  size: 16,
                                ),
                                label: Text(
                                  'BUY FOR $unlockCost COINS',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: FlitColors.gold,
                                  foregroundColor: FlitColors.backgroundDark,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  // Arrow or lock
                  Icon(
                    isUnlocked ? Icons.chevron_right : Icons.lock,
                    color: isUnlocked
                        ? FlitColors.textSecondary
                        : FlitColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  IconData _getRegionIcon(GameRegion region) {
    switch (region) {
      case GameRegion.world:
        return Icons.public;
      case GameRegion.usStates:
        return Icons.flag;
      case GameRegion.ukCounties:
        return Icons.castle;
      case GameRegion.caribbean:
        return Icons.beach_access;
      case GameRegion.ireland:
        return Icons.grass;
    }
  }
}
