import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/services/challenge_service.dart';
import '../../game/quiz/quiz_category.dart';
import '../../game/quiz/quiz_difficulty.dart';
import '../../game/quiz/quiz_map_widget.dart';
import '../../game/quiz/quiz_region_map_widget.dart';
import '../../game/quiz/quiz_session.dart';
import '../../game/map/region.dart';
import 'quiz_results_screen.dart';

/// Main quiz game screen for Flight School.
///
/// Shows an interactive map (zoomable) with a clue card at the top.
/// Player taps states/countries to answer. Provides real-time feedback.
/// Progressive hint system: extra clues, elimination, then country removal.
///
/// When [challengeId] is non-null, results are submitted to the challenge
/// system so both players can compare scores.
class QuizGameScreen extends StatefulWidget {
  const QuizGameScreen({
    super.key,
    required this.mode,
    required this.category,
    this.region = GameRegion.usStates,
    this.challengeId,
    this.challengeOpponentName,
    this.seed,
    this.flightSchoolLevelId,
    this.difficulty = QuizDifficulty.medium,
    this.h2hRoundIndex,
    this.dailyBriefingDateKey,
  });

  final QuizMode mode;
  final QuizCategory category;
  final GameRegion region;
  final QuizDifficulty difficulty;

  /// When non-null, this quiz is part of an H2H challenge.
  final String? challengeId;

  /// Opponent name for display in challenge mode.
  final String? challengeOpponentName;

  /// Deterministic seed for challenge mode (both players get same questions).
  final int? seed;

  /// Flight school level ID for progress tracking.
  final String? flightSchoolLevelId;

  /// When non-null, this quiz is a round of a best-of-3 H2H challenge.
  /// The value is the 0-based round index.
  final int? h2hRoundIndex;

  /// When non-null, this quiz is a Daily Flight Briefing. The value is the
  /// date key (YYYY-MM-DD) used for score submission.
  final String? dailyBriefingDateKey;

  @override
  State<QuizGameScreen> createState() => _QuizGameScreenState();
}

