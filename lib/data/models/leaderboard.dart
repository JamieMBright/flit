// Leaderboard models supporting global, daily/seasonal/all-time boards,
// regional and friends boards, annual cosmetic rewards, and rich placeholder
// data for UI development.
//
// **Design rationale** -- All players compete on the same boards. Pilot
// license boosts always apply, so every board reflects the full gameplay
// experience. Daily, all-time, regional and friends boards provide additional
// filters for competitive play and streaming appeal.

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// The type / scope of a leaderboard.
///
/// Global, daily, all-time, regional and friends boards.
enum LeaderboardType {
  /// Global leaderboard — pilot license boosts always apply.
  global,

  /// Today's daily challenge leaderboard (resets at midnight UTC).
  daily,

  /// All-time records across every season.
  allTime,

  /// Per-region boards filtered by geographic area (continent / country).
  regional,

  /// Friends-only leaderboard visible to the player's friend list.
  friends,
}

extension LeaderboardTypeExtension on LeaderboardType {
  String get displayName {
    switch (this) {
      case LeaderboardType.global:
        return 'Global';
      case LeaderboardType.daily:
        return 'Daily Challenge';
      case LeaderboardType.allTime:
        return 'All Time';
      case LeaderboardType.regional:
        return 'Regional';
      case LeaderboardType.friends:
        return 'Friends';
    }
  }

  String get shortName {
    switch (this) {
      case LeaderboardType.global:
        return 'Global';
      case LeaderboardType.daily:
        return 'Daily';
      case LeaderboardType.allTime:
        return 'All Time';
      case LeaderboardType.regional:
        return 'Regional';
      case LeaderboardType.friends:
        return 'Friends';
    }
  }

  String get description {
    switch (this) {
      case LeaderboardType.global:
        return 'All pilots compete on a single global board';
      case LeaderboardType.daily:
        return "Today's challenge — resets at midnight UTC";
      case LeaderboardType.allTime:
        return 'The greatest pilots across every season';
      case LeaderboardType.regional:
        return 'Top pilots in your region';
      case LeaderboardType.friends:
        return 'How you stack up against your friends';
    }
  }
}

/// The time window a leaderboard covers.
enum LeaderboardTimeframe { today, thisWeek, thisMonth, thisYear, allTime }

extension LeaderboardTimeframeExtension on LeaderboardTimeframe {
  String get displayName {
    switch (this) {
      case LeaderboardTimeframe.today:
        return 'Today';
      case LeaderboardTimeframe.thisWeek:
        return 'This Week';
      case LeaderboardTimeframe.thisMonth:
        return 'This Month';
      case LeaderboardTimeframe.thisYear:
        return 'This Year';
      case LeaderboardTimeframe.allTime:
        return 'All Time';
    }
  }
}

// ---------------------------------------------------------------------------
// LeaderboardEntry
// ---------------------------------------------------------------------------

/// A single row on any leaderboard.
///
/// Carries enough information for a rich leaderboard row: rank, score, time,
/// player level, license status, social display title, and games played count.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.playerId,
    required this.username,
    required this.score,
    required this.bestTime,
    required this.rank,
    this.gamesPlayed = 0,
    this.isLicensed = false,
    this.displayTitle,
    this.level = 1,
    this.avatarUrl,
    this.countryCode,
    this.streak = 0,
    this.timestamp,
  });

  /// Unique player identifier.
  final String playerId;

  /// Player's display username.
  final String username;

  /// Aggregate score for this leaderboard period.
  final int score;

  /// Best round completion time.
  final Duration bestTime;

  /// Position on the board (1-indexed).
  final int rank;

  /// Total games played in this leaderboard period.
  final int gamesPlayed;

  /// Whether this entry used pilot license boosts.
  final bool isLicensed;

  /// Social title displayed next to the username (e.g. "Flag Savant").
  final String? displayTitle;

  /// Player's current level.
  final int level;

  /// Optional avatar image URL.
  final String? avatarUrl;

  /// ISO 3166-1 alpha-2 country code for regional boards.
  final String? countryCode;

  /// Current win streak (consecutive games with a correct answer).
  final int streak;

  /// When this entry was last updated.
  final DateTime? timestamp;

  // ── Display helpers ──────────────────────────────────────────────────

  /// Formatted best time as `MM:SS.mm`.
  String get formattedTime {
    final minutes = bestTime.inMinutes;
    final seconds = bestTime.inSeconds % 60;
    final centis = (bestTime.inMilliseconds % 1000) ~/ 10;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${centis.toString().padLeft(2, '0')}';
  }

  /// Display string combining username and optional title.
  String get displayNameWithTitle =>
      displayTitle != null ? '$username — $displayTitle' : username;

  // ── copyWith ─────────────────────────────────────────────────────────

  LeaderboardEntry copyWith({
    String? playerId,
    String? username,
    int? score,
    Duration? bestTime,
    int? rank,
    int? gamesPlayed,
    bool? isLicensed,
    String? displayTitle,
    int? level,
    String? avatarUrl,
    String? countryCode,
    int? streak,
    DateTime? timestamp,
  }) => LeaderboardEntry(
    playerId: playerId ?? this.playerId,
    username: username ?? this.username,
    score: score ?? this.score,
    bestTime: bestTime ?? this.bestTime,
    rank: rank ?? this.rank,
    gamesPlayed: gamesPlayed ?? this.gamesPlayed,
    isLicensed: isLicensed ?? this.isLicensed,
    displayTitle: displayTitle ?? this.displayTitle,
    level: level ?? this.level,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    countryCode: countryCode ?? this.countryCode,
    streak: streak ?? this.streak,
    timestamp: timestamp ?? this.timestamp,
  );

  // ── Serialisation ────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'player_id': playerId,
    'username': username,
    'score': score,
    'best_time_ms': bestTime.inMilliseconds,
    'rank': rank,
    'games_played': gamesPlayed,
    'is_licensed': isLicensed,
    'display_title': displayTitle,
    'level': level,
    'avatar_url': avatarUrl,
    'country_code': countryCode,
    'streak': streak,
    'timestamp': timestamp?.toIso8601String(),
  };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        playerId: json['player_id'] as String,
        username: json['username'] as String,
        score: json['score'] as int,
        bestTime: Duration(milliseconds: json['best_time_ms'] as int),
        rank: json['rank'] as int,
        gamesPlayed: json['games_played'] as int? ?? 0,
        isLicensed: json['is_licensed'] as bool? ?? false,
        displayTitle: json['display_title'] as String?,
        level: json['level'] as int? ?? 1,
        avatarUrl: json['avatar_url'] as String?,
        countryCode: json['country_code'] as String?,
        streak: json['streak'] as int? ?? 0,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : null,
      );
}

