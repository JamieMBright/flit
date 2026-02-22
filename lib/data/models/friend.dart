import 'avatar_config.dart';

/// Friendship status between two players.
enum FriendshipStatus { pending, accepted, declined }

/// A friend connection between two players.
class Friend {
  const Friend({
    required this.id,
    required this.playerId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.avatarConfig,
    this.status = FriendshipStatus.accepted,
    this.isOnline = false,
    this.lastSeen,
  });

  final String id;
  final String playerId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final AvatarConfig? avatarConfig;
  final FriendshipStatus status;
  final bool isOnline;
  final DateTime? lastSeen;

  String get name => displayName ?? username;

  Map<String, dynamic> toJson() => {
    'id': id,
    'player_id': playerId,
    'username': username,
    'display_name': displayName,
    'avatar_url': avatarUrl,
    if (avatarConfig != null) 'avatar_config': avatarConfig!.toJson(),
    'status': status.name,
    'is_online': isOnline,
    'last_seen': lastSeen?.toIso8601String(),
  };

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
    id: json['id'] as String,
    playerId: json['player_id'] as String,
    username: json['username'] as String,
    displayName: json['display_name'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    avatarConfig: json['avatar_config'] != null
        ? AvatarConfig.fromJson(json['avatar_config'] as Map<String, dynamic>)
        : null,
    status: FriendshipStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => FriendshipStatus.pending,
    ),
    isOnline: json['is_online'] as bool? ?? false,
    lastSeen: json['last_seen'] != null
        ? DateTime.parse(json['last_seen'] as String)
        : null,
  );
}

/// Head-to-head record between two players.
///
/// Includes lifetime totals, last-10-game breakdown, and last-game result.
class HeadToHead {
  const HeadToHead({
    required this.friendId,
    required this.friendName,
    required this.wins,
    required this.losses,
    required this.totalChallenges,
    this.last10Wins = 0,
    this.last10Losses = 0,
    this.last10Total = 0,
    this.lastGameWon,
    this.lastPlayed,
  });

  final String friendId;
  final String friendName;

  /// Lifetime totals.
  final int wins;
  final int losses;
  final int totalChallenges;

  /// Last 10 games breakdown.
  final int last10Wins;
  final int last10Losses;
  final int last10Total;

  /// Result of the most recent game: true = you won, false = you lost,
  /// null = draw or no games played.
  final bool? lastGameWon;

  final DateTime? lastPlayed;

  int get draws => totalChallenges - wins - losses;

  String get record => '$wins - $losses';

  String get leadText {
    if (wins > losses) return 'You lead';
    if (losses > wins) return 'They lead';
    return 'Tied';
  }

  String get last10Record => '$last10Wins - $last10Losses';

  String get lastGameText {
    if (lastGameWon == null) return 'N/A';
    return lastGameWon! ? 'Won' : 'Lost';
  }

  Map<String, dynamic> toJson() => {
    'friend_id': friendId,
    'friend_name': friendName,
    'wins': wins,
    'losses': losses,
    'total_challenges': totalChallenges,
    'last_10_wins': last10Wins,
    'last_10_losses': last10Losses,
    'last_10_total': last10Total,
    'last_game_won': lastGameWon,
    'last_played': lastPlayed?.toIso8601String(),
  };

  factory HeadToHead.fromJson(Map<String, dynamic> json) => HeadToHead(
    friendId: json['friend_id'] as String,
    friendName: json['friend_name'] as String,
    wins: json['wins'] as int? ?? 0,
    losses: json['losses'] as int? ?? 0,
    totalChallenges: json['total_challenges'] as int? ?? 0,
    last10Wins: json['last_10_wins'] as int? ?? 0,
    last10Losses: json['last_10_losses'] as int? ?? 0,
    last10Total: json['last_10_total'] as int? ?? 0,
    lastGameWon: json['last_game_won'] as bool?,
    lastPlayed: json['last_played'] != null
        ? DateTime.parse(json['last_played'] as String)
        : null,
  );
}
