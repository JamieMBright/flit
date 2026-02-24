/// A single entry on the leaderboard.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.playerId,
    required this.playerName,
    required this.time,
    required this.score,
    this.avatarUrl,
    this.countryCode,
    this.timestamp,
    this.roundEmojis,
    this.equippedPlaneId,
    this.level,
  });

  final int rank;
  final String playerId;
  final String playerName;
  final Duration time;
  final int score;
  final String? avatarUrl;
  final String? countryCode;
  final DateTime? timestamp;
  final String? roundEmojis;
  final String? equippedPlaneId;
  final int? level;

  LeaderboardEntry copyWith({int? rank, String? equippedPlaneId}) =>
      LeaderboardEntry(
        rank: rank ?? this.rank,
        playerId: playerId,
        playerName: playerName,
        time: time,
        score: score,
        avatarUrl: avatarUrl,
        countryCode: countryCode,
        timestamp: timestamp,
        roundEmojis: roundEmojis,
        equippedPlaneId: equippedPlaneId ?? this.equippedPlaneId,
        level: level,
      );

  Map<String, dynamic> toJson() => {
    'rank': rank,
    'player_id': playerId,
    'player_name': playerName,
    'time_ms': time.inMilliseconds,
    'score': score,
    'avatar_url': avatarUrl,
    'country_code': countryCode,
    'timestamp': timestamp?.toIso8601String(),
    'round_emojis': roundEmojis,
    'equipped_plane_id': equippedPlaneId,
    'level': level,
  };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        rank: json['rank'] as int,
        playerId: json['player_id'] as String,
        playerName: json['player_name'] as String,
        time: Duration(milliseconds: json['time_ms'] as int),
        score: json['score'] as int,
        avatarUrl: json['avatar_url'] as String?,
        countryCode: json['country_code'] as String?,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : null,
        roundEmojis: json['round_emojis'] as String?,
        equippedPlaneId: json['equipped_plane_id'] as String?,
        level: json['level'] as int?,
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
