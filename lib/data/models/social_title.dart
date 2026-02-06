import 'cosmetic.dart';

/// Categories of social titles a player can earn through gameplay.
enum TitleCategory {
  flag,
  capital,
  outline,
  borders,
  stats,
  general,
  speed,
  streak,
}

/// A social title earned through gameplay milestones.
///
/// Titles are never purchased -- they are awarded when a player meets the
/// [threshold] for a given [category]. Each title carries a [rarity] tier
/// that controls how it is displayed on profiles and in friend lists.
class SocialTitle {
  const SocialTitle({
    required this.id,
    required this.name,
    required this.category,
    required this.threshold,
    required this.description,
    required this.rarity,
  });

  /// Unique identifier for this title.
  final String id;

  /// Display name shown on the player's profile and to friends.
  final String name;

  /// Which category this title belongs to.
  final TitleCategory category;

  /// The numeric milestone a player must reach to earn this title.
  ///
  /// For count-based categories this is the number of correct answers.
  /// For speed titles this is the time in seconds the player must beat.
  /// For streak titles this is the consecutive-correct count required.
  final int threshold;

  /// Flavour text describing the title.
  final String description;

  /// Visual rarity tier used for UI presentation (glow, colour, badge frame).
  final CosmeticRarity rarity;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'threshold': threshold,
        'description': description,
        'rarity': rarity.name,
      };

  factory SocialTitle.fromJson(Map<String, dynamic> json) => SocialTitle(
        id: json['id'] as String,
        name: json['name'] as String,
        category: TitleCategory.values.firstWhere(
          (c) => c.name == json['category'],
        ),
        threshold: json['threshold'] as int,
        description: json['description'] as String,
        rarity: CosmeticRarity.values.firstWhere(
          (r) => r.name == json['rarity'],
          orElse: () => CosmeticRarity.common,
        ),
      );
}

/// Lightweight progress snapshot used by [PlayerTitles.earnedTitles] to
/// determine which titles a player qualifies for.
///
/// Each field maps directly to a [TitleCategory]. For speed and streak the
/// values represent best-ever records rather than cumulative totals.
class PlayerClueProgress {
  const PlayerClueProgress({
    this.flagsCorrect = 0,
    this.capitalsCorrect = 0,
    this.outlinesCorrect = 0,
    this.bordersCorrect = 0,
    this.statsCorrect = 0,
    this.totalGamesPlayed = 0,
    this.bestTimeSeconds = 0,
    this.bestStreak = 0,
  });

  /// Total flag clues answered correctly.
  final int flagsCorrect;

  /// Total capital-city clues answered correctly.
  final int capitalsCorrect;

  /// Total country-outline clues answered correctly.
  final int outlinesCorrect;

  /// Total border/neighbour clues answered correctly.
  final int bordersCorrect;

  /// Total stats/data clues answered correctly.
  final int statsCorrect;

  /// Lifetime games played.
  final int totalGamesPlayed;

  /// Personal best round time in seconds (lower is better).
  /// A value of 0 means no time has been recorded yet.
  final int bestTimeSeconds;

  /// Longest streak of consecutive correct answers ever achieved.
  final int bestStreak;

  Map<String, dynamic> toJson() => {
        'flags_correct': flagsCorrect,
        'capitals_correct': capitalsCorrect,
        'outlines_correct': outlinesCorrect,
        'borders_correct': bordersCorrect,
        'stats_correct': statsCorrect,
        'total_games_played': totalGamesPlayed,
        'best_time_seconds': bestTimeSeconds,
        'best_streak': bestStreak,
      };

  factory PlayerClueProgress.fromJson(Map<String, dynamic> json) =>
      PlayerClueProgress(
        flagsCorrect: json['flags_correct'] as int? ?? 0,
        capitalsCorrect: json['capitals_correct'] as int? ?? 0,
        outlinesCorrect: json['outlines_correct'] as int? ?? 0,
        bordersCorrect: json['borders_correct'] as int? ?? 0,
        statsCorrect: json['stats_correct'] as int? ?? 0,
        totalGamesPlayed: json['total_games_played'] as int? ?? 0,
        bestTimeSeconds: json['best_time_seconds'] as int? ?? 0,
        bestStreak: json['best_streak'] as int? ?? 0,
      );
}

