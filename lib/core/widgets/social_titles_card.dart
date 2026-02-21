import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/flit_colors.dart';
import '../../data/models/cosmetic.dart';
import '../../data/models/social_title.dart';
import '../../data/providers/account_provider.dart';
import '../../data/services/title_service.dart';

/// A card widget that shows the player's social titles — earned titles,
/// the currently equipped title, and progress bars toward the next unlockable
/// titles.
///
/// Tapping an earned title equips it (or unequips it if it is already active).
///
/// This widget is self-contained and can be dropped into any screen.
class SocialTitlesCard extends ConsumerWidget {
  const SocialTitlesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountState = ref.watch(accountProvider);
    final notifier = ref.read(accountProvider.notifier);

    final unlocked = TitleService.getUnlockedTitles(accountState);
    final equipped = TitleService.getEquippedTitle(accountState);
    final nextTitles = TitleService.getNextTitles(accountState, limit: 3);

    return Container(
      decoration: BoxDecoration(
        color: FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FlitColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                const Icon(
                  Icons.military_tech_outlined,
                  color: FlitColors.gold,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Titles',
                  style: TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${unlocked.length} earned',
                  style: const TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Equipped title banner ────────────────────────────────────────
          if (equipped != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _EquippedTitleBanner(
                title: equipped,
                onClear: notifier.clearEquippedTitle,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: FlitColors.backgroundMid,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: FlitColors.cardBorder,
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Text(
                  'No title equipped — tap one below to display it.',
                  style: TextStyle(
                    color: FlitColors.textMuted,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          const SizedBox(height: 16),

          // ── Earned titles grid ───────────────────────────────────────────
          if (unlocked.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'EARNED',
                style: TextStyle(
                  color: FlitColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: unlocked.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final title = unlocked[index];
                  final isEquipped = equipped?.id == title.id;
                  return _TitleChip(
                    title: title,
                    isEquipped: isEquipped,
                    onTap: () {
                      if (isEquipped) {
                        notifier.clearEquippedTitle();
                      } else {
                        notifier.equipTitle(title.id);
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Progress toward next titles ──────────────────────────────────
          if (nextTitles.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'IN PROGRESS',
                style: TextStyle(
                  color: FlitColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...nextTitles.map(
              (tp) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _TitleProgressRow(progress: tp),
              ),
            ),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Equipped title banner
// ---------------------------------------------------------------------------

class _EquippedTitleBanner extends StatelessWidget {
  const _EquippedTitleBanner({required this.title, required this.onClear});

  final SocialTitle title;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final rarityColor = _rarityColor(title.rarity);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: rarityColor.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: rarityColor.withAlpha(128)),
      ),
      child: Row(
        children: [
          Icon(_rarityIcon(title.rarity), color: rarityColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title.name,
                  style: TextStyle(
                    color: rarityColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title.description,
                  style: const TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onClear,
            child: const Icon(
              Icons.close,
              color: FlitColors.textMuted,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Title chip (earned titles row)
// ---------------------------------------------------------------------------

class _TitleChip extends StatelessWidget {
  const _TitleChip({
    required this.title,
    required this.isEquipped,
    required this.onTap,
  });

  final SocialTitle title;
  final bool isEquipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rarityColor = _rarityColor(title.rarity);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isEquipped
              ? rarityColor.withAlpha(51)
              : FlitColors.backgroundMid,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isEquipped ? rarityColor : FlitColors.cardBorder,
            width: isEquipped ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isEquipped) ...[
              Icon(Icons.check_circle, color: rarityColor, size: 12),
              const SizedBox(width: 4),
            ],
            Text(
              title.name,
              style: TextStyle(
                color: isEquipped ? rarityColor : FlitColors.textSecondary,
                fontSize: 12,
                fontWeight: isEquipped ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress row (locked titles close to unlocking)
// ---------------------------------------------------------------------------

class _TitleProgressRow extends StatelessWidget {
  const _TitleProgressRow({required this.progress});

  final TitleProgress progress;

  @override
  Widget build(BuildContext context) {
    final title = progress.title;
    final rarityColor = _rarityColor(title.rarity);
    final fraction = progress.progressFraction;
    final pct = (fraction * 100).round();

    // Human-readable "X / Y" label.
    final currentLabel = _currentLabel(progress);
    final thresholdLabel = _thresholdLabel(progress);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: FlitColors.backgroundMid,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FlitColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_rarityIcon(title.rarity), color: rarityColor, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title.name,
                  style: TextStyle(
                    color: rarityColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$currentLabel / $thresholdLabel',
                style: const TextStyle(
                  color: FlitColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: FlitColors.backgroundDark,
              valueColor: AlwaysStoppedAnimation<Color>(rarityColor),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$pct% — ${title.description}',
            style: const TextStyle(color: FlitColors.textMuted, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _currentLabel(TitleProgress tp) {
    if (tp.title.category == TitleCategory.speed) {
      if (tp.currentValue <= 0) return '--';
      return '${tp.currentValue}s';
    }
    return '${tp.currentValue}';
  }

  String _thresholdLabel(TitleProgress tp) {
    if (tp.title.category == TitleCategory.speed) {
      return '<${tp.title.threshold}s';
    }
    return '${tp.title.threshold}';
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Color _rarityColor(CosmeticRarity rarity) {
  switch (rarity) {
    case CosmeticRarity.common:
      return FlitColors.textSecondary;
    case CosmeticRarity.rare:
      return FlitColors.oceanHighlight;
    case CosmeticRarity.epic:
      return const Color(0xFF9B59B6); // purple
    case CosmeticRarity.legendary:
      return FlitColors.gold;
  }
}

IconData _rarityIcon(CosmeticRarity rarity) {
  switch (rarity) {
    case CosmeticRarity.common:
      return Icons.circle_outlined;
    case CosmeticRarity.rare:
      return Icons.star_border;
    case CosmeticRarity.epic:
      return Icons.auto_awesome;
    case CosmeticRarity.legendary:
      return Icons.workspace_premium;
  }
}
