/// Level and training/campaign mission requirements for unlocking game modes.
///
/// New pilots start in Basic Training (the level-1 Flight School surface).
/// Each Basic Training mission unlocks its matching daily mode immediately,
/// and completing all three grants Level 2 and unlocks every base mode.
/// Regional Flight School levels keep their own level ladder (see
/// `flight_school_level.dart`) — only base/global modes are gated here.
library;

// ---------------------------------------------------------------------------
// Basic Training mission IDs (single source of truth for the funnel)
// ---------------------------------------------------------------------------

/// Teaches fly + find. Completing it unlocks Daily Scramble.
const String trainingFlightMissionId = 'training_flight';

/// Teaches the compass/bearing mechanic. Completing it unlocks Daily Recon.
const String trainingReconMissionId = 'training_recon';

/// Teaches the tap-the-country briefing format. Unlocks Daily Briefing.
const String trainingBriefingMissionId = 'training_briefing';

/// All three Basic Training missions. Completing the full set promotes the
/// pilot to Level 2 and unlocks every base mode.
const Set<String> basicTrainingMissionIds = {
  trainingFlightMissionId,
  trainingReconMissionId,
  trainingBriefingMissionId,
};

/// Shared unlock hint for base modes gated behind the full Basic Training
/// set. Finishing Basic Training grants Level 2, so the two are equivalent
/// from the player's point of view.
const String _basicTrainingHint = 'Reach Level 2 — finish Basic Training';

/// Level and mission requirements for a single game mode.
class ModeRequirement {
  const ModeRequirement({
    required this.modeId,
    required this.displayName,
    this.requiredLevel,
    this.requiredMissionId,
    this.requiredMissionIds,
    this.unlockHintText,
  });

  /// Identifier matching the game mode.
  final String modeId;

  /// Human-readable mode name for unlock messages.
  final String displayName;

  /// Player level needed to unlock (null = no level gate).
  final int? requiredLevel;

  /// Single mission ID that unlocks this mode (null = no single-mission gate).
  final String? requiredMissionId;

  /// Mission ID set that unlocks this mode when ALL are completed
  /// (null = no mission-set gate).
  final Set<String>? requiredMissionIds;

  /// Exact lock-reason copy shown on locked cards/tiles. When null, a
  /// generic hint is derived from the gates.
  final String? unlockHintText;

  /// Check if unlocked given player level and completed mission IDs.
  /// Gates are alternatives: satisfying any one unlocks the mode.
  bool isUnlocked(int playerLevel, Set<String> completedMissions) {
    // No requirements = always available.
    if (requiredLevel == null &&
        requiredMissionId == null &&
        requiredMissionIds == null) {
      return true;
    }
    // Level gate: player is high enough level.
    if (requiredLevel != null && playerLevel >= requiredLevel!) return true;
    // Single-mission gate: mission completed.
    if (requiredMissionId != null &&
        completedMissions.contains(requiredMissionId)) {
      return true;
    }
    // Mission-set gate: every mission in the set completed.
    if (requiredMissionIds != null &&
        completedMissions.containsAll(requiredMissionIds!)) {
      return true;
    }
    return false;
  }

  /// Human-readable unlock requirement string.
  String unlockHint(int playerLevel) {
    if (unlockHintText != null) return unlockHintText!;
    final parts = <String>[];
    if (requiredLevel != null) parts.add('Reach level $requiredLevel');
    if (requiredMissionId != null || requiredMissionIds != null) {
      parts.add('Complete training mission');
    }
    return parts.join(' or ');
  }
}

/// All game mode requirements.
///
/// Base modes are gated on the full Basic Training set rather than a raw
/// level number: gameplay XP earned during the funnel can push a pilot past
/// level 2 before all three missions are done, and the funnel must still
/// hold. Finishing Basic Training always grants Level 2, so the hint copy
/// ("Reach Level 2 — finish Basic Training") stays truthful.
const List<ModeRequirement> modeRequirements = [
  // Flight School hosts Basic Training itself, so it is never locked.
  ModeRequirement(modeId: 'flight_school', displayName: 'Flight School'),
  ModeRequirement(
    modeId: 'campaign',
    displayName: 'Pilot Training',
    requiredMissionIds: basicTrainingMissionIds,
    unlockHintText: _basicTrainingHint,
  ),
  ModeRequirement(
    modeId: 'free_flight',
    displayName: 'Free Flight',
    requiredMissionIds: basicTrainingMissionIds,
    unlockHintText: _basicTrainingHint,
  ),
  ModeRequirement(
    modeId: 'standard_sortie',
    displayName: 'Standard Sortie',
    requiredMissionIds: basicTrainingMissionIds,
    unlockHintText: _basicTrainingHint,
  ),
  ModeRequirement(
    modeId: 'training_sortie',
    displayName: 'Training Sortie',
    requiredMissionIds: basicTrainingMissionIds,
    unlockHintText: _basicTrainingHint,
  ),
  ModeRequirement(
    modeId: 'uncharted',
    displayName: 'Uncharted',
    requiredMissionIds: basicTrainingMissionIds,
    unlockHintText: _basicTrainingHint,
  ),
  ModeRequirement(
    modeId: 'triangulation',
    displayName: 'Recon',
    requiredMissionIds: basicTrainingMissionIds,
    unlockHintText: _basicTrainingHint,
  ),
  ModeRequirement(
    modeId: 'daily_challenge',
    displayName: 'Daily Scramble',
    requiredMissionId: trainingFlightMissionId,
    unlockHintText: 'Complete Basic Training: Training Flight',
  ),
  ModeRequirement(
    modeId: 'daily_triangulation',
    displayName: 'Daily Recon',
    requiredMissionId: trainingReconMissionId,
    unlockHintText: 'Complete Basic Training: Training Recon',
  ),
  ModeRequirement(
    modeId: 'daily_briefing',
    displayName: 'Daily Briefing',
    requiredMissionId: trainingBriefingMissionId,
    unlockHintText: 'Complete Basic Training: Training Briefing',
  ),
  ModeRequirement(
    modeId: 'dogfight',
    displayName: 'Dogfight',
    requiredMissionIds: basicTrainingMissionIds,
    unlockHintText: _basicTrainingHint,
  ),
  ModeRequirement(
    modeId: 'matchmaking',
    displayName: 'Find a Challenger',
    requiredMissionIds: basicTrainingMissionIds,
    unlockHintText: _basicTrainingHint,
  ),
];

/// Look up the requirement for a specific mode.
ModeRequirement? getModeRequirement(String modeId) {
  for (final req in modeRequirements) {
    if (req.modeId == modeId) return req;
  }
  return null;
}
