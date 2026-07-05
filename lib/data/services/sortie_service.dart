import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/sortie.dart';

/// Service for Standard Sortie rated runs.
///
/// Runs post to the `sortie_runs` table and ratings move via the
/// SECURITY DEFINER `apply_sortie_rating` RPC (ghost duel Elo, idempotent —
/// see supabase/migrations/20260705_standard_sortie.sql). Everything here
/// feature-detects and degrades silently: before the migration is applied,
/// runs simply aren't rated/persisted server-side and the UI shows the
/// provisional rating instead (the established ChallengeService pattern).
class SortieService {
  SortieService._();

  static final SortieService instance = SortieService._();

  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  /// The rating game_mode key in `player_ratings`.
  static const String gameMode = 'sortie';

  /// Submit a completed run and resolve the ghost duel.
  ///
  /// Returns [SortieOutcome.unavailable] when signed out, the insert fails,
  /// or the RPC isn't deployed — the run still counted locally (scores table)
  /// and the caller shows a provisional result.
  Future<SortieOutcome> submitRun({
    required SortieRun run,
    required int totalScore,
    required int totalTimeMs,
    required String playerName,
    List<Map<String, dynamic>>? roundDetails,
  }) async {
    if (_userId == null) return SortieOutcome.unavailable;

    String? runId;
    try {
      final row = await _client
          .from('sortie_runs')
          .insert({
            'user_id': _userId,
            'player_name': playerName,
            'seeds': run.seeds,
            'rounds': roundDetails,
            'score': totalScore.clamp(0, SortieRun.maxRunScore),
            'time_ms': totalTimeMs,
          })
          .select('id')
          .single();
      runId = row['id'] as String?;
    } catch (e) {
      debugPrint(
        '[SortieService] sortie_runs insert unavailable (non-critical): $e',
      );
      return SortieOutcome.unavailable;
    }
    if (runId == null) return SortieOutcome.unavailable;

    try {
      final result = await _client.rpc<dynamic>(
        'apply_sortie_rating',
        params: {'p_run_id': runId},
      );
      if (result is Map) {
        return SortieOutcome.fromJson(Map<String, dynamic>.from(result));
      }
    } catch (e) {
      debugPrint(
        '[SortieService] apply_sortie_rating unavailable (non-critical): $e',
      );
    }
    return SortieOutcome.unavailable;
  }

  /// Fetch the top sortie runs (best run per pilot), newest-first tiebreak.
  ///
  /// Returns an empty list when the table isn't deployed.
  Future<List<SortieLeaderboardRow>> fetchTopRuns({int limit = 50}) async {
    try {
      final data = await _client
          .from('sortie_runs')
          .select('user_id, player_name, score, time_ms, rating, created_at')
          .order('score', ascending: false)
          .order('time_ms', ascending: true)
          .limit(limit * 3); // Overfetch; dedupe to best-per-pilot below.

      final seen = <String>{};
      final rows = <SortieLeaderboardRow>[];
      for (final row in data) {
        final userId = row['user_id'] as String? ?? '';
        if (!seen.add(userId)) continue;
        rows.add(
          SortieLeaderboardRow(
            userId: userId,
            playerName: row['player_name'] as String? ?? 'Pilot',
            score: row['score'] as int? ?? 0,
            timeMs: row['time_ms'] as int? ?? 0,
            rating: row['rating'] as int?,
          ),
        );
        if (rows.length >= limit) break;
      }
      return rows;
    } catch (e) {
      debugPrint('[SortieService] fetchTopRuns unavailable: $e');
      return [];
    }
  }
}

/// One row on the Sortie leaderboard.
class SortieLeaderboardRow {
  const SortieLeaderboardRow({
    required this.userId,
    required this.playerName,
    required this.score,
    required this.timeMs,
    this.rating,
  });

  final String userId;
  final String playerName;
  final int score;
  final int timeMs;

  /// The pilot's sortie rating stamped on the run (null pre-rating).
  final int? rating;
}
