import 'package:flutter/material.dart';

import '../theme/flit_colors.dart';

/// One label/value stat row on a [MissionReportCard].
class ReportStat {
  const ReportStat(this.label, this.value);

  final String label;
  final String value;
}

/// One per-round performance row: coloured emoji + label + value
/// (e.g. 🟢  France  94%).
class ReportRow {
  const ReportRow(this.emoji, this.label, this.value);

  final String emoji;
  final String label;
  final String value;
}

/// The downloadable end-of-game summary card — a branded, image-ready
/// "mission report" that goes beyond the plain emoji share text.
///
/// Render inside a [RepaintBoundary] and capture with
/// `captureReportPng`; every game mode feeds the same layout:
/// header (mode + subtitle), big score, spoiler-free emoji grid, stat
/// rows, and an optional mini map (non-daily modes only — a map would
/// spoil a daily's answer for anyone the image is shared with).
class MissionReportCard extends StatelessWidget {
  const MissionReportCard({
    super.key,
    required this.modeTitle,
    this.subtitle,
    required this.score,
    this.emojiGrid,
    this.rows = const [],
    this.stats = const [],
    this.map,
    this.footnote,
  });

  final String modeTitle;
  final String? subtitle;
  final int score;
  final String? emojiGrid;

  /// Per-round performance rows (coloured emoji + label + value), the
  /// classic per-clue breakdown players share. Long sessions are capped
  /// with a "+N more" row.
  final List<ReportRow> rows;

  final List<ReportStat> stats;

  /// Mini reveal map (e.g. [RevealMapThumbnail]); omit for daily modes.
  final Widget? map;

  /// Small closing line, e.g. the app URL for friends to find the game.
  final String? footnote;

  @override
  Widget build(BuildContext context) {
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
        border: Border.all(color: FlitColors.gold.withOpacity(0.55)),
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
                'MISSION REPORT',
                style: TextStyle(
                  color: FlitColors.textMuted.withOpacity(0.9),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            modeTitle,
            style: const TextStyle(
              color: FlitColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                style: const TextStyle(
                  color: FlitColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 12),
          // Score band.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatScore(score),
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
                  'pts',
                  style: TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              if (emojiGrid != null)
                Text(
                  emojiGrid!,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 14, height: 1.3),
                ),
            ],
          ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: FlitColors.cardBackground.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  for (final row in rows.take(_maxRows))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1.5),
                      child: Row(
                        children: [
                          Text(row.emoji, style: const TextStyle(fontSize: 11)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              row.label,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: FlitColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            row.value,
                            style: const TextStyle(
                              color: FlitColors.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (rows.length > _maxRows)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '+${rows.length - _maxRows} more',
                        style: const TextStyle(
                          color: FlitColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (map != null) ...[
            const SizedBox(height: 12),
            map!,
          ],
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: FlitColors.cardBackground.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final s in stats)
                    Column(
                      children: [
                        Text(
                          s.value,
                          style: const TextStyle(
                            color: FlitColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          s.label,
                          style: const TextStyle(
                            color: FlitColors.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                footnote ?? 'jamiembright.github.io/flit',
                style: TextStyle(
                  color: FlitColors.textMuted.withOpacity(0.8),
                  fontSize: 9,
                ),
              ),
              Text(
                _todayLabel(),
                style: TextStyle(
                  color: FlitColors.textMuted.withOpacity(0.8),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Rows shown before collapsing to "+N more" (keeps long free-flight
  /// sessions from producing a poster-sized card).
  static const int _maxRows = 10;

  static String _formatScore(int score) {
    final s = score.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }

  static String _todayLabel() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
