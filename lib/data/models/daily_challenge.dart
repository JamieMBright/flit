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
  });

  final DateTime date;
  final String title;
  final String description;
  final Set<String> enabledClueTypes;
  final int coinReward;
  final int bonusCoinReward;
  final int seed;

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
      coinReward: 50,
    ),
    _DailyTheme(
      title: 'Flag Frenzy',
      description: 'Flags and flags alone. Do you know your colours?',
      enabledClueTypes: {'flag'},
      coinReward: 75,
    ),
    _DailyTheme(
      title: 'Capital Sprint',
      description: 'Name the nation from its capital city.',
      enabledClueTypes: {'capital'},
      coinReward: 75,
    ),
    _DailyTheme(
      title: 'Border Patrol',
      description: 'Only neighbouring-country clues today.',
      enabledClueTypes: {'borders'},
      coinReward: 75,
    ),
    _DailyTheme(
      title: 'Stats Master',
      description: 'Population, area, GDP -- crunch the numbers.',
      enabledClueTypes: {'stats'},
      coinReward: 75,
    ),
    _DailyTheme(
      title: 'Outline Challenge',
      description: 'Silhouettes only. Can you spot the shape?',
      enabledClueTypes: {'outline'},
      coinReward: 75,
    ),
    // "Duo Mix" and "Triple Threat" use random subsets picked with the seed.
    _DailyTheme(
      title: 'Duo Mix',
      description: 'Two random clue types -- adapt or lose!',
      enabledClueTypes: {}, // resolved at construction time
      coinReward: 60,
    ),
    _DailyTheme(
      title: 'Triple Threat',
      description: 'Three clue types thrown into the mix.',
      enabledClueTypes: {}, // resolved at construction time
      coinReward: 55,
    ),
  ];

  // ── Factories ───────────────────────────────────────────────────────

  /// Build the daily challenge for today (UTC).
  factory DailyChallenge.forToday() {
    final now = DateTime.now().toUtc();
    return DailyChallenge.forDate(
      DateTime.utc(now.year, now.month, now.day),
    );
  }

  /// Build the daily challenge for a specific [date].
  ///
  /// Only the year, month and day components are used; time is ignored.
  factory DailyChallenge.forDate(DateTime date) {
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

    return DailyChallenge(
      date: normalisedDate,
      title: theme.title,
      description: theme.description,
      enabledClueTypes: resolvedClueTypes,
      coinReward: theme.coinReward,
      bonusCoinReward: theme.coinReward * 3,
      seed: seed,
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
      };

  factory DailyChallenge.fromJson(Map<String, dynamic> json) =>
      DailyChallenge(
        date: DateTime.parse(json['date'] as String),
        title: json['title'] as String,
        description: json['description'] as String,
        enabledClueTypes:
            (json['enabled_clue_types'] as List)
                .map((e) => e as String)
                .toSet(),
        coinReward: json['coin_reward'] as int,
        bonusCoinReward: json['bonus_coin_reward'] as int,
        seed: json['seed'] as int,
      );

  // ── Placeholder leaderboard ─────────────────────────────────────────

  /// Ten sample leaderboard entries for UI development and testing.
  static final List<DailyLeaderboardEntry> placeholderLeaderboard = [
    DailyLeaderboardEntry(
      username: 'GlobeTrotter42',
      score: 9800,
      time: const Duration(minutes: 1, seconds: 12),
      rank: 1,
    ),
    DailyLeaderboardEntry(
      username: 'MapMaster',
      score: 9650,
      time: const Duration(minutes: 1, seconds: 28),
      rank: 2,
    ),
    DailyLeaderboardEntry(
      username: 'AtlasAce',
      score: 9400,
      time: const Duration(minutes: 1, seconds: 45),
      rank: 3,
    ),
    DailyLeaderboardEntry(
      username: 'WanderWiz',
      score: 9100,
      time: const Duration(minutes: 2, seconds: 3),
      rank: 4,
    ),
    DailyLeaderboardEntry(
      username: 'GeoPilot',
      score: 8800,
      time: const Duration(minutes: 2, seconds: 19),
      rank: 5,
    ),
    DailyLeaderboardEntry(
      username: 'CompassKid',
      score: 8500,
      time: const Duration(minutes: 2, seconds: 37),
      rank: 6,
    ),
    DailyLeaderboardEntry(
      username: 'BorderRunner',
      score: 8200,
      time: const Duration(minutes: 2, seconds: 52),
      rank: 7,
    ),
    DailyLeaderboardEntry(
      username: 'CapitalCrush',
      score: 7900,
      time: const Duration(minutes: 3, seconds: 11),
      rank: 8,
    ),
    DailyLeaderboardEntry(
      username: 'FlagFinder99',
      score: 7600,
      time: const Duration(minutes: 3, seconds: 30),
      rank: 9,
    ),
    DailyLeaderboardEntry(
      username: 'TerraNova',
      score: 7300,
      time: const Duration(minutes: 3, seconds: 48),
      rank: 10,
    ),
  ];
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
