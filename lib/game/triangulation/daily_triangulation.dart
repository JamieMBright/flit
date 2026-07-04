import 'dart:math';

import '../../core/services/game_settings.dart';
import '../clues/clue_types.dart';
import 'triangulation_session.dart';
import 'triangulation_target.dart';

/// A rotating daily theme: which clue visuals and labels appear on the
/// compass markers today.
class DailyTriangulationTheme {
  const DailyTriangulationTheme({
    required this.title,
    required this.clueTypes,
    required this.labelTypes,
  });

  final String title;
  final Set<ClueType> clueTypes;
  final Set<TriLabel> labelTypes;
}

/// The daily Triangulation puzzle: same date → same seed → same theme,
/// targets, and starting clues for every player.
class DailyTriangulation {
  const DailyTriangulation({
    required this.date,
    required this.seed,
    required this.theme,
  });

  /// UTC date (midnight) of this puzzle.
  final DateTime date;

  /// Deterministic seed derived from the date (YYYYMMDD, same scheme as
  /// Daily Scramble so it is proven cross-platform).
  final int seed;

  final DailyTriangulationTheme theme;

  /// Fixed daily structure: 3 hidden targets, 5 guesses each.
  static const int roundCount = 3;
  static const int guessesPerRound = 5;
  static const int markerCount = 5;

  /// Epoch for the share-text day number (#1 = launch day).
  static final DateTime epoch = DateTime.utc(2026, 7, 4);

  /// Days since [epoch], 1-based, for "Triangulation #N" share text.
  int get dayNumber => date.difference(epoch).inDays + 1;

  String get dateKey => '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static const List<DailyTriangulationTheme> _themes = [
    DailyTriangulationTheme(
      title: 'Flags & Capitals',
      clueTypes: {ClueType.flag},
      labelTypes: {TriLabel.capital},
    ),
    DailyTriangulationTheme(
      title: 'Silhouette Sweep',
      clueTypes: {ClueType.outline},
      labelTypes: {TriLabel.country},
    ),
    DailyTriangulationTheme(
      title: 'Full Recon',
      clueTypes: {ClueType.flag, ClueType.outline},
      labelTypes: {TriLabel.country, TriLabel.capital},
    ),
    DailyTriangulationTheme(
      title: "Leaders' Summit",
      clueTypes: {ClueType.flag},
      labelTypes: {TriLabel.leader},
    ),
    DailyTriangulationTheme(
      title: 'Polyglot Patrol',
      clueTypes: {ClueType.outline},
      labelTypes: {TriLabel.language},
    ),
  ];

  factory DailyTriangulation.forDate(DateTime date) {
    final normalised = DateTime.utc(date.year, date.month, date.day);
    final seed =
        normalised.year * 10000 + normalised.month * 100 + normalised.day;
    // Offset the theme RNG so today's theme rotation doesn't mirror the
    // Daily Scramble's (both derive from the same date seed).
    final rng = Random(seed + 31);
    return DailyTriangulation(
      date: normalised,
      seed: seed,
      theme: _themes[rng.nextInt(_themes.length)],
    );
  }

  factory DailyTriangulation.forToday() =>
      DailyTriangulation.forDate(DateTime.now().toUtc());

  /// Build the session config for this daily puzzle.
  TriangulationConfig toConfig() => TriangulationConfig(
        seed: seed,
        rounds: roundCount,
        guessesPerRound: guessesPerRound,
        markerCount: markerCount,
        clueTypes: theme.clueTypes,
        labelTypes: theme.labelTypes,
        difficulty: GameDifficulty.normal,
        isDaily: true,
      );
}
