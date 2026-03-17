import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../game/map/region.dart';
import '../../game/quiz/uncharted_map_widget.dart';
import '../../game/quiz/uncharted_session.dart';

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
  });

  final GameRegion region;
  final UnchartedMode mode;

  @override
  State<UnchartedGameScreen> createState() => _UnchartedGameScreenState();
}

class _UnchartedGameScreenState extends State<UnchartedGameScreen>
    with SingleTickerProviderStateMixin {
  late UnchartedSession _session;
  Timer? _timer;

  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String? _lastRevealedCode;
  String? _feedbackText;

  late AnimationController _feedbackController;
  late Animation<double> _feedbackOpacity;

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

    // Auto-focus the text field.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _textController.dispose();
    _focusNode.dispose();
    _feedbackController.dispose();
    super.dispose();
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
      }
    });

    if (_session.isComplete) {
      _timer?.cancel();
      // Short delay to show the last reveal, then navigate to results.
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) _showResults();
      });
    }

    // Keep focus on text field.
    _focusNode.requestFocus();
  }

  void _giveUp() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FlitColors.backgroundMid,
        title: const Text(
          'Give Up?',
          style: TextStyle(color: FlitColors.textPrimary),
        ),
        content: Text(
          'You\'ve found ${_session.revealedCount} of ${_session.totalCount}. '
          'Give up and see results?',
          style: const TextStyle(color: FlitColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Going',
                style: TextStyle(color: FlitColors.accent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Give Up',
                style: TextStyle(color: FlitColors.error)),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        _session.giveUp();
        _timer?.cancel();
        _showResults();
      }
    });
  }

  void _showResults() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => UnchartedResultsScreen(
          region: widget.region,
          mode: widget.mode,
          revealedCount: _session.revealedCount,
          totalCount: _session.totalCount,
          elapsedMs: _session.elapsedMs,
          score: _session.finalScore,
          givenUp: _session.givenUp,
          revealedCodes: _session.revealedCodes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use resizeToAvoidBottomInset: false so the map doesn't shrink when
    // the keyboard appears. The HUD floats on top via a Stack.
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          children: [
            // Full-screen map — stays still regardless of keyboard state.
            Positioned.fill(
              child: UnchartedMapWidget(
                region: widget.region,
                revealedCodes: _session.revealedCodes,
                lastRevealedCode: _lastRevealedCode,
                capitalsMode: widget.mode == UnchartedMode.capitals,
              ),
            ),
            // Top bar HUD.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(),
            ),
            // Feedback + input bar at the bottom.
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
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: FlitColors.backgroundMid,
      child: Row(
        children: [
          // Back button.
          IconButton(
            icon: const Icon(Icons.arrow_back, color: FlitColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          // Timer.
          const Icon(Icons.timer_outlined,
              color: FlitColors.textSecondary, size: 18),
          const SizedBox(width: 4),
          Text(
            _session.elapsedFormatted,
            style: const TextStyle(
              color: FlitColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
          const Spacer(),
          // Progress.
          Text(
            '${_session.revealedCount} / ${_session.totalCount}',
            style: const TextStyle(
              color: FlitColors.gold,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
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

  Widget _buildFeedback() {
    return AnimatedBuilder(
      animation: _feedbackController,
      builder: (context, _) {
        if (_feedbackText == null || _feedbackOpacity.value <= 0) {
          return const SizedBox(height: 28);
        }
        return SizedBox(
          height: 28,
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      color: FlitColors.backgroundMid,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              enabled: !_session.isComplete,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: null,
              enableIMEPersonalizedLearning: false,
              spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
              style: const TextStyle(
                color: FlitColors.textPrimary,
                fontSize: 18,
              ),
              decoration: InputDecoration(
                hintText: widget.mode == UnchartedMode.countries
                    ? 'Type a country name...'
                    : 'Type a capital city...',
                hintStyle: TextStyle(
                  color: FlitColors.textSecondary.withOpacity(0.5),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: FlitColors.accent),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: FlitColors.accent.withOpacity(0.4)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: FlitColors.accent, width: 2),
                ),
                filled: true,
                fillColor: const Color(0xFF1A2A3A),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: _handleInputChanged,
              onSubmitted: _handleSubmit,
              textInputAction: TextInputAction.go,
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
/// found and which were missed.
class UnchartedResultsScreen extends StatelessWidget {
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
  });

  final GameRegion region;
  final UnchartedMode mode;
  final int revealedCount;
  final int totalCount;
  final int elapsedMs;
  final int score;
  final bool givenUp;
  final Set<String> revealedCodes;

  String get _elapsedFormatted {
    final seconds = (elapsedMs / 1000).floor();
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  String get _grade {
    final pct = revealedCount / totalCount;
    if (pct >= 1.0) return 'S';
    if (pct >= 0.9) return 'A';
    if (pct >= 0.75) return 'B';
    if (pct >= 0.5) return 'C';
    if (pct >= 0.25) return 'D';
    return 'F';
  }

  @override
  Widget build(BuildContext context) {
    final areas = RegionalData.getAreas(region);
    final isCapitals = mode == UnchartedMode.capitals;

    // For capitals mode, show capital name + (code); for countries, show name.
    String displayName(RegionalArea a) =>
        isCapitals && a.capital != null ? '${a.capital} (${a.code})' : a.name;

    // Filter areas that have a capital (in capitals mode, skip areas w/o capital).
    final eligible = isCapitals
        ? areas
            .where((a) => a.capital != null && a.capital!.isNotEmpty)
            .toList()
        : areas;

    final found = eligible.where((a) => revealedCodes.contains(a.code)).toList()
      ..sort((a, b) => displayName(a).compareTo(displayName(b)));
    final missed = eligible
        .where((a) => !revealedCodes.contains(a.code))
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
      body: ListView(
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
              '${region.displayName} — ${mode.displayName}',
              style: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          if (givenUp) ...[
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
              '$score',
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
            value: '$revealedCount / $totalCount',
          ),
          _StatRow(label: 'Time', value: _elapsedFormatted),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => UnchartedGameScreen(
                        region: region,
                        mode: mode,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Play Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlitColors.accent,
                  foregroundColor: FlitColors.textPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
    );
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

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

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
            width: 100,
            child: Text(
              value,
              style: const TextStyle(
                color: FlitColors.textPrimary,
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
