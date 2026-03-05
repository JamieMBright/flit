import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/flit_colors.dart';
import '../../game/quiz/daily_briefing.dart';
import '../../game/quiz/quiz_category.dart';
import '../../game/quiz/quiz_difficulty.dart';
import '../../game/quiz/quiz_session.dart';
import 'quiz_game_screen.dart';

/// Daily Flight Briefing screen.
///
/// Shows today's deterministically generated quiz settings (level, category,
/// difficulty, mode) and lets the player start the briefing. Players who have
/// already completed today's briefing see a "CLEARED" badge and their score.
///
/// After completing the quiz, the score is submitted to the
/// `daily_briefing_scores` table.
class DailyBriefingScreen extends StatefulWidget {
  const DailyBriefingScreen({super.key});

  @override
  State<DailyBriefingScreen> createState() => _DailyBriefingScreenState();
}

class _DailyBriefingScreenState extends State<DailyBriefingScreen>
    with SingleTickerProviderStateMixin {
  late final DailyBriefing _briefing;
  late final AnimationController _pulseController;

  bool _loading = true;
  bool _completedToday = false;
  int? _previousScore;
  int? _previousTimeMs;

  @override
  void initState() {
    super.initState();
    _briefing = DailyBriefing.today();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _checkCompletion();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkCompletion() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final row = await Supabase.instance.client
          .from('daily_briefing_scores')
          .select('score, time_ms')
          .eq('user_id', userId)
          .eq('date_key', _briefing.dateKey)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _completedToday = row != null;
          _previousScore = row?['score'] as int?;
          _previousTimeMs = row?['time_ms'] as int?;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startBriefing() {
    if (_completedToday) return;

    Navigator.of(context)
        .push(
      MaterialPageRoute<QuizSummary>(
        builder: (_) => QuizGameScreen(
          mode: _briefing.mode,
          category: _briefing.category,
          region: _briefing.level.region,
          difficulty: _briefing.difficulty,
          seed: _briefing.seed,
          flightSchoolLevelId: _briefing.level.id,
          dailyBriefingDateKey: _briefing.dateKey,
        ),
      ),
    )
        .then((summary) {
      // The QuizGameScreen pushes QuizResultsScreen, but for the daily
      // briefing we intercept the pop result to submit the score.
      // QuizGameScreen pops without a result (navigates to results itself),
      // so we check completion when returning.
      _checkCompletion();
    });
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
        title: const Text('Daily Flight Briefing'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildMissionHeader(),
                  const SizedBox(height: 24),
                  _buildBriefingCard(),
                  const SizedBox(height: 24),
                  _buildActionArea(),
                  const SizedBox(height: 32),
                  _buildInfoFooter(),
                ],
              ),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mission header
  // ---------------------------------------------------------------------------

  Widget _buildMissionHeader() {
    return Column(
      children: [
        // Date badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: FlitColors.accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: FlitColors.accent.withOpacity(0.4)),
          ),
          child: Text(
            _briefing.dateKey,
            style: const TextStyle(
              color: FlitColors.accent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Title
        const Text(
          'DAILY FLIGHT BRIEFING',
          style: TextStyle(
            color: FlitColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _briefing.missionSubtitle,
          style: const TextStyle(
            color: FlitColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Briefing card (shows today's parameters)
  // ---------------------------------------------------------------------------

  Widget _buildBriefingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FlitColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: FlitColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'MISSION PARAMETERS',
                style: TextStyle(
                  color: FlitColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Parameters grid
          _buildParameter(
            'SORTIE',
            _briefing.level.name,
            _briefing.level.subtitle,
            Icons.public,
          ),
          const SizedBox(height: 14),
          _buildParameter(
            'INTEL TYPE',
            _briefing.category.displayName,
            _briefing.category.description,
            _categoryIcon(_briefing.category),
          ),
          const SizedBox(height: 14),
          _buildParameter(
            'ALTITUDE',
            _briefing.difficulty.displayName,
            _briefing.difficulty.description,
            _difficultyIcon(_briefing.difficulty),
          ),
          const SizedBox(height: 14),
          _buildParameter(
            'MISSION TYPE',
            _briefing.mode.displayName,
            _briefing.estimatedDuration,
            _modeIcon(_briefing.mode),
          ),
        ],
      ),
    );
  }

  Widget _buildParameter(
    String label,
    String value,
    String subtitle,
    IconData icon,
  ) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: FlitColors.backgroundDark,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: FlitColors.gold, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: FlitColors.textMuted.withOpacity(0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: FlitColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Action area (button or completed badge)
  // ---------------------------------------------------------------------------

  Widget _buildActionArea() {
    if (_completedToday) {
      return _buildCompletedBadge();
    }
    return _buildStartButton();
  }

  Widget _buildCompletedBadge() {
    final timeStr = _formatTime(_previousTimeMs ?? 0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FlitColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FlitColors.success.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: FlitColors.success, size: 28),
              const SizedBox(width: 10),
              const Text(
                'CLEARED',
                style: TextStyle(
                  color: FlitColors.success,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatChip('SCORE', '${_previousScore ?? 0}'),
              const SizedBox(width: 20),
              _buildStatChip('TIME', timeStr),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Return tomorrow for a new briefing',
            style: TextStyle(color: FlitColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: FlitColors.textMuted.withOpacity(0.8),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: FlitColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildStartButton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + _pulseController.value * 0.02;
        return Transform.scale(scale: scale, child: child);
      },
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _startBriefing,
          style: ElevatedButton.styleFrom(
            backgroundColor: FlitColors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 6,
            shadowColor: FlitColors.accent.withOpacity(0.5),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.flight_takeoff, size: 22),
              SizedBox(width: 10),
              Text(
                'BEGIN BRIEFING',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Info footer
  // ---------------------------------------------------------------------------

  Widget _buildInfoFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlitColors.backgroundMid,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlitColors.cardBorder.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: FlitColors.textMuted, size: 16),
              const SizedBox(width: 8),
              const Text(
                'OPERATIONAL BRIEF',
                style: TextStyle(
                  color: FlitColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildInfoLine('Every pilot receives the same mission parameters.'),
          _buildInfoLine('One sortie per day. Make it count.'),
          _buildInfoLine('No level unlock required for daily briefings.'),
          _buildInfoLine(
            'Scores are posted to the Flight Briefing leaderboard.',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '  -  ',
            style: TextStyle(color: FlitColors.textMuted, fontSize: 12),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _formatTime(int ms) {
    if (ms <= 0) return '--';
    final seconds = (ms / 1000).floor();
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  IconData _categoryIcon(QuizCategory category) {
    switch (category) {
      case QuizCategory.stateName:
        return Icons.map;
      case QuizCategory.capital:
        return Icons.location_city;
      case QuizCategory.nickname:
        return Icons.label;
      case QuizCategory.sportsTeam:
        return Icons.sports_football;
      case QuizCategory.landmark:
        return Icons.landscape;
      case QuizCategory.flagDescription:
        return Icons.flag;
      case QuizCategory.stateBird:
        return Icons.flutter_dash;
      case QuizCategory.stateFlower:
        return Icons.local_florist;
      case QuizCategory.motto:
        return Icons.format_quote;
      case QuizCategory.celebrity:
        return Icons.star;
      case QuizCategory.filmSetting:
        return Icons.movie;
      case QuizCategory.mixed:
        return Icons.shuffle;
    }
  }

  IconData _difficultyIcon(QuizDifficulty difficulty) {
    switch (difficulty) {
      case QuizDifficulty.easy:
        return Icons.cloud;
      case QuizDifficulty.medium:
        return Icons.cloud_queue;
      case QuizDifficulty.hard:
        return Icons.thunderstorm;
    }
  }

  IconData _modeIcon(QuizMode mode) {
    switch (mode) {
      case QuizMode.allStates:
        return Icons.checklist;
      case QuizMode.timeTrial:
        return Icons.timer;
      case QuizMode.rapidFire:
        return Icons.bolt;
      case QuizMode.typeIn:
        return Icons.keyboard;
    }
  }
}
