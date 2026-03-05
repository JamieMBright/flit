import 'dart:math';

import '../data/us_state_clues.dart';
import '../map/region.dart';

/// Categories of quiz questions available in Flight School.
enum QuizCategory {
  stateName,
  capital,
  nickname,
  sportsTeam,
  landmark,
  flagDescription,
  stateBird,
  stateFlower,
  motto,
  celebrity,
  filmSetting,
  mixed,
}

extension QuizCategoryExtension on QuizCategory {
  String get displayName {
    switch (this) {
      case QuizCategory.stateName:
        return 'State Name';
      case QuizCategory.capital:
        return 'Capitals';
      case QuizCategory.nickname:
        return 'Nicknames';
      case QuizCategory.sportsTeam:
        return 'Sports Teams';
      case QuizCategory.landmark:
        return 'Landmarks';
      case QuizCategory.flagDescription:
        return 'Flags';
      case QuizCategory.stateBird:
        return 'State Birds';
      case QuizCategory.stateFlower:
        return 'State Flowers';
      case QuizCategory.motto:
        return 'Mottos';
      case QuizCategory.celebrity:
        return 'Celebrities';
      case QuizCategory.filmSetting:
        return 'Film Settings';
      case QuizCategory.mixed:
        return 'Mixed';
    }
  }

  String get description {
    switch (this) {
      case QuizCategory.stateName:
        return 'Tap the named state on the map';
      case QuizCategory.capital:
        return 'Find the state from its capital city';
      case QuizCategory.nickname:
        return 'Match the nickname to the state';
      case QuizCategory.sportsTeam:
        return 'Which state has this team?';
      case QuizCategory.landmark:
        return 'Locate the famous landmark';
      case QuizCategory.flagDescription:
        return 'Identify the state from its flag';
      case QuizCategory.stateBird:
        return 'Which state has this bird?';
      case QuizCategory.stateFlower:
        return 'Which state has this flower?';
      case QuizCategory.motto:
        return 'Match the motto to the state';
      case QuizCategory.celebrity:
        return 'Where is this celebrity from?';
      case QuizCategory.filmSetting:
        return 'Where was this film/show set?';
      case QuizCategory.mixed:
        return 'A random mix of all categories';
    }
  }

  String get icon {
    switch (this) {
      case QuizCategory.stateName:
        return 'map';
      case QuizCategory.capital:
        return 'location_city';
      case QuizCategory.nickname:
        return 'label';
      case QuizCategory.sportsTeam:
        return 'sports_football';
      case QuizCategory.landmark:
        return 'landscape';
      case QuizCategory.flagDescription:
        return 'flag';
      case QuizCategory.stateBird:
        return 'flutter_dash';
      case QuizCategory.stateFlower:
        return 'local_florist';
      case QuizCategory.motto:
        return 'format_quote';
      case QuizCategory.celebrity:
        return 'star';
      case QuizCategory.filmSetting:
        return 'movie';
      case QuizCategory.mixed:
        return 'shuffle';
    }
  }
}

/// A single quiz question for the player to answer by tapping a state.
class QuizQuestion {
  const QuizQuestion({
    required this.category,
    required this.clueText,
    required this.answerCode,
    required this.answerName,
  });

  /// The category this question belongs to.
  final QuizCategory category;

  /// The clue text shown to the player (e.g. "The Golden State").
  final String clueText;

  /// The correct state code (e.g. 'CA').
  final String answerCode;

  /// The correct state name for display (e.g. 'California').
  final String answerName;
}

/// Generates quiz questions from existing state data.
class QuizQuestionGenerator {
  QuizQuestionGenerator({required this.region, int? seed})
      : _random = Random(seed);

  final GameRegion region;
  final Random _random;

  /// All non-mixed single categories.
  static const List<QuizCategory> _singleCategories = [
    QuizCategory.stateName,
    QuizCategory.capital,
    QuizCategory.nickname,
    QuizCategory.sportsTeam,
    QuizCategory.landmark,
    QuizCategory.flagDescription,
    QuizCategory.stateBird,
    QuizCategory.stateFlower,
    QuizCategory.motto,
    QuizCategory.celebrity,
    QuizCategory.filmSetting,
  ];

  /// Categories available for any region (name + capital).
  static const List<QuizCategory> _universalCategories = [
    QuizCategory.stateName,
    QuizCategory.capital,
  ];

