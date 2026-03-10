import 'package:flit/game/data/country_difficulty.dart';

/// Per-round result data for daily challenge share text.
class DailyRoundResult {
  const DailyRoundResult({
    required this.hintsUsed,
    required this.completed,
    required this.timeMs,
    required this.score,
    this.countryCode,
  });

  /// Number of hints used this round (0-4).
  final int hintsUsed;

  /// Whether the player found the target (false = fuel ran out / aborted).
  final bool completed;

  /// Time in milliseconds for this round.
  final int timeMs;

  /// Score for this round (time-based with difficulty multiplier).
  final int score;

  /// ISO country code for difficulty lookup (nullable for old data).
  final String? countryCode;

  /// Compute a time-based score from elapsed time, hints, and difficulty.
  ///
  /// Formula:
  ///   raw      = 10,000 − hintPenalties − timePenalty
  ///   hints    = escalating penalty per tier (500, 1000, 1500, 2500)
  ///   time     = 0 at ≤10s, linear to 5,000 at ≥60s
  ///   final    = raw × difficultyMultiplier (0.5–1.0)
  ///
  /// When [countryCode] is null (old data without it), the difficulty
  /// multiplier defaults to 0.75 (midpoint).
  static int computeTimeScore({
    required int timeMs,
    required int hintsUsed,
    required bool completed,
    String? countryCode,
  }) {
    if (!completed) return 0;
    const int base = 10000;
    const List<int> hintPenalties = [500, 1000, 1500, 2500];
    int hintPenalty = 0;
    for (int i = 0; i < hintsUsed && i < hintPenalties.length; i++) {
      hintPenalty += hintPenalties[i];
    }
    final seconds = timeMs / 1000.0;
    int timePenalty = 0;
    if (seconds > 10 && seconds < 60) {
      timePenalty = ((seconds - 10) / 50.0 * 5000).round();
    } else if (seconds >= 60) {
      timePenalty = 5000;
    }
    final raw = base - hintPenalty - timePenalty;
    if (raw <= 0) return 0;
    final multiplier =
        countryCode != null ? difficultyMultiplier(countryCode) : 0.75;
    return (raw * multiplier).round().clamp(0, 10000);
  }

  /// Emoji representation of this round's performance.
  String get emoji {
    if (!completed) return '\u{1F534}'; // red
    if (hintsUsed == 0) return '\u{1F7E2}'; // green
    if (hintsUsed <= 2) return '\u{1F7E1}'; // yellow
    if (hintsUsed <= 4) return '\u{1F7E0}'; // orange
    return '\u{1F534}'; // red
  }

  Map<String, dynamic> toJson() => {
        'hints_used': hintsUsed,
        'completed': completed,
        'time_ms': timeMs,
        'score': score,
        if (countryCode != null) 'country_code': countryCode,
      };

  /// Deserialize from JSON, recalculating the score using the time-based
  /// formula so that old fuel-based scores align with new time-based ones.
  factory DailyRoundResult.fromJson(Map<String, dynamic> json) {
    final hintsUsed = json['hints_used'] as int? ?? 0;
    final completed = json['completed'] as bool? ?? false;
    final timeMs = json['time_ms'] as int? ?? 0;
    final countryCode = json['country_code'] as String?;
    return DailyRoundResult(
      hintsUsed: hintsUsed,
      completed: completed,
      timeMs: timeMs,
      countryCode: countryCode,
      score: computeTimeScore(
        timeMs: timeMs,
        hintsUsed: hintsUsed,
        completed: completed,
        countryCode: countryCode,
      ),
    );
  }
}

/// Complete daily challenge result for sharing and persistence.
class DailyResult {
  const DailyResult({
    required this.date,
    required this.rounds,
    required this.totalScore,
    required this.totalTimeMs,
    required this.totalRounds,
    required this.theme,
  });

  /// Date of the daily challenge (YYYY-MM-DD).
  final String date;

  /// Per-round results (completed rounds only; unplayed rounds are inferred).
  final List<DailyRoundResult> rounds;

  /// Total score across all completed rounds.
  final int totalScore;

  /// Total time in milliseconds.
  final int totalTimeMs;

  /// Total rounds in the challenge (typically 5).
  final int totalRounds;

  /// Challenge theme title (e.g. "Flag Frenzy").
  final String theme;

  /// Generate the Wordle-style shareable text.
  ///
  /// Example output:
  /// ```
  ///      🛫 🌍 🛬
  /// Flit daily challenge!
  /// 🟢🟡🟠🟢🔴
  /// Score: 34,655 pts
  /// Time: 4m30s
  /// ```
  String toShareText() {
    final emojiRow = _buildEmojiRow();
    final scoreFormatted = formatScore(totalScore);
    final timeFormatted = formatTime(totalTimeMs);

    return '     \u{1F6EB} \u{1F30D} \u{1F6EC}\n'
        'Flit daily challenge!\n'
        '$emojiRow\n'
        'Score: $scoreFormatted pts\n'
        'Time: $timeFormatted';
  }

  String _buildEmojiRow() {
    final emojis = <String>[];
    for (var i = 0; i < totalRounds; i++) {
      if (i < rounds.length) {
        emojis.add(rounds[i].emoji);
      } else {
        emojis.add('\u{1F534}'); // red for unplayed rounds
      }
    }
    return emojis.join();
  }

  /// Format a score with comma separators (e.g. 34,655).
  static String formatScore(int score) {
    if (score >= 1000) {
      final str = score.toString();
      final result = StringBuffer();
      var count = 0;
      for (var i = str.length - 1; i >= 0; i--) {
        if (count > 0 && count % 3 == 0) result.write(',');
        result.write(str[i]);
        count++;
      }
      return result.toString().split('').reversed.join();
    }
    return score.toString();
  }

  /// Format milliseconds as a human-readable time string (e.g. 4m30s).
  static String formatTime(int totalMs) {
    final totalSeconds = totalMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m${seconds.toString().padLeft(2, '0')}s';
    }
    return '${seconds}s';
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'rounds': rounds.map((r) => r.toJson()).toList(),
        'total_score': totalScore,
        'total_time_ms': totalTimeMs,
        'total_rounds': totalRounds,
        'theme': theme,
      };

  /// Deserialize from JSON, recalculating totalScore from round data so
  /// that old fuel-based scores align with the current time-based formula.
  factory DailyResult.fromJson(Map<String, dynamic> json) {
    final rounds = (json['rounds'] as List)
        .map((r) => DailyRoundResult.fromJson(r as Map<String, dynamic>))
        .toList();
    // Recalculate total from per-round scores (which are themselves
    // recalculated in DailyRoundResult.fromJson using time-based formula).
    final recalculatedTotal = rounds.fold<int>(0, (sum, r) => sum + r.score);
    return DailyResult(
      date: json['date'] as String,
      rounds: rounds,
      totalScore: recalculatedTotal,
      totalTimeMs: json['total_time_ms'] as int,
      totalRounds: json['total_rounds'] as int? ?? 5,
      theme: json['theme'] as String? ?? '',
    );
  }
}
