import 'dart:math';

import 'quiz_category.dart';
import 'quiz_difficulty.dart';
import '../map/region.dart';

/// Game modes for Flight School quizzes.
enum QuizMode {
  /// Answer all areas as fast as possible.
  allStates,

  /// Time trial: answer as many as you can in a time limit.
  timeTrial,

  /// Rapid fire: 3 strikes and you're out.
  rapidFire,

  /// Type-in: type the name from the clue instead of tapping the map.
  typeIn,
}

extension QuizModeExtension on QuizMode {
  String get displayName {
    switch (this) {
      case QuizMode.allStates:
        return 'Complete';
      case QuizMode.timeTrial:
        return 'Time Trial';
      case QuizMode.rapidFire:
        return 'Rapid Fire';
      case QuizMode.typeIn:
        return 'Type-In';
    }
  }

  String get description {
    switch (this) {
      case QuizMode.allStates:
        return 'Find every area — fastest time wins';
      case QuizMode.timeTrial:
        return '60 seconds — how many can you get?';
      case QuizMode.rapidFire:
        return '3 wrong answers and you\'re out';
      case QuizMode.typeIn:
        return 'Type the name from the clue';
    }
  }

  /// Time limit in seconds, or null for untimed modes.
  int? get timeLimit {
    switch (this) {
      case QuizMode.allStates:
        return null;
      case QuizMode.timeTrial:
        return 60;
      case QuizMode.rapidFire:
        return null;
      case QuizMode.typeIn:
        return 90;
    }
  }

  /// Max wrong answers before game over, or null for unlimited.
  int? get maxWrong {
    switch (this) {
      case QuizMode.allStates:
        return null;
      case QuizMode.timeTrial:
        return null;
      case QuizMode.rapidFire:
        return 3;
      case QuizMode.typeIn:
        return null;
    }
  }
}

/// Result of a single answer attempt.
class QuizAnswerResult {
  const QuizAnswerResult({
    required this.correct,
    required this.points,
    required this.streak,
    required this.questionIndex,
    required this.answerCode,
    required this.correctCode,
    required this.elapsedMs,
    this.hintUsed = false,
  });

  final bool correct;
  final int points;
  final int streak;
  final int questionIndex;
  final String answerCode;
  final String correctCode;
  final int elapsedMs;
  final bool hintUsed;
}

/// Manages the state of a single quiz round.
class QuizSession {
  QuizSession({
    required this.mode,
    required this.category,
    required this.region,
    this.difficulty = QuizDifficulty.medium,
    int? seed,
  })  : _generator = QuizQuestionGenerator(region: region, seed: seed),
        _results = [],
        _answeredCodes = {},
        _startTime = null,
        _currentIndex = 0,
        _streak = 0,
        _totalScore = 0,
        _wrongCount = 0,
        _hintsUsed = 0,
        _currentHintLevel = 0,
        _isFinished = false;

  final QuizMode mode;
  final QuizCategory category;
  final GameRegion region;
  final QuizDifficulty difficulty;
  final QuizQuestionGenerator _generator;

  late final List<QuizQuestion> _questions;
  final List<QuizAnswerResult> _results;
  final Set<String> _answeredCodes;

  DateTime? _startTime;
  int _currentIndex;
  int _streak;
  int _totalScore;
  int _wrongCount;
  int _hintsUsed;
  int _currentHintLevel;
  bool _isFinished;

  // ── Public getters ────────────────────────────────────────────────────────

  bool get isStarted => _startTime != null;
  bool get isFinished => _isFinished;
  int get currentIndex => _currentIndex;
  int get totalQuestions => _questions.length;
  int get streak => _streak;
  int get totalScore => _totalScore;
  int get wrongCount => _wrongCount;
  int get hintsUsed => _hintsUsed;
  int get correctCount => _results.where((r) => r.correct).length;
  Set<String> get answeredCodes => Set.unmodifiable(_answeredCodes);
  List<QuizAnswerResult> get results => List.unmodifiable(_results);
  bool get showLabels => difficulty.showLabels;

  /// Current hint level for the current question (0 = no hint, 1-3 = progressive).
  int get currentHintLevel => _currentHintLevel;

