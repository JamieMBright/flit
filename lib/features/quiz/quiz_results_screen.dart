import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/flit_colors.dart';
import '../../core/utils/report_capture.dart';
import '../../core/widgets/consumable_widgets.dart';
import '../../core/widgets/menu_content_wrapper.dart';
import '../../core/widgets/mission_report_card.dart';
import '../../core/widgets/share_variant_sheet.dart';
import '../../data/models/daily_result.dart';
import '../../data/providers/account_provider.dart';
import '../../data/services/leaderboard_service.dart';
import '../../data/services/score_submitter.dart';
import '../../game/economy/supply_drop.dart';
import '../../game/map/region.dart';
import '../../game/quiz/flight_school_level.dart';
import '../../game/quiz/quiz_category.dart';
import '../../game/quiz/quiz_difficulty.dart';
import '../../game/quiz/quiz_result_map.dart';
import '../../game/quiz/quiz_session.dart';
import '../../game/ui/ink_burst_overlay.dart';
import 'flight_school_screen.dart';

/// Results screen shown after completing a Flight School quiz.
///
/// Displays:
/// - Grade (S/A/B/C/D/F)
/// - Total score
/// - Accuracy percentage
/// - Time taken
/// - Best streak
/// - Correct/Wrong breakdown
class QuizResultsScreen extends ConsumerStatefulWidget {
  const QuizResultsScreen({
    super.key,
    required this.summary,
    this.challengeId,
    this.opponentName,
    this.flightSchoolLevelId,
    this.region,
    this.h2hRoundIndex,
    this.dailyBriefingDateKey,
  });

  final QuizSummary summary;

  /// Non-null when this was an H2H challenge.
  final String? challengeId;

  /// Opponent name for challenge display.
  final String? opponentName;

  /// Flight school level ID for progress tracking.
  final String? flightSchoolLevelId;

  /// Region played (for context).
  final GameRegion? region;

  /// When non-null, this was a round of a best-of-3 H2H challenge.
  final int? h2hRoundIndex;

  /// When non-null, this quiz was a Daily Flight Briefing. The value is the
  /// date key (YYYY-MM-DD) for score submission.
  final String? dailyBriefingDateKey;

  @override
  ConsumerState<QuizResultsScreen> createState() => _QuizResultsScreenState();
}

