import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flame/components.dart';

import '../models/challenge.dart';
import '../models/h2h_challenge.dart';
import '../../game/clues/clue_types.dart';
import '../../game/quiz/quiz_category.dart';
import '../../game/quiz/quiz_session.dart';

/// Service for managing H2H challenges via Supabase.
///
/// Supports multiple game modes: flight (dogfight) and quiz (flight school).
class ChallengeService {
  ChallengeService._();

  static final ChallengeService instance = ChallengeService._();

  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------

  /// Create a new challenge against a friend.
  ///
  /// Generates [Challenge.totalRounds] round seeds so both players play the
  /// same countries in the same order. Returns the challenge ID on success.
  ///
  /// For quiz challenges, [quizCategory] and [quizMode] specify the quiz
  /// configuration that both players will use.
  ///
  /// [gameModeName] overrides the mode string stored in the database so
  /// future modes ('recon', 'scramble', ...) can create challenges without a
  /// new enum value; [roundsConfig] is an optional per-round configuration
  /// blob stored opaquely alongside the rounds (its length also drives the
  /// round count for generic modes). Flight/quiz behaviour is unchanged.
  Future<String?> createChallenge({
    required String challengedId,
    required String challengedName,
    required String challengerName,
    ChallengeGameMode gameMode = ChallengeGameMode.flight,
    String? gameModeName,
    List<Map<String, dynamic>>? roundsConfig,
    QuizCategory? quizCategory,
    QuizMode? quizMode,
  }) async {
    if (_userId == null) return null;
    try {
      final rng = Random();
      // For quiz challenges we use a single round; for flight, best-of-5.
      // Generic modes with a rounds_config drive the count from the config.
      final roundCount = roundsConfig?.length ??
          (gameMode == ChallengeGameMode.quiz ? 1 : Challenge.totalRounds);

      // Generate deterministic seeds for each round.
      final rounds = List.generate(
        roundCount,
        (i) => <String, dynamic>{
          'round_number': i + 1,
          'seed': rng.nextInt(1 << 31),
        },
      );

      final insertData = <String, dynamic>{
        'challenger_id': _userId,
        'challenger_name': challengerName,
        'challenged_id': challengedId,
        'challenged_name': challengedName,
        'status': 'pending',
        'game_mode': gameModeName ?? gameMode.dbName,
        'rounds': rounds,
      };

      if (roundsConfig != null) {
        insertData['rounds_config'] = roundsConfig;
      }
      if (quizCategory != null) {
        insertData['quiz_category'] = quizCategory.name;
      }
      if (quizMode != null) {
        insertData['quiz_mode'] = quizMode.name;
      }

      final data = await _client
          .from('challenges')
          .insert(insertData)
          .select('id')
          .single();

      return data['id'] as String;
    } catch (e) {
      debugPrint('[ChallengeService] createChallenge failed: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Fetch
  // ---------------------------------------------------------------------------

  /// Fetch ALL active challenges (pending + in_progress) involving the current
  /// user as either challenger or challenged.
  ///
  /// Used by the friends screen to show per-friend challenge status
  /// (your turn, their turn, play, sent, etc.).
  Future<List<Challenge>> fetchAllActiveChallenges() async {
    if (_userId == null) return [];
    try {
      final data = await _client
          .from('challenges')
          .select()
          .or('challenger_id.eq.$_userId,challenged_id.eq.$_userId')
          .inFilter('status', ['pending', 'in_progress']).order('created_at',
              ascending: false);

      return data.map((row) => _rowToChallenge(row)).toList();
    } catch (e) {
      debugPrint('[ChallengeService] fetchAllActiveChallenges failed: $e');
      return [];
    }
  }

  /// Fetch incoming pending challenges (where current user is the challenged).
  Future<List<Challenge>> fetchPendingChallenges() async {
    if (_userId == null) return [];
    try {
      final data = await _client
          .from('challenges')
          .select()
          .eq('challenged_id', _userId!)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return data.map((row) => _rowToChallenge(row)).toList();
    } catch (e) {
      debugPrint('[ChallengeService] fetchPendingChallenges failed: $e');
      return [];
    }
  }

  /// Fetch outgoing pending challenges (where current user is the challenger).
  Future<List<Challenge>> fetchSentChallenges() async {
    if (_userId == null) return [];
    try {
      final data = await _client
          .from('challenges')
          .select()
          .eq('challenger_id', _userId!)
          .inFilter('status', ['pending', 'in_progress']).order('created_at',
              ascending: false);

      return data.map((row) => _rowToChallenge(row)).toList();
    } catch (e) {
      debugPrint('[ChallengeService] fetchSentChallenges failed: $e');
      return [];
    }
  }

  /// Fetch a single challenge by ID.
  Future<Challenge?> fetchChallenge(String challengeId) async {
    if (_userId == null) return null;
    try {
      final data = await _client
          .from('challenges')
          .select()
          .eq('id', challengeId)
          .single();
      return _rowToChallenge(data);
    } catch (e) {
      debugPrint('[ChallengeService] fetchChallenge failed: $e');
      return null;
    }
  }

  /// Fetch recent completed challenges involving the current user.
  Future<List<Challenge>> fetchRecentChallenges({int limit = 20}) async {
    if (_userId == null) return [];
    try {
      final data = await _client
          .from('challenges')
          .select()
          .eq('status', 'completed')
          .or('challenger_id.eq.$_userId,challenged_id.eq.$_userId')
          .order('completed_at', ascending: false)
          .limit(limit);

      return data.map((row) => _rowToChallenge(row)).toList();
    } catch (e) {
      debugPrint('[ChallengeService] fetchRecentChallenges failed: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Submit round result
  // ---------------------------------------------------------------------------

  /// Maximum retry attempts for round result submission.
  static const int _maxRetries = 3;

  /// Submit the result of a single round with exponential backoff retry.
  ///
  /// [roundIndex] is 0-based. [timeMs] is the player's completion time.
  /// [score] is the round score (0-10000) factoring in hints and fuel.
  /// [hintsUsed] is the number of hint tiers used (0-4).
  /// [clueTypeName] and [countryName] are recorded once per round (by the
  /// first player to submit) so the match history can display clue context.
  ///
  /// Prefers the atomic `submit_challenge_round` RPC (row-level jsonb merge
  /// under a lock, so concurrent submissions can't drop each other). When the
  /// RPC isn't deployed, falls back to the legacy read-modify-write, which
  /// retries up to [_maxRetries] times with exponential backoff (1s, 2s, 4s).
  Future<bool> submitRoundResult({
    required String challengeId,
    required int roundIndex,
    required int timeMs,
    int? score,
    int? hintsUsed,
    String? clueTypeName,
    String? countryName,
  }) async {
    if (_userId == null) return false;

    // Atomic path: server-side merge under row lock.
    final rpcOk = await _submitRoundViaRpc(
      challengeId: challengeId,
      roundNumber: roundIndex + 1,
      playerFields: {
        'time_ms': timeMs,
        if (score != null) 'score': score,
        if (hintsUsed != null) 'hints_used': hintsUsed,
      },
      sharedFields: {
        if (clueTypeName != null) 'clue_type': clueTypeName,
        if (countryName != null) 'country_name': countryName,
      },
    );
    if (rpcOk) return true;

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        // Fetch current challenge state.
        final row = await _client
            .from('challenges')
            .select('challenger_id, challenged_id, rounds, status')
            .eq('id', challengeId)
            .single();

        final isChallenger = row['challenger_id'] == _userId;
        final rounds = List<Map<String, dynamic>>.from(
          (row['rounds'] as List).map(
            (r) => Map<String, dynamic>.from(r as Map),
          ),
        );

        if (roundIndex < 0 || roundIndex >= rounds.length) return false;

        // Set the time for the appropriate player.
        final prefix = isChallenger ? 'challenger' : 'challenged';
        rounds[roundIndex]['${prefix}_time_ms'] = timeMs;
        if (score != null) rounds[roundIndex]['${prefix}_score'] = score;
        if (hintsUsed != null) {
          rounds[roundIndex]['${prefix}_hints_used'] = hintsUsed;
        }

        // Persist clue metadata once (first submitter writes it).
        if (clueTypeName != null && rounds[roundIndex]['clue_type'] == null) {
          rounds[roundIndex]['clue_type'] = clueTypeName;
        }
        if (countryName != null && rounds[roundIndex]['country_name'] == null) {
          rounds[roundIndex]['country_name'] = countryName;
        }

        // If the challenge was pending, move to in_progress.
        final newStatus =
            row['status'] == 'pending' ? 'in_progress' : row['status'];

        await _client.from('challenges').update(
            {'rounds': rounds, 'status': newStatus}).eq('id', challengeId);

        return true;
      } catch (e) {
        debugPrint(
          '[ChallengeService] submitRoundResult failed '
          '(attempt ${attempt + 1}/${_maxRetries + 1}): $e',
        );
        if (attempt < _maxRetries) {
          // Exponential backoff: 1s, 2s, 4s
          await Future<void>.delayed(Duration(seconds: 1 << attempt));
        }
      }
    }

    debugPrint(
      '[ChallengeService] submitRoundResult exhausted all retries for '
      'challenge=$challengeId round=$roundIndex',
    );
    return false;
  }

  // ---------------------------------------------------------------------------
  // Submit quiz round result
  // ---------------------------------------------------------------------------

  /// Submit the result of a quiz round.
  ///
  /// Quiz challenges are single-round: both players play the same category
  /// with the same seed, and the higher score wins. Prefers the atomic
  /// `submit_challenge_round` RPC, falling back to read-modify-write when
  /// the RPC isn't deployed.
  Future<bool> submitQuizRoundResult({
    required String challengeId,
    required int score,
    required int timeMs,
    required int correctCount,
    required int wrongCount,
  }) async {
    if (_userId == null) return false;

    // Atomic path: server-side merge under row lock (quiz uses round 0).
    final rpcOk = await _submitRoundViaRpc(
      challengeId: challengeId,
      roundNumber: 1,
      playerFields: {
        'time_ms': timeMs,
        'score': score,
        'quiz_correct': correctCount,
        'quiz_wrong': wrongCount,
      },
      sharedFields: const {},
    );
    if (rpcOk) return true;

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final row = await _client
            .from('challenges')
            .select('challenger_id, challenged_id, rounds, status')
            .eq('id', challengeId)
            .single();

        final isChallenger = row['challenger_id'] == _userId;
        final rounds = List<Map<String, dynamic>>.from(
          (row['rounds'] as List).map(
            (r) => Map<String, dynamic>.from(r as Map),
          ),
        );

        if (rounds.isEmpty) return false;

        // Quiz challenges use round 0 (single round).
        final prefix = isChallenger ? 'challenger' : 'challenged';
        rounds[0]['${prefix}_time_ms'] = timeMs;
        rounds[0]['${prefix}_score'] = score;
        rounds[0]['${prefix}_quiz_correct'] = correctCount;
        rounds[0]['${prefix}_quiz_wrong'] = wrongCount;

        final newStatus =
            row['status'] == 'pending' ? 'in_progress' : row['status'];

        await _client.from('challenges').update(
            {'rounds': rounds, 'status': newStatus}).eq('id', challengeId);

        return true;
      } catch (e) {
        debugPrint(
          '[ChallengeService] submitQuizRoundResult failed '
          '(attempt ${attempt + 1}/${_maxRetries + 1}): $e',
        );
        if (attempt < _maxRetries) {
          await Future<void>.delayed(Duration(seconds: 1 << attempt));
        }
      }
    }
    return false;
  }

  /// Try to submit a round via the atomic `submit_challenge_round` RPC.
  ///
  /// [playerFields] are suffix-keyed values ('time_ms', 'score', ...) that
  /// get prefixed with challenger_/challenged_ for the calling player;
  /// [sharedFields] (clue metadata) are written first-submitter-wins by the
  /// RPC. Returns false on any failure — including the RPC not being
  /// deployed — so callers can fall back to the legacy read-modify-write.
  Future<bool> _submitRoundViaRpc({
    required String challengeId,
    required int roundNumber,
    required Map<String, dynamic> playerFields,
    required Map<String, dynamic> sharedFields,
  }) async {
    try {
      // One light read to learn which side we're on.
      final row = await _client
          .from('challenges')
          .select('challenger_id')
          .eq('id', challengeId)
          .single();
      final isChallenger = row['challenger_id'] == _userId;
      final prefix = isChallenger ? 'challenger' : 'challenged';

      final result = <String, dynamic>{
        for (final entry in playerFields.entries)
          '${prefix}_${entry.key}': entry.value,
        ...sharedFields,
      };

      final ok = await _client.rpc<dynamic>(
        'submit_challenge_round',
        params: {
          'p_challenge_id': challengeId,
          'p_round_number': roundNumber,
          'p_is_challenger': isChallenger,
          'p_result': result,
        },
      );
      return ok == true;
    } catch (e) {
      debugPrint(
        '[ChallengeService] submit_challenge_round RPC unavailable, '
        'falling back to read-modify-write: $e',
      );
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Complete challenge
  // ---------------------------------------------------------------------------

  /// Check if the challenge is complete and determine the winner.
  ///
  /// Call this after submitting a round result. If either player has reached
  /// [Challenge.winsRequired] wins (best-of-5 early victory), or all rounds
  /// are complete, sets winner, awards coins, and marks as completed.
  /// Returns the updated challenge, or null if not yet complete. Retries up
  /// to [_maxRetries] times with exponential backoff on failure.
  Future<Challenge?> tryCompleteChallenge(String challengeId) async {
    if (_userId == null) return null;

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final row = await _client
            .from('challenges')
            .select()
            .eq('id', challengeId)
            .single();

        final challenge = _rowToChallenge(row);

        // Early victory: complete as soon as one player clinches enough wins
        // (e.g. 3 wins in best-of-5). Also complete if all rounds are done.
        // Compare against the challenge's actual round count, not the flight
        // constant — quiz challenges are single-round, so checking against
        // totalRounds (5) would mean they never complete.
        if (!challenge.isComplete) {
          final completedRounds =
              challenge.rounds.where((r) => r.isComplete).length;
          if (challenge.rounds.isEmpty ||
              completedRounds < challenge.rounds.length) {
            return null;
          }
        }

        // Determine winner.
        String? winnerId;
        if (challenge.challengerWins > challenge.challengedWins) {
          winnerId = challenge.challengerId;
        } else if (challenge.challengedWins > challenge.challengerWins) {
          winnerId = challenge.challengedId;
        }
        // null winnerId means draw.

        // Calculate coins.
        final challengerCoins = _calculateCoins(
          roundWins: challenge.challengerWins,
          isWinner: winnerId == challenge.challengerId,
          isDraw: winnerId == null,
        );
        final challengedCoins = _calculateCoins(
          roundWins: challenge.challengedWins,
          isWinner: winnerId == challenge.challengedId,
          isDraw: winnerId == null,
        );

        await _client.from('challenges').update({
          'status': 'completed',
          'winner_id': winnerId,
          'challenger_coins': challengerCoins,
          'challenged_coins': challengedCoins,
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', challengeId);

        // Apply the per-mode ELO rating change. Fire-and-forget: the RPC is
        // idempotent (rating_applied_at guard) and silently no-ops when it
        // isn't deployed, so completion never blocks on it.
        unawaited(_applyChallengeRating(challengeId));

        return challenge;
      } catch (e) {
        debugPrint(
          '[ChallengeService] tryCompleteChallenge failed '
          '(attempt ${attempt + 1}/${_maxRetries + 1}): $e',
        );
        if (attempt < _maxRetries) {
          await Future<void>.delayed(Duration(seconds: 1 << attempt));
        }
      }
    }
    return null;
  }

  /// Fire the `apply_challenge_rating` RPC for a just-completed challenge.
  ///
  /// Safe to call multiple times / from both players — the RPC is idempotent.
  /// Silently no-ops when the ratings migration hasn't been applied yet.
  Future<void> _applyChallengeRating(String challengeId) async {
    try {
      await _client.rpc<dynamic>(
        'apply_challenge_rating',
        params: {'p_challenge_id': challengeId},
      );
    } catch (e) {
      debugPrint(
        '[ChallengeService] apply_challenge_rating unavailable (non-critical): '
        '$e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Claim coins
  // ---------------------------------------------------------------------------

  /// Claim the coin reward for a completed challenge.
  ///
  /// Calls the `claim_challenge_coins` RPC, which atomically marks the
  /// current player's share as claimed and returns the coin amount. Returns
  /// null if the reward was already claimed, the challenge isn't completed,
  /// or the RPC isn't deployed yet (safe no-op in all failure cases — the
  /// caller should only credit coins when this returns a positive value).
  Future<int?> claimChallengeCoins(String challengeId) async {
    if (_userId == null) return null;
    try {
      final result = await _client.rpc<dynamic>(
        'claim_challenge_coins',
        params: {'p_challenge_id': challengeId},
      );
      final coins = result is int ? result : int.tryParse('$result');
      if (coins == null || coins <= 0) return null;
      return coins;
    } catch (e) {
      debugPrint('[ChallengeService] claimChallengeCoins failed: $e');
      return null;
    }
  }

  /// Claim the coin reward for a completed H2H (best-of-3) challenge.
  ///
  /// Calls the `claim_h2h_coins` RPC, which atomically marks the current
  /// player's share as claimed and returns true exactly once. The reward
  /// amount is computed client-side from [H2HChallenge] constants. Returns
  /// false when already claimed, not completed, or the RPC isn't deployed
  /// (safe no-op — callers must only credit coins on true).
  Future<bool> claimH2HCoins(String challengeId) async {
    if (_userId == null) return false;
    try {
      final result = await _client.rpc<dynamic>(
        'claim_h2h_coins',
        params: {'p_challenge_id': challengeId},
      );
      return result == true;
    } catch (e) {
      debugPrint('[ChallengeService] claimH2HCoins failed: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Decline
  // ---------------------------------------------------------------------------

  /// Decline a pending challenge.
  Future<bool> declineChallenge(String challengeId) async {
    if (_userId == null) return false;
    try {
      await _client
          .from('challenges')
          .update({'status': 'declined'}).eq('id', challengeId);
      return true;
    } catch (e) {
      debugPrint('[ChallengeService] declineChallenge failed: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  int _calculateCoins({
    required int roundWins,
    required bool isWinner,
    required bool isDraw,
  }) {
    var coins = Challenge.participationCoins;
    coins += roundWins * Challenge.roundWinCoins;
    if (isWinner) {
      coins += Challenge.winnerCoins;
    } else if (!isDraw) {
      coins += Challenge.loserCoins;
    }
    return coins;
  }

  // ===========================================================================
  // H2H Flight School Challenges (best-of-3)
  // ===========================================================================

  /// Create a new H2H Flight School challenge.
  ///
  /// [challengedUsername] is looked up in the profiles table.
  /// [rounds] contains the 3 round configurations (level, category, difficulty).
  /// Returns the challenge ID on success, or null on failure.
  Future<String?> createH2HChallenge({
    required String challengedUsername,
    required String challengerName,
    required List<H2HRound> rounds,
  }) async {
    if (_userId == null) return null;
    if (rounds.length != H2HChallenge.totalRounds) return null;

    try {
      // Look up the challenged user by username.
      final profile = await _client
          .from('profiles')
          .select('id, username, display_name')
          .eq('username', challengedUsername)
          .neq('id', _userId!)
          .maybeSingle();

      if (profile == null) return null;

      final challengedId = profile['id'] as String;
      final challengedName = (profile['display_name'] as String?) ??
          (profile['username'] as String? ?? '');

      final roundsJson = rounds.map((r) => r.toJson()).toList();

      final data = await _client
          .from('h2h_challenges')
          .insert({
            'challenger_id': _userId,
            'challenger_name': challengerName,
            'challenged_id': challengedId,
            'challenged_name': challengedName,
            'rounds': roundsJson,
            'status': 'pending',
          })
          .select('id')
          .single();

      return data['id'] as String;
    } catch (e) {
      debugPrint('[ChallengeService] createH2HChallenge failed: $e');
      return null;
    }
  }

  /// Accept a pending H2H challenge (marks it as in_progress).
  Future<bool> acceptH2HChallenge(String challengeId) async {
    if (_userId == null) return false;
    try {
      await _client
          .from('h2h_challenges')
          .update({'status': 'in_progress'})
          .eq('id', challengeId)
          .eq('challenged_id', _userId!)
          .eq('status', 'pending');
      return true;
    } catch (e) {
      debugPrint('[ChallengeService] acceptH2HChallenge failed: $e');
      return false;
    }
  }

  /// Decline a pending H2H challenge.
  Future<bool> declineH2HChallenge(String challengeId) async {
    if (_userId == null) return false;
    try {
      await _client
          .from('h2h_challenges')
          .update({'status': 'declined'})
          .eq('id', challengeId)
          .eq('challenged_id', _userId!)
          .eq('status', 'pending');
      return true;
    } catch (e) {
      debugPrint('[ChallengeService] declineH2HChallenge failed: $e');
      return false;
    }
  }

  /// Submit a round score for an H2H challenge.
  ///
  /// [roundIndex] is 0-based. The method reads the current rounds JSONB,
  /// updates the appropriate field, and writes it back.
  Future<bool> submitH2HRoundScore({
    required String challengeId,
    required int roundIndex,
    required int score,
    required int timeMs,
    required int correctCount,
    required int wrongCount,
  }) async {
    if (_userId == null) return false;

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final row = await _client
            .from('h2h_challenges')
            .select('challenger_id, challenged_id, rounds, status')
            .eq('id', challengeId)
            .single();

        final isChallenger = row['challenger_id'] == _userId;
        final rounds = List<Map<String, dynamic>>.from(
          (row['rounds'] as List).map(
            (r) => Map<String, dynamic>.from(r as Map),
          ),
        );

        if (roundIndex < 0 || roundIndex >= rounds.length) return false;

        final prefix = isChallenger ? 'challenger' : 'challenged';
        rounds[roundIndex]['${prefix}_score'] = score;
        rounds[roundIndex]['${prefix}_time_ms'] = timeMs;
        rounds[roundIndex]['${prefix}_correct'] = correctCount;
        rounds[roundIndex]['${prefix}_wrong'] = wrongCount;

        // Move to in_progress if still pending.
        final newStatus =
            row['status'] == 'pending' ? 'in_progress' : row['status'];

        await _client.from('h2h_challenges').update(
            {'rounds': rounds, 'status': newStatus}).eq('id', challengeId);

        return true;
      } catch (e) {
        debugPrint(
          '[ChallengeService] submitH2HRoundScore failed '
          '(attempt ${attempt + 1}/${_maxRetries + 1}): $e',
        );
        if (attempt < _maxRetries) {
          await Future<void>.delayed(Duration(seconds: 1 << attempt));
        }
      }
    }
    return false;
  }

  /// Check if the H2H challenge is complete and determine the winner.
  ///
  /// If one player has won 2+ rounds or all rounds are done, marks the
  /// challenge as completed and sets the winner.
  Future<H2HChallenge?> tryCompleteH2HChallenge(String challengeId) async {
    if (_userId == null) return null;

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final row = await _client
            .from('h2h_challenges')
            .select()
            .eq('id', challengeId)
            .single();

        final challenge = H2HChallenge.fromJson(row);

        if (!challenge.isComplete) return null;

        String? winnerId;
        if (challenge.challengerWins > challenge.challengedWins) {
          winnerId = challenge.challengerId;
        } else if (challenge.challengedWins > challenge.challengerWins) {
          winnerId = challenge.challengedId;
        }

        await _client.from('h2h_challenges').update({
          'status': 'completed',
          'winner_id': winnerId,
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', challengeId);

        return challenge.copyWith(
          status: H2HStatus.completed,
          winnerId: winnerId,
          completedAt: DateTime.now().toUtc(),
        );
      } catch (e) {
        debugPrint(
          '[ChallengeService] tryCompleteH2HChallenge failed '
          '(attempt ${attempt + 1}/${_maxRetries + 1}): $e',
        );
        if (attempt < _maxRetries) {
          await Future<void>.delayed(Duration(seconds: 1 << attempt));
        }
      }
    }
    return null;
  }

  /// Fetch pending H2H challenges where the current user is challenged.
  Future<List<H2HChallenge>> fetchPendingH2HChallenges() async {
    if (_userId == null) return [];
    try {
      final data = await _client
          .from('h2h_challenges')
          .select()
          .eq('challenged_id', _userId!)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return data.map((row) => H2HChallenge.fromJson(row)).toList();
    } catch (e) {
      debugPrint('[ChallengeService] fetchPendingH2HChallenges failed: $e');
      return [];
    }
  }

  /// Fetch all H2H challenges involving the current user.
  Future<List<H2HChallenge>> fetchMyH2HChallenges({int limit = 50}) async {
    if (_userId == null) return [];
    try {
      final data = await _client
          .from('h2h_challenges')
          .select()
          .or('challenger_id.eq.$_userId,challenged_id.eq.$_userId')
          .order('created_at', ascending: false)
          .limit(limit);

      return data.map((row) => H2HChallenge.fromJson(row)).toList();
    } catch (e) {
      debugPrint('[ChallengeService] fetchMyH2HChallenges failed: $e');
      return [];
    }
  }

  /// Fetch a single H2H challenge by ID.
  Future<H2HChallenge?> fetchH2HChallenge(String challengeId) async {
    if (_userId == null) return null;
    try {
      final data = await _client
          .from('h2h_challenges')
          .select()
          .eq('id', challengeId)
          .single();
      return H2HChallenge.fromJson(data);
    } catch (e) {
      debugPrint('[ChallengeService] fetchH2HChallenge failed: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Challenge _rowToChallenge(Map<String, dynamic> row) {
    final roundsList = row['rounds'] as List? ?? [];
    final rounds = roundsList.map<ChallengeRound>((r) {
      final round = r as Map<String, dynamic>;
      // Parse clue type if present, falling back to default.
      final clueTypeStr = round['clue_type'] as String?;
      final clueType = clueTypeStr != null
          ? ClueType.values.firstWhere(
              (t) => t.name == clueTypeStr,
              orElse: () => _defaultClueType,
            )
          : _defaultClueType;
      return ChallengeRound(
        roundNumber: round['round_number'] as int? ?? 0,
        seed: round['seed'] as int? ?? 0,
        clueType: clueType,
        startLocation: _defaultLocation,
        targetCountryCode: round['target_country_code'] as String? ?? '',
        countryName: round['country_name'] as String?,
        challengerTime: round['challenger_time_ms'] != null
            ? Duration(milliseconds: round['challenger_time_ms'] as int)
            : null,
        challengedTime: round['challenged_time_ms'] != null
            ? Duration(milliseconds: round['challenged_time_ms'] as int)
            : null,
        challengerScore: round['challenger_score'] as int?,
        challengedScore: round['challenged_score'] as int?,
        challengerHintsUsed: round['challenger_hints_used'] as int?,
        challengedHintsUsed: round['challenged_hints_used'] as int?,
      );
    }).toList();

    // Parse quiz metadata if present.
    final quizCatStr = row['quiz_category'] as String?;
    final quizModeStr = row['quiz_mode'] as String?;

    return Challenge(
      id: row['id'] as String,
      challengerId: row['challenger_id'] as String,
      challengerName: row['challenger_name'] as String,
      challengedId: row['challenged_id'] as String,
      challengedName: row['challenged_name'] as String,
      status: ChallengeStatus.fromDb(row['status'] as String),
      gameMode: ChallengeGameMode.fromDb(
        row['game_mode'] as String? ?? 'flight',
      ),
      rawGameMode: row['game_mode'] as String? ?? 'flight',
      roundsConfig: (row['rounds_config'] as List?)
          ?.map((c) => Map<String, dynamic>.from(c as Map))
          .toList(),
      rounds: rounds,
      quizCategory: quizCatStr != null
          ? QuizCategory.values.firstWhere(
              (c) => c.name == quizCatStr,
              orElse: () => QuizCategory.mixed,
            )
          : null,
      quizMode: quizModeStr != null
          ? QuizMode.values.firstWhere(
              (m) => m.name == quizModeStr,
              orElse: () => QuizMode.allStates,
            )
          : null,
      winnerId: row['winner_id'] as String?,
      challengerCoins: row['challenger_coins'] as int? ?? 0,
      challengedCoins: row['challenged_coins'] as int? ?? 0,
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'] as String)
          : null,
      completedAt: row['completed_at'] != null
          ? DateTime.tryParse(row['completed_at'] as String)
          : null,
    );
  }
}

final ClueType _defaultClueType = ClueType.values.first;
final Vector2 _defaultLocation = Vector2.zero();
