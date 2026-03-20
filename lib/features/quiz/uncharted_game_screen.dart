import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/providers/account_provider.dart';
import '../../data/services/leaderboard_service.dart';
import '../../game/map/region.dart';
import '../../game/quiz/uncharted_map_widget.dart';
import '../../game/quiz/uncharted_session.dart';
import '../../game/ui/ink_burst_overlay.dart';

/// Main game screen for the Uncharted mode.
///
/// Shows a blank map with area outlines. The player types names into a
/// persistent text field at the bottom. Correct guesses reveal areas on the
/// map with a flash animation. A timer counts up and progress is displayed
/// in the top bar.
class UnchartedGameScreen extends StatefulWidget {
  const UnchartedGameScreen({
    super.key,
    required this.region,
    required this.mode,
    this.showLabels = false,
  });

  final GameRegion region;
  final UnchartedMode mode;

  /// When true, unrevealed country names are shown on the map and the
  /// final score is halved.
  final bool showLabels;

  @override
  State<UnchartedGameScreen> createState() => _UnchartedGameScreenState();
}

class _UnchartedGameScreenState extends State<UnchartedGameScreen>
    with TickerProviderStateMixin {
  late UnchartedSession _session;
  Timer? _timer;

  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String? _lastRevealedCode;
  String? _feedbackText;

  /// When true, all areas are revealed and the user can explore the map
  /// before going to results.
  bool _exploringMap = false;

  late AnimationController _feedbackController;
  late Animation<double> _feedbackOpacity;

  /// Ping animation: flashes unrevealed areas to hint at remaining countries.
  late AnimationController _pingController;

  /// Seconds of inactivity before auto-ping fires.
  static const int _autoPingDelaySec = 30;
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    _session = UnchartedSession(region: widget.region, mode: widget.mode);
    _session.start();

    // Tick timer every second for display.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_session.isComplete) setState(() {});
    });

    _feedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _feedbackOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _feedbackController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _pingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _resetInactivityTimer();

    // Auto-focus the text field.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _inactivityTimer?.cancel();
    _textController.dispose();
    _focusNode.dispose();
    _feedbackController.dispose();
    _pingController.dispose();
    super.dispose();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (_session.isComplete) return;
    _inactivityTimer = Timer(
      const Duration(seconds: _autoPingDelaySec),
      _triggerPing,
    );
  }

  void _triggerPing() {
    if (_session.isComplete || !mounted) return;
    _pingController.forward(from: 0);
  }

  void _handleInputChanged(String value) {
    if (value.trim().isEmpty) return;
    if (_session.hasExactMatch(value.trim())) {
      _handleSubmit(value);
    }
  }

  void _handleSubmit(String value) {
    if (value.trim().isEmpty) return;

    final result = _session.submitGuess(value.trim());
    _textController.clear();

    setState(() {
      if (result.matched) {
        _lastRevealedCode = result.code;
        _feedbackText = result.areaName;
        _feedbackController.forward(from: 0);
        _resetInactivityTimer();
      }
    });

    if (_session.isComplete) {
      _timer?.cancel();
      _inactivityTimer?.cancel();
      // Short delay to show the last reveal, then enter explore mode.
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          setState(() => _exploringMap = true);
        }
      });
    }

    // Keep focus on text field.
    _focusNode.requestFocus();
  }

  void _giveUp() {
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FlitColors.backgroundMid,
        title: const Text(
          'Give Up?',
          style: TextStyle(color: FlitColors.textPrimary),
        ),
        content: Text(
          'You\'ve found ${_session.correctGuesses} of ${_session.totalCount}. '
          'What would you like to do?',
          style: const TextStyle(color: FlitColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'keep'),
            child: const Text('Keep Going',
                style: TextStyle(color: FlitColors.accent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'reveal'),
            child: const Text('Reveal All',
                style: TextStyle(color: FlitColors.gold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'quit'),
            child: const Text('Give Up',
                style: TextStyle(color: FlitColors.error)),
          ),
        ],
      ),
    ).then((choice) {
      if (choice == 'quit') {
        _session.giveUp();
        _timer?.cancel();
        _showResults();
      } else if (choice == 'reveal') {
        _session.giveUp();
        _session.revealAll();
        _timer?.cancel();
        _inactivityTimer?.cancel();
        setState(() {
          _exploringMap = true;
        });
      }
    });
  }

  void _showResults() {
    // Halve score when labels are enabled.
    final score = widget.showLabels
        ? (_session.finalScore * 0.5).round()
        : _session.finalScore;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => UnchartedResultsScreen(
          region: widget.region,
          mode: widget.mode,
          revealedCount: _session.correctGuesses,
          totalCount: _session.totalCount,
          elapsedMs: _session.elapsedMs,
          score: score,
          givenUp: _session.givenUp,
          revealedCodes: _session.revealedCodes,
          guessedCodes: _session.guessedCodes,
          labelsUsed: widget.showLabels,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use resizeToAvoidBottomInset: false so the map doesn't shrink when
    // the keyboard appears. The HUD floats on top via a Stack.
    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: false,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Stack(
            children: [
              // Full-screen map — stays still regardless of keyboard state.
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _pingController,
                  builder: (context, _) => UnchartedMapWidget(
                    region: widget.region,
                    revealedCodes: _session.revealedCodes,
                    lastRevealedCode: _lastRevealedCode,
                    capitalsMode: widget.mode == UnchartedMode.capitals,
                    pingProgress: _pingController.value,
                    showUnrevealedLabels: widget.showLabels,
                  ),
                ),
              ),
              // Top bar HUD.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _exploringMap ? _buildExploreTopBar() : _buildTopBar(),
              ),
              // Feedback + input bar at the bottom (hidden in explore mode).
              if (!_exploringMap)
                Positioned(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFeedback(),
                      _buildInputBar(),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    // Ctrl key triggers a ping/flash of unrevealed areas on desktop.
    if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.controlLeft ||
        event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.controlRight) {
      _triggerPing();
    }
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: FlitColors.backgroundMid,
      child: Row(
        children: [
          // Back button.
          IconButton(
            icon: const Icon(Icons.arrow_back,
                color: FlitColors.textPrimary, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          // Timer.
          const Icon(Icons.timer_outlined,
              color: FlitColors.textSecondary, size: 16),
          const SizedBox(width: 3),
          Text(
            _session.elapsedFormatted,
            style: const TextStyle(
              color: FlitColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
          const Spacer(),
          // Progress.
          Text(
            '${_session.correctGuesses} / ${_session.totalCount}',
            style: const TextStyle(
              color: FlitColors.gold,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (widget.showLabels) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: FlitColors.gold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'x0.5',
                style: TextStyle(
                  color: FlitColors.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(width: 12),
          // Give up.
          TextButton(
            onPressed: _session.isComplete ? null : _giveUp,
            child: const Text(
              'Give Up',
              style: TextStyle(color: FlitColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExploreTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: FlitColors.backgroundMid,
      child: Row(
        children: [
          // Back button.
          IconButton(
            icon: const Icon(Icons.arrow_back,
                color: FlitColors.textPrimary, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.explore, color: FlitColors.gold, size: 16),
          const SizedBox(width: 6),
          const Text(
            'Explore Map',
            style: TextStyle(
              color: FlitColors.gold,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          // See Results button.
          TextButton(
            onPressed: _showResults,
            child: const Text(
              'See Results',
              style: TextStyle(color: FlitColors.accent, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedback() {
    return AnimatedBuilder(
      animation: _feedbackController,
      builder: (context, _) {
        if (_feedbackText == null || _feedbackOpacity.value <= 0) {
          return const SizedBox(height: 20);
        }
        return SizedBox(
          height: 20,
          child: Opacity(
            opacity: _feedbackOpacity.value,
            child: Center(
              child: Text(
                _feedbackText!,
                style: const TextStyle(
                  color: FlitColors.success,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      color: FlitColors.backgroundMid,
      child: Row(
        children: [
          // Ping hint button — flashes unrevealed areas on the map.
          IconButton(
            icon: const Icon(Icons.radar, color: FlitColors.gold, size: 20),
            tooltip: 'Ping unrevealed areas',
            onPressed: _session.isComplete ? null : _triggerPing,
            padding: const EdgeInsets.only(right: 6),
            constraints: const BoxConstraints(),
          ),
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                enabled: !_session.isComplete,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const <String>[],
                enableIMEPersonalizedLearning: false,
                spellCheckConfiguration:
                    const SpellCheckConfiguration.disabled(),
                keyboardType: TextInputType.visiblePassword,
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: widget.mode == UnchartedMode.countries
                      ? 'Type a country name...'
                      : 'Type a capital city...',
                  hintStyle: TextStyle(
                    color: FlitColors.textSecondary.withOpacity(0.5),
                    fontSize: 14,
                  ),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: FlitColors.accent),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: FlitColors.accent.withOpacity(0.4)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: FlitColors.accent, width: 2),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1A2A3A),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: _handleInputChanged,
                onSubmitted: _handleSubmit,
                textInputAction: TextInputAction.go,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Results screen for Uncharted mode.
///
/// Shows grade, score, stats, and a full breakdown of which areas were
/// found and which were missed. Triggers a fireworks celebration on good
/// results.
class UnchartedResultsScreen extends ConsumerStatefulWidget {
  const UnchartedResultsScreen({
    super.key,
    required this.region,
    required this.mode,
    required this.revealedCount,
    required this.totalCount,
    required this.elapsedMs,
    required this.score,
    required this.givenUp,
    required this.revealedCodes,
    this.guessedCodes,
    this.labelsUsed = false,
  });

  final GameRegion region;
  final UnchartedMode mode;
  final int revealedCount;
  final int totalCount;
  final int elapsedMs;
  final int score;
  final bool givenUp;
  final Set<String> revealedCodes;

  /// Codes the player actually typed. Null when all revealed = guessed.
  final Set<String>? guessedCodes;

  /// Whether country name labels were shown (score halved).
  final bool labelsUsed;

  @override
  ConsumerState<UnchartedResultsScreen> createState() =>
      _UnchartedResultsScreenState();
}

class _UnchartedResultsScreenState
    extends ConsumerState<UnchartedResultsScreen> {
  final GlobalKey<InkBurstOverlayState> _inkBurstKey = GlobalKey();
  bool _progressSaved = false;
  Future<UnchartedAllTimeStats?>? _allTimeStatsFuture;

  String get _elapsedFormatted {
    final seconds = (widget.elapsedMs / 1000).floor();
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  String get _grade {
    final pct = widget.revealedCount / widget.totalCount;
    if (pct >= 1.0) return 'S';
    if (pct >= 0.9) return 'A';
    if (pct >= 0.75) return 'B';
    if (pct >= 0.5) return 'C';
    if (pct >= 0.25) return 'D';
    return 'F';
  }

  Color get _gradeColor {
    switch (_grade) {
      case 'S':
        return FlitColors.gold;
      case 'A':
        return FlitColors.success;
      case 'B':
        return FlitColors.accent;
      case 'C':
        return FlitColors.textSecondary;
      case 'D':
        return FlitColors.error;
      default:
        return FlitColors.error;
    }
  }

  @override
  void initState() {
    super.initState();
    _saveProgress();
    _saveScoreToLeaderboard();
    _loadAllTimeStats();

    // Fire celebration burst for good results (grade B or better).
    final pct = widget.revealedCount / widget.totalCount;
    if (pct >= 0.75 && !widget.givenUp) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final size = MediaQuery.of(context).size;
        _inkBurstKey.currentState?.trigger(
          Offset(size.width / 2, size.height * 0.3),
        );
        // Fire additional bursts for S-grade (100%).
        if (pct >= 1.0) {
          Future<void>.delayed(const Duration(milliseconds: 400), () {
            if (!mounted) return;
            _inkBurstKey.currentState?.trigger(
              Offset(size.width * 0.25, size.height * 0.35),
            );
          });
          Future<void>.delayed(const Duration(milliseconds: 700), () {
            if (!mounted) return;
            _inkBurstKey.currentState?.trigger(
              Offset(size.width * 0.75, size.height * 0.35),
            );
          });
        }
      });
    }
  }

  void _saveProgress() {
    if (_progressSaved) return;
    _progressSaved = true;

    final key = '${widget.region.name}_${widget.mode.name}';
    final isCompleted =
        !widget.givenUp && widget.revealedCount >= widget.totalCount;

    ref.read(accountProvider.notifier).updateUnchartedProgress(
          key: key,
          score: widget.score,
          timeMs: widget.elapsedMs,
          revealedCount: widget.revealedCount,
          totalCount: widget.totalCount,
          completed: isCompleted,
        );
  }

  Future<void> _saveScoreToLeaderboard() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await Supabase.instance.client.from('scores').insert({
        'user_id': userId,
        'score': widget.score,
        'time_ms': widget.elapsedMs,
        'region': 'uncharted_${widget.region.name}_${widget.mode.name}',
        'rounds_completed': widget.revealedCount,
      });
      LeaderboardService.instance.invalidateCache();
    } catch (e) {
      debugPrint('[Uncharted] Failed to save score: $e');
    }
  }

  void _loadAllTimeStats() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _allTimeStatsFuture =
        LeaderboardService.instance.fetchUnchartedAllTimeStats(
      regionKey: 'uncharted_${widget.region.name}_${widget.mode.name}',
      userId: userId,
      playerScore: widget.score,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Read personal best for this region+mode.
    final key = '${widget.region.name}_${widget.mode.name}';
    final progress = ref.watch(accountProvider).unchartedProgress[key];

    final areas = RegionalData.getAreas(widget.region);
    final isCapitals = widget.mode == UnchartedMode.capitals;

    // For capitals mode, show capital name + (code); for countries, show name.
    String displayName(RegionalArea a) =>
        isCapitals && a.capital != null ? '${a.capital} (${a.code})' : a.name;

    // Filter areas that have a capital (in capitals mode, skip areas w/o capital).
    final eligible = isCapitals
        ? areas
            .where((a) => a.capital != null && a.capital!.isNotEmpty)
            .toList()
        : areas;

    final playerGuessed = widget.guessedCodes ?? widget.revealedCodes;
    final found = eligible.where((a) => playerGuessed.contains(a.code)).toList()
      ..sort((a, b) => displayName(a).compareTo(displayName(b)));
    final forceRevealed = eligible
        .where((a) =>
            widget.revealedCodes.contains(a.code) &&
            !playerGuessed.contains(a.code))
        .toList()
      ..sort((a, b) => displayName(a).compareTo(displayName(b)));
    final missed = eligible
        .where((a) => !widget.revealedCodes.contains(a.code))
        .toList()
      ..sort((a, b) => displayName(a).compareTo(displayName(b)));

    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: FlitColors.backgroundMid,
        title: const Text('Uncharted Results',
            style: TextStyle(color: FlitColors.textPrimary)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: FlitColors.textPrimary),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).popUntil(
            (route) => route.isFirst,
          ),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            children: [
              // Grade badge + score.
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _gradeColor.withValues(alpha: 0.2),
                    border: Border.all(color: _gradeColor, width: 3),
                  ),
                  child: Center(
                    child: Text(
                      _grade,
                      style: TextStyle(
                        color: _gradeColor,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '${widget.region.displayName} — ${widget.mode.displayName}',
                  style: const TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
              if (widget.givenUp) ...[
                const SizedBox(height: 4),
                const Center(
                  child: Text(
                    'Given Up',
                    style: TextStyle(
                      color: FlitColors.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Center(
                child: Text(
                  '${widget.score}',
                  style: const TextStyle(
                    color: FlitColors.gold,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Center(
                child: Text(
                  'POINTS',
                  style: TextStyle(
                    color: FlitColors.textSecondary,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Stats row.
              _StatRow(
                label: 'Discovered',
                value: '${widget.revealedCount} / ${widget.totalCount}',
              ),
              _StatRow(label: 'Time', value: _elapsedFormatted),
              if (widget.labelsUsed)
                const _StatRow(
                  label: 'Labels',
                  value: 'ON (score halved)',
                  valueColor: FlitColors.gold,
                ),
              if (progress != null && progress.hasPlayed) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: FlitColors.backgroundMid,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: FlitColors.cardBorder.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _MiniStat(
                        label: 'BEST',
                        value: '${progress.bestScore}',
                        icon: Icons.star,
                        color: FlitColors.gold,
                      ),
                      Container(
                          width: 1, height: 28, color: FlitColors.cardBorder),
                      _MiniStat(
                        label: 'GRADE',
                        value: progress.grade,
                        icon: Icons.military_tech,
                        color: FlitColors.accent,
                      ),
                      Container(
                          width: 1, height: 28, color: FlitColors.cardBorder),
                      _MiniStat(
                        label: 'PLAYS',
                        value: '${progress.attempts}',
                        icon: Icons.replay,
                        color: FlitColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // ── All-time community stats ──
              if (_allTimeStatsFuture != null)
                FutureBuilder<UnchartedAllTimeStats?>(
                  future: _allTimeStatsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: FlitColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }
                    final stats = snapshot.data;
                    if (stats == null) return const SizedBox.shrink();
                    return _AllTimeStatsCard(stats: stats);
                  },
                ),

              const SizedBox(height: 24),

              // Actions.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                    icon: const Icon(Icons.home),
                    label: const Text('Home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlitColors.backgroundMid,
                      foregroundColor: FlitColors.textPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => UnchartedGameScreen(
                            region: widget.region,
                            mode: widget.mode,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Play Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlitColors.accent,
                      foregroundColor: FlitColors.textPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── Found areas breakdown ──
              if (found.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.check_circle,
                  label: 'Found (${found.length})',
                  color: FlitColors.success,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: found
                      .map((a) => _AreaChip(name: displayName(a), found: true))
                      .toList(),
                ),
                const SizedBox(height: 20),
              ],

              // ── Force-revealed areas (from "Reveal All") ──
              if (forceRevealed.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.visibility,
                  label: 'Revealed (${forceRevealed.length})',
                  color: FlitColors.gold,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: forceRevealed
                      .map((a) => _AreaChip(name: displayName(a), found: false))
                      .toList(),
                ),
                const SizedBox(height: 20),
              ],

              // ── Missed areas breakdown ──
              if (missed.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.cancel,
                  label: 'Missed (${missed.length})',
                  color: FlitColors.error,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: missed
                      .map((a) => _AreaChip(name: displayName(a), found: false))
                      .toList(),
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
          // Celebration overlay
          Positioned.fill(
            child: InkBurstOverlay(key: _inkBurstKey),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AreaChip extends StatelessWidget {
  const _AreaChip({required this.name, required this.found});

  final String name;
  final bool found;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: found
            ? FlitColors.success.withValues(alpha: 0.15)
            : FlitColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: found
              ? FlitColors.success.withValues(alpha: 0.4)
              : FlitColors.error.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: found ? FlitColors.success : FlitColors.error,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: FlitColors.textMuted,
            fontSize: 9,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 140,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? FlitColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// All-time community stats card with score distribution histogram.
class _AllTimeStatsCard extends StatelessWidget {
  const _AllTimeStatsCard({required this.stats});

  final UnchartedAllTimeStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlitColors.backgroundMid,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: FlitColors.cardBorder.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row.
          const Row(
            children: [
              Icon(Icons.public, color: FlitColors.accent, size: 18),
              SizedBox(width: 8),
              Text(
                'ALL-TIME STATS',
                style: TextStyle(
                  color: FlitColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Rank + percentile headline.
          Center(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 15,
                ),
                children: [
                  const TextSpan(text: 'You ranked '),
                  TextSpan(
                    text: '#${stats.playerRank}',
                    style: const TextStyle(
                      color: FlitColors.gold,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  TextSpan(
                    text: ' of ${stats.totalPlayers} player'
                        '${stats.totalPlayers == 1 ? '' : 's'}',
                  ),
                ],
              ),
            ),
          ),
          if (stats.totalPlayers > 1) ...[
            const SizedBox(height: 4),
            Center(
              child: Text(
                'Top ${(100 - stats.percentile).clamp(1, 100)}%',
                style: TextStyle(
                  color: _percentileColor(stats.percentile),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Score distribution histogram.
          const Text(
            'Score Distribution',
            style: TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: _ScoreHistogram(
              bucketCounts: stats.bucketCounts,
              playerBucket: stats.playerBucket,
            ),
          ),
          const SizedBox(height: 12),

          // Summary stats row.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MiniStat(
                label: 'AVG',
                value: '${stats.averageScore}',
                icon: Icons.analytics,
                color: FlitColors.textSecondary,
              ),
              Container(
                width: 1,
                height: 28,
                color: FlitColors.cardBorder,
              ),
              _MiniStat(
                label: 'MEDIAN',
                value: '${stats.medianScore}',
                icon: Icons.align_vertical_center,
                color: FlitColors.textSecondary,
              ),
              Container(
                width: 1,
                height: 28,
                color: FlitColors.cardBorder,
              ),
              _MiniStat(
                label: 'TOP',
                value: '${stats.topScore}',
                icon: Icons.emoji_events,
                color: FlitColors.gold,
              ),
              Container(
                width: 1,
                height: 28,
                color: FlitColors.cardBorder,
              ),
              _MiniStat(
                label: 'PLAYS',
                value: '${stats.totalPlays}',
                icon: Icons.people,
                color: FlitColors.textSecondary,
              ),
            ],
          ),

          // Top 5 leaderboard.
          if (stats.top5.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Top 5 All-Time',
              style: TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            for (final entry in stats.top5)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '#${entry.rank}',
                        style: TextStyle(
                          color: entry.rank <= 3
                              ? FlitColors.gold
                              : FlitColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.playerName,
                        style: const TextStyle(
                          color: FlitColors.textPrimary,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${entry.score}',
                      style: const TextStyle(
                        color: FlitColors.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Color _percentileColor(int percentile) {
    if (percentile >= 90) return FlitColors.gold;
    if (percentile >= 70) return FlitColors.success;
    if (percentile >= 40) return FlitColors.accent;
    return FlitColors.textSecondary;
  }
}

/// Simple bar chart showing score distribution with the player's bucket
/// highlighted.
class _ScoreHistogram extends StatelessWidget {
  const _ScoreHistogram({
    required this.bucketCounts,
    required this.playerBucket,
  });

  final List<int> bucketCounts;
  final int playerBucket;

  @override
  Widget build(BuildContext context) {
    final maxCount = bucketCounts
        .reduce((a, b) => a > b ? a : b)
        .clamp(1, double.maxFinite.toInt());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(bucketCounts.length, (i) {
        final fraction = bucketCounts[i] / maxCount;
        final isPlayer = i == playerBucket;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isPlayer)
                  const Icon(
                    Icons.arrow_drop_down,
                    color: FlitColors.accent,
                    size: 14,
                  ),
                Container(
                  height: math.max(2.0, fraction * 60),
                  decoration: BoxDecoration(
                    color: isPlayer
                        ? FlitColors.accent
                        : FlitColors.textSecondary.withValues(alpha: 0.35),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
