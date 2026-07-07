import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/flit_colors.dart';
import '../../core/widgets/country_flag.dart';
import '../../core/widgets/menu_content_wrapper.dart';
import '../../data/providers/account_provider.dart';
import '../../game/map/region.dart';
import '../../game/tutorial/training_missions.dart';
import '../campaign/coach_portrait.dart';
import '../campaign/coached_intro_screen.dart';
import '../friends/friends_screen.dart';
import '../license/license_screen.dart';
import '../play/play_screen.dart';
import '../quiz/briefing_tutorial_screen.dart';
import '../shop/shop_screen.dart';
import '../sortie/sortie_screen.dart';
import '../triangulation/recon_tutorial_screen.dart';

/// Basic + Advanced Training — the new-pilot school surface.
///
/// At level 1 this IS the Flight School: exactly three short coached
/// missions (fly, recon, briefing). Each one unlocks its matching daily
/// mode immediately; finishing all three earns the pilot's wings (Level 2,
/// every base mode). Afterwards the same surface carries the optional
/// Advanced Training track — one-time-reward lessons on sorties, hints,
/// the license, fuel, the shop, and head-to-head play.
/// How the pilot chose to fulfil the Wingman Duel mission.
enum _DuelChoice { friends, practice }

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

    // Advanced Training missions open with a short coach-led walkthrough that
    // teaches the system this mission introduces (rated play, hints, the
    // license, fuel, the shop, or challenges) BEFORE handing the pilot to the
    // real activity — mirroring the guided thinking of the Basic Training
    // lessons rather than dropping them in cold. Basic missions have their own
    // dedicated guided flow, so they skip this.
    if (!mission.isBasic) {
      final proceed = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => _advancedIntroFor(mission),
        ),
      );
      if (proceed != true || !mounted) return;
    }

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
        // Fully guided, forgiving Recon lesson (find France by its
        // neighbours) rather than a live timed round. Completion is recorded
        // through the same campaign path, so Daily Recon still unlocks and
        // Basic Training still progresses toward the pilot's wings.
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ReconTutorialScreen(
              onComplete: (totalScore) => ref
                  .read(accountProvider.notifier)
                  .completeTrainingMission(mission.id, score: totalScore),
            ),
          ),
        );
      case TrainingMissionKind.briefing:
        // Fully guided, forgiving Briefing lesson (find the country Lotfia
        // names, over Egypt and its neighbours) rather than a timed quiz.
        // Completion is recorded through the same campaign path, so Daily
        // Briefing still unlocks and Basic Training still progresses toward
        // the pilot's wings.
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BriefingTutorialScreen(
              onComplete: (totalScore) => ref
                  .read(accountProvider.notifier)
                  .completeTrainingMission(mission.id, score: totalScore),
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
        // A pilot with no friends yet must never be stuck on this mission, so
        // offer both paths: duel a real rival, or fly a self-contained
        // practice duel that completes the objective on its own.
        final choice = await _showDuelChoice();
        if (!mounted) return;
        if (choice == _DuelChoice.friends) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const FriendsScreen()),
          );
        } else if (choice == _DuelChoice.practice) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PlayScreen(
                totalRounds: challengePracticeDuelMission.rounds,
                enabledClueTypes: challengePracticeDuelMission.allowedClues
                    .map((c) => c.name)
                    .toSet(),
                region: GameRegion.world,
                campaignMission: challengePracticeDuelMission,
              ),
            ),
          );
        }
    }

    await _maybeCelebrateWings(wasBasicsDone);
  }

  /// Ask how the pilot wants to complete Wingman Duel: challenge a real friend
  /// or fly a self-contained practice duel. Returns null if dismissed.
  Future<_DuelChoice?> _showDuelChoice() {
    return showDialog<_DuelChoice>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FlitColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Throw the gauntlet',
          style: TextStyle(
            color: FlitColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Challenge a friend to a real head-to-head — or, if you have no '
          'rival yet, fly a practice duel to rehearse the format. Either '
          'earns your wings.',
          style: TextStyle(color: FlitColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_DuelChoice.practice),
            child: const Text(
              'Practice Duel',
              style: TextStyle(color: FlitColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(_DuelChoice.friends),
            style: ElevatedButton.styleFrom(
              backgroundColor: FlitColors.accent,
              foregroundColor: FlitColors.textPrimary,
            ),
            child: const Text('Duel a Friend'),
          ),
        ],
      ),
    );
  }

  /// The short, coach-led walkthrough shown before an Advanced Training
  /// activity. Each mission's beats teach the system it introduces, in the
  /// coach's own voice, then the pilot presses through to the real screen.
  CoachedIntroScreen _advancedIntroFor(TrainingMission mission) {
    switch (mission.id) {
      case 'adv_rated_sortie':
        return CoachedIntroScreen(
          coach: mission.coach,
          title: mission.title,
          launchLabel: 'FLY THE SORTIE',
          beats: const [
            CoachIntroBeat(
              icon: Icons.military_tech_rounded,
              headline: 'RATED PLAY',
              message: 'The Standard Sortie is rated flying — five rounds, one '
                  'score that counts. This is where a pilot earns their rank.',
              points: [
                'Five rated rounds flown back to back',
                'Your best run is remembered — every sortie is on the record',
              ],
            ),
            CoachIntroBeat(
              icon: Icons.leaderboard_rounded,
              headline: 'THE TIER LADDER',
              message:
                  'Your score sorts you onto a tier ladder — climb from the '
                  'lower ranks toward Ace as your scores rise.',
              points: [
                'Higher scores lift you into higher tiers',
                'The ladder remembers you between sorties',
              ],
            ),
            CoachIntroBeat(
              icon: Icons.balance_rounded,
              headline: 'A FAIR FIELD',
              message:
                  'Rated sorties normalise boosts so rank reflects skill, not '
                  'your inventory. Post a score — the result matters less than '
                  'the wheels leaving the ground.',
              points: [
                'Consumable boosts are levelled out in rated play',
                'One run is all you need to join the ladder',
              ],
            ),
          ],
        );
      case 'adv_hint_school':
        return CoachedIntroScreen(
          coach: mission.coach,
          title: mission.title,
          launchLabel: 'START THE FLIGHT',
          beats: const [
            CoachIntroBeat(
              icon: Icons.style_rounded,
              headline: 'CLUE TYPES',
              message:
                  'Each clue names the country a different way. Cycle between '
                  'them and cross-reference before you commit.',
              points: [
                'Flag — the colours and emblem of the nation',
                'Capital — the city at its heart',
                'Borders — the neighbours that surround it',
              ],
            ),
            CoachIntroBeat(
              icon: Icons.lightbulb_rounded,
              headline: 'HINT COSTS',
              message:
                  'When you are truly stuck, buy a hint — but each one costs '
                  'more than the last. Ask early, or not at all.',
              points: [
                '−500, then −1,000, −1,500…',
                'Up to −2,500 for a full auto-navigate',
              ],
            ),
            CoachIntroBeat(
              icon: Icons.flag_rounded,
              headline: 'YOUR TARGET',
              message: 'One country waits: a red flag with a green pentagram, '
                  'capital Rabat. Cross-reference your clues and find it.',
              points: ['Spend a hint if you must — that is what this is for'],
            ),
          ],
        );
      case 'adv_license':
        return CoachedIntroScreen(
          coach: mission.coach,
          title: mission.title,
          launchLabel: 'OPEN THE HANGAR',
          beats: const [
            CoachIntroBeat(
              icon: Icons.badge_rounded,
              headline: 'YOUR PILOT LICENSE',
              message:
                  'Your License is a living record — stats that grow as you '
                  'fly. Everything you do is written into it.',
              points: ['Study it often; it is the measure of your progress'],
            ),
            CoachIntroBeat(
              icon: Icons.local_fire_department_rounded,
              headline: 'HEAT & PITY',
              message:
                  'Heat builds as you play and raises your luck. Pity is your '
                  'safety net — it guarantees a reward when fortune stalls.',
              points: [
                'Heat rises the more you fly, improving your odds',
                'Pity ensures a dry streak still pays out eventually',
              ],
            ),
            CoachIntroBeat(
              icon: Icons.refresh_rounded,
              headline: 'THE FREE REROLL',
              message:
                  'One reroll is free every single day. Never let it go to '
                  'waste — open the hangar and see it for yourself.',
              points: ['Resets daily — a free spin of fortune, always'],
            ),
          ],
        );
      case 'adv_fuel_run':
        return CoachedIntroScreen(
          coach: mission.coach,
          title: mission.title,
          launchLabel: 'START THE RUN',
          beats: const [
            CoachIntroBeat(
              icon: Icons.local_gas_station_rounded,
              headline: 'A REAL TANK',
              message:
                  'This flight has fuel, and it drains. Every wasted turn is '
                  'fuel you will not get back — fly straight lines.',
              points: [
                'Two island targets to reach before the tank runs dry',
                'Bank hard only when you must',
              ],
            ),
            CoachIntroBeat(
              icon: Icons.emoji_events_rounded,
              headline: 'LAND WITH FUEL',
              message:
                  'The fuel left in your tank when you land pays a bonus — up '
                  'to 5,000 points. Efficiency is rewarded.',
              points: ['Reach both targets, then land with a margin to spare'],
            ),
            CoachIntroBeat(
              icon: Icons.flight_rounded,
              headline: 'OR FLY FREE',
              message:
                  'And remember Free Flight: no tank, no pressure — just coins '
                  'for every country you find, at your own pace.',
              points: ['Free Flight is the calm way to farm coins and learn'],
            ),
          ],
        );
      case 'adv_shop':
        return CoachedIntroScreen(
          coach: mission.coach,
          title: mission.title,
          launchLabel: 'BROWSE THE SHOP',
          beats: const [
            CoachIntroBeat(
              icon: Icons.storefront_rounded,
              headline: 'THE SUPPLY SHOP',
              message:
                  'The Supply Shop stocks consumables — the tools that carry '
                  'you through the toughest days aloft.',
              points: ['Hints, boosts and supplies, all bought with coins'],
            ),
            CoachIntroBeat(
              icon: Icons.calendar_month_rounded,
              headline: 'THE WEEKLY HANGAR',
              message:
                  'The hangar rotates every week — fresh stock and limited '
                  'offers worth planning your coins around.',
              points: ['New supplies each week; check in before they rotate'],
            ),
            CoachIntroBeat(
              icon: Icons.savings_rounded,
              headline: 'SPEND WISELY',
              message:
                  'Know what your coins can buy before you need it. Come, let '
                  'us walk the shelves together.',
              points: ['Plan your purchases; every coin should earn its keep'],
            ),
          ],
        );
      case 'adv_challenge':
        return CoachedIntroScreen(
          coach: mission.coach,
          title: mission.title,
          launchLabel: 'FIND YOUR RIVAL',
          beats: const [
            CoachIntroBeat(
              icon: Icons.sports_mma_rounded,
              headline: 'HEAD TO HEAD',
              message:
                  'A duel is you against one rival — the same targets, and the '
                  'higher score takes it. Simple, and fierce.',
              points: ['Same challenge for both pilots; best score wins'],
            ),
            CoachIntroBeat(
              icon: Icons.send_rounded,
              headline: 'THROW THE GAUNTLET',
              message:
                  'Open Friends and send a challenge — or accept one already '
                  'waiting for you. Either counts.',
              points: [
                'Send a fresh challenge to a friend',
                'Or answer a duel someone has sent you',
              ],
            ),
            CoachIntroBeat(
              icon: Icons.timer_rounded,
              headline: 'THE DUEL IS LIVE',
              message:
                  'The duel counts from the moment the gauntlet is thrown. '
                  'Let us go and find your rival.',
              points: ['One rival is all you need — go and challenge them'],
            ),
          ],
        );
      default:
        // Fallback: a single-beat intro from the mission's own description,
        // so any future advanced mission still opens coached rather than cold.
        return CoachedIntroScreen(
          coach: mission.coach,
          title: mission.title,
          launchLabel: 'BEGIN',
          beats: [
            CoachIntroBeat(
              icon: Icons.school_rounded,
              headline: mission.subtitle.toUpperCase(),
              message: mission.description,
            ),
          ],
        );
    }
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
                            CountryFlag(
                              code: mission.coach.countryCode,
                              height: 14,
                              width: 21,
                              borderRadius: 2,
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
