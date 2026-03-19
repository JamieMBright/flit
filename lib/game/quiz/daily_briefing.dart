import 'dart:math';

import 'flight_school_level.dart';
import 'quiz_category.dart';
import 'quiz_difficulty.dart';
import 'quiz_session.dart';

/// Daily Flight Briefing configuration — a deterministic quiz challenge
/// generated from the current date.
///
/// Every player who opens the briefing on the same calendar day (UTC) receives
/// the same level, category, difficulty, mode, and question seed. This allows
/// fair leaderboard competition: one attempt per day, same conditions for all.
class DailyBriefing {
  const DailyBriefing({
    required this.dateKey,
    required this.seed,
    required this.level,
    required this.category,
    required this.difficulty,
    required this.mode,
  });

  /// Date string in YYYY-MM-DD format.
  final String dateKey;

  /// Deterministic seed derived from the date (used for question order).
  final int seed;

  /// The Flight School level selected for today's briefing.
  final FlightSchoolLevel level;

  /// The quiz category for today's briefing.
  final QuizCategory category;

  /// The difficulty setting for today's briefing.
  final QuizDifficulty difficulty;

  /// The quiz mode for today's briefing.
  final QuizMode mode;

  /// Modes eligible for the daily briefing rotation.
  ///
  /// [QuizMode.typeIn] is excluded because it requires a text input UX that
  /// doesn't pair well with the "same conditions for everyone" philosophy
  /// (autocomplete/keyboard differences across devices).
  static const List<QuizMode> _eligibleModes = [
    QuizMode.allStates,
    QuizMode.timeTrial,
    QuizMode.rapidFire,
  ];

  // ---------------------------------------------------------------------------
  // Factories
  // ---------------------------------------------------------------------------

  /// Generate today's briefing (UTC).
  factory DailyBriefing.today() {
    final now = DateTime.now().toUtc();
    return DailyBriefing.forDate(DateTime.utc(now.year, now.month, now.day));
  }

  /// Generate a briefing for a specific [date].
  ///
  /// Only the year/month/day components matter; the time portion is ignored.
  factory DailyBriefing.forDate(DateTime date) {
    final normalised = DateTime.utc(date.year, date.month, date.day);
    final dateKey = '${normalised.year}-'
        '${normalised.month.toString().padLeft(2, '0')}-'
        '${normalised.day.toString().padLeft(2, '0')}';

    // Build a seed from the date string hash so it's stable across platforms.
    final seed = _hashDateKey(dateKey);
    final rng = Random(seed);

    // 1. Pick a level from all available flight school levels.
    final level = flightSchoolLevels[rng.nextInt(flightSchoolLevels.length)];

    // 2. Pick a difficulty, biased by the level's tier.
    //
    // Higher-tier levels (requiredLevel >= 13) shouldn't appear as "Easy" —
    // it's nonsensical to label a Marshall Islands quiz as easy. We restrict
    // the eligible difficulty pool based on the level's required player level.
    final List<QuizDifficulty> difficultyPool;
    if (level.requiredLevel >= 17) {
      // Expert levels (Oceania, Caribbean, etc.) — medium or hard only.
      difficultyPool = [QuizDifficulty.medium, QuizDifficulty.hard];
    } else if (level.requiredLevel >= 9) {
      // Mid-tier levels (Asia, Latin America, UK, Ireland) — all allowed but
      // weighted away from easy by excluding it from the pool.
      difficultyPool = [QuizDifficulty.medium, QuizDifficulty.hard];
    } else {
      // Starter levels (Europe, US, Africa) — any difficulty.
      difficultyPool = QuizDifficulty.values;
    }
    final difficulty = difficultyPool[rng.nextInt(difficultyPool.length)];

    // 3. Pick a category valid for this level (respecting difficulty filter).
    final filteredCategories = difficulty.filterCategories(
      level.availableCategories,
    );
    final categoryPool = filteredCategories.isNotEmpty
        ? filteredCategories
        : level.availableCategories;
    final category = categoryPool[rng.nextInt(categoryPool.length)];

    // 4. Pick a mode from the eligible set.
    final mode = _eligibleModes[rng.nextInt(_eligibleModes.length)];

    return DailyBriefing(
      dateKey: dateKey,
      seed: seed,
      level: level,
      category: category,
      difficulty: difficulty,
      mode: mode,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Simple djb2-style hash of the date key string to produce a stable int
  /// seed across all Dart platforms.
  static int _hashDateKey(String key) {
    int hash = 5381;
    for (int i = 0; i < key.length; i++) {
      hash = ((hash << 5) + hash) + key.codeUnitAt(i); // hash * 33 + c
    }
    return hash.abs();
  }

  /// Aviation-themed subtitle describing the mission parameters.
  String get missionSubtitle {
    final modeLabel = mode.displayName.toUpperCase();
    final diffLabel = difficulty.displayName.toUpperCase();
    return '$modeLabel / $diffLabel';
  }

  /// Estimated duration label for the briefing card.
  String get estimatedDuration {
    switch (mode) {
      case QuizMode.allStates:
        return '~${level.areaCount} questions';
      case QuizMode.timeTrial:
        return '60 seconds';
      case QuizMode.rapidFire:
        return '3 strikes';
      case QuizMode.typeIn:
        return '90 seconds';
    }
  }
}
