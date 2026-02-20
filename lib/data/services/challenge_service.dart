import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/challenge.dart';

/// Service for managing H2H dogfight challenges via Supabase.
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
  Future<String?> createChallenge({
    required String challengedId,
    required String challengedName,
    required String challengerName,
  }) async {
    if (_userId == null) return null;
    try {
      final rng = Random();
      // Generate deterministic seeds for each round.
      final rounds = List.generate(
        Challenge.totalRounds,
        (i) => <String, dynamic>{
          'round_number': i + 1,
          'seed': rng.nextInt(1 << 31),
        },
      );

      final data = await _client
          .from('challenges')
          .insert({
            'challenger_id': _userId,
            'challenger_name': challengerName,
            'challenged_id': challengedId,
            'challenged_name': challengedName,
            'status': 'pending',
            'rounds': rounds,
          })
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
          .inFilter('status', ['pending', 'in_progress'])
          .order('created_at', ascending: false);

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

  /// Submit the result of a single round.
  ///
  /// [roundIndex] is 0-based. [timeMs] is the player's completion time.
  /// The method reads the current rounds JSONB, updates the appropriate field,
  /// and writes it back.
  Future<bool> submitRoundResult({
    required String challengeId,
    required int roundIndex,
    required int timeMs,
  }) async {
    if (_userId == null) return false;
    try {
      // Fetch current challenge state.
      final row = await _client
          .from('challenges')
          .select('challenger_id, challenged_id, rounds, status')
          .eq('id', challengeId)
          .single();

      final isChallenger = row['challenger_id'] == _userId;
      final rounds = List<Map<String, dynamic>>.from(
        (row['rounds'] as List).map((r) => Map<String, dynamic>.from(r as Map)),
      );

      if (roundIndex < 0 || roundIndex >= rounds.length) return false;

      // Set the time for the appropriate player.
      final timeKey = isChallenger ? 'challenger_time_ms' : 'challenged_time_ms';
      rounds[roundIndex][timeKey] = timeMs;

      // If the challenge was pending, move to in_progress.
      final newStatus = row['status'] == 'pending' ? 'in_progress' : row['status'];

      await _client.from('challenges').update({
        'rounds': rounds,
        'status': newStatus,
      }).eq('id', challengeId);

      return true;
    } catch (e) {
      debugPrint('[ChallengeService] submitRoundResult failed: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Complete challenge
  // ---------------------------------------------------------------------------

  /// Check if the challenge is complete and determine the winner.
  ///
  /// Call this after submitting the final round. If both players have
  /// completed all rounds, sets winner, awards coins, and marks as completed.
  /// Returns the updated challenge, or null if not yet complete.
  Future<Challenge?> tryCompleteChallenge(String challengeId) async {
    if (_userId == null) return null;
    try {
      final row = await _client
          .from('challenges')
          .select()
          .eq('id', challengeId)
          .single();

      final challenge = _rowToChallenge(row);

      // Check if all rounds are complete (both players submitted).
      final completedRounds = challenge.rounds.where((r) => r.isComplete).length;
      if (completedRounds < Challenge.totalRounds) return null;

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

      return challenge;
    } catch (e) {
      debugPrint('[ChallengeService] tryCompleteChallenge failed: $e');
      return null;
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
          .update({'status': 'declined'})
          .eq('id', challengeId);
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

  Challenge _rowToChallenge(Map<String, dynamic> row) {
    final roundsList = row['rounds'] as List? ?? [];
    final rounds = roundsList.map<ChallengeRound>((r) {
      final round = r as Map<String, dynamic>;
      return ChallengeRound(
        roundNumber: round['round_number'] as int? ?? 0,
        seed: round['seed'] as int? ?? 0,
        clueType: _defaultClueType,
        startLocation: _defaultLocation,
        targetCountryCode: '',
        challengerTime: round['challenger_time_ms'] != null
            ? Duration(milliseconds: round['challenger_time_ms'] as int)
            : null,
        challengedTime: round['challenged_time_ms'] != null
            ? Duration(milliseconds: round['challenged_time_ms'] as int)
            : null,
      );
    }).toList();

    return Challenge(
      id: row['id'] as String,
      challengerId: row['challenger_id'] as String,
      challengerName: row['challenger_name'] as String,
      challengedId: row['challenged_id'] as String,
      challengedName: row['challenged_name'] as String,
      status: ChallengeStatus.values.firstWhere(
        (s) => s.name == row['status'],
        orElse: () => ChallengeStatus.pending,
      ),
      rounds: rounds,
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

// Sentinel values for round fields not stored in Supabase JSONB.
// The actual clue type and location are derived from the seed at play time.
import 'package:flame/components.dart';
import '../../game/clues/clue_types.dart';

final ClueType _defaultClueType = ClueType.values.first;
final Vector2 _defaultLocation = Vector2.zero();
