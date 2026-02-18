// Live group game mode models for real-time multiplayer sessions.
//
// Live Group is a premium feature where a subscriber hosts a lobby of
// friends (up to 8 players). All players receive the same seeded questions
// and race through rounds while a streaming leaderboard shows progress.
//
// Two round modes are supported:
// - **standard** -- everyone plays every round; best cumulative score wins.
// - **firstToAnswer** -- the first correct answer claims the round.

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// Lifecycle status of a live group session.
enum LiveGroupStatus {
  lobby, // Host is waiting for players to join
  inProgress, // Game is actively being played
  completed, // All rounds finished
  cancelled, // Host or system cancelled the session
}

/// How each round is scored.
enum LiveRoundMode {
  /// Everyone plays the round; highest score wins.
  standard,

  /// First correct answer takes the round -- speed is everything.
  firstToAnswer,
}

// ---------------------------------------------------------------------------
// LiveGroupPlayer
// ---------------------------------------------------------------------------

/// A player participating in a live group session.
class LiveGroupPlayer {
  const LiveGroupPlayer({
    required this.id,
    required this.username,
    this.isHost = false,
    this.isSubscriber = true,
    this.score = 0,
    this.roundsWon = 0,
    this.currentRound = 0,
    this.lastAnswerTime,
    this.isFinished = false,
  });

  final String id;
  final String username;

  /// Whether this player created the session.
  final bool isHost;

  /// Invited non-subscribers are marked so the UI can badge them.
  final bool isSubscriber;

  /// Cumulative score across all completed rounds.
  final int score;

  /// Number of rounds this player has won outright.
  final int roundsWon;

  /// The round this player is currently on (streams to the leaderboard).
  final int currentRound;

  /// Time taken on the most recently completed round.
  final Duration? lastAnswerTime;

  /// Whether this player has finished all rounds.
  final bool isFinished;

  // ── copyWith ─────────────────────────────────────────────────────────

  LiveGroupPlayer copyWith({
    String? id,
    String? username,
    bool? isHost,
    bool? isSubscriber,
    int? score,
    int? roundsWon,
    int? currentRound,
    Duration? lastAnswerTime,
    bool? isFinished,
  }) =>
      LiveGroupPlayer(
        id: id ?? this.id,
        username: username ?? this.username,
        isHost: isHost ?? this.isHost,
        isSubscriber: isSubscriber ?? this.isSubscriber,
        score: score ?? this.score,
        roundsWon: roundsWon ?? this.roundsWon,
        currentRound: currentRound ?? this.currentRound,
        lastAnswerTime: lastAnswerTime ?? this.lastAnswerTime,
        isFinished: isFinished ?? this.isFinished,
      );

  // ── Serialisation ────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'is_host': isHost,
        'is_subscriber': isSubscriber,
        'score': score,
        'rounds_won': roundsWon,
        'current_round': currentRound,
        'last_answer_time_ms': lastAnswerTime?.inMilliseconds,
        'is_finished': isFinished,
      };

  factory LiveGroupPlayer.fromJson(Map<String, dynamic> json) =>
      LiveGroupPlayer(
        id: json['id'] as String,
        username: json['username'] as String,
        isHost: json['is_host'] as bool? ?? false,
        isSubscriber: json['is_subscriber'] as bool? ?? true,
        score: json['score'] as int? ?? 0,
        roundsWon: json['rounds_won'] as int? ?? 0,
        currentRound: json['current_round'] as int? ?? 0,
        lastAnswerTime: json['last_answer_time_ms'] != null
            ? Duration(milliseconds: json['last_answer_time_ms'] as int)
            : null,
        isFinished: json['is_finished'] as bool? ?? false,
      );
}

// ---------------------------------------------------------------------------
// LiveGroupAnswer
// ---------------------------------------------------------------------------

/// A single player's answer to a round.
class LiveGroupAnswer {
  const LiveGroupAnswer({
    required this.playerId,
    required this.answer,
    required this.isCorrect,
    required this.timeTaken,
    this.pointsEarned = 0,
  });

