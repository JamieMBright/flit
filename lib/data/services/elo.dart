import 'dart:math';

/// Pure ELO rating math for H2H challenges.
///
/// Mirrors the SQL implementation in the `apply_challenge_rating` RPC
/// (supabase/migrations/20260705_player_ratings.sql) so the client can
/// display and reason about rating changes without a round trip. Keep the
/// two in sync: standard Elo, K = 32, draws count as 0.5, cold-start seeds
/// clamped to [coldStartMin, coldStartMax].
class Elo {
  Elo._();

  /// K-factor: maximum rating movement per game.
  static const int kFactor = 32;

  /// Default rating for a brand-new player with no profile stats.
  static const int initialRating = 1000;

  /// Cold-start seed clamp bounds.
  static const int coldStartMin = 800;
  static const int coldStartMax = 2000;

  /// Result values for [update].
  static const double win = 1.0;
  static const double draw = 0.5;
  static const double loss = 0.0;

  /// Expected score (0..1) for a player rated [rating] against
  /// [opponentRating]. Equal ratings give 0.5; the two players' expected
  /// scores always sum to 1.
  static double expectedScore(int rating, int opponentRating) =>
      1 / (1 + pow(10, (opponentRating - rating) / 400.0));

  /// New rating after a game. [score] is [win], [draw], or [loss].
  static int update({
    required int rating,
    required int opponentRating,
    required double score,
  }) =>
      (rating + kFactor * (score - expectedScore(rating, opponentRating)))
          .round();

  /// Cold-start rating seeded from profile stats, mirroring
  /// `MatchmakingService.estimateElo` but clamped to
  /// [[coldStartMin], [coldStartMax]] like the server-side seed.
  static int coldStartRating({required int level, int bestScore = 0}) =>
      (initialRating + level * 50 + bestScore ~/ 20)
          .clamp(coldStartMin, coldStartMax);
}
