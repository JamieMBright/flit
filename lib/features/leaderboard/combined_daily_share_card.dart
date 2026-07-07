import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';

/// One daily mode's identity for the combined card, in display order
/// (Scramble, Briefing, Recon) matching the `_combinedBreakdown` ordering.
class _CombinedMode {
  const _CombinedMode(this.region, this.label);

  /// `scores.region` key used in [CombinedDailyShareCard.modeEfficiencyBps].
  final String region;

  /// Human label shown on the card.
  final String label;
}

const List<_CombinedMode> _combinedModes = [
  _CombinedMode('daily', 'Scramble'),
  _CombinedMode('briefing', 'Briefing'),
  _CombinedMode('daily_triangulation', 'Recon'),
];

/// A spoiler-free, image-ready share card for the *combined* daily
/// leaderboard — the mean-efficiency board across all three dailies
/// (Scramble, Briefing, Recon).
///
/// Render inside a [RepaintBoundary] and capture with `captureReportPng`.
/// Both variants are answer-safe: they show the player's combined efficiency
/// and per-mode efficiency percentages only — never country names, maps, or
/// any other daily answer. The [detailed] variant adds numbers (rank, field
/// size, day number, modes played), not spoilers.
class CombinedDailyShareCard extends StatelessWidget {
  const CombinedDailyShareCard({
    super.key,
    required this.combinedBps,
    required this.modeEfficiencyBps,
    this.detailed = false,
    this.rank,
    this.totalPlayers,
    this.dayNumber,
  });

  /// Combined efficiency in basis points (0–10000, 8740 = 87.40%).
  final int combinedBps;

  /// Per-region efficiency in basis points, keyed by `scores.region`.
  /// A missing key means the mode was not played (rendered as "—").
  final Map<String, int> modeEfficiencyBps;

  /// When true, adds the numeric detail block (rank / field / day / played).
  final bool detailed;

  /// The player's rank across the full field (1-based). Detail variant only.
  final int? rank;

  /// Size of the full field that day. Detail variant only.
  final int? totalPlayers;

  /// 1-based daily day number ("Day N"). Detail variant only.
  final int? dayNumber;

  /// Coloured performance emoji for an efficiency in basis points.
  /// White (⚪) marks an unplayed mode.
  static String _perfEmoji(int? bps) {
    if (bps == null) return '\u{26AA}'; // ⚪ unplayed
    final pct = bps / 100;
    if (pct >= 85) return '\u{1F7E2}'; // 🟢 strong
    if (pct >= 65) return '\u{1F7E1}'; // 🟡 solid
    if (pct >= 40) return '\u{1F7E0}'; // 🟠 fair
    return '\u{1F534}'; // 🔴 low
  }

  static String _heroPct(int bps) => '${(bps / 100).toStringAsFixed(1)}%';

  static String _modePct(int? bps) =>
      bps == null ? '—' : '${(bps / 100).round()}%';

  int get _playedCount =>
      _combinedModes.where((m) => modeEfficiencyBps[m.region] != null).length;

  @override
  Widget build(BuildContext context) {
    final emojiGrid = _combinedModes
        .map((m) => _perfEmoji(modeEfficiencyBps[m.region]))
        .join();

    return Container(
      width: 340,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FlitColors.backgroundMid, FlitColors.backgroundDark],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FlitColors.gold.withValues(alpha: 0.55)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand row.
          Row(
            children: [
              const Icon(Icons.flight_takeoff,
                  color: FlitColors.gold, size: 18),
              const SizedBox(width: 6),
              const Text(
                'FLIT',
                style: TextStyle(
                  color: FlitColors.gold,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const Spacer(),
              Text(
                'DAILY REPORT',
                style: TextStyle(
                  color: FlitColors.textMuted.withValues(alpha: 0.9),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'ALL DAILIES',
            style: TextStyle(
              color: FlitColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              detailed && dayNumber != null
                  ? 'Combined daily · Day $dayNumber'
                  : 'Combined daily challenge',
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Hero: combined efficiency percentage. The number + label scale
          // down together (FittedBox) so a wide value can never overflow the
          // fixed-width card; the emoji strip sits at the trailing edge.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _heroPct(combinedBps),
                        style: const TextStyle(
                          color: FlitColors.gold,
                          fontSize: 34,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 3),
                        child: Text(
                          'combined',
                          style: TextStyle(
                            color: FlitColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                emojiGrid,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 16, height: 1.3),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Per-mode efficiency rows (spoiler-free: percentages only).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: FlitColors.cardBackground.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                for (final m in _combinedModes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text(
                          _perfEmoji(modeEfficiencyBps[m.region]),
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            m.label,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: FlitColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          _modePct(modeEfficiencyBps[m.region]),
                          style: const TextStyle(
                            color: FlitColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Detail block: rank / field / day / modes played — numbers only,
          // never answers. Capped at four so it renders as one clean row.
          if (detailed) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: FlitColors.cardBackground.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (rank != null) _stat('RANK', '#$rank'),
                  if (totalPlayers != null) _stat('FIELD', '$totalPlayers'),
                  if (dayNumber != null) _stat('DAY', '#$dayNumber'),
                  _stat('PLAYED', '$_playedCount/3'),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'jamiembright.github.io/flit',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: FlitColors.textMuted.withValues(alpha: 0.8),
                    fontSize: 9,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _todayLabel(),
                style: TextStyle(
                  color: FlitColors.textMuted.withValues(alpha: 0.8),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: FlitColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(
              color: FlitColors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      );

  static String _todayLabel() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
