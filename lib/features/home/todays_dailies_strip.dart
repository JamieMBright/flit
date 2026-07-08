import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/flit_colors.dart';
import '../../core/theme/flit_theme.dart';
import '../../core/utils/report_capture.dart';
import '../../data/models/leaderboard_entry.dart';
import '../../data/services/leaderboard_service.dart';
import '../leaderboard/combined_daily_share_card.dart';
import '../daily/daily_challenge_screen.dart';
import '../quiz/daily_briefing_screen.dart';
import '../triangulation/daily_triangulation_screen.dart';

/// One daily mode shown as a chip in the home strip.
class _DailyMode {
  const _DailyMode(this.region, this.label, this.icon, this.builder);

  /// `scores.region` key used in [LeaderboardEntry.combinedEfficiencyBps].
  final String region;
  final String label;
  final IconData icon;

  /// Route to the mode's own screen for the full result / to play.
  final Widget Function() builder;
}

final List<_DailyMode> _modes = [
  _DailyMode('daily', 'Scramble', Icons.today_rounded,
      () => const DailyChallengeScreen()),
  _DailyMode('briefing', 'Briefing', Icons.assignment_rounded,
      () => const DailyBriefingScreen()),
  _DailyMode('daily_triangulation', 'Recon', Icons.explore_rounded,
      () => const DailyTriangulationScreen()),
];

/// Home-screen strip showing the player's efficiency on each of today's three
/// dailies plus the combined board. Each chip is tappable: a daily opens a
/// spoiler-free result/share sheet (or a Play CTA when unplayed); the combined
/// chip opens the shareable combined card. Efficiency (your best vs the day's
/// top score) is used because it's the one number available on any device the
/// player signs into — the raw per-mode scores are device-local.
class TodaysDailiesStrip extends ConsumerStatefulWidget {
  const TodaysDailiesStrip({super.key});

  @override
  ConsumerState<TodaysDailiesStrip> createState() => _TodaysDailiesStripState();
}

class _TodaysDailiesStripState extends ConsumerState<TodaysDailiesStrip> {
  bool _loading = true;
  LeaderboardEntry? _entry;
  int _totalPlayers = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result =
        await LeaderboardService.instance.fetchOwnCombinedDailyScore();
    if (!mounted) return;
    setState(() {
      _entry = result?.entry;
      _totalPlayers = result?.totalPlayers ?? 0;
      _loading = false;
    });
  }

  int? _effBps(String region) => _entry?.combinedEfficiencyBps?[region];

  /// A daily field with only this player is degenerate (best == top → 100%),
  /// so the combined % is shown as "—" rather than a misleading perfect score.
  bool get _solo => _totalPlayers <= 1;

  static String _pct(int? bps) => bps == null ? '—' : '${(bps / 100).round()}%';

  @override
  Widget build(BuildContext context) {
    // Hide entirely until we know there's something to show — a fresh player
    // who hasn't touched a daily gets no empty strip.
    if (_loading || _entry == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: FlitColors.cardBackground.withOpacity(0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FlitColors.gold.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stars_rounded, color: FlitColors.gold, size: 14),
              const SizedBox(width: 6),
              const Text(
                "TODAY'S DAILIES",
                style: TextStyle(
                  color: FlitColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                'tap for results',
                style: TextStyle(
                  color: FlitColors.textMuted.withOpacity(0.8),
                  fontSize: 9,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < _modes.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _Chip(
                    label: _modes[i].label,
                    value: _pct(_effBps(_modes[i].region)),
                    icon: _modes[i].icon,
                    played: _effBps(_modes[i].region) != null,
                    onTap: () => _openMode(_modes[i]),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          _Chip(
            label: 'Combined',
            value: _solo ? '—' : _pct(_entry!.score),
            icon: Icons.emoji_events_rounded,
            played: true,
            highlighted: true,
            trailing: _solo ? null : '#${_entry!.rank}',
            onTap: _openCombined,
          ),
        ],
      ),
    );
  }

  void _openMode(_DailyMode mode) {
    final bps = _effBps(mode.region);
    if (bps == null) {
      // Not played yet — route straight to the mode to play it.
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => mode.builder()));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ModeResultSheet(
        mode: mode,
        efficiencyBps: bps,
        onOpenFull: () {
          Navigator.of(ctx).pop();
          Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => mode.builder()));
        },
      ),
    );
  }

  void _openCombined() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _CombinedResultSheet(
        combinedBps: _entry!.score,
        modeEfficiencyBps: _entry!.combinedEfficiencyBps ?? const {},
        rank: _entry!.rank,
        totalPlayers: _totalPlayers,
      ),
    );
  }
}

