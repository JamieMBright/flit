import '../map/region.dart';
import 'quiz_category.dart';

/// A single Flight School level representing a geographic region to quiz on.
class FlightSchoolLevel {
  const FlightSchoolLevel({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.region,
    required this.requiredLevel,
    required this.areaCount,
    required this.icon,
    required this.availableCategories,
    this.unlockCost = 0,
  });

  final String id;
  final String name;
  final String subtitle;
  final GameRegion region;

  /// Minimum player level required. 0 = no level requirement (pay-only).
  final int requiredLevel;
  final int areaCount;
  final String icon;
  final List<QuizCategory> availableCategories;

  /// Coin cost to unlock early (before reaching requiredLevel).
  /// 0 means no early unlock available (level-gated only).
  final int unlockCost;

  /// Whether this level supports rich US-specific categories.
  bool get hasRichClues => region == GameRegion.usStates;

  /// Whether this level quizzes sovereign countries (vs sub-national
  /// divisions like US states or French régions). The Daily Briefing draws
  /// ONLY from country-level regions so a daily can never ask for a US state;
  /// sub-national levels stay available in Flight School practice.
  bool get isCountryLevel => const {
        GameRegion.europe,
        GameRegion.africa,
        GameRegion.asia,
        GameRegion.latinAmerica,
        GameRegion.oceania,
        GameRegion.caribbean,
      }.contains(region);
}

/// Progress data for a single flight school level.
class FlightSchoolProgress {
  const FlightSchoolProgress({
    this.bestScore = 0,
    this.bestTimeMs = 0,
    this.completions = 0,
    this.attempts = 0,
  });

  final int bestScore;
  final int bestTimeMs;
  final int completions;
  final int attempts;

  String get grade => computeGrade(bestScore, completions, attempts);

  bool get hasPlayed => attempts > 0;

  String get bestTimeFormatted {
    if (bestTimeMs <= 0) return '--';
    final seconds = (bestTimeMs / 1000).floor();
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  double get completionRate => attempts > 0 ? completions / attempts : 0;

  /// Coin reward for the next completion.
  ///
  /// First completion: full reward (50 coins).
  /// Subsequent completions: diminishing returns.
  int coinRewardForCompletion(int baseCoinReward) {
    if (completions == 0) return baseCoinReward;
    if (completions < 3) return (baseCoinReward * 0.5).round();
    if (completions < 10) return (baseCoinReward * 0.25).round();
    return (baseCoinReward * 0.1).round(); // Minimal reward after 10+
  }

  FlightSchoolProgress copyWith({
    int? bestScore,
    int? bestTimeMs,
    int? completions,
    int? attempts,
  }) =>
      FlightSchoolProgress(
        bestScore: bestScore ?? this.bestScore,
        bestTimeMs: bestTimeMs ?? this.bestTimeMs,
        completions: completions ?? this.completions,
        attempts: attempts ?? this.attempts,
      );

  Map<String, dynamic> toJson() => {
        'best_score': bestScore,
        'best_time_ms': bestTimeMs,
        'completions': completions,
        'attempts': attempts,
      };

  factory FlightSchoolProgress.fromJson(Map<String, dynamic> json) =>
      FlightSchoolProgress(
        bestScore: json['best_score'] as int? ?? 0,
        bestTimeMs: json['best_time_ms'] as int? ?? 0,
        completions: json['completions'] as int? ?? 0,
        attempts: json['attempts'] as int? ?? 0,
      );

  /// Compute an aviation grade based on score, completions, and attempts.
  static String computeGrade(int bestScore, int completions, int attempts) {
    if (attempts == 0) return '-';
    if (completions == 0) return 'F';

    final rate = completions / attempts;

    if (rate >= 0.95 && bestScore >= 50000) return 'S';
    if (rate >= 0.90 || bestScore >= 40000) return 'A';
    if (rate >= 0.75 || bestScore >= 30000) return 'B';
    if (rate >= 0.50 || bestScore >= 20000) return 'C';
    return 'D';
  }

  static String gradeTitle(String grade) {
    switch (grade) {
      case 'S':
        return 'Captain';
      case 'A':
        return 'First Officer';
      case 'B':
        return 'Flight Engineer';
      case 'C':
        return 'Navigator';
      case 'D':
        return 'Cadet';
      case 'F':
        return 'Grounded';
      default:
        return 'Unranked';
    }
  }
}

/// All available flight school levels in unlock order.
///
/// Levels with unlockCost > 0 can be purchased early with coins.
/// Levels with requiredLevel > 0 unlock automatically at that level.
/// Some levels are both level-gated AND purchasable early.
const List<FlightSchoolLevel> flightSchoolLevels = [
  // ── Tier 1: Starter (free / low level) ──
  FlightSchoolLevel(
    id: 'europe',
    name: 'Europe',
    subtitle: '47 Countries',
    region: GameRegion.europe,
    requiredLevel: 1,
    areaCount: 47,
    icon: 'castle',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.nickname,
      QuizCategory.landmark,
      QuizCategory.flagDescription,
      QuizCategory.sportsTeam,
      QuizCategory.celebrity,
      QuizCategory.motto,
      QuizCategory.mixed,
    ],
  ),

