import 'package:flame/components.dart';

import '../../core/services/game_settings.dart';
import '../../core/utils/math_utils.dart';
import '../clues/clue_types.dart';
import '../map/country_data.dart';
import 'triangulation_scoring.dart';
import 'triangulation_target.dart';

/// Configuration for a Triangulation game (daily or free play).
class TriangulationConfig {
  const TriangulationConfig({
    required this.seed,
    this.rounds = 3,
    this.guessesPerRound = 5,
    this.markerCount = 5,
    this.clueTypes = const {ClueType.flag},
    this.labelTypes = const {TriLabel.capital},
    this.difficulty = GameDifficulty.normal,
    this.targetType = TriTargetType.capital,
    this.isDaily = false,
  });

  final int seed;
  final int rounds;
  final int guessesPerRound;
  final int markerCount;

  /// What the player is hunting. Capital days: capital = full points,
  /// country = ×0.7. Country days: only country names are answer
  /// candidates (the UI offers no capital entries).
  final TriTargetType targetType;

  /// Visual clue types shown in each marker's info box
  /// (flag / outline / borders / capital supported).
  final Set<ClueType> clueTypes;

  /// Label types shown in each marker's info box.
  final Set<TriLabel> labelTypes;

  final GameDifficulty difficulty;
  final bool isDaily;

  /// Whether clue anchors must have leader/language stats available.
  bool get requiresStats =>
      labelTypes.contains(TriLabel.leader) ||
      labelTypes.contains(TriLabel.language);
}

/// One guess the player has made in a round.
class TriangulationGuess {
  const TriangulationGuess({
    required this.countryCode,
    required this.countryName,
    required this.capitalName,
    required this.capitalLngLat,
    required this.viaCapital,
    required this.isCorrect,
    required this.distanceKm,
    required this.bearingFromTargetDeg,
    required this.penalty,
  });

  final String countryCode;
  final String countryName;
  final String capitalName;

  /// Guessed capital coordinates as (lng, lat) degrees.
  final Vector2 capitalLngLat;

  /// True when the player typed the capital name (full points on solve);
  /// false when they answered with the country name (reduced multiplier).
  final bool viaCapital;

  final bool isCorrect;

  /// Great-circle distance from the guessed capital to the target capital.
  final double distanceKm;

  /// Bearing from the target capital to the guessed capital — this is the
  /// red marker added to the compass for a wrong guess.
  final double bearingFromTargetDeg;

  /// Proximity penalty charged for this guess (0 when correct).
  final int penalty;
}

/// Live state for one round.
class TriangulationRoundState {
  TriangulationRoundState(this.round);

  final TriangulationRound round;
  final List<TriangulationGuess> guesses = [];
  bool solved = false;
  bool expired = false;
  int elapsedMs = 0;
  int score = 0;

  bool get isOver => solved || expired;
  bool get solvedAsCountry =>
      solved && guesses.isNotEmpty && !guesses.last.viaCapital;
  List<TriangulationGuess> get wrongGuesses =>
      guesses.where((g) => !g.isCorrect).toList();
}

/// A full Triangulation game: [TriangulationConfig.rounds] hidden targets,
/// each guessable up to [TriangulationConfig.guessesPerRound] times.
///
/// Deterministic from the config seed: on a daily seed every player gets
/// identical targets and starting clues; games diverge only through each
/// player's own guesses.
class TriangulationSession {
  TriangulationSession(this.config) {
    final usedTargets = <String>{};
    final usedAnchors = <String>{};
    for (var i = 0; i < config.rounds; i++) {
      final round = TriangulationRound.generate(
        seed: config.seed + i * 7919,
        difficulty: config.difficulty,
        markerCount: config.markerCount,
        requireStats: config.requiresStats,
        excludedTargetCodes: Set.unmodifiable(usedTargets),
        excludedAnchorCodes: Set.unmodifiable(usedAnchors),
      );
      usedTargets.add(round.targetCountryCode);
      usedAnchors.addAll(round.clues.map((c) => c.countryCode));
      rounds.add(TriangulationRoundState(round));
    }
  }

  final TriangulationConfig config;
  final List<TriangulationRoundState> rounds = [];
  int _currentIndex = 0;

  TriangulationRoundState get currentRound => rounds[_currentIndex];
  int get currentRoundNumber => _currentIndex + 1;
  bool get isLastRound => _currentIndex >= rounds.length - 1;
  bool get isFinished => rounds.every((r) => r.isOver);
  int get totalScore => rounds.fold(0, (sum, r) => sum + r.score);
  int get totalTimeMs => rounds.fold(0, (sum, r) => sum + r.elapsedMs);
  int get solvedRounds => rounds.where((r) => r.solved).length;

  int get guessesRemaining =>
      config.guessesPerRound - currentRound.guesses.length;

  /// Submit a guess for the current round. [countryCode] must be an ISO
  /// code resolved by the input matcher; [viaCapital] records whether the
  /// player typed the capital or the country name. [elapsedMs] is the
  /// round timer at the moment of the guess.
  ///
  /// Returns the recorded guess. When wrong, its bearing becomes a new
  /// red marker on the compass. Solves or expires the round as needed.
  TriangulationGuess submitGuess(
    String countryCode, {
    required bool viaCapital,
    required int elapsedMs,
  }) {
    final state = currentRound;
    assert(!state.isOver, 'Round is already over');

    final round = state.round;
    final country = CountryData.getCountry(countryCode);
    final capital = CountryData.getCapital(countryCode);
    final capitalLngLat = capital?.location ?? round.targetCapitalLngLat;

    final isCorrect = countryCode == round.targetCountryCode;
    final distanceKm = isCorrect
        ? 0.0
        : greatCircleKm(round.targetCapitalLngLat, capitalLngLat);
    final isNeighbor = Clue.getNeighbors(round.targetCountryCode)
        .map((n) => n.toLowerCase())
        .contains((country?.name ?? '').toLowerCase());

    final guess = TriangulationGuess(
      countryCode: countryCode,
      countryName: country?.name ?? countryCode,
      capitalName: capital?.name ?? '',
      capitalLngLat: capitalLngLat,
      viaCapital: viaCapital,
      isCorrect: isCorrect,
      distanceKm: distanceKm,
      // Flat-map bearing, matching the clue arrows' convention.
      bearingFromTargetDeg:
          flatMapBearingDeg(round.targetCapitalLngLat, capitalLngLat),
      penalty: isCorrect
          ? 0
          : triProximityPenalty(distanceKm, isNeighbor: isNeighbor),
    );
    state.guesses.add(guess);
    state.elapsedMs = elapsedMs;

    if (isCorrect) {
      state.solved = true;
    } else if (state.guesses.length >= config.guessesPerRound) {
      state.expired = true;
    }
    if (state.isOver) {
      state.score = computeTriangulationScore(
        solved: state.solved,
        // The ×0.7 country-name discount only exists on capital days;
        // on country days the country name IS the asked-for answer.
        solvedAsCountry:
            state.solvedAsCountry && config.targetType == TriTargetType.capital,
        timeMs: state.elapsedMs,
        wrongGuessPenalties: state.wrongGuesses.map((g) => g.penalty).toList(),
        targetCountryCode: round.targetCountryCode,
      );
    }
    return guess;
  }

  /// Move to the next round after the current one is over.
  void advanceRound() {
    assert(currentRound.isOver, 'Current round is not over yet');
    if (!isLastRound) _currentIndex++;
  }
}
