/// Scoring constants and helpers for the Triangulation game mode.
///
/// Deliberately gentler than the Daily Scramble curve (daily_result.dart):
/// Scramble is fast recall, but Triangulation asks the player to reason
/// over five bearings, so full marks last 30s and the decay runs out to
/// 3 minutes. Scaled by the country difficulty multiplier, plus a
/// per-wrong-guess proximity penalty unique to this mode (a near-miss
/// costs little, a wild guess costs more — but never so much that a
/// mid-round solve feels pointless).
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
const int triWrongGuessFloor = 100;

/// Distance-scaled cost on top of the floor (at >= [triMaxPenaltyKm]).
const int triWrongGuessDistanceMax = 1400;

/// Full-marks window: no time penalty while reading and reasoning.
const int triTimeGraceSeconds = 30;

/// Time at which the time penalty saturates.
const int triTimeMaxSeconds = 180;

/// Largest possible time penalty (at >= [triTimeMaxSeconds]).
const int triTimePenaltyMax = 4000;

/// Multiplier applied when the round is solved via the country name
/// instead of the capital.
const double triCountryAnswerMultiplier = 0.7;

/// Cost of the one distance hint per round (reveals how far each starting
/// clue is from the hidden target). Wrong-guess distances are always shown
/// free — only the up-front reveal of the original clues costs score.
const int triDistanceHintPenalty = 600;

/// Penalty for one wrong guess, based on how far the guessed capital is
/// from the target capital. Direct neighbours are softened by half.
int triProximityPenalty(double distanceKm, {bool isNeighbor = false}) {
  final frac = (distanceKm / triMaxPenaltyKm).clamp(0.0, 1.0);
  final penalty =
      triWrongGuessFloor + (triWrongGuessDistanceMax * frac).round();
  return isNeighbor ? penalty ~/ 2 : penalty;
}

/// Time penalty: 0 within [triTimeGraceSeconds], then linear to
/// [triTimePenaltyMax] at [triTimeMaxSeconds]. Slower than Scramble's
/// recall curve on purpose — thinking is the game here.
int triTimePenalty(int timeMs) {
  final seconds = timeMs / 1000.0;
  if (seconds <= triTimeGraceSeconds) return 0;
  if (seconds >= triTimeMaxSeconds) return triTimePenaltyMax;
  return ((seconds - triTimeGraceSeconds) /
          (triTimeMaxSeconds - triTimeGraceSeconds) *
          triTimePenaltyMax)
      .round();
}

/// Final round score.
///
/// Expired (unsolved) rounds score 0. Otherwise:
///   raw   = base − timePenalty − Σ proximityPenalties − hint
///   score = raw × difficultyMultiplier(target) × (0.7 if solved by country)
int computeTriangulationScore({
  required bool solved,
  required bool solvedAsCountry,
  required int timeMs,
  required List<int> wrongGuessPenalties,
  required String targetCountryCode,
  bool hintUsed = false,
}) {
  if (!solved) return 0;
  final proximityTotal = wrongGuessPenalties.fold<int>(0, (sum, p) => sum + p);
  final hintPenalty = hintUsed ? triDistanceHintPenalty : 0;
  final raw =
      triBaseScore - triTimePenalty(timeMs) - proximityTotal - hintPenalty;
  if (raw <= 0) return 0;
  var score = raw * difficultyMultiplier(targetCountryCode);
  if (solvedAsCountry) score *= triCountryAnswerMultiplier;
  return score.round().clamp(0, triBaseScore);
}