/// A single tappable daily chip.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.value,
    required this.icon,
    required this.played,
    required this.onTap,
    this.highlighted = false,
    this.trailing,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool played;
  final bool highlighted;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = highlighted ? FlitColors.gold : FlitColors.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: FlitColors.backgroundDark.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: highlighted
                  ? FlitColors.gold.withOpacity(0.5)
                  : FlitColors.cardBorder.withOpacity(0.6),
            ),
          ),
          child: Row(
            mainAxisAlignment: highlighted
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14, color: played ? accent : FlitColors.textMuted),
              const SizedBox(width: 6),
              Flexible(
                child: Column(
                  crossAxisAlignment: highlighted
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FlitColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      played ? value : 'PLAY',
                      style: TextStyle(
                        color: played ? FlitColors.textPrimary : accent,
                        fontSize: highlighted ? 15 : 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const Spacer(),
                Text(
                  trailing!,
                  style: const TextStyle(
                    color: FlitColors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for a single daily's spoiler-free result + share.
class _ModeResultSheet extends StatelessWidget {
  const _ModeResultSheet({
    required this.mode,
    required this.efficiencyBps,
    required this.onOpenFull,
  });

  final _DailyMode mode;
  final int efficiencyBps;
  final VoidCallback onOpenFull;

  @override
  Widget build(BuildContext context) {
    final pct = (efficiencyBps / 100).round();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: const BoxDecoration(
        color: FlitColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: FlitColors.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Icon(mode.icon, color: FlitColors.accent, size: 30),
          const SizedBox(height: 8),
          Text(
            'Daily ${mode.label}',
            style: const TextStyle(
              color: FlitColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$pct%',
            style: const TextStyle(
              color: FlitColors.gold,
              fontSize: 40,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'efficiency today',
            style: TextStyle(color: FlitColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: FlitColors.accent),
              onPressed: onOpenFull,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text('Open full ${mode.label} result'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet hosting the shareable combined daily card.
class _CombinedResultSheet extends StatefulWidget {
  const _CombinedResultSheet({
    required this.combinedBps,
    required this.modeEfficiencyBps,
    required this.rank,
    required this.totalPlayers,
  });

  final int combinedBps;
  final Map<String, int> modeEfficiencyBps;
  final int? rank;
  final int totalPlayers;

  @override
  State<_CombinedResultSheet> createState() => _CombinedResultSheetState();
}

class _CombinedResultSheetState extends State<_CombinedResultSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final png = await captureReportPng(_cardKey);
      if (png == null || !mounted) return;
      await shareReportImage(
        context,
        png: png,
        filename: 'flit-combined-daily.png',
        fallbackText: 'Flit — All Dailies\n'
            'Combined ${(widget.combinedBps / 100).toStringAsFixed(1)}%',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: const BoxDecoration(
        color: FlitColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: FlitColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            RepaintBoundary(
              key: _cardKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
                child: CombinedDailyShareCard(
                  combinedBps: widget.combinedBps,
                  modeEfficiencyBps: widget.modeEfficiencyBps,
                  detailed: true,
                  rank: widget.rank,
                  totalPlayers: widget.totalPlayers,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: FlitColors.gold),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: FlitColors.backgroundDark),
                      )
                    : const Icon(Icons.ios_share_rounded, size: 18),
                label: Text(_saving ? 'Saving…' : 'Share combined card'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
