/// Level and campaign mission requirements for unlocking game modes.
class ModeRequirement {
  const ModeRequirement({
    required this.modeId,
    required this.displayName,
    this.requiredLevel,
    this.requiredMissionId,
  });

  /// Identifier matching the game mode.
  final String modeId;

  /// Human-readable mode name for unlock messages.
  final String displayName;

  /// Player level needed to unlock (null = always available).
  final int? requiredLevel;

  /// Campaign mission ID that unlocks this mode (null = no campaign gate).
  final String? requiredMissionId;

  /// Check if unlocked given player level and completed mission IDs.
  bool isUnlocked(int playerLevel, Set<String> completedMissions) {
    // No requirements = always available.
    if (requiredLevel == null && requiredMissionId == null) return true;
    // Level gate: player is high enough level.
    if (requiredLevel != null && playerLevel >= requiredLevel!) return true;
    // Campaign gate: mission completed.
    if (requiredMissionId != null &&
        completedMissions.contains(requiredMissionId)) {
      return true;
    }
    return false;
  }

  /// Human-readable unlock requirement string.
  String unlockHint(int playerLevel) {
    final parts = <String>[];
    if (requiredLevel != null) parts.add('Reach level $requiredLevel');
    if (requiredMissionId != null) parts.add('Complete campaign mission');
    return parts.join(' or ');
  }
}

/// All game mode requirements.
const List<ModeRequirement> modeRequirements = [
  ModeRequirement(modeId: 'campaign', displayName: 'Pilot Training'),
  ModeRequirement(modeId: 'free_flight', displayName: 'Free Flight'),
  ModeRequirement(modeId: 'training_sortie', displayName: 'Training Sortie'),
  ModeRequirement(modeId: 'uncharted', displayName: 'Uncharted'),
  ModeRequirement(modeId: 'flight_school', displayName: 'Flight School'),
  ModeRequirement(
    modeId: 'daily_briefing',
    displayName: 'Daily Briefing',
    requiredLevel: 3,
    requiredMissionId: 'hint_strategy',
  ),
  ModeRequirement(
    modeId: 'daily_challenge',
    displayName: 'Daily Challenge',
    requiredLevel: 5,
    requiredMissionId: 'world_tour',
  ),
  ModeRequirement(
    modeId: 'dogfight',
    displayName: 'Dogfight',
    requiredLevel: 5,
    requiredMissionId: 'daily_prep',
  ),
  ModeRequirement(
    modeId: 'matchmaking',
    displayName: 'Find a Challenger',
    requiredLevel: 7,
    requiredMissionId: 'ready_for_takeoff',
  ),
];

/// Look up the requirement for a specific mode.
ModeRequirement? getModeRequirement(String modeId) {
  for (final req in modeRequirements) {
    if (req.modeId == modeId) return req;
  }
  return null;
}
