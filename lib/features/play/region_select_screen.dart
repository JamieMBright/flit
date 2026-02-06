import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/providers/account_provider.dart';
import '../../game/map/region.dart';
import 'play_screen.dart';

/// Screen for selecting which region to play.
class RegionSelectScreen extends ConsumerWidget {
  const RegionSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerLevel = ref.watch(currentLevelProvider);

    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: const Text('Select Region'),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: GameRegion.values.length,
        itemBuilder: (context, index) {
          final region = GameRegion.values[index];
          final isUnlocked = playerLevel >= region.requiredLevel;

          return _RegionCard(
            region: region,
            isUnlocked: isUnlocked,
            playerLevel: playerLevel,
            onTap: isUnlocked
                ? () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (context) => PlayScreen(region: region),
                      ),
                    )
                : null,
          );
        },
      ),
    );
  }
}

class _RegionCard extends StatelessWidget {
  const _RegionCard({
    required this.region,
    required this.isUnlocked,
    required this.playerLevel,
    this.onTap,
  });

  final GameRegion region;
  final bool isUnlocked;
  final int playerLevel;
  final VoidCallback? onTap;

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
                  color: isUnlocked ? FlitColors.cardBorder : FlitColors.textMuted,
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
                        color: isUnlocked ? FlitColors.accent : FlitColors.textMuted,
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
                        ],
                      ],
                    ),
                  ),
                  // Arrow or lock
                  Icon(
                    isUnlocked ? Icons.chevron_right : Icons.lock,
                    color: isUnlocked ? FlitColors.textSecondary : FlitColors.textMuted,
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