  final String playerId;
  final String answer;
  final bool isCorrect;
  final Duration timeTaken;
  final int pointsEarned;

  // ── Serialisation ────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'player_id': playerId,
        'answer': answer,
        'is_correct': isCorrect,
        'time_taken_ms': timeTaken.inMilliseconds,
        'points_earned': pointsEarned,
      };

  factory LiveGroupAnswer.fromJson(Map<String, dynamic> json) =>
      LiveGroupAnswer(
        playerId: json['player_id'] as String,
        answer: json['answer'] as String,
        isCorrect: json['is_correct'] as bool,
        timeTaken: Duration(milliseconds: json['time_taken_ms'] as int),
        pointsEarned: json['points_earned'] as int? ?? 0,
      );
}

// ---------------------------------------------------------------------------
// LiveGroupRound
// ---------------------------------------------------------------------------

/// The state and results of a single round in a live group session.
class LiveGroupRound {
  const LiveGroupRound({
    required this.roundNumber,
    required this.countryAnswer,
    this.answers = const {},
    this.firstCorrectPlayerId,
    this.fastestTime,
  });

  /// 1-based round index.
  final int roundNumber;

  /// The correct country code for this round.
  final String countryAnswer;

  /// Each player's answer, keyed by player ID.
  final Map<String, LiveGroupAnswer> answers;

  /// The first player to answer correctly (used in [LiveRoundMode.firstToAnswer]).
  final String? firstCorrectPlayerId;

  /// The fastest correct answer time across all players.
  final Duration? fastestTime;

  /// Whether every player has submitted an answer.
  bool isComplete(int playerCount) => answers.length >= playerCount;

  /// All correct answers sorted by time taken (fastest first).
  List<LiveGroupAnswer> get correctAnswersBySpeed {
    return answers.values.where((a) => a.isCorrect).toList()
      ..sort((a, b) => a.timeTaken.compareTo(b.timeTaken));
  }

  // ── Serialisation ────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'round_number': roundNumber,
        'country_answer': countryAnswer,
        'answers': answers.map((key, value) => MapEntry(key, value.toJson())),
        'first_correct_player_id': firstCorrectPlayerId,
        'fastest_time_ms': fastestTime?.inMilliseconds,
      };

  factory LiveGroupRound.fromJson(Map<String, dynamic> json) => LiveGroupRound(
        roundNumber: json['round_number'] as int,
        countryAnswer: json['country_answer'] as String,
        answers: (json['answers'] as Map<String, dynamic>?)?.map(
              (key, value) => MapEntry(
                key,
                LiveGroupAnswer.fromJson(value as Map<String, dynamic>),
              ),
            ) ??
            {},
        firstCorrectPlayerId: json['first_correct_player_id'] as String?,
        fastestTime: json['fastest_time_ms'] != null
            ? Duration(milliseconds: json['fastest_time_ms'] as int)
            : null,
      );
}

// ---------------------------------------------------------------------------
// LiveLeaderboardEntry
// ---------------------------------------------------------------------------

/// A row in the streaming leaderboard shown during a live group session.
///
/// This is a derived view model -- it is computed from the session state
/// rather than stored directly.
class LiveLeaderboardEntry {
  const LiveLeaderboardEntry({
    required this.playerId,
    required this.username,
    required this.totalScore,
    required this.roundsCompleted,
    required this.roundsWon,
    required this.totalTime,
    this.isCurrentPlayer = false,
  });

  final String playerId;
  final String username;
  final int totalScore;
  final int roundsCompleted;
  final int roundsWon;
  final Duration totalTime;

  /// Whether this entry represents the local player (for highlight styling).
  final bool isCurrentPlayer;

  // ── Serialisation ────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'player_id': playerId,
        'username': username,
        'total_score': totalScore,
        'rounds_completed': roundsCompleted,
        'rounds_won': roundsWon,
        'total_time_ms': totalTime.inMilliseconds,
        'is_current_player': isCurrentPlayer,
      };

  factory LiveLeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LiveLeaderboardEntry(
        playerId: json['player_id'] as String,
        username: json['username'] as String,
        totalScore: json['total_score'] as int,
        roundsCompleted: json['rounds_completed'] as int,
        roundsWon: json['rounds_won'] as int,
        totalTime: Duration(milliseconds: json['total_time_ms'] as int),
        isCurrentPlayer: json['is_current_player'] as bool? ?? false,
      );
}

