import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../game/tutorial/campaign_mission.dart';
import '../../game/tutorial/coach.dart';

/// Dialogs for mission briefing (before) and completion (after) screens.
class MissionDialog {
  MissionDialog._();

  /// Show the pre-mission briefing dialog with coach introduction.
  static void showBriefing(
    BuildContext context, {
    required CampaignMission mission,
    required VoidCallback onStart,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: FlitColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Coach portrait + name row + close button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Coach portrait (top-left)
                  _CoachPortrait(coach: mission.coach, size: 56),
                  const SizedBox(width: 12),
                  // Name, flag, and title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              mission.coach.flagEmoji,
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                mission.coach.name,
                                style: const TextStyle(
                                  color: FlitColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mission.coach.title,
                          style: const TextStyle(
                            color: FlitColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Close button (top-right)
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: FlitColors.backgroundMid,
                        border: Border.all(
                          color: FlitColors.cardBorder.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: FlitColors.textSecondary,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Coach bio
              Text(
                mission.coach.bio,
                style: const TextStyle(
                  color: FlitColors.textSecondary,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 14),
              // Mission title (centered)
              Center(
                child: Text(
                  'MISSION ${mission.order}: ${mission.title.toUpperCase()}',
                  style: const TextStyle(
                    color: FlitColors.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),
              // Mission briefing
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: FlitColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '"${mission.description}"',
                  style: const TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              // Mission details
              _MissionDetail(
                icon: Icons.flag,
                label: 'Rounds',
                value: '${mission.rounds}',
              ),
              _MissionDetail(
                icon: Icons.local_gas_station,
                label: 'Fuel',
                value: mission.fuelEnabled ? 'Enabled' : 'Disabled',
              ),
              _MissionDetail(
                icon: Icons.star,
                label: 'XP Reward',
                value: '+${mission.xpReward}',
              ),
              _MissionDetail(
                icon: Icons.monetization_on,
                label: 'Coins',
                value: '+${mission.coinReward}',
              ),
              const SizedBox(height: 16),
              // Start button (full width — close via X in top-right)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onStart();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlitColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'START MISSION',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show the coach farewell speech before the results dialog.
  static void showFarewell(
    BuildContext context, {
    required CampaignMission mission,
    required String farewellText,
    required VoidCallback onContinue,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: FlitColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Coach portrait
              _CoachPortrait(coach: mission.coach, size: 64),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    mission.coach.flagEmoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    mission.coach.name,
                    style: const TextStyle(
                      color: FlitColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Farewell message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F0E8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFD4C9B8),
                  ),
                ),
                child: Text(
                  farewellText,
                  style: const TextStyle(
                    color: Color(0xFF2D2D2D),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onContinue();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlitColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'CONTINUE',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show the post-mission completion dialog with results.
  static void showCompletion(
    BuildContext context, {
    required CampaignMission mission,
    required CampaignMissionResult result,
    required bool isFirstCompletion,
    VoidCallback? onContinue,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: FlitColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.military_tech_rounded,
                color: FlitColors.success,
                size: 48,
              ),
              const SizedBox(height: 8),
              const Text(
                'MISSION COMPLETE',
                style: TextStyle(
                  color: FlitColors.success,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              // Stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  return Icon(
                    i < result.stars ? Icons.star : Icons.star_border,
                    color: i < result.stars
                        ? FlitColors.warning
                        : FlitColors.textMuted,
                    size: 32,
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                'Score: ${result.score}',
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isFirstCompletion) ...[
                const SizedBox(height: 12),
                _RewardRow(
                  icon: Icons.star,
                  label: 'XP Earned',
                  value: '+${mission.xpReward}',
                  color: FlitColors.accent,
                ),
                _RewardRow(
                  icon: Icons.monetization_on,
                  label: 'Coins Earned',
                  value: '+${mission.coinReward}',
                  color: FlitColors.warning,
                ),
              ],
              if (mission.unlockMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: FlitColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: FlitColors.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_open,
                          size: 16, color: FlitColors.accent),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          mission.unlockMessage!,
                          style: const TextStyle(
                            color: FlitColors.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              // Coach congratulation with portrait
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: FlitColors.backgroundDark.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _CoachPortrait(coach: mission.coach, size: 36),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '"${mission.coach.greeting}"',
                        style: const TextStyle(
                          color: FlitColors.textSecondary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onContinue?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlitColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'CONTINUE',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Coach portrait widget — shows asset image with initial-circle fallback
// ---------------------------------------------------------------------------

class _CoachPortrait extends StatelessWidget {
  const _CoachPortrait({required this.coach, this.size = 48});

  final Coach coach;
  final double size;

  @override
  Widget build(BuildContext context) {
    // If an asset image is provided, try loading it.
    if (coach.imageAsset != null) {
      return ClipOval(
        child: Image.asset(
          coach.imageAsset!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialCircle(),
        ),
      );
    }
    return _initialCircle();
  }

  Widget _initialCircle() {
    // Deterministic colour from coach ID hash.
    final colors = [
      FlitColors.accent,
      FlitColors.success,
      FlitColors.warning,
      const Color(0xFF7C4DFF),
      const Color(0xFF00BFA5),
      const Color(0xFFFF6D00),
      const Color(0xFFAA00FF),
      const Color(0xFF2979FF),
      const Color(0xFFD50000),
      const Color(0xFF00C853),
    ];
    final colorIndex = coach.id.hashCode.abs() % colors.length;
    final bgColor = colors[colorIndex];

    // Extract initials (first letter of first and last name).
    final parts = coach.name.split(' ');
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'
        : parts.first.substring(0, 2);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor.withValues(alpha: 0.2),
        border: Border.all(color: bgColor.withValues(alpha: 0.5), width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            initials.toUpperCase(),
            style: TextStyle(
              color: bgColor,
              fontSize: size * 0.35,
              fontWeight: FontWeight.w800,
            ),
          ),
          // Flag badge at bottom-right
          Positioned(
            right: 0,
            bottom: 0,
            child: Text(
              coach.flagEmoji,
              style: TextStyle(fontSize: size * 0.28),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Supporting widgets
// ---------------------------------------------------------------------------

class _MissionDetail extends StatelessWidget {
  const _MissionDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: FlitColors.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: FlitColors.textMuted,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: FlitColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
