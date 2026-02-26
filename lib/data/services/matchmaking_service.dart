import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/error_service.dart';
import '../models/challenge.dart';
import 'friends_service.dart';

/// Result of a matchmaking attempt.
class MatchResult {
  const MatchResult({
    required this.matched,
    this.opponentId,
    this.opponentName,
    this.challengeId,
    this.poolEntryId,
  });

  /// Whether a match was found.
  final bool matched;

  /// The matched opponent's user ID (null if not matched).
  final String? opponentId;

  /// The matched opponent's display name (null if not matched).
  final String? opponentName;

  /// The challenge ID created for the match (null if not matched).
  final String? challengeId;

  /// The pool entry ID (always set — either the new or existing entry).
  final String? poolEntryId;
}

/// Service for async challengerless matchmaking.
///
/// Players submit completed rounds into a matchmaking pool. The system pairs
/// them by ELO band and gameplay version, creates a challenge, and auto-friends
/// the two players.
///
/// World-mode only for now.
class MatchmakingService {
  MatchmakingService._();

  static final MatchmakingService instance = MatchmakingService._();

  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  /// Current gameplay version — tied to the app version from ErrorService.
  /// When mechanics change (scoring, flight speed, clues), bump this to
  /// invalidate stale pool entries.
  String get _gameplayVersion => ErrorService.appVersion;

  // ---------------------------------------------------------------------------
  // ELO estimation
  // ---------------------------------------------------------------------------

  /// Estimate an ELO rating from player level and best score.
  ///
  /// Formula: `1000 + (level * 50) + (bestScore / 20)`
  ///
  /// This provides a rough skill bracket without requiring a full ELO system.
  static int estimateElo({required int level, int bestScore = 0}) {
    return 1000 + (level * 50) + (bestScore ~/ 20);
  }

  /// Calculate the ELO band width based on pool size.
  ///
  /// - Pool < 10 entries  -> +/- 500 (very wide, fast matches)
  /// - Pool 10-49 entries -> +/- 300 (moderate)
  /// - Pool 50+ entries   -> +/- 200 (tight, fair matches)
  static int calculateEloBand({required int elo, required int poolSize}) {
    if (poolSize < 10) return 500;
    if (poolSize < 50) return 300;
    return 200;
  }

  // ---------------------------------------------------------------------------
  // Submit to pool
  // ---------------------------------------------------------------------------

