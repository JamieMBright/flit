import 'dart:math';

import '../data/africa_clues.dart';
import '../data/asia_clues.dart';
import '../data/canada_clues.dart';
import '../data/caribbean_clues.dart';
import '../data/europe_clues.dart';
import '../data/ireland_clues.dart';
import '../data/latin_america_clues.dart';
import '../data/oceania_clues.dart';
import '../data/uk_clues.dart';
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
        return 'Name';
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
        return 'Famous People';
      case QuizCategory.filmSetting:
        return 'Film Settings';
      case QuizCategory.mixed:
        return 'All';
    }
  }

  String get description {
    switch (this) {
      case QuizCategory.stateName:
        return 'Tap the named area on the map';
      case QuizCategory.capital:
        return 'Find the area from its capital city';
      case QuizCategory.nickname:
        return 'Match the nickname to the area';
      case QuizCategory.sportsTeam:
        return 'Which area has this team?';
      case QuizCategory.landmark:
        return 'Locate the famous landmark';
      case QuizCategory.flagDescription:
        return 'Identify the area from its flag';
      case QuizCategory.stateBird:
        return 'Which state has this bird?';
      case QuizCategory.stateFlower:
        return 'Which state has this flower?';
      case QuizCategory.motto:
        return 'Match the motto to the area';
      case QuizCategory.celebrity:
        return 'Where is this person from?';
      case QuizCategory.filmSetting:
        return 'Where was this film/show set?';
      case QuizCategory.mixed:
        return 'Random mix of all available categories';
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

/// Non-mixed categories available for each region with rich clue data.
///
/// Regions not listed here only support [stateName] and [capital].
const Map<GameRegion, List<QuizCategory>> regionCategories = {
  GameRegion.usStates: [
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
  ],
  GameRegion.europe: [
    QuizCategory.stateName,
    QuizCategory.capital,
    QuizCategory.nickname,
    QuizCategory.landmark,
    QuizCategory.flagDescription,
    QuizCategory.sportsTeam,
    QuizCategory.celebrity,
    QuizCategory.motto,
  ],
  GameRegion.ireland: [
    QuizCategory.stateName,
    QuizCategory.capital,
    QuizCategory.nickname,
    QuizCategory.landmark,
    QuizCategory.sportsTeam,
    QuizCategory.celebrity,
    QuizCategory.flagDescription,
  ],
  GameRegion.ukCounties: [
    QuizCategory.stateName,
    QuizCategory.capital,
    QuizCategory.nickname,
    QuizCategory.landmark,
    QuizCategory.sportsTeam,
    QuizCategory.celebrity,
    QuizCategory.flagDescription,
  ],
  GameRegion.canadianProvinces: [
    QuizCategory.stateName,
    QuizCategory.capital,
    QuizCategory.nickname,
    QuizCategory.landmark,
    QuizCategory.sportsTeam,
    QuizCategory.flagDescription,
    QuizCategory.motto,
  ],
  GameRegion.africa: [
    QuizCategory.stateName,
    QuizCategory.capital,
    QuizCategory.nickname,
    QuizCategory.landmark,
    QuizCategory.flagDescription,
    QuizCategory.celebrity,
  ],
  GameRegion.asia: [
    QuizCategory.stateName,
    QuizCategory.capital,
    QuizCategory.nickname,
    QuizCategory.landmark,
    QuizCategory.flagDescription,
    QuizCategory.celebrity,
  ],
  GameRegion.latinAmerica: [
    QuizCategory.stateName,
    QuizCategory.capital,
    QuizCategory.nickname,
    QuizCategory.landmark,
    QuizCategory.flagDescription,
    QuizCategory.celebrity,
  ],
  GameRegion.oceania: [
    QuizCategory.stateName,
    QuizCategory.capital,
    QuizCategory.nickname,
    QuizCategory.landmark,
    QuizCategory.flagDescription,
    QuizCategory.celebrity,
  ],
  GameRegion.caribbean: [
    QuizCategory.stateName,
    QuizCategory.capital,
    QuizCategory.nickname,
    QuizCategory.landmark,
    QuizCategory.flagDescription,
    QuizCategory.celebrity,
  ],
};

/// Categories available for any region (name + capital).
const List<QuizCategory> universalCategories = [
  QuizCategory.stateName,
  QuizCategory.capital,
];

/// Generates quiz questions from regional clue data.
class QuizQuestionGenerator {
  QuizQuestionGenerator({required this.region, int? seed})
      : _random = Random(seed);

  final GameRegion region;
  final Random _random;

  /// Non-mixed categories available for this region.
  List<QuizCategory> get _pool =>
      regionCategories[region] ?? universalCategories;

  /// Generate a list of questions for the given categories, covering all areas.
  ///
  /// When [categories] contains a single non-mixed category, all questions use
  /// that category. When it contains multiple categories, each question picks
  /// randomly from the set. When it contains [QuizCategory.mixed], it picks
  /// from [allowedPool] if provided, otherwise from all available categories
  /// for the region.
  List<QuizQuestion> generateQuestions(
    Set<QuizCategory> categories, {
    List<QuizCategory>? allowedPool,
  }) {
    final areas = RegionalData.getAreas(region);
    final questions = <QuizQuestion>[];

    for (final area in areas) {
      final question = _generateForArea(area, categories, allowedPool);
      if (question != null) {
        questions.add(question);
      }
    }

    questions.shuffle(_random);
    return questions;
  }

  /// Generate a single question for an area from the given category set.
  QuizQuestion? _generateForArea(
    RegionalArea area,
    Set<QuizCategory> categories,
    List<QuizCategory>? allowedPool,
  ) {
    QuizCategory effectiveCategory;
    if (categories.contains(QuizCategory.mixed)) {
      // "All" — pick from the allowed pool (difficulty-filtered) or region pool.
      final pool = allowedPool ?? _pool;
      // Exclude 'mixed' itself from the pool to avoid recursion.
      final candidates = pool.where((c) => c != QuizCategory.mixed).toList();
      if (candidates.isEmpty) return null;
      effectiveCategory = candidates[_random.nextInt(candidates.length)];
    } else if (categories.length == 1) {
      effectiveCategory = categories.first;
    } else {
      // Multi-select — pick randomly from the selected subset.
      final list = categories.toList();
      effectiveCategory = list[_random.nextInt(list.length)];
    }

    switch (effectiveCategory) {
      case QuizCategory.stateName:
        return QuizQuestion(
          category: QuizCategory.stateName,
          clueText: area.name,
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
        return _generateNickname(area);
      case QuizCategory.sportsTeam:
        return _generateSportsTeam(area);
      case QuizCategory.landmark:
        return _generateLandmark(area);
      case QuizCategory.flagDescription:
        return _generateFlag(area);
      case QuizCategory.stateBird:
        final bird = _usField(area.code, 'stateBird');
        if (bird == null) return null;
        return QuizQuestion(
          category: QuizCategory.stateBird,
          clueText: 'State Bird: $bird',
          answerCode: area.code,
          answerName: area.name,
        );
      case QuizCategory.stateFlower:
        final flower = _usField(area.code, 'stateFlower');
        if (flower == null) return null;
        return QuizQuestion(
          category: QuizCategory.stateFlower,
          clueText: 'State Flower: $flower',
          answerCode: area.code,
          answerName: area.name,
        );
      case QuizCategory.motto:
        return _generateMotto(area);
      case QuizCategory.celebrity:
        return _generateCelebrity(area);
      case QuizCategory.filmSetting:
        final film = _usField(area.code, 'filmSetting');
        if (film == null) return null;
        return QuizQuestion(
          category: QuizCategory.filmSetting,
          clueText: 'Film/Show: $film',
          answerCode: area.code,
          answerName: area.name,
        );
      case QuizCategory.mixed:
        return null;
    }
  }

  // ── Multi-region category generators ───────────────────────────────────

  QuizQuestion? _generateNickname(RegionalArea area) {
    final value = _getRegionalString(area.code, 'nickname');
    if (value == null) return null;
    return QuizQuestion(
      category: QuizCategory.nickname,
      clueText: 'Nickname: $value',
      answerCode: area.code,
      answerName: area.name,
    );
  }

  QuizQuestion? _generateLandmark(RegionalArea area) {
    final value = _getRegionalString(area.code, 'landmark');
    if (value == null) return null;
    return QuizQuestion(
      category: QuizCategory.landmark,
      clueText: 'Landmark: $value',
      answerCode: area.code,
      answerName: area.name,
    );
  }

  QuizQuestion? _generateSportsTeam(RegionalArea area) {
    final value = _getRegionalString(area.code, 'sportsTeam');
    if (value == null) return null;
    final prefix = region == GameRegion.ireland
        ? 'GAA Team'
        : region == GameRegion.ukCounties
            ? 'Football'
            : 'Team';
    return QuizQuestion(
      category: QuizCategory.sportsTeam,
      clueText: '$prefix: $value',
      answerCode: area.code,
      answerName: area.name,
    );
  }

  QuizQuestion? _generateCelebrity(RegionalArea area) {
    final value = _getRegionalString(area.code, 'celebrity');
    if (value == null) return null;
    return QuizQuestion(
      category: QuizCategory.celebrity,
      clueText: 'Famous Person: $value',
      answerCode: area.code,
      answerName: area.name,
    );
  }

  QuizQuestion? _generateFlag(RegionalArea area) {
    final value = _getRegionalString(area.code, 'flag');
    if (value == null) return null;
    return QuizQuestion(
      category: QuizCategory.flagDescription,
      clueText: 'Flag: $value',
      answerCode: area.code,
      answerName: area.name,
    );
  }

  QuizQuestion? _generateMotto(RegionalArea area) {
    final value = _getRegionalString(area.code, 'motto');
    if (value == null) return null;
    return QuizQuestion(
      category: QuizCategory.motto,
      clueText: 'Motto: "$value"',
      answerCode: area.code,
      answerName: area.name,
    );
  }

  // ── Generic regional data lookup ───────────────────────────────────────

  /// Look up a string clue value for [areaCode] from the region's data source.
  ///
  /// [field] is a logical field name: nickname, landmark, celebrity, flag,
  /// motto, sportsTeam.
  String? _getRegionalString(String areaCode, String field) {
    switch (region) {
      case GameRegion.usStates:
        return _usField(areaCode, field);
      case GameRegion.ireland:
        return _irelandField(areaCode, field);
      case GameRegion.ukCounties:
        return _ukField(areaCode, field);
      case GameRegion.canadianProvinces:
        return _canadaField(areaCode, field);
      case GameRegion.europe:
        return _europeField(areaCode, field);
      case GameRegion.africa:
        return _africaField(areaCode, field);
      case GameRegion.asia:
        return _asiaField(areaCode, field);
      case GameRegion.latinAmerica:
        return _latinAmericaField(areaCode, field);
      case GameRegion.oceania:
        return _oceaniaField(areaCode, field);
      case GameRegion.caribbean:
        return _caribbeanField(areaCode, field);
      case GameRegion.world:
        return null;
    }
  }

  String? _nonEmpty(String? v) => (v != null && v.isNotEmpty) ? v : null;

  // ── US ─────────────────────────────────────────────────────────────────

  String? _usField(String code, String field) {
    final d = UsStateClues.data[code];
    if (d == null) return null;
    switch (field) {
      case 'nickname':
        return _nonEmpty(d.nickname);
      case 'landmark':
        return _nonEmpty(d.famousLandmark);
      case 'flag':
        return _nonEmpty(d.flag);
      case 'motto':
        return _nonEmpty(d.motto);
      case 'stateBird':
        return _nonEmpty(d.stateBird);
      case 'stateFlower':
        return _nonEmpty(d.stateFlower);
      case 'sportsTeam':
        return d.sportsTeams.isNotEmpty
            ? d.sportsTeams[_random.nextInt(d.sportsTeams.length)]
            : null;
      case 'celebrity':
        return d.celebrities.isNotEmpty
            ? d.celebrities[_random.nextInt(d.celebrities.length)]
            : null;
      case 'filmSetting':
        return d.filmSettings.isNotEmpty
            ? d.filmSettings[_random.nextInt(d.filmSettings.length)]
            : null;
      default:
        return null;
    }
  }

  // ── Ireland ────────────────────────────────────────────────────────────

  String? _irelandField(String code, String field) {
    final d = IrelandClues.data[code];
    if (d == null) return null;
    switch (field) {
      case 'nickname':
        return _nonEmpty(d.nickname);
      case 'landmark':
        return _nonEmpty(d.famousLandmark);
      case 'celebrity':
        return _nonEmpty(d.famousPerson);
      case 'sportsTeam':
        return _nonEmpty(d.gaaTeam);
      case 'flag':
        return _nonEmpty(d.flag);
      default:
        return null;
    }
  }

  // ── UK ─────────────────────────────────────────────────────────────────

  String? _ukField(String code, String field) {
    final d = UkClues.data[code];
    if (d == null) return null;
    switch (field) {
      case 'nickname':
        return _nonEmpty(d.nickname);
      case 'landmark':
        return _nonEmpty(d.famousLandmark);
      case 'celebrity':
        return _nonEmpty(d.famousPerson);
      case 'sportsTeam':
        return _nonEmpty(d.footballTeam);
      case 'flag':
        return _nonEmpty(d.flag);
      default:
        return null;
    }
  }

  // ── Canada ─────────────────────────────────────────────────────────────

  String? _canadaField(String code, String field) {
    final d = CanadaClues.data[code];
    if (d == null) return null;
    switch (field) {
      case 'nickname':
        return _nonEmpty(d.nickname);
      case 'landmark':
        return _nonEmpty(d.famousLandmark);
      case 'flag':
        return _nonEmpty(d.flag);
      case 'motto':
        return _nonEmpty(d.motto);
      case 'sportsTeam':
        return d.sportsTeams.isNotEmpty
            ? d.sportsTeams[_random.nextInt(d.sportsTeams.length)]
            : null;
      default:
        return null;
    }
  }

  // ── Europe ─────────────────────────────────────────────────────────────

  String? _europeField(String code, String field) {
    final d = EuropeClues.data[code];
    if (d == null) return null;
    switch (field) {
      case 'nickname':
        return _nonEmpty(d.nickname);
      case 'landmark':
        return _nonEmpty(d.famousLandmark);
      case 'celebrity':
        return _nonEmpty(d.famousPerson);
      case 'flag':
        return _nonEmpty(d.flag);
      case 'motto':
        return _nonEmpty(d.motto);
      case 'sportsTeam':
        return _nonEmpty(d.footballTeam);
      default:
        return null;
    }
  }

  // ── Africa ─────────────────────────────────────────────────────────────

  String? _africaField(String code, String field) {
    final d = AfricaClues.data[code];
    if (d == null) return null;
    switch (field) {
      case 'nickname':
        return _nonEmpty(d.nickname);
      case 'landmark':
        return _nonEmpty(d.famousLandmark);
      case 'celebrity':
        return _nonEmpty(d.famousPerson);
      case 'flag':
        return _nonEmpty(d.flag);
      default:
        return null;
    }
  }

  // ── Asia ───────────────────────────────────────────────────────────────

  String? _asiaField(String code, String field) {
    final d = AsiaClues.data[code];
    if (d == null) return null;
    switch (field) {
      case 'nickname':
        return _nonEmpty(d.nickname);
      case 'landmark':
        return _nonEmpty(d.famousLandmark);
      case 'celebrity':
        return _nonEmpty(d.famousPerson);
      case 'flag':
        return _nonEmpty(d.flag);
      default:
        return null;
    }
  }

  // ── Latin America ──────────────────────────────────────────────────────

  String? _latinAmericaField(String code, String field) {
    final d = LatinAmericaClues.data[code];
    if (d == null) return null;
    switch (field) {
      case 'nickname':
        return _nonEmpty(d.nickname);
      case 'landmark':
        return _nonEmpty(d.famousLandmark);
      case 'celebrity':
        return _nonEmpty(d.famousPerson);
      case 'flag':
        return _nonEmpty(d.flag);
      default:
        return null;
    }
  }

  // ── Oceania ────────────────────────────────────────────────────────────

  String? _oceaniaField(String code, String field) {
    final d = OceaniaClues.data[code];
    if (d == null) return null;
    switch (field) {
      case 'nickname':
        return _nonEmpty(d.nickname);
      case 'landmark':
        return _nonEmpty(d.famousLandmark);
      case 'celebrity':
        return _nonEmpty(d.famousPerson);
      case 'flag':
        return _nonEmpty(d.flag);
      default:
        return null;
    }
  }

  // ── Caribbean ──────────────────────────────────────────────────────────

  String? _caribbeanField(String code, String field) {
    final d = CaribbeanClues.data[code];
    if (d == null) return null;
    switch (field) {
      case 'nickname':
        return _nonEmpty(d.nickname);
      case 'landmark':
        return _nonEmpty(d.famousLandmark);
      case 'celebrity':
        return _nonEmpty(d.famousPerson);
      case 'flag':
        return _nonEmpty(d.flag);
      default:
        return null;
    }
  }
}