/// Tracks a player's earned titles and which one is currently displayed.
///
/// [activeTitleId] is the id of the [SocialTitle] the player has chosen to
/// show on their profile and in friend lists. It must reference a title that
/// appears in the earned set, or be `null` if no title is selected.
class PlayerTitles {
  const PlayerTitles({
    this.activeTitleId,
  });

  /// The [SocialTitle.id] currently displayed on the player's profile.
  /// `null` means no title is shown.
  final String? activeTitleId;

  /// Returns every [SocialTitle] the player has unlocked based on [progress].
  ///
  /// Count-based categories use a >= comparison. Speed titles use a
  /// strictly-less-than comparison (the player's best time must be below
  /// the threshold). A [bestTimeSeconds] of 0 means no time has been
  /// recorded and no speed titles are earned.
  List<SocialTitle> earnedTitles(PlayerClueProgress progress) {
    return SocialTitleCatalog.all.where((title) {
      switch (title.category) {
        case TitleCategory.flag:
          return progress.flagsCorrect >= title.threshold;
        case TitleCategory.capital:
          return progress.capitalsCorrect >= title.threshold;
        case TitleCategory.outline:
          return progress.outlinesCorrect >= title.threshold;
        case TitleCategory.borders:
          return progress.bordersCorrect >= title.threshold;
        case TitleCategory.stats:
          return progress.statsCorrect >= title.threshold;
        case TitleCategory.general:
          return progress.totalGamesPlayed >= title.threshold;
        case TitleCategory.speed:
          return progress.bestTimeSeconds > 0 &&
              progress.bestTimeSeconds < title.threshold;
        case TitleCategory.streak:
          return progress.bestStreak >= title.threshold;
      }
    }).toList();
  }

  /// The currently active [SocialTitle], resolved from the catalog.
  /// Returns `null` when [activeTitleId] is unset or references an
  /// unknown title.
  SocialTitle? get activeTitle {
    if (activeTitleId == null) return null;
    return SocialTitleCatalog.getById(activeTitleId!);
  }

  /// Returns `true` when the [activeTitleId] is present in the set of
  /// titles earned by [progress]. Always returns `true` when no title is
  /// selected.
  bool isActiveTitleValid(PlayerClueProgress progress) {
    if (activeTitleId == null) return true;
    return earnedTitles(progress).any((t) => t.id == activeTitleId);
  }

  PlayerTitles copyWith({
    String? activeTitleId,
  }) =>
      PlayerTitles(
        activeTitleId: activeTitleId ?? this.activeTitleId,
      );

  /// Creates a copy with no active title.
  PlayerTitles clearActiveTitle() => const PlayerTitles(activeTitleId: null);

  Map<String, dynamic> toJson() => {
        'active_title_id': activeTitleId,
      };

  factory PlayerTitles.fromJson(Map<String, dynamic> json) => PlayerTitles(
        activeTitleId: json['active_title_id'] as String?,
      );
}