// ---------------------------------------------------------------------------
// LiveGroupSession
// ---------------------------------------------------------------------------

/// A complete live group game session.
///
/// The host creates a session and shares an invite code with friends.
/// All players receive the same seeded questions so results are comparable.
/// Subscribers can invite non-subscribers to play.
class LiveGroupSession {
  const LiveGroupSession({
    required this.id,
    required this.hostId,
    required this.hostUsername,
    required this.seed,
    required this.status,
    this.roundMode = LiveRoundMode.standard,
    this.totalRounds = 10,
    this.currentRound = 0,
    this.enabledClueTypes = const {
      'flag',
      'outline',
      'borders',
      'capital',
      'stats',
    },
    this.players = const [],
    this.rounds = const [],
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.timeLimit,
    this.inviteCode,
  });

  final String id;
  final String hostId;
  final String hostUsername;

  /// Deterministic seed so every player receives the same questions.
  final int seed;

  final LiveGroupStatus status;
  final LiveRoundMode roundMode;

  /// Total number of rounds in this session (e.g. 5, 10, 15).
  final int totalRounds;

  /// The round currently in progress (0 = not started, 1-based during play).
  final int currentRound;

  /// Which clue types are enabled for this session.
  final Set<String> enabledClueTypes;

  /// All players currently in the session (including the host).
  final List<LiveGroupPlayer> players;

  /// Completed and in-progress rounds.
  final List<LiveGroupRound> rounds;

  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  /// Per-round time limit. `null` means unlimited.
  final Duration? timeLimit;

  /// Short code players use to join the lobby.
  final String? inviteCode;

  // ── Constraints ──────────────────────────────────────────────────────

  static const int maxPlayers = 8;
  static const int minPlayers = 2;

  // ── Derived getters ──────────────────────────────────────────────────

  /// Whether the lobby is full.
  bool get isFull => players.length >= maxPlayers;

  /// Whether there are enough players to start.
  bool get canStart =>
      players.length >= minPlayers && status == LiveGroupStatus.lobby;

  /// Whether the session is still joinable.
  bool get isJoinable => status == LiveGroupStatus.lobby && !isFull;

  /// Progress through the session as a fraction (0.0 to 1.0).
  double get progress => totalRounds > 0 ? currentRound / totalRounds : 0.0;

  /// Build the streaming leaderboard from current player state.
  ///
  /// Pass [currentPlayerId] to flag the local player's entry.
  List<LiveLeaderboardEntry> leaderboard({String? currentPlayerId}) {
    final entries = players.map((p) {
      return LiveLeaderboardEntry(
        playerId: p.id,
        username: p.username,
        totalScore: p.score,
        roundsCompleted: p.currentRound,
        roundsWon: p.roundsWon,
        totalTime: p.lastAnswerTime ?? Duration.zero,
        isCurrentPlayer: p.id == currentPlayerId,
      );
    }).toList()
      ..sort((a, b) {
        // Primary: higher score first.
        final scoreCmp = b.totalScore.compareTo(a.totalScore);
        if (scoreCmp != 0) return scoreCmp;
        // Tiebreaker: faster total time first.
        return a.totalTime.compareTo(b.totalTime);
      });

    return entries;
  }

  // ── copyWith ─────────────────────────────────────────────────────────

