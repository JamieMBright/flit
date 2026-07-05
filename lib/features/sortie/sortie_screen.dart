import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/flit_colors.dart';
import '../../core/widgets/menu_content_wrapper.dart';
import '../../core/widgets/rating_tier_chip.dart';
import '../../data/models/cosmetic.dart';
import '../../data/models/rating_tier.dart';
import '../../data/models/seasonal_theme.dart';
import '../../data/models/sortie.dart';
import '../../data/providers/account_provider.dart';
import '../../data/services/matchmaking_service.dart';
import '../../data/services/sortie_service.dart';
import '../../game/economy/rated_loadout.dart';
import '../play/play_screen.dart';

/// Standard Sortie: the rated, standardized, seeded 5-round flight run.
///
/// Same format as H2H challenges, solo-playable anytime. Scores post to the
/// Sortie leaderboard and drive the per-mode 'sortie' rating via ghost
/// duels. RATED = boost-normalized: standard loadout, cosmetics only
/// (see lib/game/economy/rated_loadout.dart).
class SortieScreen extends ConsumerStatefulWidget {
  const SortieScreen({super.key});

  @override
  ConsumerState<SortieScreen> createState() => _SortieScreenState();
}

class _SortieScreenState extends ConsumerState<SortieScreen> {
  RatingInfo? _rating;
  List<SortieLeaderboardRow> _topRuns = const [];
  bool _loadingBoard = true;

  /// Outcome of the most recent run (shown in a sheet after the flight).
  SortieOutcome? _lastOutcome;
  int _lastScore = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final player = ref.read(accountProvider).currentPlayer;
    final ratingFuture = player.id.isEmpty
        ? Future<RatingInfo?>.value(null)
        : MatchmakingService.instance.fetchRating(
            userId: player.id,
            gameMode: SortieService.gameMode,
            fallbackLevel: player.level,
            fallbackBestScore: player.bestScore ?? 0,
          );
    final boardFuture = SortieService.instance.fetchTopRuns(limit: 10);

