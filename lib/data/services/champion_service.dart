import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../game/economy/consumables.dart';

/// A claimed daily-champion reward: which board, which day, what dropped.
class ChampionReward {
  const ChampionReward({
    required this.gameMode,
    required this.date,
    required this.reward,
  });

  /// Board region key ('daily' | 'daily_triangulation' | 'briefing').
  final String gameMode;

  /// The UTC day the board covered (YYYY-MM-DD).
  final String date;

  final ConsumableType reward;

  /// Player-facing board name.
  String get boardLabel => switch (gameMode) {
        'daily' => 'Daily Scramble',
        'daily_triangulation' => 'Daily Recon',
        'briefing' => 'Daily Briefing',
        _ => gameMode,
      };
}

/// Client for the daily-champion consumable rewards
/// (supabase/migrations/20260705_daily_champion_claims.sql).
///
/// The #1 finisher on each daily board (Scramble, Recon, Briefing) always
/// gets a consumable for that day. Claiming is server-side and idempotent:
/// the `claim_daily_champion` RPC returns the reward id exactly once.
///
/// Feature-detects and degrades silently (the established ChallengeService
/// pattern): before the migration is applied — or on any network/auth
/// error — every claim returns null and behaviour is unchanged.
class ChampionService {
  ChampionService._();

  static final ChampionService instance = ChampionService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Board region keys that pay champion rewards.
  static const List<String> championModes = [
    'daily',
    'daily_triangulation',
    'briefing',
  ];

  /// UTC day (YYYY-MM-DD) already checked this session — the RPC is
  /// idempotent, but there's no point re-asking three boards on every
  /// screen visit within the same day.
  String? _checkedDay;

  /// Testing seam: reset the once-per-day guard.
  @visibleForTesting
  void resetSessionGuard() => _checkedDay = null;

  /// Claim the champion reward for one board+day. Returns the consumable
  /// exactly once (server-guaranteed), or null in every other case —
  /// including when the RPC isn't deployed yet (safe no-op).
  Future<ConsumableType?> claimDailyChampion({
    required String gameMode,
    required DateTime date,
  }) async {
    try {
      if (_client.auth.currentUser?.id == null) return null;
      final result = await _client.rpc<dynamic>(
        'claim_daily_champion',
        params: {
          'p_game_mode': gameMode,
          'p_challenge_date': _dayKey(date),
        },
      );
      if (result is! String || result.isEmpty) return null;
      return ConsumableTypeInfo.fromId(result);
    } catch (e) {
      // RPC missing (migration not applied), offline, or Supabase not
      // initialised — degrade silently, established pattern.
      debugPrint(
        '[ChampionService] claim_daily_champion unavailable '
        '(non-critical): $e',
      );
      return null;
    }
  }

  /// Check yesterday's three boards and claim anything owed. Called on app
  /// open and when leaderboards are viewed; guarded to once per UTC day
  /// per session. Returns the rewards claimed by THIS call (usually empty).
  Future<List<ChampionReward>> checkAndClaimYesterday() async {
    final now = DateTime.now().toUtc();
    final today = _dayKey(now);
    if (_checkedDay == today) return const [];
    _checkedDay = today;

    final yesterday = now.subtract(const Duration(days: 1));
    final rewards = <ChampionReward>[];
    for (final mode in championModes) {
      final reward = await claimDailyChampion(gameMode: mode, date: yesterday);
      if (reward != null) {
        rewards.add(
          ChampionReward(
            gameMode: mode,
            date: _dayKey(yesterday),
            reward: reward,
          ),
        );
      }
    }
    return rewards;
  }

  static String _dayKey(DateTime date) {
    final utc = date.toUtc();
    return '${utc.year}-${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
  }
}