class _QuizGameScreenState extends State<QuizGameScreen>
    with TickerProviderStateMixin {
  late QuizSession _session;
  late Map<String, StateVisual> _stateVisuals;
  Timer? _timer;

  // Animation state
  String? _lastWrongCode;
  String? _highlightCode;
  int? _lastPoints;
  bool _showPointsPopup = false;
  late AnimationController _pointsAnimController;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();

    _pointsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _initSession();
  }

  void _initSession() {
    _session = QuizSession(
      mode: widget.mode,
      category: widget.category,
      region: widget.region,
      difficulty: widget.difficulty,
      seed: widget.seed,
    );

    // Build initial visual state for all states
    final areas = RegionalData.getAreas(widget.region);
    _stateVisuals = {
      for (final area in areas) area.code: StateVisual(area: area),
    };

    _session.start();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _session.tick();
      if (_session.isFinished) {
        _timer?.cancel();
        _navigateToResults();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pointsAnimController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _handleStateTapped(String code) {
    if (_session.isFinished) return;

    final result = _session.submitAnswer(code);
    if (result == null) return;

    setState(() {
      if (result.correct) {
        _stateVisuals[code]?.status = StateVisualStatus.correct;
        _lastPoints = result.points;
        _showPointsPopup = true;
        _highlightCode = null;
        _lastWrongCode = null;

        _pointsAnimController.forward(from: 0).then((_) {
          if (mounted) {
            setState(() => _showPointsPopup = false);
          }
        });

        // After a brief flash, mark as completed (muted green via correctCodes)
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            setState(() {
              _stateVisuals[code]?.status = StateVisualStatus.completed;
            });
          }
        });
      } else {
        _stateVisuals[code]?.status = StateVisualStatus.wrong;
        _lastWrongCode = code;
        _lastPoints = result.points;
        _showPointsPopup = true;

        _shakeController.forward(from: 0);
        _pointsAnimController.forward(from: 0).then((_) {
          if (mounted) {
            setState(() => _showPointsPopup = false);
          }
        });

        // Revert wrong flash after a brief moment
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              // Only revert if still in wrong state (hasn't been answered since)
              if (_stateVisuals[code]?.status == StateVisualStatus.wrong) {
                _stateVisuals[code]?.status = StateVisualStatus.idle;
              }
            });
          }
        });
      }
    });

    if (_session.isFinished) {
      _timer?.cancel();
      Future.delayed(const Duration(milliseconds: 600), _navigateToResults);
    }
  }

  void _useHint() {
    final level = _session.useHint();
    if (level == null) return;

    final question = _session.currentQuestion;
    if (question == null) return;

    setState(() {
      if (level >= 5) {
        // Level 5+: Highlight the exact correct answer
        _highlightCode = question.answerCode;
      }
      // Levels 1-2: Extra clue texts (handled by session, shown in clue card)
      // Levels 3-4: Elimination (handled by session via eliminatedCodes)
      // Level 6+: Country removal (handled by session via eliminatedCodes)
    });
  }

  Future<void> _navigateToResults() async {
    if (!mounted) return;

    // Submit results to challenge system if this is an H2H quiz.
    if (widget.challengeId != null) {
      final summary = _session.summary;

      if (widget.h2hRoundIndex != null) {
        // Best-of-3 H2H challenge round.
        await ChallengeService.instance.submitH2HRoundScore(
          challengeId: widget.challengeId!,
          roundIndex: widget.h2hRoundIndex!,
          score: summary.totalScore,
          timeMs: summary.elapsedMs,
          correctCount: summary.correctCount,
          wrongCount: summary.wrongCount,
        );
        await ChallengeService.instance.tryCompleteH2HChallenge(
          widget.challengeId!,
        );
      } else {
        // Legacy single-round quiz challenge.
        await ChallengeService.instance.submitQuizRoundResult(
          challengeId: widget.challengeId!,
          score: summary.totalScore,
          timeMs: summary.elapsedMs,
          correctCount: summary.correctCount,
          wrongCount: summary.wrongCount,
        );
        await ChallengeService.instance.tryCompleteChallenge(
          widget.challengeId!,
        );
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => QuizResultsScreen(
          summary: _session.summary,
          challengeId: widget.challengeId,
          opponentName: widget.challengeOpponentName,
          flightSchoolLevelId: widget.flightSchoolLevelId,
          region: widget.region,
          h2hRoundIndex: widget.h2hRoundIndex,
          dailyBriefingDateKey: widget.dailyBriefingDateKey,
        ),
      ),
    );
  }

  void _confirmQuit() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FlitColors.cardBackground,
        title: const Text(
          'Quit Quiz?',
          style: TextStyle(color: FlitColors.textPrimary),
        ),
        content: const Text(
          'Your progress will be lost.',
          style: TextStyle(color: FlitColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: FlitColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(true);
              _session.finish();
              _navigateToResults();
            },
            child: const Text(
              'QUIT',
              style: TextStyle(color: FlitColors.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = _session.currentQuestion;
    final remaining = _session.remainingMs;

    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: back button, mode label, timer
            _buildTopBar(remaining),

            // Clue card (with extra hint clues)
            _buildClueCard(question),

            // Score and streak bar
            _buildScoreBar(),

            // Map (takes remaining space)
            Expanded(
              child: Stack(
                children: [
                  // Interactive map (US-specific or generic region map)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: widget.region == GameRegion.usStates
                        ? QuizMapWidget(
                            stateVisuals: _stateVisuals,
                            onStateTapped: _handleStateTapped,
                            highlightCode: _highlightCode,
                            showLabels: _session.showLabels,
                            eliminatedCodes: _session.eliminatedCodes,
                            correctCodes: _session.correctCodes,
                          )
                        : QuizRegionMapWidget(
                            region: widget.region,
                            stateVisuals: _stateVisuals,
                            onStateTapped: _handleStateTapped,
                            highlightCode: _highlightCode,
                            showLabels: _session.showLabels,
                            eliminatedCodes: _session.eliminatedCodes,
                            correctCodes: _session.correctCodes,
                          ),
                  ),

                  // Points popup animation
                  if (_showPointsPopup && _lastPoints != null)
                    _buildPointsPopup(),

                  // Wrong answer indicator (strikes for rapid fire)
                  if (widget.mode == QuizMode.rapidFire)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: _buildStrikesIndicator(),
                    ),
                ],
              ),
            ),

            // Progress bar (for allStates mode)
            if (widget.mode == QuizMode.allStates) _buildProgressBar(),
          ],
        ),
      ),
    );
  }

  // ── Top bar ─────────────────────────────────────────────────────────────

  Widget _buildTopBar(int? remainingMs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: FlitColors.backgroundMid,
        border: Border(
          bottom: BorderSide(color: FlitColors.cardBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: _confirmQuit,
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: FlitColors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Mode label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: FlitColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.mode.displayName.toUpperCase(),
              style: const TextStyle(
                color: FlitColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Category label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: FlitColors.gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.category.displayName.toUpperCase(),
              style: const TextStyle(
                color: FlitColors.gold,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),

          const Spacer(),

          // Timer
          _buildTimer(remainingMs),
        ],
      ),
    );
  }

  Widget _buildTimer(int? remainingMs) {
    final isCountdown = remainingMs != null;
    final displayTime =
        isCountdown ? _formatMs(remainingMs) : _session.elapsedFormatted;
    final isUrgent = isCountdown && remainingMs < 10000;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isUrgent
            ? FlitColors.error.withOpacity(0.2)
            : FlitColors.backgroundDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUrgent ? FlitColors.error : FlitColors.cardBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCountdown ? Icons.timer : Icons.access_time,
            color: isUrgent ? FlitColors.error : FlitColors.textSecondary,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            displayTime,
            style: TextStyle(
              color: isUrgent ? FlitColors.error : FlitColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  String _formatMs(int ms) {
    final seconds = (ms / 1000).ceil();
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  // ── Clue card ──────────────────────────────────────────────────────────

  Widget _buildClueCard(QuizQuestion? question) {
    final extraClues = _session.extraClueTexts;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(
          '${question?.clueText ?? 'empty'}_${extraClues.length}',
        ),
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlitColors.accent.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: FlitColors.accent.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: question != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Question number
                  Text(
                    '${_session.currentIndex + 1} / ${_session.totalQuestions}',
                    style: const TextStyle(
                      color: FlitColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Clue text
                  Text(
                    question.clueText,
                    style: const TextStyle(
                      color: FlitColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  // Extra clue texts from hints
                  if (extraClues.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    const Divider(
                      color: FlitColors.cardBorder,
                      height: 1,
                    ),
                    const SizedBox(height: 6),
                    for (final clue in extraClues)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          clue,
                          style: const TextStyle(
                            color: FlitColors.warning,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ],
              )
            : const Text(
                'Quiz Complete!',
                style: TextStyle(
                  color: FlitColors.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }

  // ── Score bar ──────────────────────────────────────────────────────────

  Widget _buildScoreBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Score
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: FlitColors.gold, size: 18),
              const SizedBox(width: 4),
              Text(
                '${_session.totalScore}',
                style: const TextStyle(
                  color: FlitColors.gold,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),

          // Streak
          if (_session.streak > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: FlitColors.accent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department,
                    color: FlitColors.accent,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_session.streak}x streak',
                    style: const TextStyle(
                      color: FlitColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

          // Hint button (always available now)
          if (_session.canUseHint)
            GestureDetector(
              onTap: _useHint,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: FlitColors.warning.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: FlitColors.warning.withOpacity(0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      color: FlitColors.warning,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _session.currentHintLevel == 0
                          ? 'Hint'
                          : 'Hint (${_session.currentHintLevel})',
                      style: const TextStyle(
                        color: FlitColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Correct / Wrong counts
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_session.correctCount}',
                style: const TextStyle(
                  color: FlitColors.success,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                ' / ',
                style: TextStyle(color: FlitColors.textMuted, fontSize: 14),
              ),
              Text(
                '${_session.wrongCount}',
                style: const TextStyle(
                  color: FlitColors.error,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Points popup ───────────────────────────────────────────────────────

  Widget _buildPointsPopup() {
    final isPositive = _lastPoints != null && _lastPoints! > 0;
    return AnimatedBuilder(
      animation: _pointsAnimController,
      builder: (context, child) {
        final offset = _pointsAnimController.value * 40;
        final opacity = 1.0 - _pointsAnimController.value;
        return Positioned(
          top: 20 - offset,
          left: 0,
          right: 0,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Center(
              child: Text(
                isPositive ? '+$_lastPoints' : '$_lastPoints',
                style: TextStyle(
                  color: isPositive ? FlitColors.success : FlitColors.error,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  shadows: const [
                    Shadow(
                      color: Colors.black54,
                      offset: Offset(1, 1),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Strikes indicator (rapid fire) ─────────────────────────────────────

  Widget _buildStrikesIndicator() {
    final maxWrong = widget.mode.maxWrong ?? 3;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxWrong, (i) {
        final isUsed = i < _session.wrongCount;
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(
            isUsed ? Icons.close : Icons.circle_outlined,
            color: isUsed ? FlitColors.error : FlitColors.textMuted,
            size: 24,
          ),
        );
      }),
    );
  }

  // ── Progress bar (all states) ──────────────────────────────────────────

  Widget _buildProgressBar() {
    final progress = _session.totalQuestions > 0
        ? _session.correctCount / _session.totalQuestions
        : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: FlitColors.backgroundMid,
        border: Border(
          top: BorderSide(color: FlitColors.cardBorder, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_session.correctCount} of ${_session.totalQuestions} found',
                style: const TextStyle(
                  color: FlitColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: FlitColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: FlitColors.backgroundDark,
              valueColor: const AlwaysStoppedAnimation<Color>(FlitColors.gold),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}
