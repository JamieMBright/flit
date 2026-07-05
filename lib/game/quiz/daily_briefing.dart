import 'dart:math';

import '../map/region.dart';
import 'flight_school_level.dart';
import 'quiz_category.dart';
import 'quiz_difficulty.dart';
import 'quiz_session.dart';

/// Daily Flight Briefing configuration — a deterministic quiz challenge
/// generated from the current date.
///
/// Every player who opens the briefing on the same calendar day (UTC) receives
/// the same region, questions, order, and label rules. This allows fair
/// leaderboard competition: one attempt per day, same conditions for all.
///
/// Selection policy (why the daily differs from Flight School practice):
/// - The daily must be short, accessible, and achievable. It is always exactly
///   [questionCount] tap-the-map questions — untimed, no strikes.
/// - Regions rotate on a seeded weighted schedule: broadly-known regions
///   (Europe, US States) dominate, a "world tour" tier (Africa, Asia, Latin
///   America) fills most other days, and niche regions (UK, Ireland, Canada,
///   Oceania, Caribbean) combined appear at most ~1 day in 7.
/// - Questions use only the accessible categories: name and capital. On
///   well-known regions (tier <= [_flavourMaxTier]) at most ONE question may
///   instead be a nickname/landmark "flavour" clue. Obscure categories
///   (stateFlower, stateBird, motto, sportsTeam, celebrity, filmSetting,
///   flagDescription) never appear — they stay in Flight School practice.
/// - Difficulty is always easy (labels on); challenge comes from per-question
///   [QuizQuestion.labelFree] "stretch" questions at the end of the set —
///   2 for easy regions, 1 for mid-tier, 0 for hard regions.
class DailyBriefing {
  const DailyBriefing({
    required this.dateKey,
    required this.seed,
    required this.level,
    required this.categories,
    required this.difficulty,
    required this.mode,
    required this.questions,
  });

  /// Date string in YYYY-MM-DD format.
  final String dateKey;

  /// Deterministic seed derived from the date.
  final int seed;

  /// The Flight School level (region) selected for today's briefing.
  final FlightSchoolLevel level;

  /// The categories used across today's question set.
  final Set<QuizCategory> categories;

  /// The difficulty setting for today's briefing (always label-friendly;
  /// label-blindness is applied per-question via [QuizQuestion.labelFree]).
  final QuizDifficulty difficulty;

  /// The quiz mode for today's briefing (always untimed, no fail-out).
  final QuizMode mode;

  /// Today's curated question list — exactly [questionCount] entries, no
  /// duplicate answer areas, identical for every player.
  final List<QuizQuestion> questions;

  /// The daily is always exactly this many questions.
  static const int questionCount = 6;

  /// Highest level tier that may receive a nickname/landmark flavour question.
  static const int _flavourMaxTier = 5;

  /// Weighted region rotation, keyed by [FlightSchoolLevel.id].
  ///
  /// Europe and US States dominate; Africa/Asia/Latin America form the
  /// "world tour" tier; the niche five (UK, Ireland, Canada, Oceania,
  /// Caribbean) get weight 1 each — 5/33 of days, roughly 1 day in 7
  /// combined.
  static const Map<String, int> _levelWeights = {
    'europe': 8,
    'us_states': 8,
    'africa': 4,
    'asia': 4,
    'latin_america': 4,
    'uk_counties': 1,
    'ireland': 1,
    'canada': 1,
    'oceania': 1,
    'caribbean': 1,
  };

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
  /// Deterministic: the same date always yields the same region, questions,
  /// order, and labelFree flags on every platform.
  factory DailyBriefing.forDate(DateTime date) {
    final normalised = DateTime.utc(date.year, date.month, date.day);
    final dateKey = '${normalised.year}-'
        '${normalised.month.toString().padLeft(2, '0')}-'
        '${normalised.day.toString().padLeft(2, '0')}';

    // Build a seed from the date string hash so it's stable across platforms.
    final seed = _hashDateKey(dateKey);
    final rng = Random(seed);

    // 1. Weighted region pick (draw order is load-bearing: level first, then
    // the question plan — changing it changes every day's briefing).
    final level = _pickLevel(rng);

    // 2. Build the curated question set.
    final questions = _buildQuestions(level, rng, seed);

    return DailyBriefing(
      dateKey: dateKey,
      seed: seed,
      level: level,
      categories: questions.map((q) => q.category).toSet(),
      // Always a labels-on difficulty: easy is the only tier with
      // showLabels == true. Label-blindness is per-question (labelFree).
      difficulty: QuizDifficulty.easy,
      // Complete-the-set semantics: answer all six, untimed, no strikes.
      mode: QuizMode.allStates,
      questions: questions,
    );
  }

