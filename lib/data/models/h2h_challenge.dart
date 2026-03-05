import '../../game/quiz/quiz_category.dart';
import '../../game/quiz/quiz_difficulty.dart';

/// Status of a Head-to-Head Flight School challenge.
enum H2HStatus {
  pending('pending'),
  inProgress('in_progress'),
  completed('completed'),
  declined('declined'),
  expired('expired');

  const H2HStatus(this.dbName);

  final String dbName;

  static H2HStatus fromDb(String value) => H2HStatus.values.firstWhere(
    (s) => s.dbName == value,
    orElse: () => H2HStatus.pending,
  );
}

/// A single round in a best-of-3 H2H Flight School challenge.
///
/// Each round specifies a flight school level, quiz category, and difficulty.
/// Both players play with the same [seed] so they get identical questions.
class H2HRound {
  const H2HRound({
    required this.levelId,
    required this.levelName,
    required this.category,
    required this.difficulty,
    required this.seed,
    this.challengerScore,
    this.challengedScore,
    this.challengerTimeMs,
    this.challengedTimeMs,
    this.challengerCorrect,
    this.challengedCorrect,
    this.challengerWrong,
    this.challengedWrong,
  });

  /// Flight school level ID (e.g. 'europe', 'us_states').
  final String levelId;

  /// Human-readable level name (e.g. 'Europe', 'United States').
  final String levelName;

  /// Quiz category for this round.
  final QuizCategory category;

  /// Quiz difficulty for this round.
  final QuizDifficulty difficulty;

  /// Deterministic seed so both players get the same questions.
  final int seed;

  /// Challenger's total score for this round (null if not yet played).
  final int? challengerScore;

  /// Challenged player's total score (null if not yet played).
  final int? challengedScore;

  /// Challenger's time in milliseconds.
  final int? challengerTimeMs;

  /// Challenged player's time in milliseconds.
  final int? challengedTimeMs;

  /// Challenger's correct answer count.
  final int? challengerCorrect;

  /// Challenged player's correct answer count.
  final int? challengedCorrect;

  /// Challenger's wrong answer count.
  final int? challengerWrong;

  /// Challenged player's wrong answer count.
  final int? challengedWrong;

  /// Whether the challenger has completed this round.
  bool get challengerPlayed => challengerScore != null;

  /// Whether the challenged player has completed this round.
  bool get challengedPlayed => challengedScore != null;

  /// Whether both players have completed this round.
  bool get isComplete => challengerPlayed && challengedPlayed;

  /// Determine the round winner. Returns 'challenger', 'challenged', or 'draw'.
  /// Returns null if not yet complete.
  String? get winner {
    if (!isComplete) return null;
    if (challengerScore! > challengedScore!) return 'challenger';
    if (challengedScore! > challengerScore!) return 'challenged';
    return 'draw';
  }

  Map<String, dynamic> toJson() => {
    'level_id': levelId,
    'level_name': levelName,
    'category': category.name,
    'difficulty': difficulty.name,
    'seed': seed,
    if (challengerScore != null) 'challenger_score': challengerScore,
    if (challengedScore != null) 'challenged_score': challengedScore,
    if (challengerTimeMs != null) 'challenger_time_ms': challengerTimeMs,
    if (challengedTimeMs != null) 'challenged_time_ms': challengedTimeMs,
    if (challengerCorrect != null) 'challenger_correct': challengerCorrect,
    if (challengedCorrect != null) 'challenged_correct': challengedCorrect,
    if (challengerWrong != null) 'challenger_wrong': challengerWrong,
    if (challengedWrong != null) 'challenged_wrong': challengedWrong,
  };

  factory H2HRound.fromJson(Map<String, dynamic> json) => H2HRound(
    levelId: json['level_id'] as String? ?? '',
    levelName: json['level_name'] as String? ?? '',
    category: QuizCategory.values.firstWhere(
      (c) => c.name == json['category'],
      orElse: () => QuizCategory.mixed,
    ),
    difficulty: QuizDifficulty.values.firstWhere(
      (d) => d.name == json['difficulty'],
      orElse: () => QuizDifficulty.medium,
    ),
    seed: json['seed'] as int? ?? 0,
    challengerScore: json['challenger_score'] as int?,
    challengedScore: json['challenged_score'] as int?,
    challengerTimeMs: json['challenger_time_ms'] as int?,
    challengedTimeMs: json['challenged_time_ms'] as int?,
    challengerCorrect: json['challenger_correct'] as int?,
    challengedCorrect: json['challenged_correct'] as int?,
    challengerWrong: json['challenger_wrong'] as int?,
    challengedWrong: json['challenged_wrong'] as int?,
  );