  /// Submit a completed round to the matchmaking pool.
  ///
  /// Returns the pool entry ID on success, or null on failure.
  Future<String?> submitToPool({
    required String seed,
    required List<Map<String, dynamic>> rounds,
    required int eloRating,
    String region = 'world',
  }) async {
    if (_userId == null) return null;
    try {
      final data = await _client
          .from('matchmaking_pool')
          .insert({
            'user_id': _userId,
            'region': region,
            'seed': seed,
            'rounds': rounds,
            'elo_rating': eloRating,
            'gameplay_version': _gameplayVersion,
          })
          .select('id')
          .single();

      return data['id'] as String;
    } catch (e) {
      debugPrint('[MatchmakingService] submitToPool failed: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Find match
  // ---------------------------------------------------------------------------

  /// Search the pool for a match.
  ///
  /// Queries unmatched entries in the same region and gameplay version,
  /// filters by ELO band, excludes the current user's entries, and picks
  /// the oldest qualifying entry (FIFO).
  ///
  /// If a match is found:
  /// 1. A challenge is created between the two players.
  /// 2. Both pool entries are marked as matched.
  /// 3. Both players are auto-friended.
  ///
  /// Returns a [MatchResult] indicating whether a match was found.
  Future<MatchResult> findMatch({
    required int eloRating,
    required String playerName,
    String region = 'world',
    String? myPoolEntryId,
  }) async {
    if (_userId == null) {
      return const MatchResult(matched: false);
    }

    try {
      // 1. Count total unmatched entries to determine band width.
      final countResponse = await _client
          .from('matchmaking_pool')
          .select('id')
          .eq('region', region)
          .eq('gameplay_version', _gameplayVersion)
          .isFilter('matched_at', null);

      final poolSize = countResponse.length;
      final bandWidth = calculateEloBand(elo: eloRating, poolSize: poolSize);

      // 2. Query unmatched entries within ELO band.
      final eloMin = eloRating - bandWidth;
      final eloMax = eloRating + bandWidth;

      final candidates = await _client
          .from('matchmaking_pool')
          .select('id, user_id, seed, rounds, elo_rating')
          .eq('region', region)
          .eq('gameplay_version', _gameplayVersion)
          .isFilter('matched_at', null)
          .neq('user_id', _userId!)
          .gte('elo_rating', eloMin)
          .lte('elo_rating', eloMax)
          .order('created_at', ascending: true)
          .limit(1);

      if (candidates.isEmpty) {
        return const MatchResult(matched: false);
      }

      final match = candidates.first;
      final matchedUserId = match['user_id'] as String;
      final matchedEntryId = match['id'] as String;
      final matchedSeed = match['seed'] as String;
      final matchedRounds = match['rounds'] as List;

      // 3. Fetch the matched player's profile for their name.
      final profile = await _client
          .from('profiles')
          .select('display_name, username')
          .eq('id', matchedUserId)
          .single();

      final opponentName =
          (profile['display_name'] as String?) ??
          (profile['username'] as String?) ??
          'Challenger';

      // 4. Create a challenge — CURRENT user must be challenger_id
      //    (RLS requires auth.uid() = challenger_id for INSERT).
      final rng = Random();
      final challengeRounds = List.generate(Challenge.totalRounds, (i) {
        if (i < matchedRounds.length) {
          final poolRound = matchedRounds[i] as Map<String, dynamic>;
          return <String, dynamic>{
            'round_number': i + 1,
            'seed': poolRound['seed'] ?? rng.nextInt(1 << 31),
          };
        }
        return <String, dynamic>{
          'round_number': i + 1,
          'seed': (matchedSeed.hashCode + i * 7919) & 0x7FFFFFFF,
        };
      });

      final challengeData = await _client
          .from('challenges')
          .insert({
            'challenger_id': _userId,
            'challenger_name': playerName,
            'challenged_id': matchedUserId,
            'challenged_name': opponentName,
            'status': 'pending',
            'rounds': challengeRounds,
          })
          .select('id')
          .single();

      final challengeId = challengeData['id'] as String;

      // 5. Mark both pool entries as matched.
      final now = DateTime.now().toUtc().toIso8601String();

      // Mark our own entry first (RLS always allows user_id = auth.uid()).
      final myEntryId =
          myPoolEntryId ??
          (await _client
                  .from('matchmaking_pool')
                  .select('id')
                  .eq('user_id', _userId!)
                  .eq('region', region)
                  .eq('gameplay_version', _gameplayVersion)
                  .isFilter('matched_at', null)
                  .order('created_at', ascending: true)
                  .limit(1)
                  .maybeSingle())?['id']
              as String?;

      if (myEntryId != null) {
        await _client
            .from('matchmaking_pool')
            .update({
              'matched_at': now,
              'matched_with': matchedUserId,
              'challenge_id': challengeId,
            })
            .eq('id', myEntryId);
      }

      // Mark the opponent's entry (RLS allows update when matched_at IS NULL).
      await _client
          .from('matchmaking_pool')
          .update({
            'matched_at': now,
            'matched_with': _userId,
            'challenge_id': challengeId,
          })
          .eq('id', matchedEntryId);

      // 6. Auto-friend both players (fire-and-forget, ignore if already friends).
      _autoFriend(matchedUserId);

      return MatchResult(
        matched: true,
        opponentId: matchedUserId,
        opponentName: opponentName,
        challengeId: challengeId,
        poolEntryId: myEntryId ?? matchedEntryId,
      );
    } catch (e) {
      debugPrint('[MatchmakingService] findMatch failed: $e');
      return const MatchResult(matched: false);
    }
  }

  // ---------------------------------------------------------------------------
  // Check for existing matches (passive match detection)
  // ---------------------------------------------------------------------------

  /// Check if any of the current user's pool entries have been matched by
  /// another player while they were away.
  ///
  /// Returns a [MatchResult] with the most recent match, or
  /// `MatchResult(matched: false)` if no matches found.
  Future<MatchResult> checkForExistingMatches() async {
    if (_userId == null) return const MatchResult(matched: false);
    try {
      // Look for entries that were matched (matched_at != null) and have a
      // challenge_id, ordered by most recent first.
      final matched = await _client
          .from('matchmaking_pool')
          .select()
          .eq('user_id', _userId!)
          .not('matched_at', 'is', null)
          .not('challenge_id', 'is', null)
          .order('matched_at', ascending: false)
          .limit(1);

      if (matched.isEmpty) {
        return const MatchResult(matched: false);
      }

      final entry = matched.first;
      final challengeId = entry['challenge_id'] as String?;
      final matchedWith = entry['matched_with'] as String?;

      if (challengeId == null || matchedWith == null) {
        return const MatchResult(matched: false);
      }

      // Check if the challenge is still actionable (pending or in_progress).
      final challenge = await _client
          .from('challenges')
          .select('id, status')
          .eq('id', challengeId)
          .maybeSingle();

      if (challenge == null) {
        return const MatchResult(matched: false);
      }

      final status = challenge['status'] as String?;
      if (status != 'pending' && status != 'in_progress') {
        return const MatchResult(matched: false);
      }

      // Fetch the opponent's name.
      final profile = await _client
          .from('profiles')
          .select('display_name, username')
          .eq('id', matchedWith)
          .maybeSingle();

      final opponentName =
          (profile?['display_name'] as String?) ??
          (profile?['username'] as String?) ??
          'Challenger';

      return MatchResult(
        matched: true,
        opponentId: matchedWith,
        opponentName: opponentName,
        challengeId: challengeId,
        poolEntryId: entry['id'] as String?,
      );
    } catch (e) {
      debugPrint('[MatchmakingService] checkForExistingMatches failed: $e');
      return const MatchResult(matched: false);
    }
  }

  // ---------------------------------------------------------------------------
  // Cancel / remove pool entry
  // ---------------------------------------------------------------------------

  /// Cancel a matchmaking pool entry. Only unmatched entries can be cancelled.
  ///
  /// Returns true if the entry was successfully deleted.
  Future<bool> cancelPoolEntry(String entryId) async {
    if (_userId == null) return false;
    try {
      final deleted = await _client
          .from('matchmaking_pool')
          .delete()
          .eq('id', entryId)
          .eq('user_id', _userId!)
          .isFilter('matched_at', null)
          .select('id');

      return deleted.isNotEmpty;
    } catch (e) {
      debugPrint('[MatchmakingService] cancelPoolEntry failed: $e');
      return false;
    }
  }

  /// Cancel ALL of the current user's unmatched pool entries.
  ///
  /// Returns the number of entries cancelled.
  Future<int> cancelAllPoolEntries() async {
    if (_userId == null) return 0;
    try {
      final deleted = await _client
          .from('matchmaking_pool')
          .delete()
          .eq('user_id', _userId!)
          .isFilter('matched_at', null)
          .select('id');

      return deleted.length;
    } catch (e) {
      debugPrint('[MatchmakingService] cancelAllPoolEntries failed: $e');
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // Query pool entries
  // ---------------------------------------------------------------------------

  /// Fetch the current user's unmatched pool entries.
  Future<List<Map<String, dynamic>>> getMyPoolEntries() async {
    if (_userId == null) return [];
    try {
      final data = await _client
          .from('matchmaking_pool')
          .select()
          .eq('user_id', _userId!)
          .isFilter('matched_at', null)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('[MatchmakingService] getMyPoolEntries failed: $e');
      return [];
    }
  }

  /// Check if a specific pool entry has been matched.
  ///
  /// Returns the full entry row if matched (matched_at != null), or null
  /// if still waiting.
  Future<Map<String, dynamic>?> getMatchResult(String poolEntryId) async {
    if (_userId == null) return null;
    try {
      final data = await _client
          .from('matchmaking_pool')
          .select()
          .eq('id', poolEntryId)
          .single();

      if (data['matched_at'] != null) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (e) {
      debugPrint('[MatchmakingService] getMatchResult failed: $e');
      return null;
    }
  }

  /// Fetch all of the current user's matched entries (with challenge IDs).
  Future<List<Map<String, dynamic>>> getMyMatchedEntries() async {
    if (_userId == null) return [];
    try {
      final data = await _client
          .from('matchmaking_pool')
          .select()
          .eq('user_id', _userId!)
          .not('matched_at', 'is', null)
          .order('matched_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('[MatchmakingService] getMyMatchedEntries failed: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Auto-friend two players after a matchmaking pairing.
  ///
  /// This is fire-and-forget — if they're already friends or the request
  /// fails, we silently ignore it.
  Future<void> _autoFriend(String otherUserId) async {
    try {
      await FriendsService.instance.sendFriendRequest(otherUserId);
    } catch (e) {
      debugPrint('[MatchmakingService] autoFriend failed (non-critical): $e');
    }
  }
}
