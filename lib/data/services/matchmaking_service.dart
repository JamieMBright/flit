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
  /// 1. Both pool entries are marked as matched.
  /// 2. A challenge is created between the two players.
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

      final poolSize = (countResponse as List).length;
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

      // 4. Create a challenge between the two players using the matched seed.
      final rng = Random();
      final challengeRounds = List.generate(Challenge.totalRounds, (i) {
        // Use round data from the pool entry if available, otherwise
        // generate new seeds based on the original seed.
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
            'challenger_id': matchedUserId,
            'challenger_name': opponentName,
            'challenged_id': _userId,
            'challenged_name': playerName,
            'status': 'pending',
            'rounds': challengeRounds,
          })
          .select('id')
          .single();

      final challengeId = challengeData['id'] as String;

      // 5. Mark both pool entries as matched.
      final now = DateTime.now().toUtc().toIso8601String();
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
              .maybeSingle())?['id'] as String?;

      await _client
          .from('matchmaking_pool')
          .update({
            'matched_at': now,
            'matched_with': _userId,
            'challenge_id': challengeId,
          })
          .eq('id', matchedEntryId);

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
      // The other player will see a friend request. In a full implementation,
      // we'd auto-accept on both sides, but for now a pending request is fine
      // since both players will see each other in the challenge flow.
    } catch (e) {
      debugPrint('[MatchmakingService] autoFriend failed (non-critical): $e');
    }
  }
}