  H2HRound copyWith({
    String? levelId,
    String? levelName,
    QuizCategory? category,
    QuizDifficulty? difficulty,
    int? seed,
    int? challengerScore,
    int? challengedScore,
    int? challengerTimeMs,
    int? challengedTimeMs,
    int? challengerCorrect,
    int? challengedCorrect,
    int? challengerWrong,
    int? challengedWrong,
  }) => H2HRound(
    levelId: levelId ?? this.levelId,
    levelName: levelName ?? this.levelName,
    category: category ?? this.category,
    difficulty: difficulty ?? this.difficulty,
    seed: seed ?? this.seed,
    challengerScore: challengerScore ?? this.challengerScore,
    challengedScore: challengedScore ?? this.challengedScore,
    challengerTimeMs: challengerTimeMs ?? this.challengerTimeMs,
    challengedTimeMs: challengedTimeMs ?? this.challengedTimeMs,
    challengerCorrect: challengerCorrect ?? this.challengerCorrect,
    challengedCorrect: challengedCorrect ?? this.challengedCorrect,
    challengerWrong: challengerWrong ?? this.challengerWrong,
    challengedWrong: challengedWrong ?? this.challengedWrong,
  );
}

/// A Head-to-Head Flight School challenge (best of 3 rounds).
///
/// The challenger picks 3 rounds (level + category + difficulty), each with
/// a deterministic seed. The challenged player accepts and plays all 3 rounds.
/// Whoever wins 2+ rounds wins the challenge.
class H2HChallenge {
  const H2HChallenge({
    required this.id,
    required this.challengerId,
    required this.challengerName,
    required this.challengedId,
    required this.challengedName,
    required this.rounds,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.winnerId,
  });

  final String id;
  final String challengerId;
  final String challengerName;
  final String challengedId;
  final String challengedName;

  /// Exactly 3 rounds.
  final List<H2HRound> rounds;
  final H2HStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? winnerId;

  /// Total rounds (always 3 for H2H).
  static const int totalRounds = 3;

  /// Wins required to win the challenge (2 out of 3).
  static const int winsRequired = 2;

  /// Coin rewards.
  static const int winnerCoins = 75;
  static const int roundWinCoins = 15;
  static const int loserCoins = 10;
  static const int participationCoins = 5;

  int get challengerWins =>
      rounds.where((r) => r.isComplete && r.winner == 'challenger').length;

  int get challengedWins =>
      rounds.where((r) => r.isComplete && r.winner == 'challenged').length;

  /// Index of the next round to play (for the challenged player), or -1 if all
  /// rounds are complete.
  int get nextUnplayedRoundIndex {
    for (var i = 0; i < rounds.length; i++) {
      if (!rounds[i].isComplete) return i;
    }
    return -1;
  }

  /// Whether someone has clinched the majority of rounds.
  bool get isClinched =>
      challengerWins >= winsRequired || challengedWins >= winsRequired;

  /// Whether all rounds are complete or someone has clinched.
  bool get isComplete => isClinched || rounds.every((r) => r.isComplete);

  /// The winner's name, or null if draw or not complete.
  String? get winnerName {
    if (winnerId == challengerId) return challengerName;
    if (winnerId == challengedId) return challengedName;
    return null;
  }

  /// Score text like "2 - 1".
  String get scoreText => '$challengerWins - $challengedWins';

  Map<String, dynamic> toJson() => {
    'id': id,
    'challenger_id': challengerId,
    'challenger_name': challengerName,
    'challenged_id': challengedId,
    'challenged_name': challengedName,
    'rounds': rounds.map((r) => r.toJson()).toList(),
    'status': status.dbName,
    'created_at': createdAt.toIso8601String(),
    if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
    if (winnerId != null) 'winner_id': winnerId,
  };

  factory H2HChallenge.fromJson(Map<String, dynamic> json) {
    final roundsList = json['rounds'] as List? ?? [];
    return H2HChallenge(
      id: json['id'] as String,
      challengerId: json['challenger_id'] as String,
      challengerName: json['challenger_name'] as String? ?? '',
      challengedId: json['challenged_id'] as String,
      challengedName: json['challenged_name'] as String? ?? '',
      rounds: roundsList
          .map((r) => H2HRound.fromJson(r as Map<String, dynamic>))
          .toList(),
      status: H2HStatus.fromDb(json['status'] as String? ?? 'pending'),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
      winnerId: json['winner_id'] as String?,
    );
  }

  H2HChallenge copyWith({
    String? id,
    String? challengerId,
    String? challengerName,
    String? challengedId,
    String? challengedName,
    List<H2HRound>? rounds,
    H2HStatus? status,
    DateTime? createdAt,
    DateTime? completedAt,
    String? winnerId,
  }) => H2HChallenge(
    id: id ?? this.id,
    challengerId: challengerId ?? this.challengerId,
    challengerName: challengerName ?? this.challengerName,
    challengedId: challengedId ?? this.challengedId,
    challengedName: challengedName ?? this.challengedName,
    rounds: rounds ?? this.rounds,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt ?? this.completedAt,
    winnerId: winnerId ?? this.winnerId,
  );
}
