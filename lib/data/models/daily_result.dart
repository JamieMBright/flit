/// Per-round result data for daily challenge share text.
class DailyRoundResult {
  const DailyRoundResult({
    required this.hintsUsed,
    required this.completed,
    required this.timeMs,
    required this.score,
  });

  /// Number of hints used this round (0-4).
  final int hintsUsed;

  /// Whether the player found the target (false = fuel ran out).
  final bool completed;

  /// Time in milliseconds for this round.
  final int timeMs;

  /// Score for this round.
  final int score;

  /// Emoji representation of this round's performance.
  String get emoji {
    if (!completed) return '\u{1F534}'; // red
    if (hintsUsed == 0) return '\u{1F7E2}'; // green
    if (hintsUsed == 1) return '\u{1F7E0}'; // orange
    if (hintsUsed <= 3) return '\u{1F7E1}'; // yellow
    return '\u{1F7E0}'; // orange
  }

  Map<String, dynamic> toJson() => {
    'hints_used': hintsUsed,
    'completed': completed,
    'time_ms': timeMs,
    'score': score,
  };

  factory DailyRoundResult.fromJson(Map<String, dynamic> json) =>
      DailyRoundResult(
        hintsUsed: json['hints_used'] as int? ?? 0,
        completed: json['completed'] as bool? ?? false,
        timeMs: json['time_ms'] as int? ?? 0,
        score: json['score'] as int? ?? 0,
      );
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

  factory DailyResult.fromJson(Map<String, dynamic> json) => DailyResult(
    date: json['date'] as String,
    rounds: (json['rounds'] as List)
        .map((r) => DailyRoundResult.fromJson(r as Map<String, dynamic>))
        .toList(),
    totalScore: json['total_score'] as int,
    totalTimeMs: json['total_time_ms'] as int,
    totalRounds: json['total_rounds'] as int? ?? 5,
    theme: json['theme'] as String? ?? '',
  );
}
