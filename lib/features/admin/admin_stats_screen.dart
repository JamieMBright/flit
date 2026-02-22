import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/flit_colors.dart';

/// Admin usage statistics dashboard.
///
/// Queries Supabase directly for player counts, game activity,
/// matchmaking status, and top players. Pull-to-refresh supported.
class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  SupabaseClient get _client => Supabase.instance.client;

  bool _loading = true;
  String? _error;

  // Player stats
  int _totalPlayers = 0;
  int _signups24h = 0;
  int _signups7d = 0;
  int _signups30d = 0;

  // Game stats
  int _totalGames = 0;
  int _games1h = 0;
  int _games24h = 0;
  int _games7d = 0;

  // Social stats
  int _activeChallenges = 0;
  int _matchmakingPool = 0;
  int _totalFriendships = 0;

  // Top players
  List<Map<String, dynamic>> _topPlayers = [];

  // Recent games
  List<Map<String, dynamic>> _recentGames = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final now = DateTime.now().toUtc();
      final h1 = now.subtract(const Duration(hours: 1)).toIso8601String();
      final h24 = now.subtract(const Duration(hours: 24)).toIso8601String();
      final d7 = now.subtract(const Duration(days: 7)).toIso8601String();
      final d30 = now.subtract(const Duration(days: 30)).toIso8601String();

      // Run all queries in parallel
      final results = await Future.wait<dynamic>([
        // 0: total players
        _client.from('profiles').select('id').count(CountOption.exact),
        // 1: signups 24h
        _client
            .from('profiles')
            .select('id')
            .gte('created_at', h24)
            .count(CountOption.exact),
        // 2: signups 7d
        _client
            .from('profiles')
            .select('id')
            .gte('created_at', d7)
            .count(CountOption.exact),
        // 3: signups 30d
        _client
            .from('profiles')
            .select('id')
            .gte('created_at', d30)
            .count(CountOption.exact),
        // 4: total games
        _client.from('scores').select('id').count(CountOption.exact),
        // 5: games 1h
        _client
            .from('scores')
            .select('id')
            .gte('created_at', h1)
            .count(CountOption.exact),
        // 6: games 24h
        _client
            .from('scores')
            .select('id')
            .gte('created_at', h24)
            .count(CountOption.exact),
        // 7: games 7d
        _client
            .from('scores')
            .select('id')
            .gte('created_at', d7)
            .count(CountOption.exact),
        // 8: active challenges
        _client
            .from('challenges')
            .select('id')
            .inFilter('status', ['pending', 'in_progress'])
            .count(CountOption.exact),
        // 9: matchmaking pool (unmatched)
        _client
            .from('matchmaking_pool')
            .select('id')
            .isFilter('matched_at', null)
            .count(CountOption.exact),
        // 10: total friendships
        _client
            .from('friendships')
            .select('id')
            .eq('status', 'accepted')
            .count(CountOption.exact),
        // 11: top players by games played
        _client
            .from('profiles')
            .select(
              'username, level, xp, coins, games_played, best_score, best_time_ms',
            )
            .order('games_played', ascending: false)
            .limit(10),
        // 12: recent games
        _client
            .from('scores')
            .select('score, time_ms, region, rounds_completed, created_at')
            .order('created_at', ascending: false)
            .limit(15),
      ]);

      if (!mounted) return;

      setState(() {
        _totalPlayers = _extractCount(results[0]);
        _signups24h = _extractCount(results[1]);
        _signups7d = _extractCount(results[2]);
        _signups30d = _extractCount(results[3]);
        _totalGames = _extractCount(results[4]);
        _games1h = _extractCount(results[5]);
        _games24h = _extractCount(results[6]);
        _games7d = _extractCount(results[7]);
        _activeChallenges = _extractCount(results[8]);
        _matchmakingPool = _extractCount(results[9]);
        _totalFriendships = _extractCount(results[10]);
        _topPlayers = _extractList(results[11]);
        _recentGames = _extractList(results[12]);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int _extractCount(dynamic result) {
    if (result is PostgrestResponse) return result.count;
    return 0;
  }

  List<Map<String, dynamic>> _extractList(dynamic result) {
    if (result is List) {
      return result.cast<Map<String, dynamic>>();
    }
    if (result is PostgrestResponse && result.data is List) {
      return (result.data as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: const Text('Usage Stats'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadStats,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: FlitColors.accent),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: FlitColors.error,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: FlitColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadStats,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadStats,
              color: FlitColors.accent,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildPlayerStats(),
                  const SizedBox(height: 16),
                  _buildGameActivity(),
                  const SizedBox(height: 16),
                  _buildSocialStats(),
                  const SizedBox(height: 16),
                  _buildTopPlayers(),
                  const SizedBox(height: 16),
                  _buildRecentGames(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildPlayerStats() {
    return _StatsCard(
      title: 'Players',
      icon: Icons.people,
      iconColor: FlitColors.accent,
      children: [
        _StatRow('Total registered', _totalPlayers.toString()),
        _StatRow('Signups (24h)', _signups24h.toString()),
        _StatRow('Signups (7d)', _signups7d.toString()),
        _StatRow('Signups (30d)', _signups30d.toString()),
      ],
    );
  }

  Widget _buildGameActivity() {
    final gamesPerPlayer = _totalPlayers > 0
        ? (_totalGames / _totalPlayers).toStringAsFixed(1)
        : '0';
    return _StatsCard(
      title: 'Game Activity',
      icon: Icons.flight,
      iconColor: FlitColors.oceanHighlight,
      children: [
        _StatRow('Total games played', _totalGames.toString()),
        _StatRow(
          'Games (last hour)',
          _games1h.toString(),
          highlight: _games1h > 0,
        ),
        _StatRow('Games (24h)', _games24h.toString(), highlight: _games24h > 0),
        _StatRow('Games (7d)', _games7d.toString()),
        _StatRow('Avg games/player', gamesPerPlayer),
      ],
    );
  }

  Widget _buildSocialStats() {
    return _StatsCard(
      title: 'Social & Matchmaking',
      icon: Icons.handshake,
      iconColor: FlitColors.gold,
      children: [
        _StatRow('Active challenges', _activeChallenges.toString()),
        _StatRow('Matchmaking queue', _matchmakingPool.toString()),
        _StatRow('Total friendships', _totalFriendships.toString()),
      ],
    );
  }

  Widget _buildTopPlayers() {
    return _StatsCard(
      title: 'Top Players (by flights)',
      icon: Icons.leaderboard,
      iconColor: FlitColors.goldLight,
      children: [
        if (_topPlayers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No players yet',
              style: TextStyle(color: FlitColors.textMuted, fontSize: 13),
            ),
          )
        else
          for (var i = 0; i < _topPlayers.length; i++)
            _buildPlayerRow(i + 1, _topPlayers[i]),
      ],
    );
  }

  Widget _buildPlayerRow(int rank, Map<String, dynamic> player) {
    final username = player['username'] ?? '???';
    final level = player['level'] ?? 0;
    final games = player['games_played'] ?? 0;
    final bestScore = player['best_score'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: rank <= 3 ? FlitColors.gold : FlitColors.textMuted,
                fontSize: 12,
                fontWeight: rank <= 3 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '@$username',
              style: const TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            'Lv.$level',
            style: const TextStyle(
              color: FlitColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$games flights',
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Best: $bestScore',
            style: const TextStyle(color: FlitColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentGames() {
    return _StatsCard(
      title: 'Recent Games',
      icon: Icons.history,
      iconColor: FlitColors.accentLight,
      children: [
        if (_recentGames.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No recent games',
              style: TextStyle(color: FlitColors.textMuted, fontSize: 13),
            ),
          )
        else
          for (final game in _recentGames) _buildGameRow(game),
      ],
    );
  }

  Widget _buildGameRow(Map<String, dynamic> game) {
    final score = game['score'] ?? 0;
    final timeMs = game['time_ms'] ?? 0;
    final region = game['region'] ?? 'world';
    final rounds = game['rounds_completed'] ?? 0;
    final createdAt = game['created_at'] as String?;

    String timeAgo = '';
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt);
      if (dt != null) {
        final diff = DateTime.now().toUtc().difference(dt);
        if (diff.inMinutes < 60) {
          timeAgo = '${diff.inMinutes}m ago';
        } else if (diff.inHours < 24) {
          timeAgo = '${diff.inHours}h ago';
        } else {
          timeAgo = '${diff.inDays}d ago';
        }
      }
    }

    final timeSec = (timeMs / 1000).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: FlitColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              region.toString().toUpperCase(),
              style: const TextStyle(
                color: FlitColors.accent,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$score pts',
            style: const TextStyle(
              color: FlitColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${timeSec}s',
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$rounds rds',
            style: const TextStyle(color: FlitColors.textMuted, fontSize: 11),
          ),
          const Spacer(),
          Text(
            timeAgo,
            style: const TextStyle(color: FlitColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ──

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlitColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value, {this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: highlight ? FlitColors.success : FlitColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
