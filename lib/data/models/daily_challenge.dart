import 'dart:math';

/// Configuration for a single clue-type theme in the daily rotation.
class _DailyTheme {
  const _DailyTheme({
    required this.title,
    required this.description,
    required this.enabledClueTypes,
    required this.coinReward,
  });

  final String title;
  final String description;
  final Set<String> enabledClueTypes;
  final int coinReward;
}

/// A daily challenge with a deterministic configuration seeded by the date.
///
/// Each calendar day maps to exactly one theme from an eight-entry rotation.
/// The seed guarantees every player sees the same challenge on any given day.
class DailyChallenge {
  const DailyChallenge({
    required this.date,
    required this.title,
    required this.description,
    required this.enabledClueTypes,
    required this.coinReward,
    required this.bonusCoinReward,
    required this.seed,
    required this.mapRegion,
  });

  final DateTime date;
  final String title;
  final String description;
  final Set<String> enabledClueTypes;
  final int coinReward;
  final int bonusCoinReward;
  final int seed;
  final String mapRegion;

  // ── Theme rotation ──────────────────────────────────────────────────

  static const Set<String> _allClueTypes = {
    'flag',
    'outline',
    'borders',
    'capital',
    'stats',
  };

  static const List<_DailyTheme> _themes = [
    _DailyTheme(
      title: 'All Clues',
      description: 'Every clue type is in play -- use them all!',
      enabledClueTypes: _allClueTypes,
      coinReward: 150,
    ),
    _DailyTheme(
      title: 'Flag Frenzy',
      description: 'Flags and flags alone. Do you know your colours?',
      enabledClueTypes: {'flag'},
      coinReward: 200,
    ),
    _DailyTheme(
      title: 'Capital Sprint',
      description: 'Name the nation from its capital city.',
      enabledClueTypes: {'capital'},
      coinReward: 200,
    ),
    _DailyTheme(
      title: 'Border Patrol',
      description: 'Only neighbouring-country clues today.',
      enabledClueTypes: {'borders'},
      coinReward: 200,
    ),
    _DailyTheme(
      title: 'Stats Master',
      description: 'Population, area, GDP -- crunch the numbers.',
      enabledClueTypes: {'stats'},
      coinReward: 200,
    ),
    _DailyTheme(
      title: 'Outline Challenge',
      description: 'Silhouettes only. Can you spot the shape?',
      enabledClueTypes: {'outline'},
      coinReward: 200,
    ),
    // "Duo Mix" and "Triple Threat" use random subsets picked with the seed.
    _DailyTheme(
      title: 'Duo Mix',
      description: 'Two random clue types -- adapt or lose!',
      enabledClueTypes: {}, // resolved at construction time
      coinReward: 175,
    ),
    _DailyTheme(
      title: 'Triple Threat',
      description: 'Three clue types thrown into the mix.',
      enabledClueTypes: {}, // resolved at construction time
      coinReward: 160,
    ),
  ];

  // ── Factories ───────────────────────────────────────────────────────

  /// Build the daily challenge for today (UTC).
  ///
  /// When [baseRewardOverride] is non-null, it replaces the hardcoded per-theme
  /// coin reward with the admin-configured base reward. Single-clue themes
  /// still get a difficulty multiplier on top of the base.
  factory DailyChallenge.forToday({int? baseRewardOverride}) {
    final now = DateTime.now().toUtc();
    return DailyChallenge.forDate(
      DateTime.utc(now.year, now.month, now.day),
      baseRewardOverride: baseRewardOverride,
    );
  }

