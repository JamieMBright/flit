import 'dart:math';

import '../../core/services/game_settings.dart';
import '../clues/clue_types.dart';
import '../data/country_difficulty.dart';
import 'triangulation_session.dart';
import 'triangulation_target.dart';

/// A rotating daily theme: what the player hunts (capital or country) and
/// which clue visuals and labels appear on the compass markers today.
class DailyTriangulationTheme {
  const DailyTriangulationTheme({
    required this.title,
    required this.description,
    required this.targetType,
    required this.clueTypes,
    required this.labelTypes,
  });

  final String title;
  final String description;
  final TriTargetType targetType;
  final Set<ClueType> clueTypes;
  final Set<TriLabel> labelTypes;

  /// Label-free themes are the expert runs.
  bool get isExpert => labelTypes.isEmpty;
}

/// The daily Triangulation puzzle: same date → same seed → same theme,
/// target type, difficulty, targets, and starting clues for every player.
class DailyTriangulation {
  const DailyTriangulation({
    required this.date,
    required this.seed,
    required this.theme,
    required this.difficulty,
  });

  /// UTC date (midnight) of this puzzle.
  final DateTime date;

  /// Deterministic seed derived from the date (YYYYMMDD, same scheme as
  /// Daily Scramble so it is proven cross-platform).
  final int seed;

  final DailyTriangulationTheme theme;

  /// Which target-country pool today draws from (rotates deterministically,
  /// weighted toward normal).
  final GameDifficulty difficulty;

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
      description: 'Flags with their capitals — hunt the hidden capital.',
      targetType: TriTargetType.capital,
      clueTypes: {ClueType.flag},
      labelTypes: {TriLabel.capital},
    ),
    DailyTriangulationTheme(
      title: 'Silhouette Sweep',
      description: 'Country shapes point the way — name the hidden country.',
      targetType: TriTargetType.country,
      clueTypes: {ClueType.outline},
      labelTypes: {TriLabel.country},
    ),
    DailyTriangulationTheme(
      title: 'Full Recon',
      description: 'Everything on the table: flags, shapes, and names.',
      targetType: TriTargetType.capital,
      clueTypes: {ClueType.flag, ClueType.outline},
      labelTypes: {TriLabel.country, TriLabel.capital},
    ),
    DailyTriangulationTheme(
      title: "Leaders' Summit",
      description: 'Flags with their heads of state — find the country.',
      targetType: TriTargetType.country,
      clueTypes: {ClueType.flag},
      labelTypes: {TriLabel.leader},
    ),
    DailyTriangulationTheme(
      title: 'Polyglot Patrol',
      description: 'Shapes and spoken tongues — find the country.',
      targetType: TriTargetType.country,
      clueTypes: {ClueType.outline},
      labelTypes: {TriLabel.language},
    ),
    DailyTriangulationTheme(
      title: 'Silent Compass',
      description: 'Bare flags, no names. Expert bearings only.',
      targetType: TriTargetType.capital,
      clueTypes: {ClueType.flag},
      labelTypes: {},
    ),
    DailyTriangulationTheme(
      title: 'Ghost Shapes',
      description: 'Unlabelled silhouettes. For seasoned navigators.',
      targetType: TriTargetType.country,
      clueTypes: {ClueType.outline},
      labelTypes: {},
    ),
  ];

  factory DailyTriangulation.forDate(DateTime date) {
    final normalised = DateTime.utc(date.year, date.month, date.day);
    final seed =
        normalised.year * 10000 + normalised.month * 100 + normalised.day;
    // Offset the theme RNG so today's rotation doesn't mirror the Daily
    // Scramble's (both derive from the same date seed). Draw order is
    // load-bearing: theme first, then difficulty — changing it changes
    // every day's puzzle.
    final rng = Random(seed + 31);
    final theme = _themes[rng.nextInt(_themes.length)];
    // Difficulty pool: weighted 1/4 easy, 1/2 normal, 1/4 hard.
    final roll = rng.nextInt(4);
    final difficulty = roll == 0
        ? GameDifficulty.easy
        : roll == 3
            ? GameDifficulty.hard
            : GameDifficulty.normal;
    return DailyTriangulation(
      date: normalised,
      seed: seed,
      theme: theme,
      difficulty: difficulty,
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
        difficulty: difficulty,
        targetType: theme.targetType,
        isDaily: true,
      );

  /// Difficulty percent for the lobby pill (0–100), Scramble-style.
  ///
  /// Simulates today's 3 rounds with the exact same seeds and dedup the
  /// session uses, so the displayed number reflects the real targets:
  /// average target obscurity, nudged up for label-free (expert) and
  /// outline-only clue configs. Pair with [difficultyLabel] for the text.
  int get difficultyPercent {
    final config = toConfig();
    final usedTargets = <String>{};
    var total = 0.0;
    for (var i = 0; i < roundCount; i++) {
      final round = TriangulationRound.generate(
        seed: seed + i * 7919,
        difficulty: difficulty,
        markerCount: markerCount,
        requireStats: config.requiresStats,
        excludedTargetCodes: Set.unmodifiable(usedTargets),
      );
      usedTargets.add(round.targetCountryCode);
      total += countryDifficultyRating(round.targetCountryCode);
    }
    var percent = (total / roundCount * 100).round();
    if (theme.isExpert) percent += 15;
    if (theme.clueTypes.length == 1 &&
        theme.clueTypes.contains(ClueType.outline)) {
      percent += 5;
    }
    return percent.clamp(0, 100);
  }

  /// Scramble-style difficulty label for [difficultyPercent].
  String get difficultyLabelText => difficultyLabel(difficultyPercent / 100.0);
}