/// Master catalog of every earnable social title in the game.
///
/// Titles are organised by [TitleCategory] and ordered by ascending
/// [threshold] within each category. Rarity tiers roughly map to the
/// difficulty of reaching each threshold.
abstract class SocialTitleCatalog {
  // ---------------------------------------------------------------------------
  // Flag (Vexillology)
  // ---------------------------------------------------------------------------
  static const List<SocialTitle> _flag = [
    SocialTitle(
      id: 'flag_spotter',
      name: 'Flag Spotter',
      category: TitleCategory.flag,
      threshold: 10,
      description: 'Taking the first steps into the world of flags.',
      rarity: CosmeticRarity.common,
    ),
    SocialTitle(
      id: 'flag_enthusiast',
      name: 'Flag Enthusiast',
      category: TitleCategory.flag,
      threshold: 50,
      description: 'A growing passion for world flags.',
      rarity: CosmeticRarity.common,
    ),
    SocialTitle(
      id: 'flag_novice_vexillologist',
      name: 'Novice Vexillologist',
      category: TitleCategory.flag,
      threshold: 100,
      description: 'No flag escapes your keen eye.',
      rarity: CosmeticRarity.rare,
    ),
    SocialTitle(
      id: 'flag_vexillologist',
      name: 'Vexillologist',
      category: TitleCategory.flag,
      threshold: 250,
      description: 'You could write a textbook on vexillology.',
      rarity: CosmeticRarity.rare,
    ),
    SocialTitle(
      id: 'flag_master_vexillologist',
      name: 'Master Vexillologist',
      category: TitleCategory.flag,
      threshold: 500,
      description: 'A true authority on the flags of the world.',
      rarity: CosmeticRarity.epic,
    ),
    SocialTitle(
      id: 'flag_grand_vexillologist',
      name: 'Grand Vexillologist',
      category: TitleCategory.flag,
      threshold: 1000,
      description: 'Your knowledge of flags borders on supernatural.',
      rarity: CosmeticRarity.legendary,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Capital Cities
  // ---------------------------------------------------------------------------
  static const List<SocialTitle> _capital = [
    SocialTitle(
      id: 'capital_tourist',
      name: 'Tourist',
      category: TitleCategory.capital,
      threshold: 10,
      description: 'Just passing through the world\'s capitals.',
      rarity: CosmeticRarity.common,
    ),
    SocialTitle(
      id: 'capital_city_hopper',
      name: 'City Hopper',
      category: TitleCategory.capital,
      threshold: 50,
      description: 'Hopping from capital to capital with ease.',
      rarity: CosmeticRarity.common,
    ),
    SocialTitle(
      id: 'capital_correspondent',
      name: 'Capital Correspondent',
      category: TitleCategory.capital,
      threshold: 100,
      description: 'Reporting live from every seat of power.',
      rarity: CosmeticRarity.rare,
    ),
    SocialTitle(
      id: 'capital_ambassador',
      name: 'Ambassador',
      category: TitleCategory.capital,
      threshold: 250,
      description: 'World leaders would consult you on geography.',
      rarity: CosmeticRarity.rare,
    ),
    SocialTitle(
      id: 'capital_diplomat',
      name: 'Diplomat',
      category: TitleCategory.capital,
      threshold: 500,
      description: 'Every capital in the world is at your command.',
      rarity: CosmeticRarity.epic,
    ),
    SocialTitle(
      id: 'capital_secretary_general',
      name: 'Secretary General',
      category: TitleCategory.capital,
      threshold: 1000,
      description: 'The highest office of geographic diplomacy is yours.',
      rarity: CosmeticRarity.legendary,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Country Outlines (Cartography)
  // ---------------------------------------------------------------------------
  static const List<SocialTitle> _outline = [
    SocialTitle(
      id: 'outline_map_reader',
      name: 'Map Reader',
      category: TitleCategory.outline,
      threshold: 10,
      description: 'Recognising countries by their shape alone.',
      rarity: CosmeticRarity.common,
    ),
    SocialTitle(
      id: 'outline_cartographer_apprentice',
      name: 'Cartographer\'s Apprentice',
      category: TitleCategory.outline,
      threshold: 50,
      description: 'Every silhouette tells a story you can read.',
      rarity: CosmeticRarity.common,
    ),
    SocialTitle(
      id: 'outline_cartographer',
      name: 'Cartographer',
      category: TitleCategory.outline,
      threshold: 100,
      description: 'Outlines morph into country names in your mind.',
      rarity: CosmeticRarity.rare,
    ),
    SocialTitle(
      id: 'outline_master_cartographer',
      name: 'Master Cartographer',
      category: TitleCategory.outline,
      threshold: 250,
      description: 'You could draw the world map from memory.',
      rarity: CosmeticRarity.rare,
    ),
    SocialTitle(
      id: 'outline_royal_cartographer',
      name: 'Royal Cartographer',
      category: TitleCategory.outline,
      threshold: 500,
      description: 'Appointed by the crown to chart the known world.',
      rarity: CosmeticRarity.epic,
    ),
    SocialTitle(
      id: 'outline_legendary_cartographer',
      name: 'Legendary Cartographer',
      category: TitleCategory.outline,
      threshold: 1000,
      description: 'A single curve is all you need to name the nation.',
      rarity: CosmeticRarity.legendary,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Borders / Neighbours
  // ---------------------------------------------------------------------------
  static const List<SocialTitle> _borders = [
    SocialTitle(
      id: 'borders_fence_sitter',
      name: 'Fence Sitter',
      category: TitleCategory.borders,
      threshold: 10,
      description: 'Keeping an eye on the boundary lines.',
      rarity: CosmeticRarity.common,
    ),
    SocialTitle(
      id: 'borders_border_hopper',
      name: 'Border Hopper',
      category: TitleCategory.borders,
      threshold: 50,
      description: 'Leaping across frontiers without breaking a sweat.',
      rarity: CosmeticRarity.common,
    ),
    SocialTitle(
      id: 'borders_border_guard',
      name: 'Border Guard',
      category: TitleCategory.borders,
      threshold: 100,
      description: 'No border crossing goes unnoticed.',
      rarity: CosmeticRarity.rare,
    ),
    SocialTitle(
      id: 'borders_customs_officer',
      name: 'Customs Officer',
      category: TitleCategory.borders,
      threshold: 250,
      description: 'You know where every country ends and begins.',
      rarity: CosmeticRarity.rare,
    ),
    SocialTitle(
      id: 'borders_border_marshal',
      name: 'Border Marshal',
      category: TitleCategory.borders,
      threshold: 500,
      description: 'International boundaries are your specialty.',
      rarity: CosmeticRarity.epic,
    ),
    SocialTitle(
      id: 'borders_supreme_borderlord',
      name: 'Supreme Borderlord',
      category: TitleCategory.borders,
      threshold: 1000,
      description: 'Sovereign ruler of every boundary on Earth.',
      rarity: CosmeticRarity.legendary,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Stats / Data
  // ---------------------------------------------------------------------------
  static const List<SocialTitle> _stats = [
    SocialTitle(
      id: 'stats_number_cruncher',
      name: 'Number Cruncher',
      category: TitleCategory.stats,
      threshold: 10,
      description: 'Starting to make sense of the numbers.',
      rarity: CosmeticRarity.common,
    ),
    SocialTitle(
      id: 'stats_data_analyst',
      name: 'Data Analyst',
      category: TitleCategory.stats,
      threshold: 50,
      description: 'You see the stories hidden in statistics.',
      rarity: CosmeticRarity.common,
    ),
    SocialTitle(
      id: 'stats_statistician',
      name: 'Statistician',
      category: TitleCategory.stats,
      threshold: 100,
      description: 'GDP, population, area -- nothing fazes you.',
      rarity: CosmeticRarity.rare,
    ),
    SocialTitle(
      id: 'stats_data_scientist',
      name: 'Data Scientist',
      category: TitleCategory.stats,
      threshold: 250,
      description: 'You could lecture at any university on world data.',
      rarity: CosmeticRarity.rare,
    ),
    SocialTitle(
      id: 'stats_chief_analyst',
      name: 'Chief Analyst',
      category: TitleCategory.stats,
      threshold: 500,
      description: 'The final word on every dataset that matters.',
      rarity: CosmeticRarity.epic,
    ),
    SocialTitle(
      id: 'stats_oracle_of_numbers',
      name: 'Oracle of Numbers',
      category: TitleCategory.stats,
      threshold: 1000,
      description: 'Walking encyclopedia of world statistics.',
      rarity: CosmeticRarity.legendary,
    ),
  ];

  // ---------------------------------------------------------------------------
  // General (total games played)
  // ---------------------------------------------------------------------------
  static const List<SocialTitle> _general = [
    SocialTitle(
      id: 'general_rookie_pilot',
      name: 'Rookie Pilot',
      category: TitleCategory.general,
      threshold: 10,
      description: 'Every journey begins with a few early flights.',
      rarity: CosmeticRarity.common,
    ),
    SocialTitle(
      id: 'general_flight_regular',
      name: 'Flight Regular',
      category: TitleCategory.general,
      threshold: 50,
      description: 'Getting comfortable in the cockpit.',
      rarity: CosmeticRarity.common,
    ),
    SocialTitle(
      id: 'general_seasoned_flier',
      name: 'Seasoned Flier',
      category: TitleCategory.general,
      threshold: 100,
      description: 'The skies feel like home.',
      rarity: CosmeticRarity.rare,
    ),
    SocialTitle(
      id: 'general_frequent_flyer',
      name: 'Frequent Flyer',
      category: TitleCategory.general,
      threshold: 250,
      description: 'Your loyalty card is almost full.',
      rarity: CosmeticRarity.rare,
    ),
    SocialTitle(
      id: 'general_aviation_veteran',
      name: 'Aviation Veteran',
      category: TitleCategory.general,
      threshold: 500,
      description: 'A lifetime of flights behind you and many more ahead.',
      rarity: CosmeticRarity.epic,
    ),
    SocialTitle(
      id: 'general_legendary_aviator',
      name: 'Legendary Aviator',
      category: TitleCategory.general,
      threshold: 1000,
      description: 'You have circled the globe more times than anyone.',
      rarity: CosmeticRarity.legendary,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Speed (best time records)
  // ---------------------------------------------------------------------------
  static const List<SocialTitle> _speed = [
    SocialTitle(
      id: 'speed_speed_demon',
      name: 'Speed Demon',
      category: TitleCategory.speed,
      threshold: 60,
      description: 'Answered in under a minute -- no hesitation.',
      rarity: CosmeticRarity.common,
    ),
    SocialTitle(
      id: 'speed_sonic_pilot',
      name: 'Sonic Pilot',
      category: TitleCategory.speed,
      threshold: 30,
      description: 'Geography at the speed of sound.',
      rarity: CosmeticRarity.rare,
    ),
    SocialTitle(
      id: 'speed_light_speed',
      name: 'Light Speed',
      category: TitleCategory.speed,
      threshold: 15,
      description: 'Blink and you miss this pilot landing.',
      rarity: CosmeticRarity.epic,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Streak (consecutive correct answers)
  // ---------------------------------------------------------------------------
  static const List<SocialTitle> _streak = [
    SocialTitle(
      id: 'streak_hot_streak',
      name: 'Hot Streak',
      category: TitleCategory.streak,
      threshold: 5,
      description: 'Five in a row -- you are warming up.',
      rarity: CosmeticRarity.common,
    ),
    SocialTitle(
      id: 'streak_on_fire',
      name: 'On Fire',
      category: TitleCategory.streak,
      threshold: 10,
      description: 'Ten consecutive correct answers. Unstoppable momentum.',
      rarity: CosmeticRarity.rare,
    ),
    SocialTitle(
      id: 'streak_unstoppable',
      name: 'Unstoppable',
      category: TitleCategory.streak,
      threshold: 25,
      description: 'Twenty-five without a miss. A force of nature.',
      rarity: CosmeticRarity.epic,
    ),
    SocialTitle(
      id: 'streak_phenomenon',
      name: 'Phenomenon',
      category: TitleCategory.streak,
      threshold: 50,
      description: 'Fifty consecutive correct. Beyond human comprehension.',
      rarity: CosmeticRarity.legendary,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Every title available in the game, across all categories.
  static List<SocialTitle> get all => [
        ..._flag,
        ..._capital,
        ..._outline,
        ..._borders,
        ..._stats,
        ..._general,
        ..._speed,
        ..._streak,
      ];

  /// All titles belonging to [category].
  static List<SocialTitle> forCategory(TitleCategory category) =>
      all.where((t) => t.category == category).toList();

  /// Look up a single title by its [id]. Returns `null` if not found.
  static SocialTitle? getById(String id) {
    try {
      return all.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Returns every title the player has earned based on their [progress].
  ///
  /// Count-based categories use a >= comparison. Speed titles use a
  /// strictly-less-than comparison (the player's best time must be below
  /// the threshold). A [bestTimeSeconds] of 0 means no time has been
  /// recorded and no speed titles are earned.
  static List<SocialTitle> checkEarned(PlayerClueProgress progress) {
    return PlayerTitles().earnedTitles(progress);
  }
}
