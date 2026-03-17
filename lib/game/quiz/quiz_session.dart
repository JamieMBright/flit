import 'dart:math';

import 'quiz_category.dart';
import 'quiz_difficulty.dart';
import '../data/canada_clues.dart';
import '../data/ireland_clues.dart';
import '../data/uk_clues.dart';
import '../data/us_state_clues.dart';
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

/// Progressive hint levels used in the hint system.
///
/// Each level provides increasingly helpful clues:
/// 1. Show additional clue (capital, nickname, landmark, etc.)
/// 2. Show another clue (flag, sports team, celebrity, etc.)
/// 3. Reveal the answer name (e.g. "Answer: France")
/// 4. Eliminate 50% of wrong answers
/// 5. Eliminate 75% of wrong answers
/// 6. Highlight the exact correct answer
/// 7+. Start removing countries one by one until they get it
enum HintLevel {
  /// Level 1: Show bordering countries/regions as extra clue text.
  showBorders,

  /// Level 2: Show flag or additional identifying info.
  showFlag,

  /// Level 3: Reveal the answer name.
  revealName,

  /// Level 4: Eliminate 50% of wrong answers.
  eliminate50,

  /// Level 5: Eliminate 75% of wrong answers.
  eliminate75,

  /// Level 6: Highlight the exact correct answer.
  highlightAnswer,

  /// Level 7+: Remove countries one at a time.
  removeCountries,
}

/// Manages the state of a single quiz round.
class QuizSession {
  QuizSession({
    required this.mode,
    required this.categories,
    required this.region,
    this.difficulty = QuizDifficulty.medium,
    int? seed,
  })  : _generator = QuizQuestionGenerator(region: region, seed: seed),
        _random = Random(seed),
        _results = [],
        _answeredCodes = {},
        _correctCodes = {},
        _eliminatedCodes = {},
        _startTime = null,
        _currentIndex = 0,
        _streak = 0,
        _totalScore = 0,
        _wrongCount = 0,
        _hintsUsed = 0,
        _currentHintLevel = 0,
        _isFinished = false,
        _extraClueTexts = [];

  final QuizMode mode;
  final Set<QuizCategory> categories;
  final GameRegion region;
  final QuizDifficulty difficulty;
  final QuizQuestionGenerator _generator;
  final Random _random;

  late final List<QuizQuestion> _questions;
  final List<QuizAnswerResult> _results;
  final Set<String> _answeredCodes;
  final Set<String> _correctCodes;
  final Set<String> _eliminatedCodes;

  DateTime? _startTime;
  int _currentIndex;
  int _streak;
  int _totalScore;
  int _wrongCount;
  int _hintsUsed;
  int _currentHintLevel;
  bool _isFinished;
  List<String> _extraClueTexts;

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
  Set<String> get correctCodes => Set.unmodifiable(_correctCodes);
  Set<String> get eliminatedCodes => Set.unmodifiable(_eliminatedCodes);
  List<QuizAnswerResult> get results => List.unmodifiable(_results);
  bool get showLabels => difficulty.showLabels;

  /// Current hint level for the current question (0 = no hint, 1+ = progressive).
  int get currentHintLevel => _currentHintLevel;

  /// Extra clue texts generated by hints (e.g., "Borders: France, Germany").
  List<String> get extraClueTexts => List.unmodifiable(_extraClueTexts);

