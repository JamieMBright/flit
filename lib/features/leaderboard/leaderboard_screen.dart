import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/models/leaderboard_entry.dart';
import '../../data/services/leaderboard_service.dart';
import '../avatar/avatar_widget.dart';

/// Leaderboard screen showing daily challenge scores from Supabase views.
///
/// Tabs: All Time | Today | Streaks | Friends
/// Fetches ranked data from the `leaderboard_global` (daily-only),
/// `leaderboard_daily`, and `daily_streak_leaderboard` SQL views, plus a
/// friends query.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  LeaderboardTab _selectedTab = LeaderboardTab.global;
  bool _loading = true;
  List<LeaderboardEntry> _entries = [];
  LeaderboardEntry? _playerRank;

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
    _loadPlayerRank();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _loading = true);

    final service = LeaderboardService.instance;
    List<LeaderboardEntry> entries;

    switch (_selectedTab) {
      case LeaderboardTab.global:
        entries = await service.fetchGlobal();
        break;
      case LeaderboardTab.daily:
        entries = await service.fetchDaily();
        break;
      case LeaderboardTab.regional:
        entries = await service.fetchStreaks();
        break;
      case LeaderboardTab.friends:
        final userId = _userId;
        if (userId != null) {
          entries = await service.fetchFriends(userId);
        } else {
          entries = [];
        }
        break;
    }

    if (mounted) {
      setState(() {
        _entries = entries;
        _loading = false;
      });
    }
  }

  Future<void> _loadPlayerRank() async {
    final userId = _userId;
    if (userId == null) return;

    final rank = await LeaderboardService.instance.fetchPlayerRank(userId);
    if (mounted) {
      setState(() => _playerRank = rank);
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
        // Tab selector
        _TabSelector(
          selected: _selectedTab,
          onChanged: (tab) {
            setState(() {
              _selectedTab = tab;
            });
            _loadLeaderboard();
          },
        ),
        const Divider(color: FlitColors.cardBorder, height: 1),
        // Player's own rank banner
        if (_playerRank != null) _PlayerRankBanner(entry: _playerRank!),
        // Leaderboard list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _entries.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _entries.length,
                  itemBuilder: (context, index) => _LeaderboardRow(
                    entry: _entries[index],
                    isCurrentPlayer: _entries[index].playerId == _userId,
                    isStreakTab: _selectedTab == LeaderboardTab.regional,
                  ),
                ),
        ),
      ],
    ),
  );
}

/// Horizontal chip selector for leaderboard tabs.
class _TabSelector extends StatelessWidget {
  const _TabSelector({required this.selected, required this.onChanged});

  final LeaderboardTab selected;
  final ValueChanged<LeaderboardTab> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    color: FlitColors.backgroundMid,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: LeaderboardTab.values
          .map(
            (tab) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(tab.displayName),
                selected: tab == selected,
                onSelected: (_) => onChanged(tab),
                selectedColor: FlitColors.accent,
                backgroundColor: FlitColors.cardBackground,
                labelStyle: TextStyle(
                  color: tab == selected
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

/// Banner showing the current player's rank prominently at the top of the
/// list. Styled differently from regular rows to draw attention.
class _PlayerRankBanner extends StatelessWidget {
  const _PlayerRankBanner({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [FlitColors.accent, FlitColors.accentDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#${entry.rank}',
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Player info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Rank',
                  style: TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.playerName,
                  style: const TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Score
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.score} pts',
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _formatTime(entry.time),
                style: TextStyle(
                  color: FlitColors.textPrimary.withOpacity(0.8),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    final millis = (d.inMilliseconds % 1000) ~/ 10;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${millis.toString().padLeft(2, '0')}';
  }
}

/// A single leaderboard row with rank, avatar, name, score, and time.
class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.entry,
    this.isCurrentPlayer = false,
    this.isStreakTab = false,
  });

  final LeaderboardEntry entry;
  final bool isCurrentPlayer;
  final bool isStreakTab;

  @override
  Widget build(BuildContext context) {
    final minutes = entry.time.inMinutes;
    final seconds = entry.time.inSeconds % 60;
    final millis = (entry.time.inMilliseconds % 1000) ~/ 10;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentPlayer
            ? FlitColors.accent.withOpacity(0.15)
            : _rankColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentPlayer
              ? FlitColors.accent
              : entry.rank <= 3
              ? _rankColor
              : FlitColors.cardBorder,
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
                  style: TextStyle(
                    color: isCurrentPlayer
                        ? FlitColors.accent
                        : FlitColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  isStreakTab
                      ? '${entry.score} day streak'
                      : '${entry.score} pts',
                  style: const TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Time (hidden for streak tab)
          if (!isStreakTab)
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
        return '\u{1F947}';
      case 2:
        return '\u{1F948}';
      case 3:
        return '\u{1F949}';
      default:
        return '#${entry.rank}';
    }
  }
}

/// Empty state shown when there are no leaderboard entries.
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
