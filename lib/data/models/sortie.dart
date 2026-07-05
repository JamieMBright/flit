import 'dart:math';

import 'challenge.dart';

/// A Standard Sortie run: the rated, standardized, seeded 5-round flight —
/// the SAME format head-to-head challenges use, playable solo anytime.
///
/// Rated normalization (see lib/game/economy/rated_loadout.dart): every
/// sortie flies the fixed standard loadout, so scores are comparable across
/// players and money never buys rating.
class SortieRun {
  const SortieRun({required this.seeds});

  /// Rounds per run — identical to the H2H flight format.
  static const int totalRounds = Challenge.totalRounds;

  /// Maximum score per round (matches challenge round scoring, 0-10000).
  static const int maxRoundScore = 10000;

  /// Theoretical max run score.
  static const int maxRunScore = totalRounds * maxRoundScore;

  /// Flat coin reward for finishing a sortie (rated play still pays a
  /// little — it just can't buy rating).
  static const int completionCoinReward = 50;

  /// Per-round seeds, one per round, same seeded-session mechanism as H2H
  /// (`GameSession.seeded`).
  final List<int> seeds;

  /// Generate a fresh run with random round seeds (mirrors
  /// ChallengeService.createChallenge's seed generation).
  factory SortieRun.generate({Random? rng}) {
    final random = rng ?? Random();
    return SortieRun(
      seeds: List.generate(totalRounds, (_) => random.nextInt(1 << 31)),
    );
  }
}

/// Outcome of submitting a sortie run: the ghost duel + rating movement.
class SortieOutcome {
  const SortieOutcome({
    required this.applied,
    this.ratingDelta = 0,
    this.newRating,
    this.ghostName,
    this.ghostScore,
    this.playerScore = 0,
  });

  /// Whether the server applied a rating change. False when the sortie
  /// migration isn't deployed yet (silent degrade) or the run was already
  /// rated (idempotency).
  final bool applied;

  /// Elo movement for the player (ghost ratings never move).
  final int ratingDelta;

  /// Player's sortie rating after this run (null when not applied).
  final int? newRating;

  /// The ghost opponent's display name (null = house ghost / not applied).
  final String? ghostName;

  /// The ghost's run score.
  final int? ghostScore;

  /// This run's score, echoed back by the server.
  final int playerScore;

  /// Duel result against the ghost.
  bool get won => ghostScore != null && playerScore > ghostScore!;
  bool get lost => ghostScore != null && playerScore < ghostScore!;
  bool get draw => ghostScore != null && playerScore == ghostScore!;

  /// Offline / pre-migration fallback.
  static const SortieOutcome unavailable = SortieOutcome(applied: false);

  factory SortieOutcome.fromJson(Map<String, dynamic> json) => SortieOutcome(
        applied: json['applied'] == true,
        ratingDelta: json['delta'] as int? ?? 0,
        newRating: json['new_rating'] as int?,
        ghostName: json['ghost_name'] as String?,
        ghostScore: json['ghost_score'] as int?,
        playerScore: json['player_score'] as int? ?? 0,
      );
}
