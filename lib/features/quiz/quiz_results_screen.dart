import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/providers/account_provider.dart';
import '../../data/services/leaderboard_service.dart';
import '../../game/map/region.dart';
import '../../game/quiz/flight_school_level.dart';
import '../../game/quiz/quiz_category.dart';
import '../../game/quiz/quiz_session.dart';
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
        'category': summary.category.name,
        'difficulty': summary.difficulty.name,
        'mode': summary.mode.name,
      }, onConflict: 'user_id,date_key');

      // 2. Shared scores table with region = 'briefing' for the leaderboard.
      await client.from('scores').insert({
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
        child: AnimatedBuilder(
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
                        '${summary.mode.displayName} — ${summary.category.displayName}',
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

                      // Detailed breakdown
                      _buildBreakdown(summary),
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

  Widget _buildBottomBar() => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: FlitColors.backgroundMid,
          border: Border(top: BorderSide(color: FlitColors.cardBorder)),
        ),
        child: Row(
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
      );
}