  LiveGroupSession copyWith({
    String? id,
    String? hostId,
    String? hostUsername,
    int? seed,
    LiveGroupStatus? status,
    LiveRoundMode? roundMode,
    int? totalRounds,
    int? currentRound,
    Set<String>? enabledClueTypes,
    List<LiveGroupPlayer>? players,
    List<LiveGroupRound>? rounds,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    Duration? timeLimit,
    String? inviteCode,
  }) =>
      LiveGroupSession(
        id: id ?? this.id,
        hostId: hostId ?? this.hostId,
        hostUsername: hostUsername ?? this.hostUsername,
        seed: seed ?? this.seed,
        status: status ?? this.status,
        roundMode: roundMode ?? this.roundMode,
        totalRounds: totalRounds ?? this.totalRounds,
        currentRound: currentRound ?? this.currentRound,
        enabledClueTypes: enabledClueTypes ?? this.enabledClueTypes,
        players: players ?? this.players,
        rounds: rounds ?? this.rounds,
        createdAt: createdAt ?? this.createdAt,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt ?? this.completedAt,
        timeLimit: timeLimit ?? this.timeLimit,
        inviteCode: inviteCode ?? this.inviteCode,
      );

  // ── Factory constructors ─────────────────────────────────────────────

  /// Create a fresh lobby session ready for players to join.
  factory LiveGroupSession.create({
    required String hostId,
    required String hostUsername,
  }) {
    final now = DateTime.now().toUtc();
    final seed = now.year * 100000000 +
        now.month * 1000000 +
        now.day * 10000 +
        now.hour * 100 +
        now.minute;

    return LiveGroupSession(
      id: 'lg_${now.millisecondsSinceEpoch}',
      hostId: hostId,
      hostUsername: hostUsername,
      seed: seed,
      status: LiveGroupStatus.lobby,
      roundMode: LiveRoundMode.standard,
      totalRounds: 10,
      currentRound: 0,
      enabledClueTypes: const {
        'flag',
        'outline',
        'borders',
        'capital',
        'stats',
      },
      players: [
        LiveGroupPlayer(
          id: hostId,
          username: hostUsername,
          isHost: true,
          isSubscriber: true,
        ),
      ],
      rounds: const [],
      createdAt: now,
      inviteCode: _generateInviteCode(now.millisecondsSinceEpoch),
    );
  }

