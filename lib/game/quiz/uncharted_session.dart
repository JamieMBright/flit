/// Session logic for the Uncharted game mode.
///
/// Tracks which areas have been revealed, validates guesses via fuzzy
/// matching, and computes final scores.
library;

import '../map/region.dart';
import 'fuzzy_match.dart';

/// Whether the player is naming countries/areas or their capitals.
enum UnchartedMode {
  countries,
  capitals,
}

extension UnchartedModeExtension on UnchartedMode {
  String get displayName {
    switch (this) {
      case UnchartedMode.countries:
        return 'Countries';
      case UnchartedMode.capitals:
        return 'Capitals';
    }
  }

  String get description {
    switch (this) {
      case UnchartedMode.countries:
        return 'Type country names to reveal them';
      case UnchartedMode.capitals:
        return 'Type capital cities to reveal countries';
    }
  }
}

/// Result of a single guess in Uncharted mode.
class UnchartedGuessResult {
  const UnchartedGuessResult({
    required this.matched,
    this.code,
    this.areaName,
    this.matchedInput,
  });

  /// Whether the guess matched an unrevealed area.
  final bool matched;

  /// The area code that was matched (null if no match).
  final String? code;

  /// The canonical area name (null if no match).
  final String? areaName;

  /// The input text that the user typed (null if no match).
  final String? matchedInput;
}

/// Manages the state of a single Uncharted round.
class UnchartedSession {
  UnchartedSession({
    required this.region,
    required this.mode,
  }) {
    final areas = RegionalData.getAreas(region);

    // Build lookup: for countries mode, match area names.
    // For capitals mode, match capital names → area code.
    final Map<String, String> candidates = {};
    for (final area in areas) {
      if (mode == UnchartedMode.countries) {
        candidates[area.code] = area.name;
      } else {
        // Capitals mode — skip areas without a capital.
        if (area.capital != null && area.capital!.isNotEmpty) {
          candidates[area.code] = area.capital!;
          _capitalToAreaName[area.code] = area.name;
        }
      }
    }
    _matcher = FuzzyMatcher(candidates);
    _totalCount = candidates.length;
  }

  final GameRegion region;
  final UnchartedMode mode;

  late final FuzzyMatcher _matcher;
  late final int _totalCount;
  final Map<String, String> _capitalToAreaName = {};

  final Set<String> _revealedCodes = {};
  DateTime? _startTime;
  bool _givenUp = false;

  // ── Public getters ──

  bool get isStarted => _startTime != null;
  bool get isComplete => _revealedCodes.length >= _totalCount || _givenUp;
  bool get givenUp => _givenUp;
  int get totalCount => _totalCount;
  int get revealedCount => _revealedCodes.length;
  int get remainingCount => _totalCount - _revealedCodes.length;
  int get correctGuesses => _revealedCodes.length;
  Set<String> get revealedCodes => Set.unmodifiable(_revealedCodes);
  double get progress =>
      _totalCount > 0 ? _revealedCodes.length / _totalCount : 0;

  /// Elapsed time since the session started, in milliseconds.
  int get elapsedMs {
    if (_startTime == null) return 0;
    return DateTime.now().difference(_startTime!).inMilliseconds;
  }

  String get elapsedFormatted {
    final seconds = (elapsedMs / 1000).floor();
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  // ── Actions ──

  /// Start the timer. Call this when the game screen is ready.
  void start() {
    _startTime = DateTime.now();
  }

  /// Check if [input] exactly matches an unrevealed area (no side effects).
  ///
  /// Returns true only for exact or alias matches (distance 0), so that
  /// auto-submit doesn't fire on partial fuzzy matches.
  bool hasExactMatch(String input) {
    if (isComplete) return false;
    final result = _matcher.bestMatch(input, excludeCodes: _revealedCodes);
    return result != null && result.isExact;
  }

  /// Submit a guess. Returns whether it matched.
  UnchartedGuessResult submitGuess(String input) {
    if (!isStarted) start();
    if (isComplete) {
      return const UnchartedGuessResult(matched: false);
    }

    final result = _matcher.bestMatch(input, excludeCodes: _revealedCodes);

    if (result == null) {
      return const UnchartedGuessResult(matched: false);
    }

    _revealedCodes.add(result.code);

    return UnchartedGuessResult(
      matched: true,
      code: result.code,
      areaName: mode == UnchartedMode.capitals
          ? _capitalToAreaName[result.code] ?? result.canonicalName
          : result.canonicalName,
      matchedInput: result.canonicalName,
    );
  }

  /// Give up — marks the session as finished without revealing remaining areas.
  void giveUp() {
    _givenUp = true;
  }

  /// Final score.
  ///
  /// Formula:
  /// - Base: 100 points per correct answer
  /// - Time bonus: faster = higher (decays over 10 minutes)
  /// - Completion bonus: 2000 extra for finding all areas
  int get finalScore {
    if (_revealedCodes.isEmpty) return 0;

    final basePoints = _revealedCodes.length * 100;

    // Time bonus: up to 1.5x for under 2 minutes, decays to 1.0x over 10 min.
    final seconds = elapsedMs / 1000.0;
    final timeMult = seconds < 120.0
        ? 1.5
        : (1.0 + 0.5 * (1.0 - (seconds / 600.0)).clamp(0, 1));

    // Completion bonus: 2000 extra points for completing all areas.
    final completionBonus =
        (!_givenUp && _revealedCodes.length >= _totalCount) ? 2000 : 0;

    return (basePoints * timeMult).round() + completionBonus;
  }
}