class _QuizResultsScreenState extends ConsumerState<QuizResultsScreen>
    with SingleTickerProviderStateMixin {
  bool _progressSaved = false;
  int _coinsEarned = 0;
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;
  final GlobalKey<InkBurstOverlayState> _inkBurstKey = GlobalKey();

  /// Wraps the report-card preview for PNG capture.
  final GlobalKey _reportKey = GlobalKey();
  bool _savingImage = false;

  /// Which share-image flavour the report card renders. The Daily Briefing
  /// defaults to anonymous (spoiler-free, no answer map, no revealed
  /// answers); other quiz results default to the full detailed card (their
  /// map was always shown).
  late ShareVariant _shareVariant =
      _isDailyBriefing ? ShareVariant.anonymous : ShareVariant.detailed;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _slideUp = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
    _saveFlightSchoolProgress();
    _saveDailyBriefingScore();
    _rollSupplyDrop();

    // Fire celebration burst for good results (grade A or S).
    final grade = widget.summary.grade;
    if (grade == 'S' || grade == 'A') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final size = MediaQuery.of(context).size;
        _inkBurstKey.currentState?.trigger(
          Offset(size.width / 2, size.height * 0.25),
        );
        if (grade == 'S') {
          Future<void>.delayed(const Duration(milliseconds: 400), () {
            if (!mounted) return;
            _inkBurstKey.currentState?.trigger(
              Offset(size.width * 0.25, size.height * 0.3),
            );
          });
          Future<void>.delayed(const Duration(milliseconds: 700), () {
            if (!mounted) return;
            _inkBurstKey.currentState?.trigger(
              Offset(size.width * 0.75, size.height * 0.3),
            );
          });
        }
      });
    }
  }

  /// Rare supply drop (any mode): quizzes count answer accuracy as the
  /// "strong performance" gate (>= 60% correct). Deterministic per
  /// (user, mode, date, score) — reopening this screen can't re-roll.
  void _rollSupplyDrop() {
    // H2H rounds resolve rewards through the challenge flow instead.
    if (widget.challengeId != null) return;
    final summary = widget.summary;
    final dropped = ref.read(accountProvider.notifier).rollSupplyDrop(
          mode: _isDailyBriefing
              ? 'briefing'
              : 'flight_school_${widget.flightSchoolLevelId ?? 'quiz'}',
          score: summary.totalScore,
          strongPerformance: SupplyDrop.isStrong(
            score: summary.correctCount,
            maxScore: summary.totalQuestions,
          ),
        );
    if (dropped != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showSupplyDropDialog(context, dropped);
      });
    }
  }

  void _saveFlightSchoolProgress() {
    final levelId = widget.flightSchoolLevelId;
    if (levelId == null || _progressSaved) return;
    _progressSaved = true;

    final summary = widget.summary;
    final isCompleted = summary.mode == QuizMode.allStates
        ? summary.correctCount == summary.totalQuestions
        : summary.correctCount > 0;

    final notifier = ref.read(accountProvider.notifier);

    notifier.updateFlightSchoolProgress(
      levelId: levelId,
      score: summary.totalScore,
      timeMs: summary.elapsedMs,
      completed: isCompleted,
    );

    // Award coins based on performance with diminishing returns
    final progress = ref.read(accountProvider).flightSchoolProgress[levelId] ??
        const FlightSchoolProgress();
    final baseCoinReward = summary.coinReward;
    final adjustedReward = progress.coinRewardForCompletion(baseCoinReward);
    if (adjustedReward > 0) {
      notifier.addCoins(adjustedReward, source: 'flight_school');
      _coinsEarned = adjustedReward;
    }
  }

  /// Submit the score to the daily briefing tables when this quiz is a
  /// Daily Flight Briefing.
  Future<void> _saveDailyBriefingScore() async {
    final dateKey = widget.dailyBriefingDateKey;
    if (dateKey == null) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final summary = widget.summary;

    try {
      final client = Supabase.instance.client;

      // 1. Dedicated daily_briefing_scores table (one per day, upsert).
      await client.from('daily_briefing_scores').upsert({
        'user_id': userId,
        'date_key': dateKey,
        'score': summary.totalScore,
        'time_ms': summary.elapsedMs,
        'level_id': widget.flightSchoolLevelId ?? '',
        // A curated daily set can mix categories (names + capitals +
        // flavour); record it as 'mixed' rather than a joined list.
        'category': summary.categories.length == 1
            ? summary.categories.first.name
            : 'mixed',
        'difficulty': summary.difficulty.name,
        'mode': summary.mode.name,
      }, onConflict: 'user_id,date_key');

      // 2. Shared scores table with region = 'briefing' for the leaderboard.
      //    Server-authoritative submit_score RPC (with direct-insert fallback).
      await ScoreSubmitter.submit(client, {
        'user_id': userId,
        'score': summary.totalScore,
        'time_ms': summary.elapsedMs,
        'region': 'briefing',
        'rounds_completed': summary.correctCount,
      });

      LeaderboardService.instance.invalidateCache();
    } catch (e) {
      debugPrint('[QuizResults] Failed to save daily briefing score: $e');
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;

    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      body: SafeArea(
        child: MenuContentWrapper(
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeIn.value,
                    child: Transform.translate(
                      offset: Offset(0, _slideUp.value),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 24,
                        ),
                        child: Column(
                          children: [
                            // Grade badge
                            _buildGradeBadge(summary.grade),
                            const SizedBox(height: 20),

                            // Title
                            Text(
                              _gradeTitle(summary.grade),
                              style: const TextStyle(
                                color: FlitColors.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${summary.mode.displayName} — ${summary.categories.length == 1 ? summary.categories.first.displayName : 'Multi'}',
                              style: const TextStyle(
                                color: FlitColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            if (widget.opponentName != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: FlitColors.accent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: FlitColors.accent.withOpacity(0.25),
                                  ),
                                ),
                                child: Text(
                                  'vs ${widget.opponentName}',
                                  style: const TextStyle(
                                    color: FlitColors.accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 28),

                            // Score card (big)
                            _buildScoreCard(summary),
                            const SizedBox(height: 12),

                            // Coin reward
                            if (_coinsEarned > 0) ...[
                              _buildCoinReward(),
                              const SizedBox(height: 12),
                            ],

                            // Stats grid
                            _buildStatsGrid(summary),
                            const SizedBox(height: 16),

                            // Region result map: the quiz's own map with
                            // areas tinted by outcome (green found / red
                            // missed). Suppressed for the daily briefing —
                            // spoilers.
                            ..._buildResultMap(summary),

                            // Detailed breakdown
                            _buildBreakdown(summary),
                            const SizedBox(height: 16),

                            // Downloadable mission report — captured
                            // exactly as shown.
                            _buildReportCard(summary),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),

                    // Bottom actions
                    _buildBottomBar(),
                  ],
                ),
              ),
              // Celebration overlay
              Positioned.fill(
                child: InkBurstOverlay(key: _inkBurstKey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Region result map ───────────────────────────────────────────────────

  /// Splits the quiz results into found vs missed answer codes.
  ///
  /// Quiz answer codes are region-scoped (US state / UK county / ISO codes
  /// depending on the region) so they must be drawn on the quiz's own
  /// region map — NEVER resolved against world country data, where 'TN'
  /// (Tennessee) would land on Tunisia.
  ({Set<String> correct, Set<String> missed}) _outcomeCodes(
    QuizSummary summary,
  ) {
    final correct = <String>{};
    final missed = <String>{};
    for (final r in summary.results) {
      (r.correct ? correct : missed).add(r.correctCode);
    }
    // A question answered wrong first but solved later counts as found.
    missed.removeAll(correct);
    return (correct: correct, missed: missed);
  }

  /// The quiz's own region map with areas tinted by outcome: green for
  /// answers found, red for missed ones, neutral elsewhere. Shown for
  /// Flight School practice / H2H only — the daily briefing suppresses it
  /// so results screens (and screenshots of them) never spoil the day's
  /// answers for other players.
  List<Widget> _buildResultMap(QuizSummary summary) {
    if (_isDailyBriefing) return const [];
    final region = widget.region;
    if (region == null) return const [];
    final outcomes = _outcomeCodes(summary);
    if (outcomes.correct.isEmpty && outcomes.missed.isEmpty) return const [];
    return [
      Container(
        decoration: BoxDecoration(
          color: FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlitColors.cardBorder),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: QuizResultMap(
                region: region,
                correctCodes: outcomes.correct,
                missedCodes: outcomes.missed,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(FlitColors.success, 'found'),
                if (outcomes.missed.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  _buildLegendItem(FlitColors.error, 'missed'),
                ],
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  Widget _buildLegendItem(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.square_rounded, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );

  // ── Mission report card + save image ────────────────────────────────────

  /// True for the Daily Flight Briefing — the one-attempt-per-day quiz.
  /// The report card omits the result map for these so a shared image
  /// never spoils the day's answers for other players.
  bool get _isDailyBriefing => widget.dailyBriefingDateKey != null;

  /// Display name of the region played (e.g. "Europe", "US States").
  String get _regionName {
    final levelId = widget.flightSchoolLevelId;
    if (levelId != null) {
      for (final level in flightSchoolLevels) {
        if (level.id == levelId) return level.name;
      }
    }
    return widget.region?.displayName ?? 'World';
  }

  /// Classic spoiler-free emoji share text for the Daily Briefing —
  /// one coloured circle per question (green clean, yellow/orange hints,
  /// red missed), same pattern as the Scramble and Triangulation dailies.
  ///
  /// ```
  ///      🛫 🗺️ 🛬
  /// Flit Daily Briefing — Europe
  /// 🟢🟢🟡🟢🔴🟢
  /// Score: 8,420 pts
  /// Time: 1m42s
  /// jamiembright.github.io/flit
  /// ```
  String get _briefingShareText {
    final summary = widget.summary;
    return '     \u{1F6EB} \u{1F5FA}\u{FE0F} \u{1F6EC}\n'
        'Flit Daily Briefing — $_regionName\n'
        '${summary.emojiRow}\n'
        'Score: ${DailyResult.formatScore(summary.totalScore)} pts\n'
        'Time: ${DailyResult.formatTime(summary.elapsedMs)}\n'
        'jamiembright.github.io/flit';
  }

  String get _fallbackShareText {
    if (_isDailyBriefing) return _briefingShareText;
    final summary = widget.summary;
    return 'Flit ${summary.mode.displayName} — Grade ${summary.grade}\n'
        '${summary.correctCount}/${summary.totalQuestions} correct · '
        '${summary.totalScore} pts · ${summary.elapsedFormatted}\n'
        'jamiembright.github.io/flit';
  }

  void _copyShareText() {
    Clipboard.setData(ClipboardData(text: _briefingShareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Result copied — paste to share!')),
    );
  }

  Future<void> _saveImage() async {
    if (_savingImage) return;
    final variant = await showShareVariantSheet(
      context,
      detailedSpoilerNote: 'reveals the region map and the answers',
    );
    if (variant == null || !mounted) return;
    setState(() {
      _shareVariant = variant;
      _savingImage = true;
    });
    try {
      // Let the card rebuild in the chosen variant before capturing it.
      await WidgetsBinding.instance.endOfFrame;
      final png = await captureReportPng(_reportKey);
      if (png == null || !mounted) return;
      final suffix = variant == ShareVariant.detailed ? 'detail' : 'anon';
      await shareReportImage(
        context,
        png: png,
        filename: _isDailyBriefing
            ? 'flit-briefing-$suffix.png'
            : 'flit-quiz-${widget.summary.mode.name}-$suffix.png',
        fallbackText: _fallbackShareText,
      );
    } finally {
      if (mounted) setState(() => _savingImage = false);
    }
  }

  /// Area code → display name lookup for the quiz's own region (US state
  /// code, UK county code, ISO country code, …), used to name answers on
  /// the detailed report card. Region-scoped — never resolved against
  /// world country data (see [_outcomeCodes]).
  Map<String, String> get _regionAreaNames {
    final region = widget.region;
    if (region == null) return const {};
    return {
      for (final area in RegionalData.getAreas(region)) area.code: area.name,
    };
  }

  /// The target answer code for a given question index, taken from any
  /// attempt recorded against it (the target is the same across retries).
  String? _questionCorrectCode(QuizSummary summary, int questionIndex) {
    for (final r in summary.results) {
      if (r.questionIndex == questionIndex) return r.correctCode;
    }
    return null;
  }

  /// Per-question reveal rows for the Daily Briefing's detailed share
  /// variant: outcome emoji + the answer's country/area name + a
  /// correct/missed mark. Never built for the anonymous variant — that
  /// card must stay spoiler-free (emoji grid only).
  List<ReportRow> _briefingRows(QuizSummary summary) {
    final areaNames = _regionAreaNames;
    final rows = <ReportRow>[];
    for (var i = 0; i < summary.totalQuestions; i++) {
      final code = _questionCorrectCode(summary, i);
      if (code == null) continue;
      final foundCorrect =
          summary.results.any((r) => r.questionIndex == i && r.correct);
      rows.add(ReportRow(
        summary.questionEmoji(i),
        areaNames[code] ?? code,
        foundCorrect ? '\u{2713}' : '\u{2717}',
      ));
    }
    return rows;
  }

  Widget _buildReportCard(QuizSummary summary) {
    final outcomes = _outcomeCodes(summary);
    final region = widget.region;
    final detailed = _shareVariant == ShareVariant.detailed;
    return RepaintBoundary(
      key: _reportKey,
      child: MissionReportCard(
        modeTitle: _isDailyBriefing
            ? 'DAILY BRIEFING'
            : summary.mode.displayName.toUpperCase(),
        subtitle: _isDailyBriefing
            ? '$_regionName · ${summary.correctCount}/${summary.totalQuestions} correct'
                '${detailed ? ' · ${summary.difficulty.displayName}' : ''}'
            : '${summary.correctCount}/${summary.totalQuestions} correct',
        score: summary.totalScore,
        // Spoiler-free per-question outcome row — the same emoji as the
        // text share. Only for the short curated daily set; a full-region
        // practice sweep would overflow the card.
        emojiGrid: _isDailyBriefing ? summary.emojiRow : null,
        // Named per-question breakdown — only for the Daily Briefing's
        // detailed variant. The anonymous variant (and every non-daily
        // result) leaves this empty so no answers leak.
        rows: _isDailyBriefing && detailed ? _briefingRows(summary) : const [],
        stats: [
          ReportStat(
            'CORRECT',
            '${summary.correctCount}/${summary.totalQuestions}',
          ),
          ReportStat('TIME', summary.elapsedFormatted),
          if (_coinsEarned > 0) ReportStat('COINS', '+$_coinsEarned'),
        ],
        // Spoiler rule: the Daily Briefing defaults to the anonymous variant
        // (one-attempt-per-day, so a shared image must not spoil the map or
        // answers by default) but reveals the map when the player explicitly
        // picks Detailed in the share-variant chooser. Other quiz variants
        // (Flight School practice, H2H) default to Detailed, preserving
        // their previous always-shown map. Either way this shows the quiz's
        // own REGION map tinted by outcome — never the world map, where
        // region-scoped codes collide with ISO country codes.
        map: detailed &&
                region != null &&
                (outcomes.correct.isNotEmpty || outcomes.missed.isNotEmpty)
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: QuizResultMap(
                  region: region,
                  correctCodes: outcomes.correct,
                  missedCodes: outcomes.missed,
                  height: 140,
                ),
              )
            : null,
      ),
    );
  }

  // ── Grade badge ─────────────────────────────────────────────────────────

  Widget _buildGradeBadge(String grade) {
    final color = _gradeColor(grade);
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.15),
        border: Border.all(color: color, width: 3),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        grade,
        style: TextStyle(
          color: color,
          fontSize: 42,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Color _gradeColor(String grade) {
    switch (grade) {
      case 'S':
        return FlitColors.gold;
      case 'A':
        return FlitColors.success;
      case 'B':
        return const Color(0xFF6AB4E8);
      case 'C':
        return FlitColors.textSecondary;
      case 'D':
        return FlitColors.warning;
      default:
        return FlitColors.error;
    }
  }

  String _gradeTitle(String grade) {
    switch (grade) {
      case 'S':
        return 'PERFECT FLIGHT';
      case 'A':
        return 'EXCELLENT';
      case 'B':
        return 'WELL DONE';
      case 'C':
        return 'GOOD EFFORT';
      case 'D':
        return 'KEEP PRACTICING';
      default:
        return 'TRY AGAIN';
    }
  }

  // ── Score card ──────────────────────────────────────────────────────────

  Widget _buildScoreCard(QuizSummary summary) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FlitColors.gold.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: FlitColors.gold.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            const Text(
              'TOTAL SCORE',
              style: TextStyle(
                color: FlitColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: FlitColors.gold, size: 30),
                const SizedBox(width: 8),
                Text(
                  '${summary.totalScore}',
                  style: const TextStyle(
                    color: FlitColors.gold,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  // ── Coin reward ────────────────────────────────────────────────────────

  Widget _buildCoinReward() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: FlitColors.gold.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlitColors.gold.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.monetization_on, color: FlitColors.gold, size: 24),
            const SizedBox(width: 8),
            Text(
              '+$_coinsEarned coins earned',
              style: const TextStyle(
                color: FlitColors.gold,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );

  // ── Stats grid ──────────────────────────────────────────────────────────

  Widget _buildStatsGrid(QuizSummary summary) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.check_circle,
            iconColor: FlitColors.success,
            label: 'CORRECT',
            value: '${summary.correctCount}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            icon: Icons.close,
            iconColor: FlitColors.error,
            label: 'WRONG',
            value: '${summary.wrongCount}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            icon: Icons.percent,
            iconColor: FlitColors.accent,
            label: 'ACCURACY',
            value: '${(summary.accuracy * 100).round()}%',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: FlitColors.cardBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: FlitColors.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      );

  // ── Breakdown ──────────────────────────────────────────────────────────

  Widget _buildBreakdown(QuizSummary summary) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlitColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DETAILS',
              style: TextStyle(
                color: FlitColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.timer, 'Time', summary.elapsedFormatted),
            _buildDetailRow(
              Icons.local_fire_department,
              'Best Streak',
              '${summary.bestStreak}x',
            ),
            _buildDetailRow(
              Icons.quiz,
              'Questions',
              '${summary.correctCount} / ${summary.totalQuestions}',
            ),
            _buildDetailRow(
              Icons.speed,
              'Avg Speed',
              summary.correctCount > 0
                  ? '${(summary.elapsedMs / 1000 / summary.correctCount).toStringAsFixed(1)}s per answer'
                  : '--',
            ),
          ],
        ),
      );

  Widget _buildDetailRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, color: FlitColors.textMuted, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                  color: FlitColors.textSecondary, fontSize: 14),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );

  // ── Bottom bar ──────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    // Daily briefings are one-attempt-per-day — show a single DONE button
    // instead of PLAY AGAIN / CHANGE MODE.
    if (_isDailyBriefing) {
      return _buildDailyBriefingBottomBar();
    }
    return _buildDefaultBottomBar();
  }

  Widget _buildDailyBriefingBottomBar() => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: FlitColors.backgroundMid,
          border: Border(top: BorderSide(color: FlitColors.cardBorder)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // SHARE (emoji text) + SAVE IMAGE side by side — same summary
            // layout as the Triangulation daily.
            Row(
              children: [
                Expanded(child: _buildShareButton()),
                const SizedBox(width: 10),
                Expanded(child: _buildSaveImageButton()),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlitColors.success,
                  foregroundColor: FlitColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.check_circle, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'DONE',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  /// SHARE button — copies the spoiler-free emoji share text to the
  /// clipboard, matching the Triangulation daily's gold share action.
  Widget _buildShareButton() => SizedBox(
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _copyShareText,
          icon: const Icon(Icons.share, size: 18),
          label: const Text(
            'SHARE',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: FlitColors.gold,
            foregroundColor: FlitColors.backgroundDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );

  /// SAVE IMAGE button — mirrors the reference implementation's accent
  /// button with a busy spinner while the report card is being captured.
  Widget _buildSaveImageButton() => SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _savingImage ? null : _saveImage,
          icon: _savingImage
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: FlitColors.textPrimary,
                  ),
                )
              : const Icon(Icons.image_outlined, size: 18),
          label: const Text(
            'SAVE IMAGE',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: FlitColors.accent,
            foregroundColor: FlitColors.textPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );

  Widget _buildDefaultBottomBar() => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: FlitColors.backgroundMid,
          border: Border(top: BorderSide(color: FlitColors.cardBorder)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSaveImageButton(),
            const SizedBox(height: 10),
            Row(
              children: [
                // Back to setup
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => const FlightSchoolScreen(),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FlitColors.textSecondary,
                        side: const BorderSide(color: FlitColors.cardBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'CHANGE MODE',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, letterSpacing: 1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Play again
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlitColors.accent,
                        foregroundColor: FlitColors.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.replay, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'PLAY AGAIN',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}
