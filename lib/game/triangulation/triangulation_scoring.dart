/// Scoring constants and helpers for the Triangulation game mode.
///
/// Mirrors the Daily Scramble curve (daily_result.dart): full marks within
/// 10s, linear time decay to 60s, scaled by the country difficulty
/// multiplier — plus a per-wrong-guess proximity penalty unique to this
/// mode (a near-miss costs little, a wild guess costs a lot).
library;

import '../data/country_difficulty.dart';

/// Base score per round.
const int triBaseScore = 10000;

/// Proximity thresholds (km) shared by scoring and the share-grid colours.
const double triHotKm = 500;
const double triWarmKm = 2000;
const double triCoolKm = 5000;

/// Distance at which the proximity penalty saturates.
const double triMaxPenaltyKm = 8000;

/// Flat cost of any wrong guess.
const int triWrongGuessFloor = 200;

/// Distance-scaled cost on top of the floor (at >= [triMaxPenaltyKm]).
const int triWrongGuessDistanceMax = 2300;

/// Multiplier applied when the round is solved via the country name
/// instead of the capital.
const double triCountryAnswerMultiplier = 0.7;

/// Penalty for one wrong guess, based on how far the guessed capital is
/// from the target capital. Direct neighbours are softened by half.
int triProximityPenalty(double distanceKm, {bool isNeighbor = false}) {
  final frac = (distanceKm / triMaxPenaltyKm).clamp(0.0, 1.0);
  final penalty =
      triWrongGuessFloor + (triWrongGuessDistanceMax * frac).round();
  return isNeighbor ? penalty ~/ 2 : penalty;
}

/// Time penalty: 0 within 10s, linear to 5000 at 60s (same curve as
/// DailyRoundResult.computeTimeScore).
int triTimePenalty(int timeMs) {
  final seconds = timeMs / 1000.0;
  if (seconds <= 10) return 0;
  if (seconds >= 60) return 5000;
  return ((seconds - 10) / 50.0 * 5000).round();
}

/// Final round score.
///
/// Expired (unsolved) rounds score 0. Otherwise:
///   raw   = base − timePenalty − Σ proximityPenalties
///   score = raw × difficultyMultiplier(target) × (0.7 if solved by country)
int computeTriangulationScore({
  required bool solved,
  required bool solvedAsCountry,
  required int timeMs,
  required List<int> wrongGuessPenalties,
  required String targetCountryCode,
}) {
  if (!solved) return 0;
  final proximityTotal = wrongGuessPenalties.fold<int>(0, (sum, p) => sum + p);
  final raw = triBaseScore - triTimePenalty(timeMs) - proximityTotal;
  if (raw <= 0) return 0;
  var score = raw * difficultyMultiplier(targetCountryCode);
  if (solvedAsCountry) score *= triCountryAnswerMultiplier;
  return score.round().clamp(0, triBaseScore);
}
