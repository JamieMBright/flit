import 'dart:math';

import 'quiz_category.dart';
import '../map/region.dart';

/// Game modes for Flight School quizzes.
enum QuizMode {
  /// Answer all states as fast as possible.
  allStates,

  /// Time trial: answer as many as you can in a time limit.
  timeTrial,

  /// Rapid fire: 3 strikes and you're out.
  rapidFire,
}

extension QuizModeExtension on QuizMode {
  String get displayName {
    switch (this) {
      case QuizMode.allStates:
        return 'All States';
      case QuizMode.timeTrial:
        return 'Time Trial';
      case QuizMode.rapidFire:
        return 'Rapid Fire';
    }
  }

  String get description {
    switch (this) {
      case QuizMode.allStates:
        return 'Find all 50 states — fastest time wins';
      case QuizMode.timeTrial:
        return '60 seconds — how many can you get?';
      case QuizMode.rapidFire:
        return '3 wrong answers and you\'re out';
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
  });

  final bool correct;
  final int points;
  final int streak;
  final int questionIndex;
  final String answerCode;
  final String correctCode;
  final int elapsedMs;
}

/// Manages the state of a single quiz round.
class QuizSession {
  QuizSession({
    required this.mode,
    required this.category,
    required this.region,
    int? seed,
  }) : _generator = QuizQuestionGenerator(region: region, seed: seed),
       _results = [],
       _answeredCodes = {},
       _startTime = null,
       _currentIndex = 0,
       _streak = 0,
       _totalScore = 0,
       _wrongCount = 0,
       _isFinished = false;

  final QuizMode mode;
  final QuizCategory category;
  final GameRegion region;
  final QuizQuestionGenerator _generator;

  late final List<QuizQuestion> _questions;
  final List<QuizAnswerResult> _results;
  final Set<String> _answeredCodes;

  DateTime? _startTime;
  int _currentIndex;
  int _streak;
  int _totalScore;
  int _wrongCount;
  bool _isFinished;

  // ── Public getters ────────────────────────────────────────────────────────

  bool get isStarted => _startTime != null;
  bool get isFinished => _isFinished;
  int get currentIndex => _currentIndex;
  int get totalQuestions => _questions.length;
  int get streak => _streak;
  int get totalScore => _totalScore;
  int get wrongCount => _wrongCount;
  int get correctCount => _results.where((r) => r.correct).length;
  Set<String> get answeredCodes => Set.unmodifiable(_answeredCodes);
  List<QuizAnswerResult> get results => List.unmodifiable(_results);

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

  /// Submit an answer by tapping a state code.
  QuizAnswerResult? submitAnswer(String tappedCode) {
    if (_isFinished || currentQuestion == null) return null;
    if (_answeredCodes.contains(tappedCode)) return null;

    final question = currentQuestion!;
    final correct = tappedCode == question.answerCode;
    final elapsed = elapsedMs;

    if (correct) {
      _streak++;
      _answeredCodes.add(tappedCode);
      final points = _calculatePoints(elapsed);
      _totalScore += points;

      final result = QuizAnswerResult(
        correct: true,
        points: points,
        streak: _streak,
        questionIndex: _currentIndex,
        answerCode: tappedCode,
        correctCode: question.answerCode,
        elapsedMs: elapsed,
      );
      _results.add(result);
      _currentIndex++;

      if (_currentIndex >= _questions.length || isTimeUp) {
        _isFinished = true;
      }

      return result;
    } else {
      _streak = 0;
      _wrongCount++;

      final result = QuizAnswerResult(
        correct: false,
        points: -200,
        streak: 0,
        questionIndex: _currentIndex,
        answerCode: tappedCode,
        correctCode: question.answerCode,
        elapsedMs: elapsed,
      );
      _results.add(result);
      _totalScore = max(0, _totalScore - 200);

      if (isStrikedOut) {
        _isFinished = true;
      }

      return result;
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

  /// Calculate points for a correct answer based on speed and streak.
  int _calculatePoints(int elapsedMs) {
    // Base points
    const base = 1000;

    // Streak multiplier: 1.0, 1.2, 1.4, 1.6, 1.8, 2.0 (max)
    final streakMultiplier = min(2.0, 1.0 + (_streak - 1) * 0.2);

    // Speed bonus: decays over 10 seconds per question
    // Full bonus (500) if answered in <1s, linearly to 0 at 10s
    final questionElapsed = _results.isEmpty
        ? elapsedMs
        : elapsedMs - (_results.last.elapsedMs);
    final speedFraction = (1.0 - (questionElapsed / 10000)).clamp(0.0, 1.0);
    final speedBonus = (500 * speedFraction).round();

    return ((base + speedBonus) * streakMultiplier).round();
  }

  // ── Summary ───────────────────────────────────────────────────────────────

  /// Generate a summary of the quiz results.
  QuizSummary get summary => QuizSummary(
    mode: mode,
    category: category,
    totalScore: _totalScore,
    correctCount: correctCount,
    wrongCount: _wrongCount,
    totalQuestions: _questions.length,
    elapsedMs: elapsedMs,
    bestStreak: _results.fold<int>(
      0,
      (best, r) => r.correct && r.streak > best ? r.streak : best,
    ),
    results: List.unmodifiable(_results),
  );
}

/// Summary of a completed quiz session.
class QuizSummary {
  const QuizSummary({
    required this.mode,
    required this.category,
    required this.totalScore,
    required this.correctCount,
    required this.wrongCount,
    required this.totalQuestions,
    required this.elapsedMs,
    required this.bestStreak,
    required this.results,
  });

  final QuizMode mode;
  final QuizCategory category;
  final int totalScore;
  final int correctCount;
  final int wrongCount;
  final int totalQuestions;
  final int elapsedMs;
  final int bestStreak;
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