  // ── Tier 2: Purchasable early ──
  // The newer sub-national regions (Australia, France, Germany, Japan,
  // Spain, Italy, Brazil, India, New Zealand) quiz on the universal
  // categories only — name + capital — because their clue data lives
  // directly on RegionalArea with no per-division trivia files.
  FlightSchoolLevel(
    id: 'australia',
    name: 'Australia',
    subtitle: 'States & Territories',
    region: GameRegion.australia,
    requiredLevel: 3,
    unlockCost: 300,
    areaCount: 8,
    icon: 'wb_sunny',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.mixed,
    ],
  ),
  FlightSchoolLevel(
    id: 'france',
    name: 'France',
    subtitle: '13 Régions',
    region: GameRegion.france,
    requiredLevel: 4,
    unlockCost: 300,
    areaCount: 13,
    icon: 'wine_bar',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.mixed,
    ],
  ),
  FlightSchoolLevel(
    id: 'mexico',
    name: 'Mexico',
    subtitle: '32 Estados',
    region: GameRegion.mexico,
    requiredLevel: 5,
    unlockCost: 300,
    areaCount: 32,
    icon: 'local_fire_department',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.mixed,
    ],
  ),
  FlightSchoolLevel(
    id: 'netherlands',
    name: 'Netherlands',
    subtitle: '12 Provinces',
    region: GameRegion.netherlands,
    requiredLevel: 6,
    unlockCost: 500,
    areaCount: 12,
    icon: 'wind_power',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.mixed,
    ],
  ),
  FlightSchoolLevel(
    id: 'us_states',
    name: 'United States',
    subtitle: '50 States',
    region: GameRegion.usStates,
    requiredLevel: 5,
    unlockCost: 500,
    areaCount: 50,
    icon: 'flag',
    availableCategories: QuizCategory.values,
  ),
  FlightSchoolLevel(
    id: 'africa',
    name: 'Africa',
    subtitle: '55 Countries',
    region: GameRegion.africa,
    requiredLevel: 7,
    unlockCost: 500,
    areaCount: 55,
    icon: 'terrain',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.nickname,
      QuizCategory.landmark,
      QuizCategory.flagDescription,
      QuizCategory.celebrity,
      QuizCategory.mixed,
    ],
  ),

  FlightSchoolLevel(
    id: 'germany',
    name: 'Germany',
    subtitle: '16 Länder',
    region: GameRegion.germany,
    requiredLevel: 6,
    unlockCost: 500,
    areaCount: 16,
    icon: 'account_balance',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.mixed,
    ],
  ),
  FlightSchoolLevel(
    id: 'spain',
    name: 'Spain',
    subtitle: 'Autonomous Communities',
    region: GameRegion.spain,
    requiredLevel: 8,
    unlockCost: 500,
    areaCount: 16,
    icon: 'festival',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.mixed,
    ],
  ),
  FlightSchoolLevel(
    id: 'italy',
    name: 'Italy',
    subtitle: '20 Regions',
    region: GameRegion.italy,
    requiredLevel: 8,
    unlockCost: 500,
    areaCount: 20,
    icon: 'museum',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.mixed,
    ],
  ),

  // ── Tier 3: Mid-level ──
  FlightSchoolLevel(
    id: 'asia',
    name: 'Asia',
    subtitle: '47 Countries',
    region: GameRegion.asia,
    requiredLevel: 9,
    unlockCost: 750,
    areaCount: 47,
    icon: 'temple_buddhist',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.nickname,
      QuizCategory.landmark,
      QuizCategory.flagDescription,
      QuizCategory.celebrity,
      QuizCategory.mixed,
    ],
  ),
  FlightSchoolLevel(
    id: 'south_korea',
    name: 'South Korea',
    subtitle: 'Provinces & Cities',
    region: GameRegion.southKorea,
    requiredLevel: 9,
    unlockCost: 500,
    areaCount: 17,
    icon: 'location_city',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.mixed,
    ],
  ),
  FlightSchoolLevel(
    id: 'poland',
    name: 'Poland',
    subtitle: '16 Voivodeships',
    region: GameRegion.poland,
    requiredLevel: 10,
    unlockCost: 500,
    areaCount: 16,
    icon: 'church',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.mixed,
    ],
  ),
  FlightSchoolLevel(
    id: 'switzerland',
    name: 'Switzerland',
    subtitle: '26 Cantons',
    region: GameRegion.switzerland,
    requiredLevel: 11,
    unlockCost: 750,
    areaCount: 26,
    icon: 'downhill_skiing',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.mixed,
    ],
  ),
  FlightSchoolLevel(
    id: 'austria',
    name: 'Austria',
    subtitle: '9 Länder',
    region: GameRegion.austria,
    requiredLevel: 12,
    unlockCost: 750,
    areaCount: 9,
    icon: 'piano',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.mixed,
    ],
  ),
  FlightSchoolLevel(
    id: 'latin_america',
    name: 'Latin America',
    subtitle: '26 Countries',
    region: GameRegion.latinAmerica,
    requiredLevel: 11,
    unlockCost: 750,
    areaCount: 26,
    icon: 'festival',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.nickname,
      QuizCategory.landmark,
      QuizCategory.flagDescription,
      QuizCategory.celebrity,
      QuizCategory.mixed,
    ],
  ),

  FlightSchoolLevel(
    id: 'japan',
    name: 'Japan',
    subtitle: '47 Prefectures',
    region: GameRegion.japan,
    requiredLevel: 12,
    unlockCost: 750,
    areaCount: 47,
    icon: 'temple_buddhist',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.mixed,
    ],
  ),
  FlightSchoolLevel(
    id: 'portugal',
    name: 'Portugal',
    subtitle: '18 Districts',
    region: GameRegion.portugal,
    requiredLevel: 13,
    unlockCost: 750,
    areaCount: 18,
    icon: 'sailing',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.mixed,
    ],
  ),
  FlightSchoolLevel(
    id: 'greece',
    name: 'Greece',
    subtitle: '13 Regions',
    region: GameRegion.greece,
    requiredLevel: 14,
    unlockCost: 750,
    areaCount: 13,
    icon: 'account_balance',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.mixed,
    ],
  ),

  // ── Tier 4: Advanced (higher level or purchase) ──
  FlightSchoolLevel(
    id: 'brazil',
    name: 'Brazil',
    subtitle: '27 States',
    region: GameRegion.brazil,
    requiredLevel: 14,
    unlockCost: 1000,
    areaCount: 27,
    icon: 'forest',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.mixed,
    ],
  ),
  FlightSchoolLevel(
    id: 'uk_counties',
    name: 'United Kingdom',
    subtitle: 'Counties',
    region: GameRegion.ukCounties,
    requiredLevel: 13,
    unlockCost: 1000,
    areaCount: 107,
    icon: 'castle',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.nickname,
      QuizCategory.landmark,
      QuizCategory.sportsTeam,
      QuizCategory.celebrity,
      QuizCategory.flagDescription,
      QuizCategory.mixed,
    ],
  ),
  FlightSchoolLevel(
    id: 'ireland',
    name: 'Ireland',
    subtitle: '32 Counties',
    region: GameRegion.ireland,
    requiredLevel: 15,
    unlockCost: 1000,
    areaCount: 32,
    icon: 'grass',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.nickname,
      QuizCategory.landmark,
      QuizCategory.sportsTeam,
      QuizCategory.celebrity,
      QuizCategory.flagDescription,
      QuizCategory.mixed,
    ],
  ),
  FlightSchoolLevel(
    id: 'canada',
    name: 'Canada',
    subtitle: 'Provinces & Territories',
    region: GameRegion.canadianProvinces,
    requiredLevel: 17,
    unlockCost: 1500,
    areaCount: 13,
    icon: 'landscape',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.nickname,
      QuizCategory.landmark,
      QuizCategory.sportsTeam,
      QuizCategory.flagDescription,
      QuizCategory.motto,
      QuizCategory.mixed,
    ],
  ),

  FlightSchoolLevel(
    id: 'india',
    name: 'India',
    subtitle: 'States & Territories',
    region: GameRegion.india,
    requiredLevel: 16,
    unlockCost: 1000,
    areaCount: 34,
    icon: 'temple_hindu',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.mixed,
    ],
  ),
  FlightSchoolLevel(
    id: 'sweden',
    name: 'Sweden',
    subtitle: '21 Counties',
    region: GameRegion.sweden,
    requiredLevel: 15,
    unlockCost: 1000,
    areaCount: 21,
    icon: 'ac_unit',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.mixed,
    ],
  ),
  FlightSchoolLevel(
    id: 'argentina',
    name: 'Argentina',
    subtitle: '24 Provinces',
    region: GameRegion.argentina,
    requiredLevel: 16,
    unlockCost: 1000,
    areaCount: 24,
    icon: 'sports_soccer',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.mixed,
    ],
  ),
  FlightSchoolLevel(
    id: 'south_africa',
    name: 'South Africa',
    subtitle: '9 Provinces',
    region: GameRegion.southAfrica,
    requiredLevel: 17,
    unlockCost: 1000,
    areaCount: 9,
    icon: 'pets',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.mixed,
    ],
  ),

  // ── Tier 5: Expert ──
  FlightSchoolLevel(
    id: 'new_zealand',
    name: 'New Zealand',
    subtitle: '16 Regions',
    region: GameRegion.newZealand,
    requiredLevel: 18,
    unlockCost: 1500,
    areaCount: 16,
    icon: 'landscape',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.mixed,
    ],
  ),
  FlightSchoolLevel(
    id: 'indonesia',
    name: 'Indonesia',
    subtitle: '33 Provinces',
    region: GameRegion.indonesia,
    requiredLevel: 19,
    unlockCost: 1500,
    areaCount: 33,
    icon: 'waves',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.mixed,
    ],
  ),
  FlightSchoolLevel(
    id: 'oceania',
    name: 'Oceania',
    subtitle: '14 Countries',
    region: GameRegion.oceania,
    requiredLevel: 19,
    unlockCost: 2000,
    areaCount: 14,
    icon: 'beach_access',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.nickname,
      QuizCategory.landmark,
      QuizCategory.flagDescription,
      QuizCategory.celebrity,
      QuizCategory.mixed,
    ],
  ),
  FlightSchoolLevel(
    id: 'caribbean',
    name: 'Caribbean',
    subtitle: 'Island Nations',
    region: GameRegion.caribbean,
    requiredLevel: 20,
    unlockCost: 2000,
    areaCount: 28,
    icon: 'beach_access',
    availableCategories: [
      QuizCategory.stateName,
      QuizCategory.capital,
      QuizCategory.nickname,
      QuizCategory.landmark,
      QuizCategory.flagDescription,
      QuizCategory.celebrity,
      QuizCategory.mixed,
    ],
  ),
];