// ---------------------------------------------------------------------------
// LeaderboardReward
// ---------------------------------------------------------------------------

/// An annual reward granted to top-ranked players on the all-time board.
///
/// At the end of each calendar year, the top N players on the all-time
/// board receive a unique cosmetic that can never be obtained again. This
/// drives long-term competitive motivation.
class LeaderboardReward {
  const LeaderboardReward({
    required this.id,
    required this.year,
    required this.boardType,
    required this.minRank,
    required this.maxRank,
    required this.cosmeticId,
    required this.cosmeticName,
    required this.description,
  });

  /// Unique reward identifier.
  final String id;

  /// The calendar year this reward was awarded.
  final int year;

  /// Which board type this reward applies to.
  final LeaderboardType boardType;

  /// Inclusive rank range that qualifies for this reward.
  final int minRank;
  final int maxRank;

  /// The one-of-a-kind cosmetic item granted.
  final String cosmeticId;
  final String cosmeticName;

  /// Flavour text describing the reward.
  final String description;

  // ── Serialisation ────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id': id,
    'year': year,
    'board_type': boardType.name,
    'min_rank': minRank,
    'max_rank': maxRank,
    'cosmetic_id': cosmeticId,
    'cosmetic_name': cosmeticName,
    'description': description,
  };

  factory LeaderboardReward.fromJson(Map<String, dynamic> json) =>
      LeaderboardReward(
        id: json['id'] as String,
        year: json['year'] as int,
        boardType: LeaderboardType.values.firstWhere(
          (t) => t.name == json['board_type'],
        ),
        minRank: json['min_rank'] as int,
        maxRank: json['max_rank'] as int,
        cosmeticId: json['cosmetic_id'] as String,
        cosmeticName: json['cosmetic_name'] as String,
        description: json['description'] as String,
      );

  /// Placeholder annual rewards for UI development.
  static const List<LeaderboardReward> placeholderRewards = [
    LeaderboardReward(
      id: 'reward_2025_global_1',
      year: 2025,
      boardType: LeaderboardType.global,
      minRank: 1,
      maxRank: 1,
      cosmeticId: 'plane_aurora_2025',
      cosmeticName: 'Aurora Champion 2025',
      description:
          'One-of-a-kind plane awarded to the #1 pilot of 2025. '
          'A shimmering aurora-painted fuselage that can never be obtained again.',
    ),
    LeaderboardReward(
      id: 'reward_2025_global_top10',
      year: 2025,
      boardType: LeaderboardType.global,
      minRank: 2,
      maxRank: 10,
      cosmeticId: 'contrail_frost_2025',
      cosmeticName: 'Frost Trail 2025',
      description:
          'Exclusive contrail awarded to the top 10 pilots of 2025. '
          'Ice crystals shimmer in your wake.',
    ),
  ];
}

// ---------------------------------------------------------------------------
// PlayerClueStats
// ---------------------------------------------------------------------------

/// Per-clue-type progress stats used to award social titles.
///
/// Tracks correct answers across all five clue categories, plus lifetime
/// economy and challenge data.
class PlayerClueStats {
  const PlayerClueStats({
    this.flagsCorrect = 0,
    this.outlinesCorrect = 0,
    this.bordersCorrect = 0,
    this.capitalsCorrect = 0,
    this.statsCorrect = 0,
    this.bestTime,
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.coinsEarned = 0,
    this.coinsSpent = 0,
    this.challengesSent = 0,
    this.challengesWon = 0,
    this.cosmeticsOwned = 0,
  });

