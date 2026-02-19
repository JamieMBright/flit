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
class HeadToHead {
  const HeadToHead({
    required this.friendId,
    required this.friendName,
    required this.wins,
    required this.losses,
    required this.totalChallenges,
    this.lastPlayed,
  });

  final String friendId;
  final String friendName;
  final int wins;
  final int losses;
  final int totalChallenges;
  final DateTime? lastPlayed;

  int get draws => totalChallenges - wins - losses;

  String get record => '$wins - $losses';

  String get leadText {
    if (wins > losses) return 'You lead';
    if (losses > wins) return 'They lead';
    return 'Tied';
  }

  Map<String, dynamic> toJson() => {
    'friend_id': friendId,
    'friend_name': friendName,
    'wins': wins,
    'losses': losses,
    'total_challenges': totalChallenges,
    'last_played': lastPlayed?.toIso8601String(),
  };

  factory HeadToHead.fromJson(Map<String, dynamic> json) => HeadToHead(
    friendId: json['friend_id'] as String,
    friendName: json['friend_name'] as String,
    wins: json['wins'] as int? ?? 0,
    losses: json['losses'] as int? ?? 0,
    totalChallenges: json['total_challenges'] as int? ?? 0,
    lastPlayed: json['last_played'] != null
        ? DateTime.parse(json['last_played'] as String)
        : null,
  );
}
