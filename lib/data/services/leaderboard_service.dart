import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/leaderboard_entry.dart';
import '../models/daily_challenge.dart';

/// Service that fetches real leaderboard data from Supabase.
///
/// Queries the `scores` table joined with `profiles` to build ranked lists.
/// All queries use Supabase's PostgREST API — no raw SQL needed.
class LeaderboardService {
  LeaderboardService._();

  static final LeaderboardService instance = LeaderboardService._();

  SupabaseClient get _client => Supabase.instance.client;

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

      return List<DailyLeaderboardEntry>.generate(data.length, (i) {
        final row = data[i];
        final profile = row['profiles'] as Map<String, dynamic>?;
        return DailyLeaderboardEntry(
          username: profile?['username'] as String? ?? 'Unknown',
          score: row['score'] as int? ?? 0,
          time: Duration(milliseconds: row['time_ms'] as int? ?? 0),
          rank: i + 1,
        );
      });
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

      return byDate.entries.map((e) {
          final row = e.value;
          final profile = row['profiles'] as Map<String, dynamic>?;
          return {
            'date': e.key,
            'winner': profile?['username'] as String? ?? 'Unknown',
            'score': row['score'] as int? ?? 0,
          };
        }).toList()
        ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
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
    try {
      final data = await _client
          .from('scores')
          .select('score, time_ms, region, rounds_completed, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
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
    try {
      final now = DateTime.now().toUtc();
      final startOfDay = DateTime.utc(now.year, now.month, now.day);

      final data = await _client
          .from('scores')
          .select('id')
          .eq('region', 'daily')
          .gte('created_at', startOfDay.toIso8601String());

      return data.length;
    } catch (e) {
      debugPrint('[LeaderboardService] fetchDailyPlayerCount failed: $e');
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

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
