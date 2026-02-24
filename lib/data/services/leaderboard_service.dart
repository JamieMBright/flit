import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/leaderboard_entry.dart';
import '../models/daily_challenge.dart';
import 'ttl_cache.dart';

/// Service that fetches real leaderboard data from Supabase.
///
/// Queries the `scores` table joined with `profiles` to build ranked lists.
/// All queries use Supabase's PostgREST API — no raw SQL needed.
///
/// High-traffic read paths are backed by an in-memory [TtlCache] so that
/// rapid screen opens (e.g. tab switching) don't each trigger a DB round-trip.
/// The cache auto-expires after 30 s for competitive boards (global, daily,
/// regional) and 60 s for less volatile data (hall of fame, player count).
/// Call [invalidateCache] after a score insert to force a fresh fetch.
class LeaderboardService {
  LeaderboardService._();

  static final LeaderboardService instance = LeaderboardService._();

  SupabaseClient get _client => Supabase.instance.client;

  // Cache: 30 s for competitive leaderboards, 60 s for slower-changing data.
  final _boardCache = TtlCache<List<LeaderboardEntry>>(
    const Duration(seconds: 30),
  );
  final _dailyBoardCache = TtlCache<List<DailyLeaderboardEntry>>(
    const Duration(seconds: 30),
  );
  final _hallOfFameCache = TtlCache<List<Map<String, dynamic>>>(
    const Duration(seconds: 60),
  );
  final _playerCountCache = TtlCache<int>(const Duration(seconds: 60));
  final _historyCache = TtlCache<List<Map<String, dynamic>>>(
    const Duration(seconds: 30),
  );
  final _rankCache = TtlCache<LeaderboardEntry?>(const Duration(seconds: 30));

  /// Drop every cached result. Call after the current user submits a score.
  void invalidateCache() {
    _boardCache.invalidate();
    _dailyBoardCache.invalidate();
    _hallOfFameCache.invalidate();
    _playerCountCache.invalidate();
    _historyCache.invalidate();
    _rankCache.invalidate();
  }

  // ---------------------------------------------------------------------------
  // Main leaderboard (used by LeaderboardScreen)
  // ---------------------------------------------------------------------------

