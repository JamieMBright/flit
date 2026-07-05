/// A single entry on the leaderboard.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.playerId,
    required this.playerName,
    required this.time,
    required this.score,
    this.avatarUrl,
    this.avatarConfigJson,
    this.countryCode,
    this.timestamp,
    this.roundEmojis,
    this.roundDetails,
    this.equippedPlaneId,
    this.level,
    this.combinedEfficiencyBps,
  });

  final int rank;
  final String playerId;
  final String playerName;
  final Duration time;
  final int score;
  final String? avatarUrl;

  /// Raw avatar config JSON from `account_state.avatar_config`.
  /// Used for offline avatar composition when [avatarUrl] is unavailable.
  final Map<String, dynamic>? avatarConfigJson;

  final String? countryCode;
  final DateTime? timestamp;
  final String? roundEmojis;

  /// Per-round detail data stored as a JSON list. Each element contains:
  /// `country_name`, `country_code`, `clue_type`, `time_ms`, `score`,
  /// `raw_score`, `hints_used`, `completed`.
  final List<dynamic>? roundDetails;
  final String? equippedPlaneId;
  final int? level;

  /// Combined-daily breakdown: `scores.region` → efficiency basis points
  /// (0–10000, 8740 = 87.40%). Only set on entries returned by
  /// `fetchCombinedDailyLeaderboard`, where [score] holds the combined
  /// efficiency in basis points. A missing region key means unplayed (0%).
  final Map<String, int>? combinedEfficiencyBps;

  LeaderboardEntry copyWith({
    int? rank,
    String? equippedPlaneId,
    Map<String, dynamic>? avatarConfigJson,
  }) =>
      LeaderboardEntry(
        rank: rank ?? this.rank,
        playerId: playerId,
        playerName: playerName,
        time: time,
        score: score,
        avatarUrl: avatarUrl,
        avatarConfigJson: avatarConfigJson ?? this.avatarConfigJson,
        countryCode: countryCode,
        timestamp: timestamp,
        roundEmojis: roundEmojis,
        roundDetails: roundDetails,
        equippedPlaneId: equippedPlaneId ?? this.equippedPlaneId,
        level: level,
        combinedEfficiencyBps: combinedEfficiencyBps,
      );

  Map<String, dynamic> toJson() => {
        'rank': rank,
        'player_id': playerId,
        'player_name': playerName,
        'time_ms': time.inMilliseconds,
        'score': score,
        'avatar_url': avatarUrl,
        'avatar_config': avatarConfigJson,
        'country_code': countryCode,
        'timestamp': timestamp?.toIso8601String(),
        'round_emojis': roundEmojis,
        'round_details': roundDetails,
        'equipped_plane_id': equippedPlaneId,
        'level': level,
        'combined_efficiency_bps': combinedEfficiencyBps,
      };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        rank: json['rank'] as int,
        playerId: json['player_id'] as String,
        playerName: json['player_name'] as String,
        time: Duration(milliseconds: json['time_ms'] as int),
        score: json['score'] as int,
        avatarUrl: json['avatar_url'] as String?,
        avatarConfigJson: json['avatar_config'] as Map<String, dynamic>?,
        countryCode: json['country_code'] as String?,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : null,
        roundEmojis: json['round_emojis'] as String?,
        roundDetails: json['round_details'] as List<dynamic>?,
        equippedPlaneId: json['equipped_plane_id'] as String?,
        level: json['level'] as int?,
        combinedEfficiencyBps:
            (json['combined_efficiency_bps'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v as int)),
      );
}

/// Time period for leaderboard filtering (used by the legacy fetchLeaderboard).
enum LeaderboardPeriod { daily, weekly, monthly, yearly, allTime }

extension LeaderboardPeriodExtension on LeaderboardPeriod {
  String get displayName {
    switch (this) {
      case LeaderboardPeriod.daily:
        return 'Today';
      case LeaderboardPeriod.weekly:
        return 'This Week';
      case LeaderboardPeriod.monthly:
        return 'This Month';
      case LeaderboardPeriod.yearly:
        return 'This Year';
      case LeaderboardPeriod.allTime:
        return 'All Time';
    }
  }
}

/// Top-level game mode tab.
enum GameModeTab { dailyScramble, trainingFlight }

extension GameModeTabExtension on GameModeTab {
  String get displayName {
    switch (this) {
      case GameModeTab.dailyScramble:
        return 'Daily Scramble';
      case GameModeTab.trainingFlight:
        return 'Training Flight';
    }
  }
}

/// Top-level leaderboard mode tab.
enum LeaderboardMode {
  dailyScramble,
  trainingFlight,
  flightBriefing,
  dailyTriangulation,

  /// Combined daily board: normalized efficiency across all three dailies.
  dailyCombined,
}

extension LeaderboardModeExtension on LeaderboardMode {
  String get displayName {
    switch (this) {
      case LeaderboardMode.dailyScramble:
        return 'DAILY SCRAMBLE';
      case LeaderboardMode.trainingFlight:
        return 'TRAINING FLIGHT';
      case LeaderboardMode.flightBriefing:
        return 'FLIGHT BRIEFING';
      case LeaderboardMode.dailyTriangulation:
        return 'TRIANGULATION';
      case LeaderboardMode.dailyCombined:
        return 'COMBINED';
    }
  }

  /// The region filter value used in the `scores` table.
  String? get regionFilter {
    switch (this) {
      case LeaderboardMode.dailyScramble:
        return 'daily';
      case LeaderboardMode.trainingFlight:
        return null; // neq 'daily' and neq 'briefing'
      case LeaderboardMode.flightBriefing:
        return 'briefing';
      case LeaderboardMode.dailyTriangulation:
        return 'daily_triangulation';
      case LeaderboardMode.dailyCombined:
        return null; // Spans all three daily regions.
    }
  }
}

/// Time period sub-tab.
enum TimeframeTab { today, lastMonth, allTime }

extension TimeframeTabExtension on TimeframeTab {
  String get displayName {
    switch (this) {
      case TimeframeTab.today:
        return 'Today';
      case TimeframeTab.lastMonth:
        return 'Last Month';
      case TimeframeTab.allTime:
        return 'All Time';
    }
  }
}

/// Sort order for leaderboard entries.
enum LeaderboardSort { score, proficiency, time }

extension LeaderboardSortExtension on LeaderboardSort {
  String get displayName {
    switch (this) {
      case LeaderboardSort.score:
        return 'Score';
      case LeaderboardSort.proficiency:
        return 'Proficiency';
      case LeaderboardSort.time:
        return 'Time';
    }
  }
}
