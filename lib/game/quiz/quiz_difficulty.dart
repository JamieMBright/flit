import 'quiz_category.dart';

/// Difficulty level for Flight School quizzes.
///
/// Controls label visibility, available clue categories, hint availability,
/// and scoring multipliers.
enum QuizDifficulty { easy, medium, hard }

extension QuizDifficultyExtension on QuizDifficulty {
  String get displayName {
    switch (this) {
      case QuizDifficulty.easy:
        return 'Easy';
      case QuizDifficulty.medium:
        return 'Medium';
      case QuizDifficulty.hard:
        return 'Hard';
    }
  }

  String get description {
    switch (this) {
      case QuizDifficulty.easy:
        return 'Labels shown, easier clues, hints available';
      case QuizDifficulty.medium:
        return 'No labels, all clue types, fewer hints';
      case QuizDifficulty.hard:
        return 'No labels, hardest clues only, no hints';
    }
  }

  /// Whether area code labels are shown on the map.
  bool get showLabels {
    switch (this) {
      case QuizDifficulty.easy:
        return true;
      case QuizDifficulty.medium:
      case QuizDifficulty.hard:
        return false;
    }
  }

  /// Maximum hints allowed per quiz session.
  /// All difficulties now allow unlimited hints (score penalty increases).
  int get maxHints {
    switch (this) {
      case QuizDifficulty.easy:
        return 999;
      case QuizDifficulty.medium:
        return 999;
      case QuizDifficulty.hard:
        return 999;
    }
  }

  /// Scoring multiplier for this difficulty.
  /// Higher difficulty = more points.
  double get scoreMultiplier {
    switch (this) {
      case QuizDifficulty.easy:
        return 0.7;
      case QuizDifficulty.medium:
        return 1.0;
      case QuizDifficulty.hard:
        return 1.5;
    }
  }

  /// Easy categories (difficulty multiplier <= 1.3).
  static const _easyCategories = {
    QuizCategory.stateName,
    QuizCategory.capital,
    QuizCategory.nickname,
    QuizCategory.landmark,
    QuizCategory.mixed,
  };

  /// Hard categories (difficulty multiplier >= 1.4).
  static const _hardCategories = {
    QuizCategory.sportsTeam,
    QuizCategory.celebrity,
    QuizCategory.filmSetting,
    QuizCategory.flagDescription,
    QuizCategory.stateBird,
    QuizCategory.stateFlower,
    QuizCategory.motto,
    QuizCategory.mixed,
  };

  /// Filter available categories by difficulty.
  /// Easy: only the easiest categories.
  /// Medium: all categories.
  /// Hard: only the hardest categories.
  List<QuizCategory> filterCategories(List<QuizCategory> available) {
    // Regions with only name/capital/mixed have no filtering to do.
    if (available.length <= 3) return available;

    switch (this) {
      case QuizDifficulty.easy:
        final filtered =
            available.where((c) => _easyCategories.contains(c)).toList();
        return filtered.length >= 2 ? filtered : available;
      case QuizDifficulty.medium:
        return available;
      case QuizDifficulty.hard:
        final filtered =
            available.where((c) => _hardCategories.contains(c)).toList();
        // Fall back to all categories if filtering yields too few results.
        return filtered.length >= 2 ? filtered : available;
    }
  }
}

/// Difficulty rating for each quiz category.
///
/// Used as a scoring multiplier — harder clue categories earn more points.
/// Scale: 1.0 (easiest) to 2.0 (hardest).
double clueDifficultyMultiplier(QuizCategory category) {
  switch (category) {
    case QuizCategory.stateName:
      return 1.0;
    case QuizCategory.capital:
      return 1.2;
    case QuizCategory.nickname:
      return 1.3;
    case QuizCategory.sportsTeam:
      return 1.4;
    case QuizCategory.landmark:
      return 1.3;
    case QuizCategory.flagDescription:
      return 1.6;
    case QuizCategory.stateBird:
      return 1.7;
    case QuizCategory.stateFlower:
      return 1.8;
    case QuizCategory.motto:
      return 1.9;
    case QuizCategory.celebrity:
      return 1.5;
    case QuizCategory.filmSetting:
      return 1.5;
    case QuizCategory.mixed:
      return 1.3; // average of all
  }
}