  /// Fetch leaderboard entries for the given [period].
  ///
  /// Returns up to [limit] entries ordered by score descending, then time
  /// ascending (faster is better for tie-breaking).
  Future<List<LeaderboardEntry>> fetchLeaderboard({
    required LeaderboardPeriod period,
    int limit = 50,
  }) async {
    try {
      final query = _client
          .from('scores')
          .select(
            'score, time_ms, region, rounds_completed, created_at, '
            'user_id, profiles!inner(username, avatar_url)',
          );

      // Apply time filter based on period.
      final now = DateTime.now().toUtc();
      final PostgrestFilterBuilder<List<Map<String, dynamic>>> filtered;
      switch (period) {
        case LeaderboardPeriod.daily:
          final startOfDay = DateTime.utc(now.year, now.month, now.day);
          filtered = query.gte('created_at', startOfDay.toIso8601String());
          break;
        case LeaderboardPeriod.weekly:
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final start = DateTime.utc(
            startOfWeek.year,
            startOfWeek.month,
            startOfWeek.day,
          );
          filtered = query.gte('created_at', start.toIso8601String());
          break;
        case LeaderboardPeriod.monthly:
          final start = DateTime.utc(now.year, now.month, 1);
          filtered = query.gte('created_at', start.toIso8601String());
          break;
        case LeaderboardPeriod.yearly:
          final start = DateTime.utc(now.year, 1, 1);
          filtered = query.gte('created_at', start.toIso8601String());
          break;
        case LeaderboardPeriod.allTime:
          filtered = query;
          break;
      }

      final data = await filtered
          .order('score', ascending: false)
          .order('time_ms', ascending: true)
          .limit(limit);

      return _mapToLeaderboardEntries(data);
    } catch (e) {
      debugPrint('[LeaderboardService] fetchLeaderboard failed: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Daily challenge leaderboard
  // ---------------------------------------------------------------------------

  /// Fetch today's daily challenge leaderboard.
  Future<List<DailyLeaderboardEntry>> fetchDailyLeaderboard({
    int limit = 20,
  }) async {
    final cacheKey = 'daily_$limit';
    final cached = _dailyBoardCache.get(cacheKey);
    if (cached != null) return cached;

    try {
      final now = DateTime.now().toUtc();
      final startOfDay = DateTime.utc(now.year, now.month, now.day);

      final data = await _client
          .from('scores')
          .select(
            'score, time_ms, user_id, '
            'profiles!inner(username)',
          )
          .eq('region', 'daily')
          .gte('created_at', startOfDay.toIso8601String())
          .order('score', ascending: false)
          .order('time_ms', ascending: true)
          .limit(limit);

      final result = List<DailyLeaderboardEntry>.generate(data.length, (i) {
        final row = data[i];
        final profile = row['profiles'] as Map<String, dynamic>?;
        return DailyLeaderboardEntry(
          username: profile?['username'] as String? ?? 'Unknown',
          score: row['score'] as int? ?? 0,
          time: Duration(milliseconds: row['time_ms'] as int? ?? 0),
          rank: i + 1,
        );
      });

      _dailyBoardCache.set(cacheKey, result);
      return result;
    } catch (e) {
      debugPrint('[LeaderboardService] fetchDailyLeaderboard failed: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Hall of Fame (daily winners)
  // ---------------------------------------------------------------------------

  /// Fetch recent daily winners (top scorer per day for last N days).
  Future<List<Map<String, dynamic>>> fetchHallOfFame({int days = 5}) async {
    final cacheKey = 'hof_$days';
    final cached = _hallOfFameCache.get(cacheKey);
    if (cached != null) return cached;

    try {
      // Fetch top score per day for the last N days using a simple approach:
      // get the last N days of daily scores and pick the best per day.
      final now = DateTime.now().toUtc();
      final startDate = now.subtract(Duration(days: days));

      final data = await _client
          .from('scores')
          .select(
            'score, time_ms, created_at, user_id, '
            'profiles!inner(username)',
          )
          .eq('region', 'daily')
          .gte('created_at', startDate.toIso8601String())
          .order('score', ascending: false)
          .order('time_ms', ascending: true)
          .limit(100);

      // Group by date, pick best per day.
      final byDate = <String, Map<String, dynamic>>{};
      for (final row in data) {
        final createdAt = DateTime.parse(row['created_at'] as String);
        final dateKey =
            '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
        // First entry per date is the winner (already sorted by score desc).
        byDate.putIfAbsent(dateKey, () => row);
      }

      final result =
          byDate.entries.map((e) {
            final row = e.value;
            final profile = row['profiles'] as Map<String, dynamic>?;
            return {
              'date': e.key,
              'winner': profile?['username'] as String? ?? 'Unknown',
              'score': row['score'] as int? ?? 0,
            };
          }).toList()..sort(
            (a, b) => (b['date'] as String).compareTo(a['date'] as String),
          );

      _hallOfFameCache.set(cacheKey, result);
      return result;
    } catch (e) {
      debugPrint('[LeaderboardService] fetchHallOfFame failed: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Game history (for profile screen)
  // ---------------------------------------------------------------------------

  /// Fetch the current user's recent game history.
  Future<List<Map<String, dynamic>>> fetchGameHistory({
    required String userId,
    int limit = 20,
  }) async {
    final cacheKey = 'history_${userId}_$limit';
    final cached = _historyCache.get(cacheKey);
    if (cached != null) return cached;

    try {
      final data = await _client
          .from('scores')
          .select(
            'score, time_ms, region, rounds_completed, round_emojis, created_at',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      _historyCache.set(cacheKey, data);
      return data;
    } catch (e) {
      debugPrint('[LeaderboardService] fetchGameHistory failed: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Player count (for daily challenge screen)
  // ---------------------------------------------------------------------------

  /// Count how many players have submitted a daily score today.
  Future<int> fetchDailyPlayerCount() async {
    const cacheKey = 'daily_count';
    final cached = _playerCountCache.get(cacheKey);
    if (cached != null) return cached;

    try {
      final now = DateTime.now().toUtc();
      final startOfDay = DateTime.utc(now.year, now.month, now.day);

      final data = await _client
          .from('scores')
          .select('id')
          .eq('region', 'daily')
          .gte('created_at', startOfDay.toIso8601String());

      final count = data.length;
      _playerCountCache.set(cacheKey, count);
      return count;
    } catch (e) {
      debugPrint('[LeaderboardService] fetchDailyPlayerCount failed: $e');
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // View-based leaderboard queries
  // ---------------------------------------------------------------------------

  /// Fetch the global all-time leaderboard from the `leaderboard_global` view.
  ///
  /// The view pre-computes rank via `ROW_NUMBER()` ordered by score descending
  /// then time ascending, so results arrive fully ranked.
  Future<List<LeaderboardEntry>> fetchGlobal({int limit = 50}) async {
    final cacheKey = 'global_$limit';
    final cached = _boardCache.get(cacheKey);
    if (cached != null) return cached;

    try {
      final data = await _client
          .from('leaderboard_global')
          .select()
          .order('rank', ascending: true)
          .limit(limit);

      final result = _mapViewEntries(data);
      _boardCache.set(cacheKey, result);
      return result;
    } catch (e) {
      debugPrint('[LeaderboardService] fetchGlobal failed: $e');
      return [];
    }
  }

  /// Fetch today's daily leaderboard from the `leaderboard_daily` view.
  ///
  /// Only includes scores created since midnight UTC today.
  Future<List<LeaderboardEntry>> fetchDaily({int limit = 50}) async {
    final cacheKey = 'daily_view_$limit';
    final cached = _boardCache.get(cacheKey);
    if (cached != null) return cached;

    try {
      final data = await _client
          .from('leaderboard_daily')
          .select()
          .order('rank', ascending: true)
          .limit(limit);

      final result = _mapViewEntries(data);
      _boardCache.set(cacheKey, result);
      return result;
    } catch (e) {
      debugPrint('[LeaderboardService] fetchDaily failed: $e');
      return [];
    }
  }

  /// Fetch the regional leaderboard from the `leaderboard_regional` view,
  /// filtered to a specific [region].
  ///
  /// The view partitions rank by region, so each region has its own rank 1, 2,
  /// 3, etc.
  Future<List<LeaderboardEntry>> fetchRegional(
    String region, {
    int limit = 50,
  }) async {
    final cacheKey = 'regional_${region}_$limit';
    final cached = _boardCache.get(cacheKey);
    if (cached != null) return cached;

    try {
      final data = await _client
          .from('leaderboard_regional')
          .select()
          .eq('region', region)
          .order('rank', ascending: true)
          .limit(limit);

      final result = _mapViewEntries(data);
      _boardCache.set(cacheKey, result);
      return result;
    } catch (e) {
      debugPrint('[LeaderboardService] fetchRegional failed: $e');
      return [];
    }
  }

  /// Fetch daily streak leaderboard (ranked by current streak).
  Future<List<LeaderboardEntry>> fetchStreaks({int limit = 50}) async {
    const cacheKey = 'streaks';
    final cached = _boardCache.get(cacheKey);
    if (cached != null) return cached;

    try {
      final data = await _client
          .from('daily_streak_leaderboard')
          .select()
          .limit(limit);

      final result = data.asMap().entries.map((e) {
        final row = e.value;
        return LeaderboardEntry(
          playerId: row['user_id'] as String? ?? '',
          playerName: row['username'] as String? ?? 'Unknown',
          score: row['current_streak'] as int? ?? 0,
          time: Duration.zero,
          rank: e.key + 1,
        );
      }).toList();

      _boardCache.set(cacheKey, result);
      return result;
    } catch (e) {
      debugPrint('[LeaderboardService] fetchStreaks failed: $e');
      return [];
    }
  }

  /// Fetch a friends-only leaderboard for the given [userId].
  ///
  /// Joins scores with the `friendships` table to find accepted friends, then
  /// includes the user's own scores. Results are ranked by score descending.
  Future<List<LeaderboardEntry>> fetchFriends(
    String userId, {
    int limit = 50,
  }) async {
    final cacheKey = 'friends_${userId}_$limit';
    final cached = _boardCache.get(cacheKey);
    if (cached != null) return cached;

    try {
      // Step 1: Get the list of accepted friend IDs.
      final friendships = await _client
          .from('friendships')
          .select('requester_id, addressee_id')
          .eq('status', 'accepted')
          .or('requester_id.eq.$userId,addressee_id.eq.$userId');

      final friendIds = <String>{userId}; // Include the player themselves.
      for (final row in friendships) {
        final requesterId = row['requester_id'] as String;
        final addresseeId = row['addressee_id'] as String;
        friendIds.add(requesterId == userId ? addresseeId : requesterId);
      }

      // Step 2: Fetch scores for all friend IDs from the global view.
      final data = await _client
          .from('leaderboard_global')
          .select()
          .inFilter('user_id', friendIds.toList())
          .order('score', ascending: false)
          .order('time_ms', ascending: true)
          .limit(limit);

      // Step 3: Re-rank within the friends group (view rank is global).
      final result = List<LeaderboardEntry>.generate(data.length, (i) {
        final row = data[i];
        return LeaderboardEntry(
          rank: i + 1,
          playerId: row['user_id'] as String? ?? '',
          playerName: row['username'] as String? ?? 'Unknown',
          time: Duration(milliseconds: row['time_ms'] as int? ?? 0),
          score: row['score'] as int? ?? 0,
          avatarUrl: row['avatar_url'] as String?,
          timestamp: row['created_at'] != null
              ? DateTime.tryParse(row['created_at'] as String)
              : null,
        );
      });

      _boardCache.set(cacheKey, result);
      return result;
    } catch (e) {
      debugPrint('[LeaderboardService] fetchFriends failed: $e');
      return [];
    }
  }

  /// Fetch the current player's global rank.
  ///
  /// Returns the [LeaderboardEntry] for the player if found, or `null` if the
  /// player has no scores.
  Future<LeaderboardEntry?> fetchPlayerRank(String userId) async {
    final cacheKey = 'rank_$userId';
    // Note: _rankCache stores nullable values, so we check containment via get
    // returning a sentinel would over-complicate things — just re-fetch on miss.
    final cached = _rankCache.get(cacheKey);
    if (cached != null) return cached;

    try {
      final data = await _client
          .from('leaderboard_global')
          .select()
          .eq('user_id', userId)
          .order('rank', ascending: true)
          .limit(1)
          .maybeSingle();

      if (data == null) return null;

      final result = LeaderboardEntry(
        rank: data['rank'] as int? ?? 0,
        playerId: data['user_id'] as String? ?? '',
        playerName: data['username'] as String? ?? 'Unknown',
        time: Duration(milliseconds: data['time_ms'] as int? ?? 0),
        score: data['score'] as int? ?? 0,
        avatarUrl: data['avatar_url'] as String?,
        timestamp: data['created_at'] != null
            ? DateTime.tryParse(data['created_at'] as String)
            : null,
      );

      _rankCache.set(cacheKey, result);
      return result;
    } catch (e) {
      debugPrint('[LeaderboardService] fetchPlayerRank failed: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  /// Map rows from a leaderboard view (which includes `rank`, `user_id`,
  /// `username`, `avatar_url`, `score`, `time_ms`, `created_at` columns)
  /// into [LeaderboardEntry] objects.
  List<LeaderboardEntry> _mapViewEntries(List<Map<String, dynamic>> data) {
    return data.map((row) {
      return LeaderboardEntry(
        rank: row['rank'] as int? ?? 0,
        playerId: row['user_id'] as String? ?? '',
        playerName: row['username'] as String? ?? 'Unknown',
        time: Duration(milliseconds: row['time_ms'] as int? ?? 0),
        score: row['score'] as int? ?? 0,
        avatarUrl: row['avatar_url'] as String?,
        timestamp: row['created_at'] != null
            ? DateTime.tryParse(row['created_at'] as String)
            : null,
      );
    }).toList();
  }

  List<LeaderboardEntry> _mapToLeaderboardEntries(
    List<Map<String, dynamic>> data,
  ) {
    return List<LeaderboardEntry>.generate(data.length, (i) {
      final row = data[i];
      final profile = row['profiles'] as Map<String, dynamic>?;
      return LeaderboardEntry(
        rank: i + 1,
        playerId: row['user_id'] as String? ?? '',
        playerName: profile?['username'] as String? ?? 'Unknown',
        time: Duration(milliseconds: row['time_ms'] as int? ?? 0),
        score: row['score'] as int? ?? 0,
        avatarUrl: profile?['avatar_url'] as String?,
        timestamp: row['created_at'] != null
            ? DateTime.tryParse(row['created_at'] as String)
            : null,
      );
    });
  }
}
