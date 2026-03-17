import '../clues/clue_types.dart';
import 'coach.dart';

/// A tip shown by the coach during gameplay at a specific trigger.
class CoachTip {
  const CoachTip({
    required this.trigger,
    required this.message,
  });

  /// When this tip should appear.
  /// Supported triggers: 'firstClue', 'firstHint', 'fuelLow', 'fuelEmpty',
  /// 'halfwayDone', 'correctAnswer', 'wrongRegion'.
  final String trigger;

  /// The coach's dialogue text.
  final String message;
}

/// Represents a single tutorial campaign mission.
class CampaignMission {
  const CampaignMission({
    required this.id,
    required this.order,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.coach,
    required this.allowedClues,
    this.rounds = 2,
    this.maxDifficulty = 0.3,
    this.fuelEnabled = true,
    this.targetCountryCodes,
    this.xpReward = 75,
    this.coinReward = 50,
    this.unlockMessage,
    this.tips = const [],
    this.startLat,
    this.startLng,
    this.startHeading,
  });

  final String id;
  final int order;
  final String title;
  final String subtitle;
  final String description;
  final Coach coach;
  final Set<ClueType> allowedClues;
  final int rounds;
  final double maxDifficulty;
  final bool fuelEnabled;
  final List<String>? targetCountryCodes;
  final int xpReward;
  final int coinReward;
  final String? unlockMessage;
  final List<CoachTip> tips;

  /// Fixed starting latitude (degrees). When null, the session picks randomly.
  final double? startLat;

  /// Fixed starting longitude (degrees). When null, the session picks randomly.
  final double? startLng;

  /// Fixed starting heading (radians, 0 = east, π/2 = north). When null,
  /// the game picks a random heading.
  final double? startHeading;
}

/// Result of completing a campaign mission.
class CampaignMissionResult {
  const CampaignMissionResult({
    required this.missionId,
    required this.score,
    required this.stars,
    required this.completedAt,
  });

  final String missionId;
  final int score;

  /// Star rating from 1 to 3.
  final int stars;
  final DateTime completedAt;

  /// Calculate stars from score (out of max possible ~10 000 per round x rounds).
  ///
  /// Thresholds are generous because tutorial missions involve exploring
  /// controls for the first time — players shouldn't be penalised for
  /// taking time to learn.
  static int calculateStars(int score, int rounds) {
    final maxScore = rounds * 10000;
    final ratio = score / maxScore;
    if (ratio >= 0.5) return 3;
    if (ratio >= 0.25) return 2;
    return 1;
  }

  Map<String, dynamic> toJson() => {
        'mission_id': missionId,
        'score': score,
        'stars': stars,
        'completed_at': completedAt.toIso8601String(),
      };

  factory CampaignMissionResult.fromJson(Map<String, dynamic> json) =>
      CampaignMissionResult(
        missionId: json['mission_id'] as String,
        score: json['score'] as int,
        stars: json['stars'] as int,
        completedAt: DateTime.parse(json['completed_at'] as String),
      );
}