  /// Correct answers per clue type.
  final int flagsCorrect;
  final int outlinesCorrect;
  final int bordersCorrect;
  final int capitalsCorrect;
  final int statsCorrect;

  /// Sum of all correct clue answers.
  int get totalCorrect =>
      flagsCorrect +
      outlinesCorrect +
      bordersCorrect +
      capitalsCorrect +
      statsCorrect;

  /// Fastest game completion time across all modes.
  final Duration? bestTime;

  /// Lifetime game counts.
  final int gamesPlayed;
  final int gamesWon;

  /// Lifetime coin economy.
  final int coinsEarned;
  final int coinsSpent;

  /// Challenge record.
  final int challengesSent;
  final int challengesWon;

  /// Number of cosmetic items owned.
  final int cosmeticsOwned;

  // ── copyWith ──────────────────────────────────────────────────────────

  PlayerClueStats copyWith({
    int? flagsCorrect,
    int? outlinesCorrect,
    int? bordersCorrect,
    int? capitalsCorrect,
    int? statsCorrect,
    Duration? bestTime,
    int? gamesPlayed,
    int? gamesWon,
    int? coinsEarned,
    int? coinsSpent,
    int? challengesSent,
    int? challengesWon,
    int? cosmeticsOwned,
  }) => PlayerClueStats(
    flagsCorrect: flagsCorrect ?? this.flagsCorrect,
    outlinesCorrect: outlinesCorrect ?? this.outlinesCorrect,
    bordersCorrect: bordersCorrect ?? this.bordersCorrect,
    capitalsCorrect: capitalsCorrect ?? this.capitalsCorrect,
    statsCorrect: statsCorrect ?? this.statsCorrect,
    bestTime: bestTime ?? this.bestTime,
    gamesPlayed: gamesPlayed ?? this.gamesPlayed,
    gamesWon: gamesWon ?? this.gamesWon,
    coinsEarned: coinsEarned ?? this.coinsEarned,
    coinsSpent: coinsSpent ?? this.coinsSpent,
    challengesSent: challengesSent ?? this.challengesSent,
    challengesWon: challengesWon ?? this.challengesWon,
    cosmeticsOwned: cosmeticsOwned ?? this.cosmeticsOwned,
  );

  // ── Serialisation ─────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'flags_correct': flagsCorrect,
    'outlines_correct': outlinesCorrect,
    'borders_correct': bordersCorrect,
    'capitals_correct': capitalsCorrect,
    'stats_correct': statsCorrect,
    'best_time_ms': bestTime?.inMilliseconds,
    'games_played': gamesPlayed,
    'games_won': gamesWon,
    'coins_earned': coinsEarned,
    'coins_spent': coinsSpent,
    'challenges_sent': challengesSent,
    'challenges_won': challengesWon,
    'cosmetics_owned': cosmeticsOwned,
  };

  factory PlayerClueStats.fromJson(Map<String, dynamic> json) =>
      PlayerClueStats(
        flagsCorrect: json['flags_correct'] as int? ?? 0,
        outlinesCorrect: json['outlines_correct'] as int? ?? 0,
        bordersCorrect: json['borders_correct'] as int? ?? 0,
        capitalsCorrect: json['capitals_correct'] as int? ?? 0,
        statsCorrect: json['stats_correct'] as int? ?? 0,
        bestTime: json['best_time_ms'] != null
            ? Duration(milliseconds: json['best_time_ms'] as int)
            : null,
        gamesPlayed: json['games_played'] as int? ?? 0,
        gamesWon: json['games_won'] as int? ?? 0,
        coinsEarned: json['coins_earned'] as int? ?? 0,
        coinsSpent: json['coins_spent'] as int? ?? 0,
        challengesSent: json['challenges_sent'] as int? ?? 0,
        challengesWon: json['challenges_won'] as int? ?? 0,
        cosmeticsOwned: json['cosmetics_owned'] as int? ?? 0,
      );
}

// ---------------------------------------------------------------------------
// Leaderboard
// ---------------------------------------------------------------------------

/// A complete leaderboard with metadata, entries, and the current player's
/// position.
///
/// The [placeholder] factory generates rich fake data for each board type,
/// including 50 entries with the current player sitting around rank 42 to
/// demonstrate the "you are here" scroll-to behaviour. Licensed boards have
/// slightly inflated scores to reflect pilot license boost advantages.
class Leaderboard {
  const Leaderboard({
    required this.type,
    required this.timeframe,
    required this.entries,
    required this.lastUpdated,
    this.currentPlayerEntry,
    this.regionId,
    this.seasonYear,
    this.totalEntries,
    this.rewards = const [],
  });

  /// Which board this is.
  final LeaderboardType type;

  /// Time window being displayed.
  final LeaderboardTimeframe timeframe;

  /// The visible slice of leaderboard rows.
  final List<LeaderboardEntry> entries;

  /// Where the current user sits (may not be in [entries] if they are outside
  /// the visible page). The UI should use this to render a "You are here" row.
  final LeaderboardEntry? currentPlayerEntry;

