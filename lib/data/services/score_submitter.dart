import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server-authoritative score submission with transition-safe fallback.
///
/// Security hardening (WAVE 3, finding #2): leaderboard scores must be written
/// through the `submit_score` SECURITY DEFINER RPC, which forces
/// `user_id = auth.uid()` and re-validates bounds server-side, instead of a
/// direct client INSERT (which any JWT holder could forge).
///
/// The migration that adds `submit_score` is apply-held, so this helper is
/// transition-safe: it PREFERS the RPC and FALLS BACK to the current direct
/// `scores` INSERT when the RPC does not exist yet (pre-migration) — matching
/// the established pattern in `block_service.dart`. The caller keeps its own
/// offline-queue fallback for network errors.
class ScoreSubmitter {
  const ScoreSubmitter._();

  /// Prefer the `submit_score` RPC; fall back to a direct `scores` INSERT only
  /// when the RPC is missing (function not migrated yet). Any other error is
  /// rethrown so the caller can apply its own retry/queue policy.
  ///
  /// [insertData] is the exact payload used for the legacy direct INSERT (it
  /// already contains `user_id`). The RPC ignores any client-supplied
  /// `user_id` and uses `auth.uid()` server-side.
  static Future<void> submit(
    SupabaseClient client,
    Map<String, dynamic> insertData,
  ) async {
    try {
      await client.rpc('submit_score', params: rpcParamsFor(insertData));
    } catch (e) {
      if (isMissingRpc(e)) {
        // Pre-migration DB: the RPC isn't deployed. Use the still-granted
        // direct INSERT path (RLS enforces auth.uid() = user_id).
        await client.from('scores').insert(insertData);
        return;
      }
      rethrow;
    }
  }

  /// Maps a `scores` INSERT payload to `submit_score` RPC parameters.
  /// Note: `user_id` is intentionally NOT forwarded — the RPC derives the actor
  /// from `auth.uid()` server-side.
  @visibleForTesting
  static Map<String, dynamic> rpcParamsFor(Map<String, dynamic> data) {
    return <String, dynamic>{
      'p_score': data['score'],
      'p_time_ms': data['time_ms'],
      'p_region': data['region'],
      'p_rounds_completed': data['rounds_completed'] ?? 0,
      if (data['round_emojis'] != null) 'p_round_emojis': data['round_emojis'],
      if (data['round_details'] != null)
        'p_round_details': data['round_details'],
    };
  }

  /// Postgres "undefined function" (42883) / PostgREST "function not found"
  /// (PGRST202) — the RPC has not been migrated yet, so the caller should fall
  /// back to the legacy direct-write path. Mirrors `BlockService`.
  static bool isMissingRpc(Object e) {
    if (e is PostgrestException) {
      return e.code == '42883' || e.code == 'PGRST202';
    }
    final s = e.toString().toLowerCase();
    return s.contains('function') && s.contains('does not exist');
  }
}
