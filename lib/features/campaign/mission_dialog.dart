import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../game/tutorial/campaign_mission.dart';

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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Coach flag + name
              Text(
                mission.coach.flagEmoji,
                style: const TextStyle(fontSize: 40),
              ),
              const SizedBox(height: 8),
              Text(
                mission.coach.name,
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${mission.coach.title} — ${mission.coach.nationality}',
                style: const TextStyle(
                  color: FlitColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              // Mission title
              Text(
                'MISSION ${mission.order}: ${mission.title.toUpperCase()}',
                style: const TextStyle(
                  color: FlitColors.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Coach greeting / briefing
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FlitColors.backgroundDark.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: FlitColors.cardBorder.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '"${mission.description}"',
                      style: const TextStyle(
                        color: FlitColors.textSecondary,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 20),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FlitColors.textSecondary,
                        side: const BorderSide(color: FlitColors.cardBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
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
                    color: FlitColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: FlitColors.accent.withOpacity(0.3),
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
              // Coach congratulation
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: FlitColors.backgroundDark.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      mission.coach.flagEmoji,
                      style: const TextStyle(fontSize: 24),
                    ),
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
