import 'package:flame/components.dart';

import '../../game/clues/clue_types.dart';

/// Status of a challenge.
///
/// [dbName] is the snake_case value stored in Supabase.
enum ChallengeStatus {
  pending('pending'),
  inProgress('in_progress'),
  completed('completed'),
  expired('expired'),
  declined('declined');

  const ChallengeStatus(this.dbName);

  /// The snake_case string stored in the database.
  final String dbName;

  /// Look up a [ChallengeStatus] from its DB string representation.
  static ChallengeStatus fromDb(String value) =>
      ChallengeStatus.values.firstWhere(
        (s) => s.dbName == value,
        orElse: () => ChallengeStatus.pending,
      );
}

/// A single round in a challenge.
class ChallengeRound {
  const ChallengeRound({
    required this.roundNumber,
    required this.seed,
    required this.clueType,
    required this.startLocation,
    required this.targetCountryCode,
    this.countryName,
    this.challengerTime,
    this.challengedTime,
    this.challengerScore,
    this.challengedScore,
    this.challengerHintsUsed,
    this.challengedHintsUsed,
    this.challengerRoute,
    this.challengedRoute,
  });

  final int roundNumber;
  final int seed;
  final ClueType clueType;
  final Vector2 startLocation;
  final String targetCountryCode;

  /// Human-readable country name (e.g. "Brazil").
  final String? countryName;

  final Duration? challengerTime;
  final Duration? challengedTime;

  /// Round score (0-10000) factoring in hints and fuel usage.
  final int? challengerScore;
  final int? challengedScore;

  /// Hint tiers used (0-4).
  final int? challengerHintsUsed;
  final int? challengedHintsUsed;

  final List<Vector2>? challengerRoute;
  final List<Vector2>? challengedRoute;

  bool get isComplete => challengerTime != null && challengedTime != null;

  /// Determine round winner. Prefers score comparison; falls back to time.
  String? get winner {
    if (!isComplete) return null;
    // Score-based comparison (higher score wins).
    if (challengerScore != null && challengedScore != null) {
      if (challengerScore! > challengedScore!) return 'challenger';
      if (challengedScore! > challengerScore!) return 'challenged';
      return 'draw';
    }
    // Fallback: time-based comparison (lower time wins).
    if (challengerTime! < challengedTime!) return 'challenger';
    if (challengedTime! < challengerTime!) return 'challenged';
    return 'draw';
  }

  /// Hint-usage emoji for a given hint count (matches daily challenge style).
  static String hintEmoji(int? hintsUsed, {bool completed = true}) {
    if (!completed) return '\u{1F534}'; // red
    if (hintsUsed == null || hintsUsed == 0) return '\u{1F7E2}'; // green
    if (hintsUsed <= 2) return '\u{1F7E1}'; // yellow
    if (hintsUsed <= 4) return '\u{1F7E0}'; // orange
    return '\u{1F534}'; // red
  }

  Map<String, dynamic> toJson() => {
    'round_number': roundNumber,
    'seed': seed,
    'clue_type': clueType.name,
    'start_location': [startLocation.x, startLocation.y],
    'target_country_code': targetCountryCode,
    if (countryName != null) 'country_name': countryName,
    'challenger_time_ms': challengerTime?.inMilliseconds,
    'challenged_time_ms': challengedTime?.inMilliseconds,
    if (challengerScore != null) 'challenger_score': challengerScore,
    if (challengedScore != null) 'challenged_score': challengedScore,
    if (challengerHintsUsed != null)
      'challenger_hints_used': challengerHintsUsed,
    if (challengedHintsUsed != null)
      'challenged_hints_used': challengedHintsUsed,
  };

  factory ChallengeRound.fromJson(Map<String, dynamic> json) {
    final startLoc = json['start_location'] as List;
    return ChallengeRound(
      roundNumber: json['round_number'] as int,
      seed: json['seed'] as int,
      clueType: ClueType.values.firstWhere((t) => t.name == json['clue_type']),
      startLocation: Vector2(
        (startLoc[0] as num).toDouble(),
        (startLoc[1] as num).toDouble(),
      ),
      targetCountryCode: json['target_country_code'] as String,
      countryName: json['country_name'] as String?,
      challengerTime: json['challenger_time_ms'] != null
          ? Duration(milliseconds: json['challenger_time_ms'] as int)
          : null,
      challengedTime: json['challenged_time_ms'] != null
          ? Duration(milliseconds: json['challenged_time_ms'] as int)
          : null,
      challengerScore: json['challenger_score'] as int?,
      challengedScore: json['challenged_score'] as int?,
      challengerHintsUsed: json['challenger_hints_used'] as int?,
      challengedHintsUsed: json['challenged_hints_used'] as int?,
    );
  }
}

/// A challenge between two players.
class Challenge {
  const Challenge({
    required this.id,
    required this.challengerId,
    required this.challengerName,
    required this.challengedId,
    required this.challengedName,
    required this.status,
    required this.rounds,
    this.winnerId,
    this.challengerCoins = 0,
    this.challengedCoins = 0,
    this.createdAt,
    this.completedAt,
  });

  final String id;
  final String challengerId;
  final String challengerName;
  final String challengedId;
  final String challengedName;
  final ChallengeStatus status;
  final List<ChallengeRound> rounds;
  final String? winnerId;
  final int challengerCoins;
  final int challengedCoins;
  final DateTime? createdAt;
  final DateTime? completedAt;

  /// Best of 5 rounds
  static const int totalRounds = 5;
  static const int winsRequired = 3;

  /// Coin rewards
  static const int winnerCoins = 100;
  static const int roundWinCoins = 10;
  static const int loserCoins = 15;
  static const int participationCoins = 5;

  int get challengerWins =>
      rounds.where((r) => r.isComplete && r.winner == 'challenger').length;

  int get challengedWins =>
      rounds.where((r) => r.isComplete && r.winner == 'challenged').length;

  int get currentRound => rounds.where((r) => r.isComplete).length + 1;

  bool get isComplete =>
      challengerWins >= winsRequired || challengedWins >= winsRequired;

  String get scoreText => '$challengerWins - $challengedWins';

  Map<String, dynamic> toJson() => {
    'id': id,
    'challenger_id': challengerId,
    'challenger_name': challengerName,
    'challenged_id': challengedId,
    'challenged_name': challengedName,
    'status': status.dbName,
    'rounds': rounds.map((r) => r.toJson()).toList(),
    'winner_id': winnerId,
    'challenger_coins': challengerCoins,
    'challenged_coins': challengedCoins,
    'created_at': createdAt?.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
  };

  factory Challenge.fromJson(Map<String, dynamic> json) => Challenge(
    id: json['id'] as String,
    challengerId: json['challenger_id'] as String,
    challengerName: json['challenger_name'] as String,
    challengedId: json['challenged_id'] as String,
    challengedName: json['challenged_name'] as String,
    status: ChallengeStatus.fromDb(json['status'] as String),
    rounds: (json['rounds'] as List)
        .map((r) => ChallengeRound.fromJson(r as Map<String, dynamic>))
        .toList(),
    winnerId: json['winner_id'] as String?,
    challengerCoins: json['challenger_coins'] as int? ?? 0,
    challengedCoins: json['challenged_coins'] as int? ?? 0,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : null,
    completedAt: json['completed_at'] != null
        ? DateTime.parse(json['completed_at'] as String)
        : null,
  );
}
