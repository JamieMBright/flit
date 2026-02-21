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
  });

  final int rank;
  final String playerId;
  final String playerName;
  final Duration time;
  final int score;
  final String? avatarUrl;
  final String? countryCode;
  final DateTime? timestamp;

  Map<String, dynamic> toJson() => {
    'rank': rank,
    'player_id': playerId,
    'player_name': playerName,
    'time_ms': time.inMilliseconds,
    'score': score,
    'avatar_url': avatarUrl,
    'country_code': countryCode,
    'timestamp': timestamp?.toIso8601String(),
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

/// Board type tabs shown on the leaderboard screen.
///
/// Each tab maps to a different SQL view or service method.
enum LeaderboardTab { global, daily, regional, friends }

extension LeaderboardTabExtension on LeaderboardTab {
  String get displayName {
    switch (this) {
      case LeaderboardTab.global:
        return 'Global';
      case LeaderboardTab.daily:
        return 'Today';
      case LeaderboardTab.regional:
        return 'Regional';
      case LeaderboardTab.friends:
        return 'Friends';
    }
  }
}