  /// Generate a short 6-character alphanumeric invite code from a seed value.
  static String _generateInviteCode(int seedValue) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no I/1/O/0 ambiguity
    final buf = StringBuffer();
    var v = seedValue;
    for (var i = 0; i < 6; i++) {
      buf.write(chars[v % chars.length]);
      v = (v ~/ chars.length) + i + 1;
    }
    return buf.toString();
  }

  // ── Serialisation ────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'host_id': hostId,
        'host_username': hostUsername,
        'seed': seed,
        'status': status.name,
        'round_mode': roundMode.name,
        'total_rounds': totalRounds,
        'current_round': currentRound,
        'enabled_clue_types': enabledClueTypes.toList(),
        'players': players.map((p) => p.toJson()).toList(),
        'rounds': rounds.map((r) => r.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'started_at': startedAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'time_limit_ms': timeLimit?.inMilliseconds,
        'invite_code': inviteCode,
      };

  factory LiveGroupSession.fromJson(
    Map<String, dynamic> json,
  ) =>
      LiveGroupSession(
        id: json['id'] as String,
        hostId: json['host_id'] as String,
        hostUsername: json['host_username'] as String,
        seed: json['seed'] as int,
        status:
            LiveGroupStatus.values.firstWhere((s) => s.name == json['status']),
        roundMode: LiveRoundMode.values.firstWhere(
          (m) => m.name == json['round_mode'],
          orElse: () => LiveRoundMode.standard,
        ),
        totalRounds: json['total_rounds'] as int? ?? 10,
        currentRound: json['current_round'] as int? ?? 0,
        enabledClueTypes: (json['enabled_clue_types'] as List?)
                ?.map((e) => e as String)
                .toSet() ??
            const {'flag', 'outline', 'borders', 'capital', 'stats'},
        players: (json['players'] as List?)
                ?.map(
                    (p) => LiveGroupPlayer.fromJson(p as Map<String, dynamic>))
                .toList() ??
            const [],
        rounds: (json['rounds'] as List?)
                ?.map((r) => LiveGroupRound.fromJson(r as Map<String, dynamic>))
                .toList() ??
            const [],
        createdAt: DateTime.parse(json['created_at'] as String),
        startedAt: json['started_at'] != null
            ? DateTime.parse(json['started_at'] as String)
            : null,
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'] as String)
            : null,
        timeLimit: json['time_limit_ms'] != null
            ? Duration(milliseconds: json['time_limit_ms'] as int)
            : null,
        inviteCode: json['invite_code'] as String?,
      );

  // ── Placeholder data for UI development ──────────────────────────────

  /// A sample mid-game session with 4 players for UI prototyping.
  ///
  /// The session is on round 6 of 10, using standard scoring with all
  /// clue types enabled. Players have varying scores and progress to
  /// exercise the streaming leaderboard layout.
  factory LiveGroupSession.placeholder() {
    final created = DateTime.utc(2025, 6, 15, 14, 0);
    final started = DateTime.utc(2025, 6, 15, 14, 2);

    const players = <LiveGroupPlayer>[
      // Host -- leading the pack
      LiveGroupPlayer(
        id: 'player_host',
        username: 'GlobeTrotter42',
        isHost: true,
        isSubscriber: true,
        score: 5400,
        roundsWon: 3,
        currentRound: 6,
        lastAnswerTime: Duration(seconds: 8, milliseconds: 320),
        isFinished: false,
      ),
      // Strong competitor -- close behind
      LiveGroupPlayer(
        id: 'player_2',
        username: 'AtlasAce',
        isHost: false,
        isSubscriber: true,
        score: 5100,
        roundsWon: 2,
        currentRound: 6,
        lastAnswerTime: Duration(seconds: 11, milliseconds: 750),
        isFinished: false,
      ),
      // Invited non-subscriber -- mid-table
      LiveGroupPlayer(
        id: 'player_3',
        username: 'MapNewbie',
        isHost: false,
        isSubscriber: false,
        score: 3200,
        roundsWon: 1,
        currentRound: 5,
        lastAnswerTime: Duration(seconds: 18, milliseconds: 400),
        isFinished: false,
      ),
      // Slower player -- still on round 4
      LiveGroupPlayer(
        id: 'player_4',
        username: 'WanderWiz',
        isHost: false,
        isSubscriber: true,
        score: 2800,
        roundsWon: 0,
        currentRound: 4,
        lastAnswerTime: Duration(seconds: 22, milliseconds: 100),
        isFinished: false,
      ),
    ];

    const rounds = <LiveGroupRound>[
      LiveGroupRound(
        roundNumber: 1,
        countryAnswer: 'FR',
        answers: {
          'player_host': LiveGroupAnswer(
            playerId: 'player_host',
            answer: 'FR',
            isCorrect: true,
            timeTaken: Duration(seconds: 6, milliseconds: 200),
            pointsEarned: 1000,
          ),
          'player_2': LiveGroupAnswer(
            playerId: 'player_2',
            answer: 'FR',
            isCorrect: true,
            timeTaken: Duration(seconds: 7, milliseconds: 800),
            pointsEarned: 950,
          ),
          'player_3': LiveGroupAnswer(
            playerId: 'player_3',
            answer: 'DE',
            isCorrect: false,
            timeTaken: Duration(seconds: 14, milliseconds: 500),
            pointsEarned: 0,
          ),
          'player_4': LiveGroupAnswer(
            playerId: 'player_4',
            answer: 'FR',
            isCorrect: true,
            timeTaken: Duration(seconds: 19, milliseconds: 300),
            pointsEarned: 800,
          ),
        },
        firstCorrectPlayerId: 'player_host',
        fastestTime: Duration(seconds: 6, milliseconds: 200),
      ),
      LiveGroupRound(
        roundNumber: 2,
        countryAnswer: 'BR',
        answers: {
          'player_host': LiveGroupAnswer(
            playerId: 'player_host',
            answer: 'BR',
            isCorrect: true,
            timeTaken: Duration(seconds: 9, milliseconds: 100),
            pointsEarned: 900,
          ),
          'player_2': LiveGroupAnswer(
            playerId: 'player_2',
            answer: 'BR',
            isCorrect: true,
            timeTaken: Duration(seconds: 5, milliseconds: 400),
            pointsEarned: 1000,
          ),
          'player_3': LiveGroupAnswer(
            playerId: 'player_3',
            answer: 'BR',
            isCorrect: true,
            timeTaken: Duration(seconds: 16, milliseconds: 200),
            pointsEarned: 750,
          ),
          'player_4': LiveGroupAnswer(
            playerId: 'player_4',
            answer: 'AR',
            isCorrect: false,
            timeTaken: Duration(seconds: 20, milliseconds: 700),
            pointsEarned: 0,
          ),
        },
        firstCorrectPlayerId: 'player_2',
        fastestTime: Duration(seconds: 5, milliseconds: 400),
      ),
      LiveGroupRound(
        roundNumber: 3,
        countryAnswer: 'JP',
        answers: {
          'player_host': LiveGroupAnswer(
            playerId: 'player_host',
            answer: 'JP',
            isCorrect: true,
            timeTaken: Duration(seconds: 4, milliseconds: 900),
            pointsEarned: 1000,
          ),
          'player_2': LiveGroupAnswer(
            playerId: 'player_2',
            answer: 'JP',
            isCorrect: true,
            timeTaken: Duration(seconds: 8, milliseconds: 300),
            pointsEarned: 900,
          ),
          'player_3': LiveGroupAnswer(
            playerId: 'player_3',
            answer: 'JP',
            isCorrect: true,
            timeTaken: Duration(seconds: 12, milliseconds: 600),
            pointsEarned: 800,
          ),
          'player_4': LiveGroupAnswer(
            playerId: 'player_4',
            answer: 'JP',
            isCorrect: true,
            timeTaken: Duration(seconds: 15, milliseconds: 800),
            pointsEarned: 700,
          ),
        },
        firstCorrectPlayerId: 'player_host',
        fastestTime: Duration(seconds: 4, milliseconds: 900),
      ),
      LiveGroupRound(
        roundNumber: 4,
        countryAnswer: 'EG',
        answers: {
          'player_host': LiveGroupAnswer(
            playerId: 'player_host',
            answer: 'EG',
            isCorrect: true,
            timeTaken: Duration(seconds: 10, milliseconds: 500),
            pointsEarned: 850,
          ),
          'player_2': LiveGroupAnswer(
            playerId: 'player_2',
            answer: 'EG',
            isCorrect: true,
            timeTaken: Duration(seconds: 9, milliseconds: 200),
            pointsEarned: 900,
          ),
          'player_3': LiveGroupAnswer(
            playerId: 'player_3',
            answer: 'EG',
            isCorrect: true,
            timeTaken: Duration(seconds: 18, milliseconds: 400),
            pointsEarned: 650,
          ),
          'player_4': LiveGroupAnswer(
            playerId: 'player_4',
            answer: 'ZA',
            isCorrect: false,
            timeTaken: Duration(seconds: 25, milliseconds: 100),
            pointsEarned: 0,
          ),
        },
        firstCorrectPlayerId: 'player_2',
        fastestTime: Duration(seconds: 9, milliseconds: 200),
      ),
      LiveGroupRound(
        roundNumber: 5,
        countryAnswer: 'AU',
        answers: {
          'player_host': LiveGroupAnswer(
            playerId: 'player_host',
            answer: 'AU',
            isCorrect: true,
            timeTaken: Duration(seconds: 7, milliseconds: 700),
            pointsEarned: 950,
          ),
          'player_2': LiveGroupAnswer(
            playerId: 'player_2',
            answer: 'AU',
            isCorrect: true,
            timeTaken: Duration(seconds: 12, milliseconds: 100),
            pointsEarned: 850,
          ),
          'player_3': LiveGroupAnswer(
            playerId: 'player_3',
            answer: 'AU',
            isCorrect: true,
            timeTaken: Duration(seconds: 15, milliseconds: 900),
            pointsEarned: 700,
          ),
          'player_4': LiveGroupAnswer(
            playerId: 'player_4',
            answer: 'AU',
            isCorrect: true,
            timeTaken: Duration(seconds: 20, milliseconds: 500),
            pointsEarned: 600,
          ),
        },
        firstCorrectPlayerId: 'player_host',
        fastestTime: Duration(seconds: 7, milliseconds: 700),
      ),
    ];

    return LiveGroupSession(
      id: 'lg_placeholder_001',
      hostId: 'player_host',
      hostUsername: 'GlobeTrotter42',
      seed: 20250615140200,
      status: LiveGroupStatus.inProgress,
      roundMode: LiveRoundMode.standard,
      totalRounds: 10,
      currentRound: 6,
      enabledClueTypes: const {
        'flag',
        'outline',
        'borders',
        'capital',
        'stats',
      },
      players: players,
      rounds: rounds,
      createdAt: created,
      startedAt: started,
      timeLimit: const Duration(seconds: 30),
      inviteCode: 'FLTX7K',
    );
  }

  /// A sample lobby session waiting for more players, for UI prototyping.
  factory LiveGroupSession.placeholderLobby() {
    final created = DateTime.utc(2025, 6, 15, 18, 30);

    const players = <LiveGroupPlayer>[
      LiveGroupPlayer(
        id: 'player_host_2',
        username: 'CartographyCat',
        isHost: true,
        isSubscriber: true,
      ),
      LiveGroupPlayer(
        id: 'player_5',
        username: 'MercatorMaven',
        isHost: false,
        isSubscriber: true,
      ),
    ];

    return LiveGroupSession(
      id: 'lg_placeholder_lobby',
      hostId: 'player_host_2',
      hostUsername: 'CartographyCat',
      seed: 20250615183000,
      status: LiveGroupStatus.lobby,
      roundMode: LiveRoundMode.firstToAnswer,
      totalRounds: 5,
      currentRound: 0,
      enabledClueTypes: const {'flag', 'capital'},
      players: players,
      rounds: const [],
      createdAt: created,
      timeLimit: const Duration(seconds: 20),
      inviteCode: 'GEO2NR',
    );
  }

  /// A sample completed session with final results, for UI prototyping.
  factory LiveGroupSession.placeholderCompleted() {
    final created = DateTime.utc(2025, 6, 15, 10, 0);
    final started = DateTime.utc(2025, 6, 15, 10, 1);
    final completed = DateTime.utc(2025, 6, 15, 10, 12);

    const players = <LiveGroupPlayer>[
      LiveGroupPlayer(
        id: 'player_a',
        username: 'EquatorExplorer',
        isHost: true,
        isSubscriber: true,
        score: 8900,
        roundsWon: 4,
        currentRound: 10,
        lastAnswerTime: Duration(seconds: 5, milliseconds: 100),
        isFinished: true,
      ),
      LiveGroupPlayer(
        id: 'player_b',
        username: 'LatLongLegend',
        isHost: false,
        isSubscriber: true,
        score: 7600,
        roundsWon: 3,
        currentRound: 10,
        lastAnswerTime: Duration(seconds: 9, milliseconds: 800),
        isFinished: true,
      ),
      LiveGroupPlayer(
        id: 'player_c',
        username: 'IslandHopper42',
        isHost: false,
        isSubscriber: false,
        score: 6200,
        roundsWon: 2,
        currentRound: 10,
        lastAnswerTime: Duration(seconds: 14, milliseconds: 300),
        isFinished: true,
      ),
    ];

    return LiveGroupSession(
      id: 'lg_placeholder_done',
      hostId: 'player_a',
      hostUsername: 'EquatorExplorer',
      seed: 20250615100100,
      status: LiveGroupStatus.completed,
      roundMode: LiveRoundMode.standard,
      totalRounds: 10,
      currentRound: 10,
      enabledClueTypes: const {
        'flag',
        'outline',
        'borders',
        'capital',
        'stats',
      },
      players: players,
      rounds: const [],
      createdAt: created,
      startedAt: started,
      completedAt: completed,
      timeLimit: const Duration(seconds: 30),
      inviteCode: 'ENDG4M',
    );
  }
}