  /// When this board was last refreshed from the server.
  final DateTime lastUpdated;

  /// Optional region filter (ISO 3166-1 alpha-2 or continent code).
  final String? regionId;

  /// For all-time boards: the season/year this data covers.
  final int? seasonYear;

  /// Total number of entries on the full board (for "rank X of Y" display).
  final int? totalEntries;

  /// Annual cosmetic rewards associated with this board (all-time only).
  final List<LeaderboardReward> rewards;

  // ── copyWith ─────────────────────────────────────────────────────────

  Leaderboard copyWith({
    LeaderboardType? type,
    LeaderboardTimeframe? timeframe,
    List<LeaderboardEntry>? entries,
    LeaderboardEntry? currentPlayerEntry,
    DateTime? lastUpdated,
    String? regionId,
    int? seasonYear,
    int? totalEntries,
    List<LeaderboardReward>? rewards,
  }) => Leaderboard(
    type: type ?? this.type,
    timeframe: timeframe ?? this.timeframe,
    entries: entries ?? this.entries,
    currentPlayerEntry: currentPlayerEntry ?? this.currentPlayerEntry,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    regionId: regionId ?? this.regionId,
    seasonYear: seasonYear ?? this.seasonYear,
    totalEntries: totalEntries ?? this.totalEntries,
    rewards: rewards ?? this.rewards,
  );

