import 'package:flutter/material.dart';

import '../theme/flit_colors.dart';

/// Which flavour of result image the player wants to share.
///
/// - [anonymous] — spoiler-free: score, performance emojis, splits and
///   efficiency, but no map and no revealed answers. Safe to post publicly
///   (e.g. before friends have played today's daily).
/// - [detailed] — the full breakdown: the reveal map (flight path / clue
///   anchors / region), named answers, and the day's difficulty. For sharing
///   with people who have already played.
enum ShareVariant { anonymous, detailed }

/// Present the Anon vs Detailed chooser as a bottom sheet and return the
/// player's pick (or null if dismissed).
///
/// [detailedSpoilerNote] tailors the spoiler warning to the mode
/// (e.g. "reveals the flight path and countries").
Future<ShareVariant?> showShareVariantSheet(
  BuildContext context, {
  String detailedSpoilerNote = 'reveals the map and answers',
}) {
  return showModalBottomSheet<ShareVariant>(
    context: context,
    backgroundColor: FlitColors.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: FlitColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Share result',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _VariantTile(
              icon: Icons.visibility_off_rounded,
              title: 'Anonymous',
              subtitle:
                  'Score, splits and efficiency — no map, no answers. Safe to '
                  'post before others have played.',
              onTap: () => Navigator.of(context).pop(ShareVariant.anonymous),
            ),
            const SizedBox(height: 10),
            _VariantTile(
              icon: Icons.map_rounded,
              title: 'Detailed',
              subtitle:
                  'Full breakdown — $detailedSpoilerNote, plus the day\'s '
                  'difficulty. A spoiler; share with pilots who have played.',
              onTap: () => Navigator.of(context).pop(ShareVariant.detailed),
              accent: true,
            ),
          ],
        ),
      ),
    ),
  );
}

class _VariantTile extends StatelessWidget {
  const _VariantTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final border = accent ? FlitColors.accent : FlitColors.cardBorder;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FlitColors.backgroundMid,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: accent ? FlitColors.accent : FlitColors.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: FlitColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: FlitColors.textMuted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
