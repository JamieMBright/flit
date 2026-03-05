import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../game/quiz/quiz_category.dart';
import '../../game/quiz/quiz_difficulty.dart';
import '../../game/quiz/quiz_session.dart';
import '../../game/map/region.dart';
import 'quiz_results_screen.dart';

/// Type-In game screen for Flight School.
///
/// Shows a clue card and a text input field. The player types the answer
/// (country/state name) instead of tapping a map. Autocomplete suggestions
/// filter as the player types.
class TypeInGameScreen extends StatefulWidget {
  const TypeInGameScreen({
    super.key,
    required this.mode,
    required this.category,
    this.region = GameRegion.usStates,
    this.difficulty = QuizDifficulty.medium,
    this.flightSchoolLevelId,
  });

  final QuizMode mode;
  final QuizCategory category;
  final GameRegion region;
  final QuizDifficulty difficulty;
  final String? flightSchoolLevelId;

  @override
  State<TypeInGameScreen> createState() => _TypeInGameScreenState();
}

class _TypeInGameScreenState extends State<TypeInGameScreen>
    with TickerProviderStateMixin {
  late QuizSession _session;
  late List<String> _allAreaNames;
  late Map<String, String> _nameToCode;
  Timer? _timer;

  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<String> _suggestions = [];
  bool _showFeedback = false;
  bool _lastAnswerCorrect = false;
  String _feedbackText = '';
  int? _lastPoints;

  late AnimationController _feedbackAnimController;
  late Animation<double> _feedbackOpacity;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _feedbackAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _feedbackOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _feedbackAnimController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _initSession();
  }

  void _initSession() {
    _session = QuizSession(
      mode: widget.mode,
      category: widget.category,
      region: widget.region,
      difficulty: widget.difficulty,
    );

    // Build area name lookup
    final areas = RegionalData.getAreas(widget.region);
    _nameToCode = {for (final area in areas) area.name: area.code};
    _allAreaNames = areas.map((a) => a.name).toList()..sort();

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
    _textController.dispose();
    _focusNode.dispose();
    _feedbackAnimController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // ── Answer matching ──────────────────────────────────────────────────────

  /// Normalize a string for comparison: lowercase, trim, remove diacritics.
  static String _normalize(String s) {
    var result = s.toLowerCase().trim();
    // Remove common diacritics by mapping to ASCII equivalents
    const diacriticMap = {
      '\u00e0': 'a', '\u00e1': 'a', '\u00e2': 'a', '\u00e3': 'a',
      '\u00e4': 'a', '\u00e5': 'a',
      '\u00e8': 'e', '\u00e9': 'e', '\u00ea': 'e', '\u00eb': 'e',
      '\u00ec': 'i', '\u00ed': 'i', '\u00ee': 'i', '\u00ef': 'i',
      '\u00f2': 'o', '\u00f3': 'o', '\u00f4': 'o', '\u00f5': 'o',
      '\u00f6': 'o',
      '\u00f9': 'u', '\u00fa': 'u', '\u00fb': 'u', '\u00fc': 'u',
      '\u00f1': 'n',
      '\u00e7': 'c',
      '\u00ff': 'y', '\u00fd': 'y',
      '\u00f0': 'd',
      '\u00df': 'ss',
      '\u00e6': 'ae',
      '\u0153': 'oe',
      '\u00f8': 'o',
      // Uppercase variants (after lowercasing these shouldn't appear, but safe)
    };
    for (final entry in diacriticMap.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    // Also strip curly/smart quotes and normalize apostrophes
    result = result
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'")
        .replaceAll('\u201c', '"')
        .replaceAll('\u201d', '"');
    return result;
  }

  /// Check if the typed input matches the expected answer.
  bool _isMatch(String input, String expected) {
    final normInput = _normalize(input);
    final normExpected = _normalize(expected);

    if (normInput.isEmpty) return false;

    // Exact normalized match
    if (normInput == normExpected) return true;

    // Easy difficulty: accept if input contains a significant keyword
    // e.g. "congo" matches "Democratic Republic of the Congo"
    if (widget.difficulty == QuizDifficulty.easy) {
      // Split expected into words, check if any significant word (>3 chars)
      // matches or is contained
      final expectedWords = normExpected.split(RegExp(r'\s+'));
      final significantWords =
          expectedWords.where((w) => w.length > 3).toList();
      // Accept if the input matches any significant word
      for (final word in significantWords) {
        if (normInput == word) return true;
      }
      // Accept if expected contains input and input is reasonably long
      if (normInput.length >= 4 && normExpected.contains(normInput)) {
        return true;
      }
    }

    // Hard difficulty: only exact normalized match (already checked above)
    if (widget.difficulty == QuizDifficulty.hard) return false;

    // Medium: accept close matches — allow missing/extra "the", minor diffs
    // Strip common articles
    String stripArticles(String s) =>
        s.replaceAll(RegExp(r'^(the|a|an|of)\s+'), '').trim();
    final strippedInput = stripArticles(normInput);
    final strippedExpected = stripArticles(normExpected);
    if (strippedInput == strippedExpected) return true;

    // Accept if expected contains input as a substantial substring
    if (strippedInput.length >= 4 && strippedExpected.contains(strippedInput)) {
      return true;
    }

    return false;
  }

  // ── Autocomplete ────────────────────────────────────────────────────────

  void _onTextChanged(String value) {
    setState(() {
      if (value.trim().isEmpty) {
        _suggestions = [];
      } else {
        final normInput = _normalize(value);
        _suggestions = _allAreaNames.where((name) {
          final normName = _normalize(name);
          return normName.contains(normInput);
        }).toList();
        // Limit suggestions to 6
        if (_suggestions.length > 6) {
          _suggestions = _suggestions.sublist(0, 6);
        }
      }
    });
  }

  void _selectSuggestion(String name) {
    _textController.text = name;
    _textController.selection = TextSelection.collapsed(offset: name.length);
    setState(() {
      _suggestions = [];
    });
    _submitAnswer();
  }

  // ── Submit ──────────────────────────────────────────────────────────────

  void _submitAnswer() {
    if (_session.isFinished || _session.currentQuestion == null) return;

    final input = _textController.text.trim();
    if (input.isEmpty) return;

    final question = _session.currentQuestion!;
    final correct = _isMatch(input, question.answerName);

    if (correct) {
      // Submit the correct answer code to record a correct result
      final result = _session.submitAnswer(question.answerCode);
      if (result == null) return;

      setState(() {
        _showFeedback = true;
        _lastAnswerCorrect = true;
        _lastPoints = result.points;
        _feedbackText = 'Correct! ${question.answerName}';
        _textController.clear();
        _suggestions = [];
      });
    } else {
      // Submit a synthetic wrong code, then advance past the question
      final result = _session.submitAnswer('__wrong_typein__');
      if (result == null) return;
      // Advance to the next question since the player can't "retry" in type-in
      _session.advanceQuestion();

      setState(() {
        _showFeedback = true;
        _lastAnswerCorrect = false;
        _lastPoints = result.points;
        _feedbackText = 'Wrong! It was ${question.answerName}';
        _textController.clear();
        _suggestions = [];
      });

      _shakeController.forward(from: 0);
    }

    // Play feedback animation
    _feedbackAnimController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() => _showFeedback = false);
      }
    });

    if (_session.isFinished) {
      _timer?.cancel();
      Future.delayed(const Duration(milliseconds: 800), _navigateToResults);
    } else {
      _focusNode.requestFocus();
    }
  }

  void _skipQuestion() {
    if (_session.isFinished || _session.currentQuestion == null) return;
    final question = _session.currentQuestion!;

    // Record as wrong, then advance past the question
    _session.submitAnswer('__skip_typein__');
    _session.advanceQuestion();

    setState(() {
      _showFeedback = true;
      _lastAnswerCorrect = false;
      _lastPoints = 0;
      _feedbackText = 'Skipped! It was ${question.answerName}';
      _textController.clear();
      _suggestions = [];
    });

    _feedbackAnimController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() => _showFeedback = false);
      }
    });

    if (_session.isFinished) {
      _timer?.cancel();
      Future.delayed(const Duration(milliseconds: 800), _navigateToResults);
    } else {
      _focusNode.requestFocus();
    }
  }

  // ── Navigation ──────────────────────────────────────────────────────────

  Future<void> _navigateToResults() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => QuizResultsScreen(
          summary: _session.summary,
          flightSchoolLevelId: widget.flightSchoolLevelId,
          region: widget.region,
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

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final question = _session.currentQuestion;
    final remaining = _session.remainingMs;

    return Scaffold(
      backgroundColor: FlitColors.backgroundDark,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            _buildTopBar(remaining),

            // Scrollable content area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // Score bar
                    _buildScoreBar(),
                    const SizedBox(height: 12),

                    // Clue card
                    _buildClueCard(question),
                    const SizedBox(height: 8),

                    // First letter hint (easy mode)
                    if (widget.difficulty == QuizDifficulty.easy &&
                        question != null)
                      _buildFirstLetterHint(question.answerName),

                    const SizedBox(height: 16),

                    // Feedback animation
                    if (_showFeedback) _buildFeedback(),

                    // Text input
                    _buildTextInput(),
                    const SizedBox(height: 8),

                    // Action buttons
                    _buildActionButtons(),
                    const SizedBox(height: 8),

                    // Autocomplete suggestions
                    if (_suggestions.isNotEmpty) _buildSuggestions(),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Progress bar
            _buildProgressBar(),
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.keyboard, color: FlitColors.accent, size: 14),
                const SizedBox(width: 4),
                Text(
                  widget.mode.displayName.toUpperCase(),
                  style: const TextStyle(
                    color: FlitColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ],
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

  // ── Score bar ───────────────────────────────────────────────────────────

  Widget _buildScoreBar() {
    return Row(
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
    );
  }

  // ── Clue card ───────────────────────────────────────────────────────────

  Widget _buildClueCard(QuizQuestion? question) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(question?.clueText ?? 'empty'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
                  const SizedBox(height: 8),
                  // Category icon
                  Icon(
                    Icons.keyboard,
                    color: FlitColors.accent.withOpacity(0.5),
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  // Clue text
                  Text(
                    question.clueText,
                    style: const TextStyle(
                      color: FlitColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
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

  // ── First letter hint (easy mode) ───────────────────────────────────────

  Widget _buildFirstLetterHint(String answerName) {
    final firstLetter = answerName.isNotEmpty ? answerName[0] : '?';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: FlitColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FlitColors.success.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lightbulb_outline,
            color: FlitColors.success,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            'Starts with "$firstLetter"',
            style: const TextStyle(
              color: FlitColors.success,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Feedback ────────────────────────────────────────────────────────────

  Widget _buildFeedback() {
    final color = _lastAnswerCorrect ? FlitColors.success : FlitColors.error;
    final icon = _lastAnswerCorrect ? Icons.check_circle : Icons.cancel;

    return AnimatedBuilder(
      animation: _feedbackAnimController,
      builder: (context, child) {
        return Opacity(
          opacity: _feedbackOpacity.value.clamp(0.0, 1.0),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _feedbackText,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_lastPoints != null && _lastPoints != 0)
                  Text(
                    _lastPoints! > 0 ? '+$_lastPoints' : '$_lastPoints',
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Text input ──────────────────────────────────────────────────────────

  Widget _buildTextInput() {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final shakeOffset =
            _shakeAnimation.value * 8 * _shakeDirectionMultiplier();
        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: FlitColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _focusNode.hasFocus
                ? FlitColors.accent.withOpacity(0.6)
                : FlitColors.cardBorder,
            width: _focusNode.hasFocus ? 1.5 : 1,
          ),
        ),
        child: TextField(
          controller: _textController,
          focusNode: _focusNode,
          autofocus: true,
          textInputAction: TextInputAction.done,
          style: const TextStyle(
            color: FlitColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'Type the answer...',
            hintStyle: TextStyle(
              color: FlitColors.textMuted.withOpacity(0.6),
              fontSize: 16,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: InputBorder.none,
            prefixIcon: const Icon(
              Icons.edit,
              color: FlitColors.textMuted,
              size: 20,
            ),
            suffixIcon: _textController.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _textController.clear();
                      setState(() => _suggestions = []);
                    },
                    child: const Icon(
                      Icons.clear,
                      color: FlitColors.textMuted,
                      size: 20,
                    ),
                  )
                : null,
          ),
          onChanged: _onTextChanged,
          onSubmitted: (_) => _submitAnswer(),
        ),
      ),
    );
  }

  /// Produces a sine-like shake pattern based on the animation value.
  double _shakeDirectionMultiplier() {
    final t = _shakeAnimation.value;
    // Oscillate: right, left, right, center
    if (t < 0.25) return 1;
    if (t < 0.5) return -1;
    if (t < 0.75) return 1;
    return -1;
  }

  // ── Action buttons ─────────────────────────────────────────────────────

  Widget _buildActionButtons() {
    return Row(
      children: [
        // Skip button
        Expanded(
          child: GestureDetector(
            onTap: _skipQuestion,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: FlitColors.backgroundMid,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: FlitColors.cardBorder),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.skip_next,
                    color: FlitColors.textSecondary,
                    size: 20,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'SKIP',
                    style: TextStyle(
                      color: FlitColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Submit button
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: _submitAnswer,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: FlitColors.accent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: FlitColors.accent.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send, color: FlitColors.textPrimary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'SUBMIT',
                    style: TextStyle(
                      color: FlitColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Suggestions ─────────────────────────────────────────────────────────

  Widget _buildSuggestions() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: FlitColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FlitColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _suggestions.asMap().entries.map((entry) {
          final index = entry.key;
          final name = entry.value;
          final isLast = index == _suggestions.length - 1;

          return GestureDetector(
            onTap: () => _selectSuggestion(name),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : const Border(
                        bottom: BorderSide(
                          color: FlitColors.cardBorder,
                          width: 0.5,
                        ),
                      ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.place,
                    color: FlitColors.textMuted,
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _buildHighlightedName(name)),
                  const Icon(
                    Icons.north_west,
                    color: FlitColors.textMuted,
                    size: 14,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Highlight the matching portion of the suggestion.
  Widget _buildHighlightedName(String name) {
    final input = _textController.text.trim().toLowerCase();
    final nameLower = name.toLowerCase();
    final matchIndex = nameLower.indexOf(input);

    if (input.isEmpty || matchIndex < 0) {
      return Text(
        name,
        style: const TextStyle(color: FlitColors.textSecondary, fontSize: 15),
      );
    }

    final before = name.substring(0, matchIndex);
    final match = name.substring(matchIndex, matchIndex + input.length);
    final after = name.substring(matchIndex + input.length);

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: before,
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 15,
            ),
          ),
          TextSpan(
            text: match,
            style: const TextStyle(
              color: FlitColors.accent,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: after,
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // ── Progress bar ────────────────────────────────────────────────────────

  Widget _buildProgressBar() {
    final answered = _session.correctCount + _session.wrongCount;
    final total = _session.totalQuestions;
    final progress = total > 0 ? _session.correctCount / total : 0.0;

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
                '$answered of $total answered',
                style: const TextStyle(
                  color: FlitColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              Text(
                '${(progress * 100).round()}% correct',
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