    final results = await Future.wait<dynamic>([ratingFuture, boardFuture]);
    if (!mounted) return;
    setState(() {
      _rating = results[0] as RatingInfo?;
      _topRuns = results[1] as List<SortieLeaderboardRow>;
      _loadingBoard = false;
    });
  }

  // ---------------------------------------------------------------------------
  // Launch
  // ---------------------------------------------------------------------------

  void _takeoff() {
    final run = SortieRun.generate();
    final account = ref.read(accountProvider);
    final planeId = account.equippedPlaneId;
    final plane = CosmeticCatalog.getById(planeId);
    final contrail = CosmeticCatalog.getById(account.equippedContrailId);
    final contrailPrimary = contrail?.colorScheme?['primary'];
    final contrailSecondary = contrail?.colorScheme?['secondary'];

    Navigator.of(context)
        .push(
      MaterialPageRoute<void>(
        builder: (_) => PlayScreen(
          totalRounds: SortieRun.totalRounds,
          challengeSeeds: run.seeds,
          coinReward: SortieRun.completionCoinReward,
          enableFuel: true,
          scoreRegion: 'sortie',
          // RATED NORMALIZATION (owner ruling): standard loadout physics —
          // no plane stats, no license multipliers. Money never buys
          // rating. Cosmetics (skin, contrail, companion) still show.
          fuelBoostMultiplier: RatedLoadout.standard.fuelBoostMultiplier,
          planeHandling: RatedLoadout.standard.planeHandling,
          planeSpeed: RatedLoadout.standard.planeSpeed,
          planeFuelEfficiency: RatedLoadout.standard.planeFuelEfficiency,
          // Cosmetics only:
          planeColorScheme: SeasonalTheme.resolvePlaneColorScheme(
            fallback: plane?.colorScheme,
          ),
          planeWingSpan: plane?.wingSpan,
          equippedPlaneId: SeasonalTheme.resolvePlaneShapeId(
            fallback: planeId,
          ),
          companionType: account.avatar.companion,
          contrailPrimaryColor:
              contrailPrimary != null ? Color(contrailPrimary) : null,
          contrailSecondaryColor:
              contrailSecondary != null ? Color(contrailSecondary) : null,
          onRoundResults: (roundDetails, totalScore, aborted) =>
              _submitRun(run, roundDetails, totalScore),
        ),
      ),
    )
        .then((_) {
      if (!mounted) return;
      _refresh();
      _showOutcomeSheetIfAny();
    });
  }

  Future<void> _submitRun(
    SortieRun run,
    List<Map<String, dynamic>> roundDetails,
    int totalScore,
  ) async {
    final notifier = ref.read(accountProvider.notifier);
    final player = ref.read(accountProvider).currentPlayer;

    // Big sortie performances pump the license HOT (dailies do this too).
    notifier.pumpLicenseFromPerformance(
      score: totalScore,
      maxScore: SortieRun.maxRunScore,
    );

    final totalTimeMs = roundDetails.fold<int>(
      0,
      (sum, r) => sum + (r['time_ms'] as int? ?? 0),
    );
    final outcome = await SortieService.instance.submitRun(
      run: run,
      totalScore: totalScore,
      totalTimeMs: totalTimeMs,
      playerName: player.username.isNotEmpty ? player.username : 'Pilot',
      roundDetails: roundDetails,
    );
    if (!mounted) return;
    setState(() {
      _lastOutcome = outcome;
      _lastScore = totalScore;
    });
  }

  void _showOutcomeSheetIfAny() {
    final outcome = _lastOutcome;
    if (outcome == null) return;
    _lastOutcome = null;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: FlitColors.backgroundMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SortieOutcomeSheet(
        outcome: outcome,
        score: _lastScore,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: const Text(
          'Standard Sortie',
          style: TextStyle(color: FlitColors.textPrimary),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: FlitColors.textPrimary),
      ),
      body: SafeArea(
        child: MenuContentWrapper(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildSectionLabel(
                          'SORTIE LEADERBOARD', Icons.emoji_events),
                      const SizedBox(height: 10),
                      _buildLeaderboard(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final rating = _rating;
    final tier = rating != null ? RatingTier.fromRating(rating.rating) : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlitColors.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FlitColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.military_tech,
              color: FlitColors.gold,
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'STANDARD SORTIE',
            style: TextStyle(
              color: FlitColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Five seeded rounds. Same format as head-to-head. '
            'Your run duels a ghost pilot at your rating.',
            style: TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (rating != null)
            RatingTierChip(
              rating: rating.rating,
              provisional: rating.provisional,
            ),
          if (rating != null && tier != null && tier.next != null) ...[
            const SizedBox(height: 6),
            Text(
              '${tier.pointsToNext(rating.rating)} rating to '
              '${tier.next!.displayName}',
              style: const TextStyle(
                color: FlitColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: FlitColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: FlitColors.accent.withValues(alpha: 0.25),
              ),
            ),
            child: const Text(
              'Rated: standard loadout for everyone — pure skill',
              style: TextStyle(
                color: FlitColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, IconData icon) => Row(
        children: [
          Icon(icon, color: FlitColors.textMuted, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: FlitColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      );

  Widget _buildLeaderboard() {
    if (_loadingBoard) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(color: FlitColors.accent),
        ),
      );
    }
    if (_topRuns.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlitColors.cardBorder),
        ),
        child: const Text(
          'No rated runs yet — fly the first sortie and set the bar.',
          style: TextStyle(color: FlitColors.textSecondary, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }
    final myId = ref.read(accountProvider).currentPlayer.id;
    return Column(
      children: [
        for (var i = 0; i < _topRuns.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SortieBoardRow(
              rank: i + 1,
              row: _topRuns[i],
              isMe: _topRuns[i].userId == myId,
            ),
          ),
      ],
    );
  }

  Widget _buildBottomBar() => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: FlitColors.backgroundMid,
          border: Border(top: BorderSide(color: FlitColors.cardBorder)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _takeoff,
            style: ElevatedButton.styleFrom(
              backgroundColor: FlitColors.accent,
              foregroundColor: FlitColors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 4,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flight_takeoff, size: 22),
                SizedBox(width: 10),
                Text(
                  'FLY RATED SORTIE',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// =============================================================================
// Leaderboard row
// =============================================================================

class _SortieBoardRow extends StatelessWidget {
  const _SortieBoardRow({
    required this.rank,
    required this.row,
    required this.isMe,
  });

  final int rank;
  final SortieLeaderboardRow row;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe
            ? FlitColors.accent.withValues(alpha: 0.12)
            : FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMe
              ? FlitColors.accent.withValues(alpha: 0.5)
              : FlitColors.cardBorder,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: rank <= 3 ? FlitColors.gold : FlitColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.playerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FlitColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (row.rating != null) ...[
                  const SizedBox(height: 3),
                  RatingTierChip(
                    rating: row.rating!,
                    showRating: false,
                    compact: true,
                  ),
                ],
              ],
            ),
          ),
          Text(
            '${row.score}',
            style: const TextStyle(
              color: FlitColors.gold,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Post-run outcome sheet (ghost duel result)
// =============================================================================

class _SortieOutcomeSheet extends StatelessWidget {
  const _SortieOutcomeSheet({required this.outcome, required this.score});

  final SortieOutcome outcome;
  final int score;

  @override
  Widget build(BuildContext context) {
    final delta = outcome.ratingDelta;
    final deltaColor = delta > 0
        ? FlitColors.success
        : delta < 0
            ? FlitColors.error
            : FlitColors.textSecondary;
    final ghostLabel = outcome.ghostName ?? 'the House Ghost';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: FlitColors.textMuted.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          if (!outcome.applied) ...[
            const Icon(
              Icons.cloud_off,
              color: FlitColors.textMuted,
              size: 32,
            ),
            const SizedBox(height: 10),
            Text(
              'Run scored $score. Rating sync unavailable right now — '
              'your rating stays provisional.',
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Text(
              outcome.won
                  ? 'GHOST DUEL WON'
                  : outcome.lost
                      ? 'GHOST DUEL LOST'
                      : 'GHOST DUEL DRAWN',
              style: TextStyle(
                color: outcome.won
                    ? FlitColors.success
                    : outcome.lost
                        ? FlitColors.error
                        : FlitColors.textSecondary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'You $score — ${outcome.ghostScore ?? '?'} $ghostLabel',
              style: const TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  delta >= 0 ? '+$delta' : '$delta',
                  style: TextStyle(
                    color: deltaColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                if (outcome.newRating != null)
                  RatingTierChip(rating: outcome.newRating!),
              ],
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: FlitColors.accent,
                foregroundColor: FlitColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'ROGER',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
