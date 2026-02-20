import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/leaderboard_entry.dart';
import '../../data/services/leaderboard_service.dart';
import '../avatar/avatar_widget.dart';

/// Leaderboard screen showing top scores.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  LeaderboardPeriod _selectedPeriod = LeaderboardPeriod.daily;
  bool _loading = true;
  List<LeaderboardEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _loading = true);
    final entries = await LeaderboardService.instance.fetchLeaderboard(
      period: _selectedPeriod,
    );
    if (mounted) {
      setState(() {
        _entries = entries;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: FlitColors.backgroundDark,
    appBar: AppBar(
      backgroundColor: FlitColors.backgroundMid,
      title: const Text('Leaderboard'),
      centerTitle: true,
    ),
    body: Column(
      children: [
        // Period selector
        _PeriodSelector(
          selected: _selectedPeriod,
          onChanged: (period) {
            setState(() {
              _selectedPeriod = period;
            });
            _loadLeaderboard();
          },
        ),
        const Divider(color: FlitColors.cardBorder, height: 1),
        // Leaderboard list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _entries.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _entries.length,
                  itemBuilder: (context, index) =>
                      _LeaderboardRow(entry: _entries[index]),
                ),
        ),
      ],
    ),
  );
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onChanged});

  final LeaderboardPeriod selected;
  final ValueChanged<LeaderboardPeriod> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    color: FlitColors.backgroundMid,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: LeaderboardPeriod.values
          .map(
            (period) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(period.displayName),
                selected: period == selected,
                onSelected: (_) => onChanged(period),
                selectedColor: FlitColors.accent,
                backgroundColor: FlitColors.cardBackground,
                labelStyle: TextStyle(
                  color: period == selected
                      ? FlitColors.textPrimary
                      : FlitColors.textSecondary,
                  fontSize: 12,
                ),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          )
          .toList(),
    ),
  );
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final minutes = entry.time.inMinutes;
    final seconds = entry.time.inSeconds % 60;
    final millis = (entry.time.inMilliseconds % 1000) ~/ 10;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _rankColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: entry.rank <= 3 ? _rankColor : FlitColors.cardBorder,
        ),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 40,
            child: Text(
              entry.rank <= 3 ? _rankEmoji : '#${entry.rank}',
              style: TextStyle(
                fontSize: entry.rank <= 3 ? 24 : 16,
                fontWeight: FontWeight.bold,
                color: _rankColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Avatar
          AvatarFromUrl(
            avatarUrl: entry.avatarUrl,
            name: entry.playerName,
            size: 36,
          ),
          const SizedBox(width: 10),
          // Player info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.playerName,
                  style: const TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${entry.score} pts',
                  style: const TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Time
          Text(
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: FlitColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Color get _rankColor {
    switch (entry.rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return FlitColors.textSecondary;
    }
  }

  String get _rankEmoji {
    switch (entry.rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '#${entry.rank}';
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.leaderboard_outlined,
          size: 64,
          color: FlitColors.textMuted.withOpacity(0.5),
        ),
        const SizedBox(height: 16),
        const Text(
          'No scores yet',
          style: TextStyle(color: FlitColors.textSecondary, fontSize: 18),
        ),
        const SizedBox(height: 8),
        const Text(
          'Be the first to set a record!',
          style: TextStyle(color: FlitColors.textMuted, fontSize: 14),
        ),
      ],
    ),
  );
}
