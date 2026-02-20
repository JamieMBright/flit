// Leaderboard models supporting global, daily/seasonal/all-time boards,
// regional and friends boards, and annual cosmetic rewards.
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

  static const List<LeaderboardReward> placeholderRewards = [];
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

  /// Returns an empty leaderboard for the given type (no fake data).
  static Leaderboard empty(LeaderboardType type) {
    return Leaderboard(
      type: type,
      timeframe: LeaderboardTimeframe.allTime,
      entries: const [],
      lastUpdated: DateTime.now(),
      totalEntries: 0,
    );
  }
}