  /// Generate a list of questions for the given category, covering all areas.
  List<QuizQuestion> generateQuestions(QuizCategory category) {
    final areas = RegionalData.getAreas(region);
    final questions = <QuizQuestion>[];

    for (final area in areas) {
      final question = _generateForArea(area, category);
      if (question != null) {
        questions.add(question);
      }
    }

    questions.shuffle(_random);
    return questions;
  }

  /// Whether this generator's region has rich US-specific clue data.
  bool get _hasRichClues => region == GameRegion.usStates;

  /// Generate a single question for an area in the given category.
  QuizQuestion? _generateForArea(RegionalArea area, QuizCategory category) {
    QuizCategory effectiveCategory;
    if (category == QuizCategory.mixed) {
      // For non-US regions, mixed only uses universal categories.
      final pool = _hasRichClues ? _singleCategories : _universalCategories;
      effectiveCategory = pool[_random.nextInt(pool.length)];
    } else {
      effectiveCategory = category;
    }

    switch (effectiveCategory) {
      case QuizCategory.stateName:
        return QuizQuestion(
          category: QuizCategory.stateName,
          clueText: 'Tap: ${area.name}',
          answerCode: area.code,
          answerName: area.name,
        );
      case QuizCategory.capital:
        if (area.capital == null || area.capital!.isEmpty) return null;
        return QuizQuestion(
          category: QuizCategory.capital,
          clueText: 'Capital: ${area.capital}',
          answerCode: area.code,
          answerName: area.name,
        );
      case QuizCategory.nickname:
        return _fromStateClueData(
          area,
          QuizCategory.nickname,
          (data) => data.nickname,
          (value) => 'Nickname: $value',
        );
      case QuizCategory.sportsTeam:
        return _fromStateClueDataList(
          area,
          QuizCategory.sportsTeam,
          (data) => data.sportsTeams,
          (value) => 'Team: $value',
        );
      case QuizCategory.landmark:
        return _fromStateClueData(
          area,
          QuizCategory.landmark,
          (data) => data.famousLandmark,
          (value) => 'Landmark: $value',
        );
      case QuizCategory.flagDescription:
        return _fromStateClueData(
          area,
          QuizCategory.flagDescription,
          (data) => data.flag,
          (value) => 'Flag: $value',
        );
      case QuizCategory.stateBird:
        return _fromStateClueData(
          area,
          QuizCategory.stateBird,
          (data) => data.stateBird,
          (value) => 'State Bird: $value',
        );
      case QuizCategory.stateFlower:
        return _fromStateClueData(
          area,
          QuizCategory.stateFlower,
          (data) => data.stateFlower,
          (value) => 'State Flower: $value',
        );
      case QuizCategory.motto:
        return _fromStateClueData(
          area,
          QuizCategory.motto,
          (data) => data.motto,
          (value) => 'Motto: "$value"',
        );
      case QuizCategory.celebrity:
        return _fromStateClueDataList(
          area,
          QuizCategory.celebrity,
          (data) => data.celebrities,
          (value) => 'Celebrity: $value',
        );
      case QuizCategory.filmSetting:
        return _fromStateClueDataList(
          area,
          QuizCategory.filmSetting,
          (data) => data.filmSettings,
          (value) => 'Film/Show: $value',
        );
      case QuizCategory.mixed:
        // Should not reach here — handled above
        return null;
    }
  }

  QuizQuestion? _fromStateClueData(
    RegionalArea area,
    QuizCategory category,
    String Function(StateClueData) getter,
    String Function(String) formatter,
  ) {
    final data = UsStateClues.data[area.code];
    if (data == null) return null;
    final value = getter(data);
    if (value.isEmpty) return null;
    return QuizQuestion(
      category: category,
      clueText: formatter(value),
      answerCode: area.code,
      answerName: area.name,
    );
  }

  QuizQuestion? _fromStateClueDataList(
    RegionalArea area,
    QuizCategory category,
    List<String> Function(StateClueData) getter,
    String Function(String) formatter,
  ) {
    final data = UsStateClues.data[area.code];
    if (data == null) return null;
    final values = getter(data);
    if (values.isEmpty) return null;
    final value = values[_random.nextInt(values.length)];
    return QuizQuestion(
      category: category,
      clueText: formatter(value),
      answerCode: area.code,
      answerName: area.name,
    );
  }
}