  // ── Serialisation ────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'timeframe': timeframe.name,
    'entries': entries.map((e) => e.toJson()).toList(),
    'current_player_entry': currentPlayerEntry?.toJson(),
    'last_updated': lastUpdated.toIso8601String(),
    'region_id': regionId,
    'season_year': seasonYear,
    'total_entries': totalEntries,
    'rewards': rewards.map((r) => r.toJson()).toList(),
  };

  factory Leaderboard.fromJson(Map<String, dynamic> json) => Leaderboard(
    type: LeaderboardType.values.firstWhere((t) => t.name == json['type']),
    timeframe: LeaderboardTimeframe.values.firstWhere(
      (t) => t.name == json['timeframe'],
    ),
    entries: (json['entries'] as List)
        .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
    currentPlayerEntry: json['current_player_entry'] != null
        ? LeaderboardEntry.fromJson(
            json['current_player_entry'] as Map<String, dynamic>,
          )
        : null,
    lastUpdated: DateTime.parse(json['last_updated'] as String),
    regionId: json['region_id'] as String?,
    seasonYear: json['season_year'] as int?,
    totalEntries: json['total_entries'] as int?,
    rewards:
        (json['rewards'] as List?)
            ?.map((r) => LeaderboardReward.fromJson(r as Map<String, dynamic>))
            .toList() ??
        const [],
  );

  // ── Placeholder data ─────────────────────────────────────────────────

  /// Generate a fully populated placeholder leaderboard for UI development.
  ///
  /// Returns different data per [type]:
  /// - **global** uses 50 entries with pilot license boosts applied.
  /// - **daily** has fewer entries and tighter score spreads.
  /// - **allTime** includes annual reward metadata.
  /// - **regional** / **friends** use smaller entry sets with region/friend
  ///   context.
  ///
  /// The current player ("You") is always placed around rank 42 with
  /// `playerId: 'current_player'` so the UI can scroll to and highlight
  /// their position.
  static Leaderboard placeholder(LeaderboardType type) {
    final LeaderboardTimeframe timeframe;
    final List<LeaderboardEntry> entries;
    final int totalEntries;
    final List<LeaderboardReward> rewards;

    switch (type) {
      case LeaderboardType.global:
        timeframe = LeaderboardTimeframe.thisMonth;
        entries = _buildGlobalEntries();
        totalEntries = 12847;
        rewards = const [];
        break;
      case LeaderboardType.daily:
        timeframe = LeaderboardTimeframe.today;
        entries = _buildDailyEntries();
        totalEntries = 3412;
        rewards = const [];
        break;
      case LeaderboardType.allTime:
        timeframe = LeaderboardTimeframe.allTime;
        entries = _buildAllTimeEntries();
        totalEntries = 54219;
        rewards = LeaderboardReward.placeholderRewards;
        break;
      case LeaderboardType.regional:
        timeframe = LeaderboardTimeframe.thisMonth;
        entries = _buildRegionalEntries();
        totalEntries = 1876;
        rewards = const [];
        break;
      case LeaderboardType.friends:
        timeframe = LeaderboardTimeframe.thisWeek;
        entries = _buildFriendsEntries();
        totalEntries = entries.length;
        rewards = const [];
        break;
    }

    // Find the current player entry in the list.
    LeaderboardEntry? currentPlayer;
    for (final entry in entries) {
      if (entry.playerId == 'current_player') {
        currentPlayer = entry;
        break;
      }
    }

    return Leaderboard(
      type: type,
      timeframe: timeframe,
      entries: entries,
      currentPlayerEntry: currentPlayer,
      lastUpdated: DateTime.now().toUtc(),
      regionId: type == LeaderboardType.regional ? 'EU' : null,
      seasonYear: type == LeaderboardType.allTime ? 2025 : null,
      totalEntries: totalEntries,
      rewards: rewards,
    );
  }

  // ── Private placeholder builders ─────────────────────────────────────

  /// 50 entries for the global board.
  static List<LeaderboardEntry> _buildGlobalEntries() {
    // Creative usernames -- geography, aviation and exploration themed.
    const topNames = <_PlaceholderPlayer>[
      _PlaceholderPlayer('MercatorMaven', 'Master Vexillologist', 22),
      _PlaceholderPlayer('EquatorExplorer', 'Flag Savant', 21),
      _PlaceholderPlayer('PrimeMeridian', 'Capital Commander', 20),
      _PlaceholderPlayer('LatLongLegend', 'Lightning', 20),
      _PlaceholderPlayer('CartographyCat', 'Statistics Savant', 19),
      _PlaceholderPlayer('TropicOfCapri', 'Outline Oracle', 19),
      _PlaceholderPlayer('GeodeticGuru', 'Border Lord', 18),
      _PlaceholderPlayer('AzimuthAce', 'Supersonic', 18),
      _PlaceholderPlayer('IslandHopper42', 'Challenge Legend', 17),
      _PlaceholderPlayer('DatumDrifter', 'Data Professor', 17),
      _PlaceholderPlayer('ContourClimber', 'Shadow Cartographer', 16),
      _PlaceholderPlayer('ProjectionPro', 'Frontier Master', 16),
      _PlaceholderPlayer('GreatCircleGal', 'Capital Connoisseur', 15),
      _PlaceholderPlayer('RhumbRunner', 'Speed Demon', 15),
      _PlaceholderPlayer('PangaeaPilot', 'Flag Expert', 14),
      _PlaceholderPlayer('GondwanaGlider', 'Shape Shifter', 14),
      _PlaceholderPlayer('LaurasiaLark', 'Boundary Expert', 13),
      _PlaceholderPlayer('TectonicTrek', 'Number Cruncher', 13),
      _PlaceholderPlayer('MagneticNorth', 'Mile High Club', 12),
      _PlaceholderPlayer('SolsticeFlyer', 'Frequent Flier', 12),
    ];

    const midNames = <_PlaceholderPlayer>[
      _PlaceholderPlayer('FjordFinder', 'Capital Navigator', 11),
      _PlaceholderPlayer('SteppeStrider', 'Shape Detective', 11),
      _PlaceholderPlayer('TundraTracer', 'Data Analyst', 10),
      _PlaceholderPlayer('SavannaScout', 'Border Guard', 10),
      _PlaceholderPlayer('DeltaDasher', 'Quick Draw', 9),
      _PlaceholderPlayer('CanyonCruiser', 'Flag Enthusiast', 9),
      _PlaceholderPlayer('ArchipelagoAce', 'Social Butterfly', 8),
      _PlaceholderPlayer('PlainsPathfinder', 'Silhouette Spotter', 8),
      _PlaceholderPlayer('ReefRanger', 'Capital Cadet', 7),
      _PlaceholderPlayer('MesaMaster', 'Airborne', 7),
      _PlaceholderPlayer('GlacierGlider', 'Border Patrol', 6),
      _PlaceholderPlayer('OasisOracle', 'Friendly Flier', 6),
      _PlaceholderPlayer('VolcanoVoyager', null, 5),
      _PlaceholderPlayer('MonsoonMaverick', null, 5),
      _PlaceholderPlayer('TyphoonTracker', null, 5),
      _PlaceholderPlayer('CirrusCircler', null, 4),
      _PlaceholderPlayer('StratusStriker', null, 4),
      _PlaceholderPlayer('CumulusKing', null, 4),
      _PlaceholderPlayer('NimbusNavigator', null, 3),
      _PlaceholderPlayer('ZephyrZealot', null, 3),
    ];

    // The current player sits around rank 42.
    const currentPlayer = _PlaceholderPlayer('You', 'Novice Vexillologist', 6);

    const tailNames = <_PlaceholderPlayer>[
      _PlaceholderPlayer('ThermoclineThief', null, 3),
      _PlaceholderPlayer('BarometerBandit', null, 2),
      _PlaceholderPlayer('IsothermImp', null, 2),
      _PlaceholderPlayer('IsobarIntern', null, 2),
      _PlaceholderPlayer('TropopauseTraveller', null, 2),
      _PlaceholderPlayer('MesosphereMike', null, 1),
      _PlaceholderPlayer('ExosphereEllie', null, 1),
      _PlaceholderPlayer('MantleMiner', null, 1),
    ];

    final allPlayers = <_PlaceholderPlayer>[
      ...topNames,
      ...midNames,
      currentPlayer,
      ...tailNames,
    ];

    // Base score for rank 1, decaying by rank.
    const int baseScore = 12500;

    return List<LeaderboardEntry>.generate(allPlayers.length, (i) {
      final player = allPlayers[i];
      final rank = i + 1;

      // Score decay: sharp at the top, gentler in the middle.
      final int rawScore;
      if (rank <= 3) {
        rawScore = baseScore - (rank - 1) * 180;
      } else if (rank <= 10) {
        rawScore = baseScore - 540 - (rank - 3) * 150;
      } else if (rank <= 20) {
        rawScore = baseScore - 1590 - (rank - 10) * 120;
      } else if (rank <= 40) {
        rawScore = baseScore - 2790 - (rank - 20) * 95;
      } else {
        rawScore = baseScore - 4690 - (rank - 40) * 80;
      }

      // Add small per-rank variance.
      final int score = rawScore + (rank.isEven ? 37 : -23);

      // Time increases with rank (worse players are slower).
      final timeMs = 72000 + (rank * 1850) + (rank.isOdd ? 430 : -210);

      // Games played decreases with rank (top players play more).
      final gamesPlayed = (500 - rank * 8).clamp(12, 500);

      final isCurrentPlayer = player.name == 'You';

      return LeaderboardEntry(
        playerId: isCurrentPlayer ? 'current_player' : 'player_$rank',
        username: player.name,
        score: score,
        bestTime: Duration(milliseconds: timeMs),
        rank: rank,
        gamesPlayed: gamesPlayed,
        isLicensed: true,
        displayTitle: player.title,
        level: player.level,
        streak: rank <= 5 ? (20 - rank * 3) : (rank <= 15 ? 5 : 0),
      );
    });
  }

  /// 20 entries for daily challenge boards with tighter score spreads.
  static List<LeaderboardEntry> _buildDailyEntries() {
    const players = <_PlaceholderPlayer>[
      _PlaceholderPlayer('SunriseScout', 'Lightning', 18),
      _PlaceholderPlayer('DawnPatrol', 'Speed Demon', 16),
      _PlaceholderPlayer('MorningMeridian', 'Flag Expert', 15),
      _PlaceholderPlayer('NoonNavigator', 'Quick Draw', 14),
      _PlaceholderPlayer('TwilightTracer', 'Capital Navigator', 13),
      _PlaceholderPlayer('DuskDrifter', 'Shape Detective', 12),
      _PlaceholderPlayer('MidnightMapper', 'Border Guard', 11),
      _PlaceholderPlayer('StarcharterSam', 'Data Analyst', 10),
      _PlaceholderPlayer('CosmicCompass', 'Airborne', 9),
      _PlaceholderPlayer('AuroraAviator', 'Social Butterfly', 8),
      _PlaceholderPlayer('ZenithZara', null, 7),
      _PlaceholderPlayer('NadirNate', null, 7),
      _PlaceholderPlayer('SolsticeSally', null, 6),
      _PlaceholderPlayer('EquinoxEd', null, 5),
      _PlaceholderPlayer('PerihelionPete', null, 5),
      _PlaceholderPlayer('AphelionAnna', null, 4),
      _PlaceholderPlayer('You', 'Novice Vexillologist', 6),
      _PlaceholderPlayer('EclipseEmma', null, 3),
      _PlaceholderPlayer('LunarLeo', null, 2),
      _PlaceholderPlayer('TransitTina', null, 1),
    ];

    const int baseScore = 9800;

    return List<LeaderboardEntry>.generate(players.length, (i) {
      final player = players[i];
      final rank = i + 1;

      // Tighter spread for daily boards.
      final int rawScore =
          baseScore - (rank - 1) * 210 + (rank.isEven ? 25 : -15);

      // Daily times are faster (single challenge).
      final timeMs = 45000 + (rank * 2100) + (rank.isOdd ? 310 : -180);

      final isCurrentPlayer = player.name == 'You';

      return LeaderboardEntry(
        playerId: isCurrentPlayer ? 'current_player' : 'daily_player_$rank',
        username: player.name,
        score: rawScore,
        bestTime: Duration(milliseconds: timeMs),
        rank: rank,
        gamesPlayed: 1,
        isLicensed: false,
        displayTitle: player.title,
        level: player.level,
      );
    });
  }

  /// 50 entries for the all-time hall of fame with massive scores.
  static List<LeaderboardEntry> _buildAllTimeEntries() {
    const legends = <_PlaceholderPlayer>[
      _PlaceholderPlayer('xx_MercatorGOAT_xx', 'Perfect License', 25),
      _PlaceholderPlayer('VexillumMaximus', 'Flag Savant', 24),
      _PlaceholderPlayer('SovereignSkies', 'Capital Commander', 23),
      _PlaceholderPlayer('TheLastAtlas', 'Supersonic', 23),
      _PlaceholderPlayer('ProjectionQueen', 'Statistics Savant', 22),
      _PlaceholderPlayer('GnomonicGod', 'Outline Oracle', 22),
      _PlaceholderPlayer('BoundaryBoss', 'Border Lord', 21),
      _PlaceholderPlayer('PlateCarreeKing', 'Challenge Legend', 21),
      _PlaceholderPlayer('GeodesicDream', 'Data Professor', 20),
      _PlaceholderPlayer('EllipsoidElite', 'Shadow Cartographer', 20),
      _PlaceholderPlayer('OrthographicOwl', 'Frontier Master', 19),
      _PlaceholderPlayer('StereographicStar', 'Capital Connoisseur', 19),
      _PlaceholderPlayer('AzimuthalAlpha', 'Speed Demon', 18),
      _PlaceholderPlayer('ConicCrusader', 'Lightning', 18),
      _PlaceholderPlayer('CylindricalChamp', 'Flag Expert', 17),
      _PlaceholderPlayer('SinusoidalSage', 'Shape Shifter', 17),
      _PlaceholderPlayer('MollweideMonarch', 'Boundary Expert', 16),
      _PlaceholderPlayer('RobinsonRuler', 'Number Cruncher', 16),
      _PlaceholderPlayer('WinkelTripelWiz', 'Mile High Club', 15),
      _PlaceholderPlayer('FullerFlyer', 'Frequent Flier', 15),
      _PlaceholderPlayer('TransverseTitan', 'Capital Navigator', 14),
      _PlaceholderPlayer('ObliqueOracle', 'Shape Detective', 14),
      _PlaceholderPlayer('PolyconicPilot', 'Data Analyst', 13),
      _PlaceholderPlayer('PseudoConicPete', 'Border Guard', 13),
      _PlaceholderPlayer('GoodeHomoloPro', 'Quick Draw', 12),
      _PlaceholderPlayer('EckertEagle', 'Flag Enthusiast', 12),
      _PlaceholderPlayer('BonneBlaze', 'Social Butterfly', 11),
      _PlaceholderPlayer('LambertLion', 'Silhouette Spotter', 11),
      _PlaceholderPlayer('AlbersAce', 'Capital Cadet', 10),
      _PlaceholderPlayer('MillerMaster', 'Airborne', 10),
      _PlaceholderPlayer('PetersPathfinder', 'Border Patrol', 9),
      _PlaceholderPlayer('CassiniCrafter', 'Friendly Flier', 9),
      _PlaceholderPlayer('AuthalicAndy', null, 8),
      _PlaceholderPlayer('ConformalCarla', null, 8),
      _PlaceholderPlayer('EquidistantEve', null, 7),
      _PlaceholderPlayer('CompromiseChris', null, 7),
      _PlaceholderPlayer('RetroazimuthalRon', null, 6),
      _PlaceholderPlayer('GnomonicGrace', null, 6),
      _PlaceholderPlayer('ApianAnna', null, 5),
      _PlaceholderPlayer('BehrmannBen', null, 5),
      _PlaceholderPlayer('CrasterClaire', null, 4),
      _PlaceholderPlayer('You', 'Novice Vexillologist', 6),
      _PlaceholderPlayer('FaheyFrank', null, 4),
      _PlaceholderPlayer('GallGreta', null, 3),
      _PlaceholderPlayer('KavraiskyyKate', null, 3),
      _PlaceholderPlayer('LoxodromeLouis', null, 3),
      _PlaceholderPlayer('NaturalEarthNina', null, 2),
      _PlaceholderPlayer('QuarticQuinn', null, 2),
      _PlaceholderPlayer('ToroidalTom', null, 1),
      _PlaceholderPlayer('VerticalVera', null, 1),
    ];

    const int baseScore = 285000;

    return List<LeaderboardEntry>.generate(legends.length, (i) {
      final player = legends[i];
      final rank = i + 1;

      // All-time scores are much larger (cumulative across seasons).
      final int rawScore;
      if (rank <= 3) {
        rawScore = baseScore - (rank - 1) * 4200;
      } else if (rank <= 10) {
        rawScore = baseScore - 8400 - (rank - 3) * 3100;
      } else if (rank <= 25) {
        rawScore = baseScore - 30100 - (rank - 10) * 2400;
      } else {
        rawScore = baseScore - 66100 - (rank - 25) * 1800;
      }

      // Variance per rank.
      final int score = rawScore + (rank.isEven ? 520 : -380);

      // Best time across all games -- top players have sub-minute bests.
      final timeMs = 38000 + (rank * 1200) + (rank.isOdd ? 550 : -300);

      // All-time games played -- top players have thousands.
      final gamesPlayed = (8000 - rank * 120).clamp(50, 8000);

      final isCurrentPlayer = player.name == 'You';

      return LeaderboardEntry(
        playerId: isCurrentPlayer ? 'current_player' : 'alltime_player_$rank',
        username: player.name,
        score: score,
        bestTime: Duration(milliseconds: timeMs),
        rank: rank,
        gamesPlayed: gamesPlayed,
        isLicensed: false,
        displayTitle: player.title,
        level: player.level,
        streak: rank <= 3 ? (30 - rank * 5) : (rank <= 10 ? 10 : 0),
      );
    });
  }

  /// 20 entries for a regional (EU) board.
  static List<LeaderboardEntry> _buildRegionalEntries() {
    const players = <_PlaceholderPlayerRegion>[
      _PlaceholderPlayerRegion('AlpineAviator', 'Lightning', 17, 'CH'),
      _PlaceholderPlayerRegion('FjordFlyer', 'Speed Demon', 16, 'NO'),
      _PlaceholderPlayerRegion('MediterraneanMax', 'Flag Expert', 15, 'IT'),
      _PlaceholderPlayerRegion('BalticBaron', 'Quick Draw', 14, 'LT'),
      _PlaceholderPlayerRegion('IberianIsa', 'Capital Navigator', 13, 'ES'),
      _PlaceholderPlayerRegion('CarpathianCara', 'Shape Detective', 12, 'RO'),
      _PlaceholderPlayerRegion('NordicNova', 'Border Guard', 11, 'SE'),
      _PlaceholderPlayerRegion('AdriaticAndy', 'Data Analyst', 10, 'HR'),
      _PlaceholderPlayerRegion('CelticCasey', null, 9, 'IE'),
      _PlaceholderPlayerRegion('HellenicHero', null, 8, 'GR'),
      _PlaceholderPlayerRegion('DanubianDave', null, 7, 'AT'),
      _PlaceholderPlayerRegion('PyreneesPiper', null, 7, 'FR'),
      _PlaceholderPlayerRegion('BeneluxBee', null, 6, 'BE'),
      _PlaceholderPlayerRegion('VistullaVic', null, 5, 'PL'),
      _PlaceholderPlayerRegion('RhineRover', null, 5, 'DE'),
      _PlaceholderPlayerRegion('You', 'Novice Vexillologist', 6, 'GB'),
      _PlaceholderPlayerRegion('ThamesTheo', null, 4, 'GB'),
      _PlaceholderPlayerRegion('SeineSophie', null, 3, 'FR'),
      _PlaceholderPlayerRegion('TiberTina', null, 2, 'IT'),
      _PlaceholderPlayerRegion('ElbeElla', null, 1, 'DE'),
    ];

    const int baseScore = 11200;

    return List<LeaderboardEntry>.generate(players.length, (i) {
      final player = players[i];
      final rank = i + 1;

      final int rawScore =
          baseScore - (rank - 1) * 280 + (rank.isEven ? 45 : -30);
      final timeMs = 68000 + (rank * 2000) + (rank.isOdd ? 350 : -200);
      final gamesPlayed = (300 - rank * 10).clamp(15, 300);

      final isCurrentPlayer = player.name == 'You';

      return LeaderboardEntry(
        playerId: isCurrentPlayer ? 'current_player' : 'regional_player_$rank',
        username: player.name,
        score: rawScore,
        bestTime: Duration(milliseconds: timeMs),
        rank: rank,
        gamesPlayed: gamesPlayed,
        isLicensed: false,
        displayTitle: player.title,
        level: player.level,
        countryCode: player.countryCode,
      );
    });
  }

  /// 15 entries for a friends-only board.
  static List<LeaderboardEntry> _buildFriendsEntries() {
    const players = <_PlaceholderPlayer>[
      _PlaceholderPlayer('BestMateBarry', 'Challenge Legend', 14),
      _PlaceholderPlayer('SisterSarah', 'Flag Expert', 12),
      _PlaceholderPlayer('DadJokesDave', 'Frequent Flier', 10),
      _PlaceholderPlayer('ColleagueCarl', 'Quick Draw', 9),
      _PlaceholderPlayer('NeighbourNancy', 'Airborne', 8),
      _PlaceholderPlayer('CousinKev', null, 7),
      _PlaceholderPlayer('You', 'Novice Vexillologist', 6),
      _PlaceholderPlayer('OldSchoolOllie', null, 6),
      _PlaceholderPlayer('GymBuddyGina', null, 5),
      _PlaceholderPlayer('WorkmatePat', null, 4),
      _PlaceholderPlayer('BookClubBen', null, 3),
      _PlaceholderPlayer('YogaYolanda', null, 3),
      _PlaceholderPlayer('PubQuizPaul', null, 2),
      _PlaceholderPlayer('FootiePhil', null, 2),
      _PlaceholderPlayer('CasualChris', null, 1),
    ];

    const int baseScore = 8500;

    return List<LeaderboardEntry>.generate(players.length, (i) {
      final player = players[i];
      final rank = i + 1;

      final int rawScore =
          baseScore - (rank - 1) * 350 + (rank.isEven ? 60 : -40);
      final timeMs = 80000 + (rank * 2500) + (rank.isOdd ? 400 : -250);
      final gamesPlayed = (200 - rank * 10).clamp(5, 200);

      final isCurrentPlayer = player.name == 'You';

      return LeaderboardEntry(
        playerId: isCurrentPlayer ? 'current_player' : 'friend_player_$rank',
        username: player.name,
        score: rawScore,
        bestTime: Duration(milliseconds: timeMs),
        rank: rank,
        gamesPlayed: gamesPlayed,
        isLicensed: false,
        displayTitle: player.title,
        level: player.level,
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Private placeholder helpers
// ---------------------------------------------------------------------------

/// A fake player with a name, optional social title, and level.
class _PlaceholderPlayer {
  const _PlaceholderPlayer(this.name, this.title, this.level);

  final String name;
  final String? title;
  final int level;
}

/// A fake player with an additional country code for regional boards.
class _PlaceholderPlayerRegion extends _PlaceholderPlayer {
  const _PlaceholderPlayerRegion(
    super.name,
    super.title,
    super.level,
    this.countryCode,
  );

  final String countryCode;
}
