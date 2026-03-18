/// Progress data for a single uncharted region+mode combination.
class UnchartedProgress {
  const UnchartedProgress({
    this.bestScore = 0,
    this.bestTimeMs = 0,
    this.bestRevealedCount = 0,
    this.totalCount = 0,
    this.completions = 0,
    this.attempts = 0,
  });

  final int bestScore;
  final int bestTimeMs;
  final int bestRevealedCount;
  final int totalCount;
  final int completions;
  final int attempts;

  bool get hasPlayed => attempts > 0;

  String get grade {
    if (attempts == 0) return '-';
    if (totalCount == 0) return '-';
    final pct = bestRevealedCount / totalCount;
    if (pct >= 1.0) return 'S';
    if (pct >= 0.9) return 'A';
    if (pct >= 0.75) return 'B';
    if (pct >= 0.5) return 'C';
    if (pct >= 0.25) return 'D';
    return 'F';
  }

  String get bestTimeFormatted {
    if (bestTimeMs <= 0) return '--';
    final seconds = (bestTimeMs / 1000).floor();
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  double get bestPercentage =>
      totalCount > 0 ? bestRevealedCount / totalCount : 0;

  UnchartedProgress copyWith({
    int? bestScore,
    int? bestTimeMs,
    int? bestRevealedCount,
    int? totalCount,
    int? completions,
    int? attempts,
  }) =>
      UnchartedProgress(
        bestScore: bestScore ?? this.bestScore,
        bestTimeMs: bestTimeMs ?? this.bestTimeMs,
        bestRevealedCount: bestRevealedCount ?? this.bestRevealedCount,
        totalCount: totalCount ?? this.totalCount,
        completions: completions ?? this.completions,
        attempts: attempts ?? this.attempts,
      );

  Map<String, dynamic> toJson() => {
        'best_score': bestScore,
        'best_time_ms': bestTimeMs,
        'best_revealed_count': bestRevealedCount,
        'total_count': totalCount,
        'completions': completions,
        'attempts': attempts,
      };

  factory UnchartedProgress.fromJson(Map<String, dynamic> json) =>
      UnchartedProgress(
        bestScore: json['best_score'] as int? ?? 0,
        bestTimeMs: json['best_time_ms'] as int? ?? 0,
        bestRevealedCount: json['best_revealed_count'] as int? ?? 0,
        totalCount: json['total_count'] as int? ?? 0,
        completions: json['completions'] as int? ?? 0,
        attempts: json['attempts'] as int? ?? 0,
      );
}