  /// Whether a hint can be used on the current question.
  /// Hints are now unlimited — the user can always ask for more help,
  /// but each hint reduces score further.
  bool get canUseHint => currentQuestion != null && !_isFinished;

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
    // When in mixed mode, pass the difficulty-filtered pool so easy mode
    // excludes hard categories (sportsTeam, celebrity, filmSetting, etc.).
    final allowedPool = categories.contains(QuizCategory.mixed)
        ? difficulty.filterCategories(
            regionCategories[region] ?? universalCategories,
          )
        : null;
    _questions = _generator.generateQuestions(
      categories,
      allowedPool: allowedPool,
    );
    _startTime = DateTime.now();
  }

  /// Use a hint on the current question. Returns the hint level (1+).
  ///
  /// Progressive hint system:
  /// 1. Factual clue (capital, nickname, landmark)
  /// 2. Second factual clue (flag, sports team, celebrity)
  /// 3. Reveal the answer name (e.g. "Answer: France")
  /// 4. Eliminate 50% of wrong answers
  /// 5. Eliminate 75% of wrong answers
  /// 6. Highlight the exact correct answer
  /// 7+. Remove countries one at a time until they guess correctly
  ///
  /// Each hint reduces the score multiplier for this question.
  int? useHint() {
    if (!canUseHint || currentQuestion == null) return null;
    _hintsUsed++;
    _currentHintLevel++;

    final question = currentQuestion!;
    final areas = RegionalData.getAreas(region);

    switch (_currentHintLevel) {
      case 1:
        // First factual clue: capital, nickname, or landmark
        final clue = _getFactualHint(question.answerCode, areas, tier: 1);
        _extraClueTexts
            .add(clue ?? _getLocationHint(question.answerCode, areas));
        break;

      case 2:
        // Second factual clue: flag, sports team, celebrity, etc.
        final clue = _getFactualHint(question.answerCode, areas, tier: 2);
        _extraClueTexts
            .add(clue ?? _getStartsWithHint(question.answerCode, areas));
        break;

      case 3:
        // Reveal the answer name — tell the player what to look for
        final area =
            areas.where((a) => a.code == question.answerCode).firstOrNull;
        if (area != null) {
          _extraClueTexts.add('Answer: ${area.name}');
        }
        break;

      case 4:
        // Eliminate 50% of wrong answers
        _eliminateWrongAnswers(0.50, question.answerCode, areas);
        break;

      case 5:
        // Eliminate 75% of wrong answers
        _eliminateWrongAnswers(0.75, question.answerCode, areas);
        break;

      case 6:
        // Highlight the exact correct answer (handled in UI via highlightCode)
        break;

      default:
        // Level 7+: Remove one more country each time
        _removeOneWrongCountry(question.answerCode, areas);
        break;
    }

    return _currentHintLevel;
  }

  /// Get a factual hint for the given area code.
  ///
  /// Tier 1: capital, nickname, landmark (easier clues)
  /// Tier 2: flag, sports team, celebrity (deeper knowledge)
  ///
  /// Avoids duplicating clues already shown in the question itself.
  String? _getFactualHint(
    String code,
    List<RegionalArea> areas, {
    required int tier,
  }) {
    final question = currentQuestion;
    if (question == null) return null;
    final category = question.category;

    // Build a pool of candidate hints, excluding the current question's type.
    final hints = <String>[];

    // ── US States ──────────────────────────────────────────────────────
    if (region == GameRegion.usStates) {
      final data = UsStateClues.data[code];
      if (data != null) {
        if (tier == 1) {
          if (category != QuizCategory.nickname && data.nickname.isNotEmpty) {
            hints.add('Nickname: ${data.nickname}');
          }
          if (category != QuizCategory.landmark &&
              data.famousLandmark.isNotEmpty) {
            hints.add('Landmark: ${data.famousLandmark}');
          }
          if (category != QuizCategory.motto && data.motto.isNotEmpty) {
            hints.add('Motto: "${data.motto}"');
          }
          if (category != QuizCategory.stateBird && data.stateBird.isNotEmpty) {
            hints.add('State Bird: ${data.stateBird}');
          }
        } else {
          if (category != QuizCategory.flagDescription &&
              data.flag.isNotEmpty) {
            hints.add('Flag: ${data.flag}');
          }
          if (category != QuizCategory.sportsTeam &&
              data.sportsTeams.isNotEmpty) {
            final team =
                data.sportsTeams[_random.nextInt(data.sportsTeams.length)];
            hints.add('Team: $team');
          }
          if (category != QuizCategory.celebrity &&
              data.celebrities.isNotEmpty) {
            final celeb =
                data.celebrities[_random.nextInt(data.celebrities.length)];
            hints.add('Celebrity: $celeb');
          }
          if (category != QuizCategory.stateFlower &&
              data.stateFlower.isNotEmpty) {
            hints.add('State Flower: ${data.stateFlower}');
          }
          if (category != QuizCategory.filmSetting &&
              data.filmSettings.isNotEmpty) {
            final film =
                data.filmSettings[_random.nextInt(data.filmSettings.length)];
            hints.add('Film/Show: $film');
          }
        }
      }
    }

    // ── Ireland ────────────────────────────────────────────────────────
    if (region == GameRegion.ireland) {
      final data = IrelandClues.data[code];
      if (data != null) {
        if (tier == 1) {
          if (data.province.isNotEmpty) {
            hints.add('Province: ${data.province}');
          }
          if (data.nickname.isNotEmpty) hints.add('Nickname: ${data.nickname}');
          if (data.gaaTeam.isNotEmpty) hints.add('GAA Team: ${data.gaaTeam}');
        } else {
          if (data.gaelicName.isNotEmpty) {
            hints.add('Gaelic: ${data.gaelicName}');
          }
          if (data.famousPerson.isNotEmpty) {
            hints.add('Famous Person: ${data.famousPerson}');
          }
          if (data.famousLandmark.isNotEmpty) {
            hints.add('Landmark: ${data.famousLandmark}');
          }
        }
      }
    }

    // ── UK Counties ────────────────────────────────────────────────────
    if (region == GameRegion.ukCounties) {
      final data = UkClues.data[code];
      if (data != null) {
        if (tier == 1) {
          if (data.country.isNotEmpty) hints.add('Country: ${data.country}');
          if (data.nickname.isNotEmpty) hints.add('Nickname: ${data.nickname}');
          if (data.famousLandmark.isNotEmpty) {
            hints.add('Landmark: ${data.famousLandmark}');
          }
        } else {
          if (data.famousPerson.isNotEmpty) {
            hints.add('Famous Person: ${data.famousPerson}');
          }
          if (data.footballTeam.isNotEmpty) {
            hints.add('Football: ${data.footballTeam}');
          }
        }
      }
    }

    // ── Canada ─────────────────────────────────────────────────────────
    if (region == GameRegion.canadianProvinces) {
      final data = CanadaClues.data[code];
      if (data != null) {
        if (tier == 1) {
          if (data.nickname.isNotEmpty) hints.add('Nickname: ${data.nickname}');
          if (data.famousLandmark.isNotEmpty) {
            hints.add('Landmark: ${data.famousLandmark}');
          }
          if (data.motto.isNotEmpty) hints.add('Motto: "${data.motto}"');
        } else {
          if (data.flag.isNotEmpty) hints.add('Flag: ${data.flag}');
          if (data.sportsTeams.isNotEmpty) {
            final team =
                data.sportsTeams[_random.nextInt(data.sportsTeams.length)];
            hints.add('Team: $team');
          }
        }
      }
    }

    // ── Country-based regions (Europe, Africa, Asia, etc.) ─────────
    if (hints.isEmpty) {
      final area = areas.where((a) => a.code == code).firstOrNull;
      if (area != null) {
        if (tier == 1) {
          if (category != QuizCategory.capital &&
              area.capital != null &&
              area.capital!.isNotEmpty) {
            hints.add('Capital: ${area.capital}');
          }
          if (area.population != null) {
            hints.add('Population: ${_formatPopulation(area.population!)}');
          }
        } else {
          if (area.funFact != null && area.funFact!.isNotEmpty) {
            hints.add(area.funFact!);
          }
          // Capital as fallback for tier 2 if not used in tier 1
          if (category == QuizCategory.capital &&
              area.capital != null &&
              area.capital!.isNotEmpty) {
            // Capital was the question, skip it
          } else if (area.capital != null && area.capital!.isNotEmpty) {
            hints.add('Capital: ${area.capital}');
          }
        }
      }
    }

    if (hints.isEmpty) return null;
    return hints[_random.nextInt(hints.length)];
  }

  /// Format population number for display (e.g. 67000000 → "67M").
  static String _formatPopulation(int pop) {
    if (pop >= 1000000000) {
      return '${(pop / 1000000000).toStringAsFixed(1)}B';
    } else if (pop >= 1000000) {
      return '${(pop / 1000000).toStringAsFixed(1)}M';
    } else if (pop >= 1000) {
      return '${(pop / 1000).toStringAsFixed(0)}K';
    }
    return pop.toString();
  }

  /// Fallback hint: directional location within the region.
  String _getLocationHint(String code, List<RegionalArea> areas) {
    final area = areas.where((a) => a.code == code).firstOrNull;
    if (area == null || area.points.isEmpty) return 'Look carefully at the map';

    // Calculate centroid of the target area
    double cx = 0, cy = 0;
    for (final p in area.points) {
      cx += p.x;
      cy += p.y;
    }
    cx /= area.points.length;
    cy /= area.points.length;

    // Calculate bounds of the entire region
    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;
    for (final a in areas) {
      for (final p in a.points) {
        if (p.x < minX) minX = p.x;
        if (p.x > maxX) maxX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.y > maxY) maxY = p.y;
      }
    }

    final midLng = (minX + maxX) / 2;
    final midLat = (minY + maxY) / 2;
    final ew = cx < midLng ? 'western' : 'eastern';
    final ns = cy < midLat ? 'southern' : 'northern';
    return 'Location: $ns $ew part of the region';
  }

  /// Fallback hint: first letter of the answer name.
  String _getStartsWithHint(String code, List<RegionalArea> areas) {
    final area = areas.where((a) => a.code == code).firstOrNull;
    if (area == null || area.name.isEmpty) return 'Check the shape carefully';
    return 'Starts with: "${area.name[0]}"';
  }

  /// Eliminate a fraction of wrong answers by adding them to eliminated set.
  void _eliminateWrongAnswers(
    double fraction,
    String correctCode,
    List<RegionalArea> areas,
  ) {
    final wrongAreas = areas
        .where(
          (a) =>
              a.code != correctCode &&
              !_answeredCodes.contains(a.code) &&
              !_eliminatedCodes.contains(a.code),
        )
        .map((a) => a.code)
        .toList();
    wrongAreas.shuffle(_random);
    final toEliminate = wrongAreas.take((wrongAreas.length * fraction).round());
    _eliminatedCodes.addAll(toEliminate);
  }

  /// Remove one more wrong country from the map.
  void _removeOneWrongCountry(
    String correctCode,
    List<RegionalArea> areas,
  ) {
    final remaining = areas
        .where(
          (a) =>
              a.code != correctCode &&
              !_answeredCodes.contains(a.code) &&
              !_eliminatedCodes.contains(a.code),
        )
        .map((a) => a.code)
        .toList();
    if (remaining.isNotEmpty) {
      remaining.shuffle(_random);
      _eliminatedCodes.add(remaining.first);
    }
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
      _correctCodes.add(tappedCode);
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
      _extraClueTexts = []; // Clear extra clue texts
      _eliminatedCodes.clear(); // Restore all countries for next question

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
    _extraClueTexts = [];
    _eliminatedCodes.clear();
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

    // Hint penalty: each hint level reduces score by 15% (diminishing)
    // Level 0: 1.0, Level 1: 0.85, Level 2: 0.72, Level 3: 0.61, etc.
    final hintPenalty = _currentHintLevel == 0
        ? 1.0
        : (0.85 * _pow(0.85, _currentHintLevel - 1)).clamp(0.05, 1.0);

    final raw =
        (base + speedBonus) * streakMult * clueMult * diffMult * hintPenalty;
    return raw.round();
  }

  static double _pow(double base, int exp) {
    var result = 1.0;
    for (var i = 0; i < exp; i++) {
      result *= base;
    }
    return result;
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
        categories: categories,
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
    required this.categories,
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
  final Set<QuizCategory> categories;
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