  /// Build the daily challenge for a specific [date].
  ///
  /// Only the year, month and day components are used; time is ignored.
  /// When [baseRewardOverride] is non-null, the admin-configured base reward
  /// is used instead of hardcoded theme values. Theme difficulty multipliers
  /// are preserved: "All Clues" = 1.0x, single-clue = 1.33x, duo = 1.17x,
  /// triple = 1.07x.
  factory DailyChallenge.forDate(DateTime date, {int? baseRewardOverride}) {
    final normalisedDate = DateTime.utc(date.year, date.month, date.day);
    final seed =
        normalisedDate.year * 10000 +
        normalisedDate.month * 100 +
        normalisedDate.day;

    final rng = Random(seed);
    final themeIndex = rng.nextInt(_themes.length);
    final theme = _themes[themeIndex];

    // Resolve clue types for the randomised themes.
    Set<String> resolvedClueTypes;
    if (theme.title == 'Duo Mix') {
      resolvedClueTypes = _pickRandomClueTypes(rng, 2);
    } else if (theme.title == 'Triple Threat') {
      resolvedClueTypes = _pickRandomClueTypes(rng, 3);
    } else {
      resolvedClueTypes = theme.enabledClueTypes;
    }

    const regions = [
      'World',
      'Europe',
      'Asia',
      'Africa',
      'Americas',
      'Oceania',
    ];
    final mapRegion = regions[rng.nextInt(regions.length)];

    // Compute coin reward: use admin override with theme multiplier, or
    // fall back to the hardcoded per-theme value.
    int coinReward;
    if (baseRewardOverride != null) {
      // Theme difficulty multiplier based on number of clue types.
      // Fewer clue types = harder = higher reward.
      final double multiplier;
      if (resolvedClueTypes.length == 1) {
        multiplier = 1.33; // single-clue themes
      } else if (resolvedClueTypes.length == 2) {
        multiplier = 1.17; // duo
      } else if (resolvedClueTypes.length == 3) {
        multiplier = 1.07; // triple
      } else {
        multiplier = 1.0; // all clues
      }
      coinReward = (baseRewardOverride * multiplier).round();
    } else {
      coinReward = theme.coinReward;
    }

    return DailyChallenge(
      date: normalisedDate,
      title: theme.title,
      description: theme.description,
      enabledClueTypes: resolvedClueTypes,
      coinReward: coinReward,
      bonusCoinReward: coinReward * 3,
      seed: seed,
      mapRegion: mapRegion,
    );
  }

  /// Pick [count] distinct clue types using the supplied [rng].
  static Set<String> _pickRandomClueTypes(Random rng, int count) {
    final pool = _allClueTypes.toList()..shuffle(rng);
    return pool.take(count).toSet();
  }

  // ── Serialisation ───────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'title': title,
    'description': description,
    'enabled_clue_types': enabledClueTypes.toList(),
    'coin_reward': coinReward,
    'bonus_coin_reward': bonusCoinReward,
    'seed': seed,
    'map_region': mapRegion,
  };

  factory DailyChallenge.fromJson(Map<String, dynamic> json) => DailyChallenge(
    date: DateTime.parse(json['date'] as String),
    title: json['title'] as String,
    description: json['description'] as String,
    enabledClueTypes: (json['enabled_clue_types'] as List)
        .map((e) => e as String)
        .toSet(),
    coinReward: json['coin_reward'] as int,
    bonusCoinReward: json['bonus_coin_reward'] as int,
    seed: json['seed'] as int,
    mapRegion: json['map_region'] as String? ?? 'World',
  );

  // ── Placeholder leaderboard ─────────────────────────────────────────

  /// Leaderboard entries fetched from Supabase (initially empty).
  static const List<DailyLeaderboardEntry> placeholderLeaderboard = [];
}

/// A single row on the daily-challenge leaderboard.
class DailyLeaderboardEntry {
  const DailyLeaderboardEntry({
    required this.username,
    required this.score,
    required this.time,
    required this.rank,
  });

  final String username;
  final int score;
  final Duration time;
  final int rank;

  Map<String, dynamic> toJson() => {
    'username': username,
    'score': score,
    'time_ms': time.inMilliseconds,
    'rank': rank,
  };

  factory DailyLeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      DailyLeaderboardEntry(
        username: json['username'] as String,
        score: json['score'] as int,
        time: Duration(milliseconds: json['time_ms'] as int),
        rank: json['rank'] as int,
      );
}

/// Medal tier for daily challenge winners.
enum MedalMaterial { bronze, silver, gold, platinum }

/// A daily winner medal with star progression (1-5 stars per material).
/// 20 total steps: bronze 1-5, silver 1-5, gold 1-5, platinum 1-5.
class DailyMedal {
  const DailyMedal({required this.wins});

  final int wins;

  /// Current medal material based on total wins.
  MedalMaterial get material {
    if (wins >= 16) return MedalMaterial.platinum;
    if (wins >= 11) return MedalMaterial.gold;
    if (wins >= 6) return MedalMaterial.silver;
    return MedalMaterial.bronze;
  }

  /// Stars within current tier (1-5).
  int get stars {
    if (wins >= 16) return (wins - 15).clamp(1, 5);
    if (wins >= 11) return (wins - 10).clamp(1, 5);
    if (wins >= 6) return (wins - 5).clamp(1, 5);
    return wins.clamp(1, 5);
  }

  /// Total progression step (1-20).
  int get step => wins.clamp(1, 20);
}
