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
/// - Label policy: [QuizCategory.stateName] questions are ALWAYS
///   [QuizQuestion.labelFree] — a visible label literally answers "tap the
///   state by name", so name questions are the blind ones by definition.
///   Capital / nickname / landmark questions keep labels ON: the label
///   doesn't reveal which area matches the clue.
/// - Difficulty stays humane via the tier mix: easy regions (tier < 9) get
///   3 labeled capital + 3 blind name questions; mid (9–14) get 4 labeled
///   capital/flavour + 2 blind; hard (>= 15) get 5 labeled + 1 blind. The
///   blind questions always sit at the end of the set.
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
  /// "world tour" tier; the major-market country maps (Australia, France,
  /// Germany, Mexico) get a modest weight; everything else — including the
  /// niche five (UK, Ireland, Canada, Oceania, Caribbean) and the remaining
  /// country maps — appears at weight 1 so no single obscure region
  /// dominates.
  static const Map<String, int> _levelWeights = {
    'europe': 8,
    'us_states': 8,
    'africa': 4,
    'asia': 4,
    'latin_america': 4,
    'australia': 3,
    'france': 3,
    'germany': 2,
    'mexico': 2,
    'japan': 1,
    'spain': 1,
    'italy': 1,
    'brazil': 1,
    'india': 1,
    'new_zealand': 1,
    'south_korea': 1,
    'netherlands': 1,
    'poland': 1,
    'argentina': 1,
    'sweden': 1,
    'switzerland': 1,
    'austria': 1,
    'portugal': 1,
    'greece': 1,
    'south_africa': 1,
    'indonesia': 1,
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
  ///
  /// The daily draws ONLY from country-level regions (Europe, Africa, Asia,
  /// Latin America, Oceania, Caribbean) — never sub-national levels like US
  /// states or French régions — so a daily can't ask for e.g. "Annapolis →
  /// Maryland". Sub-national levels remain playable in Flight School practice.
  static FlightSchoolLevel _pickLevel(Random rng) {
    final pool = flightSchoolLevels.where((l) => l.isCountryLevel).toList();
    final totalWeight = pool.fold<int>(
      0,
      (sum, l) => sum + (_levelWeights[l.id] ?? 1),
    );
    var roll = rng.nextInt(totalWeight);
    for (final level in pool) {
      roll -= _levelWeights[level.id] ?? 1;
      if (roll < 0) return level;
    }
    return pool.first;
  }

  /// Number of blind (label-free) name questions for a region tier
  /// ([FlightSchoolLevel.requiredLevel]).
  ///
  /// Name questions are always blind — a visible label answers the question
  /// — so this is also how many [QuizCategory.stateName] questions appear.
  /// Easy regions can carry more blind questions; hard regions lean on
  /// labeled capital/flavour clues to keep difficulty humane:
  /// tier < 9 → 3 blind, tier 9–14 → 2 blind, tier >= 15 → 1 blind.
  static int labelFreeCountForTier(int requiredLevel) {
    if (requiredLevel >= 15) return 1;
    if (requiredLevel >= 9) return 2;
    return 3;
  }

  /// Build today's [questionCount] questions for [level].
  ///
  /// Seeded-samples distinct areas from the region (no duplicate answers).
  /// The plan is tier-mixed: labeled capital clues first (one may be swapped
  /// for a nickname/landmark flavour clue on well-known regions), then the
  /// blind [QuizCategory.stateName] questions at the end of the set.
  /// Label policy: stateName questions are ALWAYS labelFree; capital and
  /// flavour questions never are.
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

    // Tier mix: labeled capital clues up front, blind name questions last.
    final blindCount = labelFreeCountForTier(level.requiredLevel);
    final labeledCount = questionCount - blindCount;
    final plan = List<QuizCategory>.filled(
      labeledCount,
      QuizCategory.capital,
      growable: true,
    );

    // Flavour: well-known regions may swap ONE labeled question for a
    // nickname or landmark clue (roughly every other day).
    if (level.requiredLevel <= _flavourMaxTier && rng.nextBool()) {
      final flavour =
          rng.nextBool() ? QuizCategory.nickname : QuizCategory.landmark;
      plan[rng.nextInt(labeledCount)] = flavour;
    }

    // Blind slots: tap-the-named-area questions with labels hidden.
    plan.addAll(
      List<QuizCategory>.filled(blindCount, QuizCategory.stateName),
    );

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
      // Fallback for a labeled slot with no candidate: try a capital clue
      // first so the slot stays labeled (a name fallback would have to be
      // blind, unbalancing the tier mix).
      if (question == null &&
          category != QuizCategory.capital &&
          category != QuizCategory.stateName) {
        for (var i = 0; i < remaining.length; i++) {
          final candidate = generator.generateForArea(
            remaining[i],
            QuizCategory.capital,
          );
          if (candidate != null) {
            question = candidate;
            remaining.removeAt(i);
            break;
          }
        }
      }
      // Last resort: a plain name question always works for any area.
      if (question == null && remaining.isNotEmpty) {
        question = generator.generateForArea(
          remaining.removeAt(0),
          QuizCategory.stateName,
        );
      }
      if (question != null) questions.add(question);
    }

    // Label policy: name questions are ALWAYS blind (a label answers the
    // question); capital/flavour clues keep labels on. Stable partition so
    // any fallback name question also lands at the end of the set.
    return [
      for (final q in questions)
        if (q.category != QuizCategory.stateName) q.copyWith(labelFree: false),
      for (final q in questions)
        if (q.category == QuizCategory.stateName) q.copyWith(labelFree: true),
    ];
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
