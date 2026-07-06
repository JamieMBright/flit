import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/game_settings.dart';
import '../../core/theme/flit_colors.dart';
import '../../core/widgets/menu_content_wrapper.dart';
import '../../data/providers/account_provider.dart';
import '../../game/clues/clue_types.dart';
import '../../game/map/region.dart';
import '../../game/quiz/quiz_category.dart';
import '../../game/quiz/quiz_difficulty.dart';
import '../../game/quiz/quiz_session.dart';
import '../../game/triangulation/triangulation_session.dart';
import '../../game/triangulation/triangulation_target.dart';
import '../../game/tutorial/training_missions.dart';
import '../campaign/coach_portrait.dart';
import '../friends/friends_screen.dart';
import '../license/license_screen.dart';
import '../play/play_screen.dart';
import '../quiz/quiz_game_screen.dart';
import '../shop/shop_screen.dart';
import '../sortie/sortie_screen.dart';
import '../triangulation/triangulation_game_screen.dart';

/// Basic + Advanced Training — the new-pilot school surface.
///
/// At level 1 this IS the Flight School: exactly three short coached
/// missions (fly, recon, briefing). Each one unlocks its matching daily
/// mode immediately; finishing all three earns the pilot's wings (Level 2,
/// every base mode). Afterwards the same surface carries the optional
/// Advanced Training track — one-time-reward lessons on sorties, hints,
/// the license, fuel, the shop, and head-to-head play.
class TrainingScreen extends ConsumerStatefulWidget {
  const TrainingScreen({super.key});

