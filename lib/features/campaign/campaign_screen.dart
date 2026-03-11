import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/providers/account_provider.dart';
import '../../game/tutorial/campaign_mission.dart';
import '../../game/tutorial/campaign_missions.dart';
import '../../game/tutorial/coach.dart';
import '../play/play_screen.dart';
import '../../game/map/region.dart';
import 'mission_dialog.dart';

/// Campaign screen showing the progressive tutorial missions.
class CampaignScreen extends ConsumerWidget {
  const CampaignScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    final progress = account.campaignProgress;

    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundDark,
        foregroundColor: FlitColors.textPrimary,
        title: const Text(
          'PILOT TRAINING',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        itemCount: campaignMissions.length,
        itemBuilder: (context, index) {
          final mission = campaignMissions[index];
          final result = progress[mission.id];
          final isCompleted = result != null;

          // A mission is unlocked if it's the first, or the previous one is complete.
          final isUnlocked = index == 0 ||
              progress.containsKey(campaignMissions[index - 1].id);

          return _MissionCard(
            mission: mission,
            result: result,
            isUnlocked: isUnlocked,
            isCompleted: isCompleted,
            onTap:
                isUnlocked ? () => _startMission(context, ref, mission) : null,
          );
        },
      ),
    );
  }

  void _startMission(
    BuildContext context,
    WidgetRef ref,
    CampaignMission mission,
  ) {
    MissionDialog.showBriefing(
      context,
      mission: mission,
      onStart: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PlayScreen(
              totalRounds: mission.rounds,
              enableFuel: mission.fuelEnabled,
              enabledClueTypes: mission.allowedClues.map((c) => c.name).toSet(),
              region: GameRegion.world,
              campaignMission: mission,
            ),
          ),
        );
      },
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({
    required this.mission,
    required this.result,
    required this.isUnlocked,
    required this.isCompleted,
    this.onTap,
  });

  final CampaignMission mission;
  final CampaignMissionResult? result;
  final bool isUnlocked;
  final bool isCompleted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flight path line
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? FlitColors.success
                        : isUnlocked
                            ? FlitColors.accent
                            : FlitColors.backgroundMid,
                    border: Border.all(
                      color: isCompleted
                          ? FlitColors.success
                          : isUnlocked
                              ? FlitColors.accent
                              : FlitColors.cardBorder,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : isUnlocked
                            ? Text(
                                '${mission.order}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              )
                            : const Icon(Icons.lock_outline,
                                size: 14, color: FlitColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
          // Mission card
          Expanded(
            child: Opacity(
              opacity: isUnlocked ? 1.0 : 0.45,
              child: Material(
                color: isCompleted
                    ? FlitColors.success.withOpacity(0.08)
                    : FlitColors.backgroundMid,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCompleted
                            ? FlitColors.success.withOpacity(0.3)
                            : isUnlocked
                                ? FlitColors.accent.withOpacity(0.3)
                                : FlitColors.cardBorder.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Coach country flag
                            Text(
                              mission.coach.flagEmoji,
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                mission.title,
                                style: TextStyle(
                                  color: isUnlocked
                                      ? FlitColors.textPrimary
                                      : FlitColors.textMuted,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (isCompleted && result != null)
                              _StarRating(stars: result!.stars),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mission.subtitle,
                          style: const TextStyle(
                            color: FlitColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              'Coach: ${mission.coach.name}',
                              style: const TextStyle(
                                color: FlitColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                            const Spacer(),
                            _ClueIcons(clues: mission.allowedClues),
                          ],
                        ),
                        if (mission.unlockMessage != null && isCompleted) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: FlitColors.accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              mission.unlockMessage!,
                              style: const TextStyle(
                                color: FlitColors.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  const _StarRating({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Icon(
          i < stars ? Icons.star : Icons.star_border,
          color: i < stars ? FlitColors.warning : FlitColors.textMuted,
          size: 16,
        );
      }),
    );
  }
}

class _ClueIcons extends StatelessWidget {
  const _ClueIcons({required this.clues});

  final Set<ClueType> clues;

  static IconData _iconFor(ClueType type) {
    switch (type) {
      case ClueType.flag:
      case ClueType.flagDescription:
        return Icons.flag;
      case ClueType.outline:
        return Icons.crop_square;
      case ClueType.borders:
        return Icons.border_all;
      case ClueType.capital:
        return Icons.location_city;
      case ClueType.stats:
        return Icons.bar_chart;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: clues
          .map((c) => Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(_iconFor(c), size: 14, color: FlitColors.textMuted),
              ))
          .toList(),
    );
  }
}
