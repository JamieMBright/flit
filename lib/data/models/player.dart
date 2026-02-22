/// Player profile model.
class Player {
  const Player({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.level = 1,
    this.xp = 0,
    this.coins = 0,
    this.gamesPlayed = 0,
    this.bestScore,
    this.bestTime,
    this.totalFlightTime = Duration.zero,
    this.countriesFound = 0,
    this.flagsCorrect = 0,
    this.capitalsCorrect = 0,
    this.outlinesCorrect = 0,
    this.bordersCorrect = 0,
    this.statsCorrect = 0,
    this.bestStreak = 0,
    this.adminRole,
    this.createdAt,
  });

  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final int level;
  final int xp;
  final int coins;
  final int gamesPlayed;

  /// Best daily scramble score (points).
  final int? bestScore;
  final Duration? bestTime;

  /// Total cumulative flight time across all sessions.
  final Duration totalFlightTime;

  /// Total countries successfully found across all sessions.
  final int countriesFound;

  /// Per-clue-type correct answer counts.
  /// Tracked incrementally as gameplay events fire.
  final int flagsCorrect;
  final int capitalsCorrect;
  final int outlinesCorrect;
  final int bordersCorrect;
  final int statsCorrect;

  /// Longest streak of consecutive correct answers ever achieved.
  final int bestStreak;

  /// Admin role: null = regular user, 'moderator' = limited admin, 'owner' = god mode.
  final String? adminRole;

  /// Whether this player has any admin access.
  bool get isAdmin => adminRole != null;

  /// Whether this player has owner (god mode) access.
  bool get isOwner => adminRole == 'owner';

  /// Whether this player has moderator access.
  bool get isModerator => adminRole == 'moderator';

  final DateTime? createdAt;

  /// XP required for next level
  int get xpForNextLevel => level * 100;

  /// Progress to next level (0.0 to 1.0)
  double get levelProgress => xp / xpForNextLevel;

  /// Display name is the username — no separate display name concept.
  String get name => username;

  Player copyWith({
    String? id,
    String? username,
    String? displayName,
    String? avatarUrl,
    int? level,
    int? xp,
    int? coins,
    int? gamesPlayed,
    int? bestScore,
    Duration? bestTime,
    Duration? totalFlightTime,
    int? countriesFound,
    int? flagsCorrect,
    int? capitalsCorrect,
    int? outlinesCorrect,
    int? bordersCorrect,
    int? statsCorrect,
    int? bestStreak,
    String? adminRole,
    DateTime? createdAt,
  }) => Player(
    id: id ?? this.id,
    username: username ?? this.username,
    displayName: displayName ?? this.displayName,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    level: level ?? this.level,
    xp: xp ?? this.xp,
    coins: coins ?? this.coins,
    gamesPlayed: gamesPlayed ?? this.gamesPlayed,
    bestScore: bestScore ?? this.bestScore,
    bestTime: bestTime ?? this.bestTime,
    totalFlightTime: totalFlightTime ?? this.totalFlightTime,
    countriesFound: countriesFound ?? this.countriesFound,
    flagsCorrect: flagsCorrect ?? this.flagsCorrect,
    capitalsCorrect: capitalsCorrect ?? this.capitalsCorrect,
    outlinesCorrect: outlinesCorrect ?? this.outlinesCorrect,
    bordersCorrect: bordersCorrect ?? this.bordersCorrect,
    statsCorrect: statsCorrect ?? this.statsCorrect,
    bestStreak: bestStreak ?? this.bestStreak,
    adminRole: adminRole ?? this.adminRole,
    createdAt: createdAt ?? this.createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'display_name': displayName,
    'avatar_url': avatarUrl,
    'level': level,
    'xp': xp,
    'coins': coins,
    'games_played': gamesPlayed,
    'best_score': bestScore,
    'best_time_ms': bestTime?.inMilliseconds,
    'total_flight_time_ms': totalFlightTime.inMilliseconds,
    'countries_found': countriesFound,
    'flags_correct': flagsCorrect,
    'capitals_correct': capitalsCorrect,
    'outlines_correct': outlinesCorrect,
    'borders_correct': bordersCorrect,
    'stats_correct': statsCorrect,
    'best_streak': bestStreak,
    'admin_role': adminRole,
    'created_at': createdAt?.toIso8601String(),
  };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
    id: json['id'] as String,
    username: json['username'] as String,
    displayName: json['display_name'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    level: json['level'] as int? ?? 1,
    xp: json['xp'] as int? ?? 0,
    coins: json['coins'] as int? ?? 0,
    gamesPlayed: json['games_played'] as int? ?? 0,
    bestScore: json['best_score'] as int?,
    bestTime: json['best_time_ms'] != null
        ? Duration(milliseconds: json['best_time_ms'] as int)
        : null,
    totalFlightTime: json['total_flight_time_ms'] != null
        ? Duration(milliseconds: json['total_flight_time_ms'] as int)
        : Duration.zero,
    countriesFound: json['countries_found'] as int? ?? 0,
    flagsCorrect: json['flags_correct'] as int? ?? 0,
    capitalsCorrect: json['capitals_correct'] as int? ?? 0,
    outlinesCorrect: json['outlines_correct'] as int? ?? 0,
    bordersCorrect: json['borders_correct'] as int? ?? 0,
    statsCorrect: json['stats_correct'] as int? ?? 0,
    bestStreak: json['best_streak'] as int? ?? 0,
    adminRole: json['admin_role'] as String?,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : null,
  );
}