  @override
  ConsumerState<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends ConsumerState<TrainingScreen> {
  /// Guards the WINGS EARNED celebration so it shows exactly once per visit.
  bool _celebrationShowing = false;

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider);
    final progress = account.campaignProgress;
    final basicsDone = account.basicTrainingComplete;
    final basicCount = account.basicTrainingCompletedCount;
    final totalDone =
        allTrainingMissions.where((m) => progress.containsKey(m.id)).length;

    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundDark,
        foregroundColor: FlitColors.textPrimary,
        title: Text(
          basicsDone ? 'TRAINING MISSIONS' : 'BASIC TRAINING',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: MenuContentWrapper(
        child: Column(
          children: [
            _TrainingHeader(
              basicsDone: basicsDone,
              basicCount: basicCount,
              totalDone: totalDone,
              totalCount: allTrainingMissions.length,
            ),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  _SectionLabel(
                    label: 'BASIC TRAINING',
                    detail: basicsDone
                        ? 'Wings earned'
                        : 'Required — earn your wings',
                    icon: Icons.military_tech_rounded,
                  ),
                  const SizedBox(height: 10),
                  for (final mission in basicTrainingMissions)
                    _TrainingMissionCard(
                      mission: mission,
                      isCompleted: progress.containsKey(mission.id),
                      isAvailable: true,
                      onTap: () => _startMission(mission),
                    ),
                  const SizedBox(height: 14),
                  _SectionLabel(
                    label: 'ADVANCED TRAINING',
                    detail: basicsDone
                        ? 'Optional missions — one-time rewards'
                        : 'Opens after Basic Training',
                    icon: Icons.workspace_premium_rounded,
                  ),
                  const SizedBox(height: 10),
                  for (final mission in advancedTrainingMissions)
                    _TrainingMissionCard(
                      mission: mission,
                      isCompleted: progress.containsKey(mission.id),
                      isAvailable: basicsDone,
                      onTap: () => _startMission(mission),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Mission launching
  // ---------------------------------------------------------------------

  Future<void> _startMission(TrainingMission mission) async {
    final wasBasicsDone = ref.read(accountProvider).basicTrainingComplete;

    final start = await _showBriefing(mission);
    if (start != true || !mounted) return;

    switch (mission.kind) {
      case TrainingMissionKind.flight:
        final flight = mission.flightMission!;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PlayScreen(
              totalRounds: flight.rounds,
              enableFuel: flight.fuelEnabled,
              enabledClueTypes: flight.allowedClues.map((c) => c.name).toSet(),
              region: GameRegion.world,
              campaignMission: flight,
            ),
          ),
        );
      case TrainingMissionKind.recon:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TriangulationGameScreen(
              config: TriangulationConfig(
                seed: Random().nextInt(1 << 31),
                rounds: 1,
                markerCount: 3,
                clueTypes: {ClueType.flag},
                labelTypes: {TriLabel.capital},
                difficulty: GameDifficulty.easy,
              ),
              onSessionComplete: (totalScore) => ref
                  .read(accountProvider.notifier)
                  .completeTrainingMission(mission.id, score: totalScore),
            ),
          ),
        );
      case TrainingMissionKind.briefing:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => QuizGameScreen(
              mode: QuizMode.allStates,
              categories: const {QuizCategory.capital},
              region: GameRegion.europe,
              difficulty: QuizDifficulty.easy,
              presetQuestions: _buildTrainingBriefingQuestions(),
              onSessionComplete: (summary) => ref
                  .read(accountProvider.notifier)
                  .completeTrainingMission(mission.id,
                      score: summary.totalScore),
            ),
          ),
        );
      case TrainingMissionKind.sortie:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SortieScreen()),
        );
      case TrainingMissionKind.license:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const LicenseScreen()),
        );
        if (!mounted) return;
        // Visiting the hangar is the objective — record it on return.
        ref
            .read(accountProvider.notifier)
            .completeTrainingObjective(mission.id);
      case TrainingMissionKind.shop:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ShopScreen()),
        );
        if (!mounted) return;
        // Browsing the shop is the objective — record it on return.
        ref
            .read(accountProvider.notifier)
            .completeTrainingObjective(mission.id);
      case TrainingMissionKind.challenge:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const FriendsScreen()),
        );
    }

    await _maybeCelebrateWings(wasBasicsDone);
  }

  /// Three easy, deterministic tap-the-country questions on Europe —
  /// capital clues with labels on, mirroring the Daily Briefing format.
  static List<QuizQuestion> _buildTrainingBriefingQuestions() {
    const seed = 947001; // Fixed: the same gentle first briefing for everyone.
    final generator =
        QuizQuestionGenerator(region: GameRegion.europe, seed: seed);
    final rng = Random(seed);
    final areas = List.of(RegionalData.getAreas(GameRegion.europe))
      ..shuffle(rng);

    final questions = <QuizQuestion>[];
    for (final area in areas) {
      final question = generator.generateForArea(area, QuizCategory.capital);
      if (question != null) {
        questions.add(question.copyWith(labelFree: false));
        if (questions.length == 3) break;
      }
    }
    return questions;
  }

  /// Show the WINGS EARNED celebration when the third Basic Training
  /// mission lands. Waits until this screen is topmost again — the quiz
  /// flow replaces its route, so the push future can resolve while the
  /// results screen is still up.
  Future<void> _maybeCelebrateWings(bool wasBasicsDone) async {
    if (wasBasicsDone || _celebrationShowing) return;
    while (true) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route == null || route.isCurrent) break;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (!mounted) return;
    if (!ref.read(accountProvider).basicTrainingComplete) return;
    _celebrationShowing = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _WingsEarnedDialog(),
    );
    _celebrationShowing = false;
  }

  // ---------------------------------------------------------------------
  // Briefing dialog
  // ---------------------------------------------------------------------

  Future<bool?> _showBriefing(TrainingMission mission) {
    return showDialog<bool>(
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CoachPortrait(coach: mission.coach, size: 56),
                  const SizedBox(width: 12),
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
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(false),
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
              const SizedBox(height: 14),
              Center(
                child: Text(
                  '${mission.isBasic ? 'BASIC' : 'ADVANCED'} '
                  '${mission.order}: ${mission.title.toUpperCase()}',
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
              Container(
                width: double.infinity,
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
              _BriefingDetail(
                icon: Icons.flag_circle_rounded,
                label: 'Objective',
                value: mission.objective,
              ),
              _BriefingDetail(
                icon: Icons.star,
                label: 'XP Reward',
                value: '+${mission.xpReward}',
              ),
              _BriefingDetail(
                icon: Icons.monetization_on,
                label: 'Coins',
                value: '+${mission.coinReward}',
              ),
              if (mission.unlockPreview != null)
                _BriefingDetail(
                  icon: Icons.lock_open_rounded,
                  label: 'Clearance',
                  value: mission.unlockPreview!,
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
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
}

// ---------------------------------------------------------------------------
// Header — wing-notch progress during basics, full trail after
// ---------------------------------------------------------------------------

class _TrainingHeader extends StatelessWidget {
  const _TrainingHeader({
    required this.basicsDone,
    required this.basicCount,
    required this.totalDone,
    required this.totalCount,
  });

  final bool basicsDone;
  final int basicCount;
  final int totalDone;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                basicsDone
                    ? Icons.military_tech_rounded
                    : Icons.flight_takeoff_rounded,
                color: FlitColors.gold,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  basicsDone
                      ? 'Wings earned — keep training for rewards'
                      : 'Earn your wings — complete all 3 missions',
                  style: const TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                basicsDone ? '$totalDone/$totalCount' : '$basicCount/3',
                style: const TextStyle(
                  color: FlitColors.gold,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (basicsDone)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: totalCount == 0 ? 0 : totalDone / totalCount,
                minHeight: 6,
                backgroundColor: FlitColors.backgroundMid,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(FlitColors.gold),
              ),
            )
          else
            // Three wing-feather notches — one per Basic Training mission.
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: i < basicCount
                            ? FlitColors.gold
                            : FlitColors.backgroundMid,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.label,
    required this.detail,
    required this.icon,
  });

  final String label;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: FlitColors.gold),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: FlitColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            detail,
            style: const TextStyle(
              color: FlitColors.textMuted,
              fontSize: 11,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Mission card — coach portrait, objective, rewards, unlock chip
// ---------------------------------------------------------------------------

class _TrainingMissionCard extends StatelessWidget {
  const _TrainingMissionCard({
    required this.mission,
    required this.isCompleted,
    required this.isAvailable,
    required this.onTap,
  });

  final TrainingMission mission;
  final bool isCompleted;
  final bool isAvailable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flight-path trail marker (mirrors the campaign screen).
          SizedBox(
            width: 40,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? FlitColors.success
                    : isAvailable
                        ? FlitColors.accent
                        : FlitColors.backgroundMid,
                border: Border.all(
                  color: isCompleted
                      ? FlitColors.success
                      : isAvailable
                          ? FlitColors.accent
                          : FlitColors.cardBorder,
                  width: 2,
                ),
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : isAvailable
                        ? Text(
                            '${mission.order}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          )
                        : const Icon(
                            Icons.lock_outline,
                            size: 14,
                            color: FlitColors.textMuted,
                          ),
              ),
            ),
          ),
          Expanded(
            child: Opacity(
              opacity: isAvailable ? 1.0 : 0.45,
              child: Material(
                color: isCompleted
                    ? FlitColors.success.withValues(alpha: 0.08)
                    : FlitColors.backgroundMid,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: isAvailable
                      ? onTap
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Complete Basic Training to open '
                                'Advanced Training',
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCompleted
                            ? FlitColors.success.withValues(alpha: 0.3)
                            : isAvailable
                                ? FlitColors.accent.withValues(alpha: 0.3)
                                : FlitColors.cardBorder.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CoachPortrait(coach: mission.coach, size: 34),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mission.title,
                                    style: TextStyle(
                                      color: isAvailable
                                          ? FlitColors.textPrimary
                                          : FlitColors.textMuted,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    mission.subtitle,
                                    style: const TextStyle(
                                      color: FlitColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isCompleted)
                              const Icon(
                                Icons.verified_rounded,
                                color: FlitColors.success,
                                size: 20,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.flag_circle_rounded,
                              size: 13,
                              color: FlitColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                mission.objective,
                                style: const TextStyle(
                                  color: FlitColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Text(
                              '+${mission.xpReward} XP · '
                              '+${mission.coinReward}c',
                              style: const TextStyle(
                                color: FlitColors.gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        if (mission.unlockPreview != null && !isCompleted) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: FlitColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              mission.unlockPreview!,
                              style: const TextStyle(
                                color: FlitColors.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        if (mission.unlockMessage != null && isCompleted) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: FlitColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              mission.unlockMessage!,
                              style: const TextStyle(
                                color: FlitColors.success,
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

// ---------------------------------------------------------------------------
// WINGS EARNED — the level-2 celebration
// ---------------------------------------------------------------------------

class _WingsEarnedDialog extends StatelessWidget {
  const _WingsEarnedDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: FlitColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1.0),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: FlitColors.gold.withValues(alpha: 0.12),
                  boxShadow: [
                    BoxShadow(
                      color: FlitColors.gold.withValues(alpha: 0.35),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.military_tech_rounded,
                  color: FlitColors.gold,
                  size: 56,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'WINGS EARNED',
              style: TextStyle(
                color: FlitColors.gold,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: FlitColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: FlitColors.gold.withValues(alpha: 0.4),
                ),
              ),
              child: const Text(
                'LEVEL 2',
                style: TextStyle(
                  color: FlitColors.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Basic Training complete. Sorties, campaign, free flight, '
              'recon, uncharted and head-to-head duels are all open — '
              'the sky is yours.',
              style: TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlitColors.gold,
                  foregroundColor: FlitColors.backgroundDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'TAKE TO THE SKIES',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BriefingDetail extends StatelessWidget {
  const _BriefingDetail({
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
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