  /// Whether a hint can be used on the current question.
  bool get canUseHint =>
      _hintsUsed < difficulty.maxHints && _currentHintLevel < 3;

  QuizQuestion? get currentQuestion {
    if (_isFinished || _currentIndex >= _questions.length) return null;
    return _questions[_currentIndex];
  }

  /// Elapsed time since quiz started, in milliseconds.
  int get elapsedMs {
    if (_startTime == null) return 0;
    return DateTime.now().difference(_startTime!).inMilliseconds;
  }

  /// Elapsed time formatted as m:ss.
  String get elapsedFormatted {
    final ms = elapsedMs;
    final seconds = (ms / 1000).floor();
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  /// Remaining time for timed modes.
  int? get remainingMs {
    final limit = mode.timeLimit;
    if (limit == null) return null;
    final remaining = (limit * 1000) - elapsedMs;
    return remaining.clamp(0, limit * 1000);
  }

  /// Whether the quiz should end due to time running out.
  bool get isTimeUp {
    final remaining = remainingMs;
    return remaining != null && remaining <= 0;
  }

  /// Whether the quiz should end due to too many wrong answers.
  bool get isStrikedOut {
    final maxWrong = mode.maxWrong;
    return maxWrong != null && _wrongCount >= maxWrong;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Initialize and start the quiz.
  void start() {
    _questions = _generator.generateQuestions(category);
    _startTime = DateTime.now();
  }

  /// Use a hint on the current question. Returns the hint level (1-3).
  ///
  /// Hint levels:
  /// 1. Highlight the correct region of the map (narrows to quadrant)
  /// 2. Eliminate 75% of wrong answers (dim them out)
  /// 3. Highlight the exact correct answer (pulsing)
  ///
  /// Each hint reduces the score multiplier for this question.
  int? useHint() {
    if (!canUseHint || currentQuestion == null) return null;
    _hintsUsed++;
    _currentHintLevel++;
    return _currentHintLevel;
  }

  /// Submit an answer by tapping an area code.
  QuizAnswerResult? submitAnswer(String tappedCode) {
    if (_isFinished || currentQuestion == null) return null;
    if (_answeredCodes.contains(tappedCode)) return null;

    final question = currentQuestion!;
    final correct = tappedCode == question.answerCode;
    final elapsed = elapsedMs;
    final hintUsed = _currentHintLevel > 0;

    if (correct) {
      _streak++;
      _answeredCodes.add(tappedCode);
      final points = _calculatePoints(elapsed, question.category);
      _totalScore += points;

      final result = QuizAnswerResult(
        correct: true,
        points: points,
        streak: _streak,
        questionIndex: _currentIndex,
        answerCode: tappedCode,
        correctCode: question.answerCode,
        elapsedMs: elapsed,
        hintUsed: hintUsed,
      );
      _results.add(result);
      _currentIndex++;
      _currentHintLevel = 0; // Reset hints for next question

      if (_currentIndex >= _questions.length || isTimeUp) {
        _isFinished = true;
      }

      return result;
    } else {
      _streak = 0;
      _wrongCount++;

      final penalty = _calculatePenalty();
      final result = QuizAnswerResult(
        correct: false,
        points: -penalty,
        streak: 0,
        questionIndex: _currentIndex,
        answerCode: tappedCode,
        correctCode: question.answerCode,
        elapsedMs: elapsed,
        hintUsed: hintUsed,
      );
      _results.add(result);
      _totalScore = max(0, _totalScore - penalty);

      if (isStrikedOut) {
        _isFinished = true;
      }

      return result;
    }
  }

  /// Advance to the next question without scoring.
  ///
  /// Used by type-in mode to move past a question after a wrong answer
  /// (since the player cannot "try again" by tapping differently).
  void advanceQuestion() {
    if (_isFinished || currentQuestion == null) return;
    _currentIndex++;
    _currentHintLevel = 0;
    if (_currentIndex >= _questions.length || isTimeUp) {
      _isFinished = true;
    }
  }

  /// Call periodically to check time-based game-over.
  void tick() {
    if (!_isFinished && isTimeUp) {
      _isFinished = true;
    }
  }

  /// Force end the quiz (e.g., player quits).
  void finish() {
    _isFinished = true;
  }

  // ── Scoring ───────────────────────────────────────────────────────────────

  /// Calculate points for a correct answer.
  ///
  /// Formula: (base + speedBonus) * streakMultiplier * clueDifficulty
  ///          * difficultyMultiplier * hintPenalty
  int _calculatePoints(int elapsedMs, QuizCategory questionCategory) {
    const base = 1000;

    // Streak multiplier: 1.0, 1.2, 1.4, 1.6, 1.8, 2.0 (max)
    final streakMult = min(2.0, 1.0 + (_streak - 1) * 0.2);

    // Speed bonus: decays over 10 seconds per question
    final questionElapsed =
        _results.isEmpty ? elapsedMs : elapsedMs - (_results.last.elapsedMs);
    final speedFraction = (1.0 - (questionElapsed / 10000)).clamp(0.0, 1.0);
    final speedBonus = (500 * speedFraction).round();

    // Clue difficulty multiplier (harder clues = more points)
    final clueMult = clueDifficultyMultiplier(questionCategory);

    // Overall difficulty multiplier (easy=0.7, medium=1.0, hard=1.5)
    final diffMult = difficulty.scoreMultiplier;

    // Hint penalty: each hint level reduces score by 25%
    final hintPenalty = 1.0 - (_currentHintLevel * 0.25);

    final raw =
        (base + speedBonus) * streakMult * clueMult * diffMult * hintPenalty;
    return raw.round();
  }

  /// Calculate penalty for a wrong answer (scales with difficulty).
  int _calculatePenalty() {
    switch (difficulty) {
      case QuizDifficulty.easy:
        return 100;
      case QuizDifficulty.medium:
        return 200;
      case QuizDifficulty.hard:
        return 300;
    }
  }

  // ── Summary ───────────────────────────────────────────────────────────────

  /// Generate a summary of the quiz results.
  QuizSummary get summary => QuizSummary(
        mode: mode,
        category: category,
        difficulty: difficulty,
        totalScore: _totalScore,
        correctCount: correctCount,
        wrongCount: _wrongCount,
        totalQuestions: _questions.length,
        elapsedMs: elapsedMs,
        bestStreak: _results.fold<int>(
          0,
          (best, r) => r.correct && r.streak > best ? r.streak : best,
        ),
        hintsUsed: _hintsUsed,
        results: List.unmodifiable(_results),
      );
}

/// Summary of a completed quiz session.
class QuizSummary {
  const QuizSummary({
    required this.mode,
    required this.category,
    required this.difficulty,
    required this.totalScore,
    required this.correctCount,
    required this.wrongCount,
    required this.totalQuestions,
    required this.elapsedMs,
    required this.bestStreak,
    required this.hintsUsed,
    required this.results,
  });

  final QuizMode mode;
  final QuizCategory category;
  final QuizDifficulty difficulty;
  final int totalScore;
  final int correctCount;
  final int wrongCount;
  final int totalQuestions;
  final int elapsedMs;
  final int bestStreak;
  final int hintsUsed;
  final List<QuizAnswerResult> results;

  double get accuracy => (correctCount + wrongCount) > 0
      ? correctCount / (correctCount + wrongCount)
      : 0;

  String get elapsedFormatted {
    final seconds = (elapsedMs / 1000).floor();
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  /// Coin reward for this quiz session.
  ///
  /// Base reward scales with correct answers and difficulty.
  /// Diminishing returns for repeat completions should be applied externally.
  int get coinReward {
    final base = correctCount * 5;
    final diffBonus = (base * difficulty.scoreMultiplier).round();
    final accuracyBonus = (accuracy * 20).round();
    return diffBonus + accuracyBonus;
  }

  /// Grade based on accuracy and speed.
  String get grade {
    if (accuracy >= 0.95 && bestStreak >= 10) return 'S';
    if (accuracy >= 0.9) return 'A';
    if (accuracy >= 0.8) return 'B';
    if (accuracy >= 0.7) return 'C';
    if (accuracy >= 0.5) return 'D';
    return 'F';
  }
}