  // ---------------------------------------------------------------------------
  // Selection policy
  // ---------------------------------------------------------------------------

  /// Seeded weighted pick from the flight school levels.
  static FlightSchoolLevel _pickLevel(Random rng) {
    final totalWeight = flightSchoolLevels.fold<int>(
      0,
      (sum, l) => sum + (_levelWeights[l.id] ?? 1),
    );
    var roll = rng.nextInt(totalWeight);
    for (final level in flightSchoolLevels) {
      roll -= _levelWeights[level.id] ?? 1;
      if (roll < 0) return level;
    }
    return flightSchoolLevels.first;
  }

  /// Number of label-free "stretch" questions for a region tier
  /// ([FlightSchoolLevel.requiredLevel]). Hard regions stay fully labeled.
  static int labelFreeCountForTier(int requiredLevel) {
    if (requiredLevel >= 15) return 0;
    if (requiredLevel >= 9) return 1;
    return 2;
  }

  /// Build today's [questionCount] questions for [level].
  ///
  /// Seeded-samples distinct areas from the region (no duplicate answers),
  /// mixes name and capital clues (2–4 capitals), optionally swaps one
  /// question for a nickname/landmark flavour clue on well-known regions,
  /// and marks the trailing stretch questions label-free.
  static List<QuizQuestion> _buildQuestions(
    FlightSchoolLevel level,
    Random rng,
    int seed,
  ) {
    // No difficulty filter: the country-difficulty ratings reuse ISO codes
    // that collide with US state codes ('CA' state vs Canada), so the daily
    // prefers straightforward seeded sampling.
    final generator = QuizQuestionGenerator(region: level.region, seed: seed);
    final remaining = List.of(RegionalData.getAreas(level.region))
      ..shuffle(rng);

    // Category plan: mostly names and capitals — 2 to 4 capital clues per day.
    final capitalCount = 2 + rng.nextInt(3);
    final plan = List<QuizCategory>.generate(
      questionCount,
      (i) => i < capitalCount ? QuizCategory.capital : QuizCategory.stateName,
    )..shuffle(rng);

    // Flavour: well-known regions may swap ONE question for a nickname or
    // landmark clue (roughly every other day).
    if (level.requiredLevel <= _flavourMaxTier && rng.nextBool()) {
      final flavour =
          rng.nextBool() ? QuizCategory.nickname : QuizCategory.landmark;
      plan[rng.nextInt(questionCount)] = flavour;
    }

    final questions = <QuizQuestion>[];
    for (final category in plan) {
      QuizQuestion? question;
      // Walk the shuffled areas until one supports this clue category
      // (has a capital / nickname / landmark on record).
      for (var i = 0; i < remaining.length; i++) {
        final candidate = generator.generateForArea(remaining[i], category);
        if (candidate != null) {
          question = candidate;
          remaining.removeAt(i);
          break;
        }
      }
      // Fallback: a plain name question always works for any area.
      if (question == null && remaining.isNotEmpty) {
        question = generator.generateForArea(
          remaining.removeAt(0),
          QuizCategory.stateName,
        );
      }
      if (question != null) questions.add(question);
    }

    // Mark the trailing stretch questions label-free.
    final blindCount = labelFreeCountForTier(level.requiredLevel);
    for (var i = 0; i < questions.length; i++) {
      if (i >= questions.length - blindCount) {
        questions[i] = questions[i].copyWith(labelFree: true);
      }
    }
    return questions;
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

  /// Number of label-free stretch questions in today's set.
  int get labelFreeCount => questions.where((q) => q.labelFree).length;

  /// Aviation-themed subtitle describing the mission parameters.
  String get missionSubtitle =>
      '${level.name.toUpperCase()} / $questionCount TARGETS';

  /// Clue-type summary for the lobby card (e.g. "Names & Capitals").
  String get intelTypeLabel {
    final names = categories.map((c) => c.displayName).toList();
    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names[0]} & ${names[1]}';
    return names.join(' · ');
  }

  /// Label-visibility summary for the lobby card
  /// (e.g. "Labels on · 2 blind").
  String get labelSummary {
    final blind = labelFreeCount;
    return blind == 0 ? 'Labels on' : 'Labels on · $blind blind';
  }

  /// Estimated duration label for the briefing card.
  String get estimatedDuration => '$questionCount targets · no timer';
}
