/// Tracks the player's daily challenge streak and recovery state.
class DailyStreak {
  const DailyStreak({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastCompletionDate,
    this.totalCompleted = 0,
  });

  /// Current consecutive days of daily challenge completion.
  final int currentStreak;

  /// All-time longest streak.
  final int longestStreak;

  /// YYYY-MM-DD of the last daily challenge completion (UTC).
  final String? lastCompletionDate;

  /// Lifetime count of daily challenges completed.
  final int totalCompleted;

  /// Cost to recover a broken streak (50 coins per day missed).
  static const int recoveryCostPerDay = 50;

  /// Maximum number of missed days that can be recovered.
  static const int maxRecoveryDays = 3;

  /// Whether the player completed today's daily.
  bool get completedToday {
    if (lastCompletionDate == null) return false;
    return lastCompletionDate == _todayStr();
  }

  /// Whether the streak is still alive (completed today or yesterday).
  bool get isStreakActive {
    if (lastCompletionDate == null) return false;
    if (completedToday) return true;
    return lastCompletionDate == _yesterdayStr();
  }

  /// Whether the streak is broken but can be recovered with coins.
  bool get isRecoverable {
    if (lastCompletionDate == null || currentStreak == 0) return false;
    if (isStreakActive) return false;
    final missed = daysMissed;
    return missed >= 1 && missed <= maxRecoveryDays;
  }

  /// Number of days missed since the last completion (0 = completed today).
  int get daysMissed {
    if (lastCompletionDate == null) return 0;
    final gap = _daysSinceLastCompletion();
    // gap == 0 → completed today, gap == 1 → completed yesterday (still active)
    return (gap - 1).clamp(0, gap);
  }

  /// Total coin cost to recover the streak.
  int get recoveryCost => daysMissed * recoveryCostPerDay;

  int _daysSinceLastCompletion() {
    if (lastCompletionDate == null) return 0;
    final last = DateTime.tryParse(lastCompletionDate!);
    if (last == null) return 0;
    final today = DateTime.now().toUtc();
    final todayNorm = DateTime.utc(today.year, today.month, today.day);
    final lastNorm = DateTime.utc(last.year, last.month, last.day);
    return todayNorm.difference(lastNorm).inDays;
  }

  static String _todayStr() {
    final today = DateTime.now().toUtc();
    return '${today.year}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
  }

  static String _yesterdayStr() {
    final yesterday = DateTime.now().toUtc().subtract(const Duration(days: 1));
    return '${yesterday.year}-'
        '${yesterday.month.toString().padLeft(2, '0')}-'
        '${yesterday.day.toString().padLeft(2, '0')}';
  }

  DailyStreak copyWith({
    int? currentStreak,
    int? longestStreak,
    String? lastCompletionDate,
    int? totalCompleted,
  }) => DailyStreak(
    currentStreak: currentStreak ?? this.currentStreak,
    longestStreak: longestStreak ?? this.longestStreak,
    lastCompletionDate: lastCompletionDate ?? this.lastCompletionDate,
    totalCompleted: totalCompleted ?? this.totalCompleted,
  );

  Map<String, dynamic> toJson() => {
    'current_streak': currentStreak,
    'longest_streak': longestStreak,
    'last_completion_date': lastCompletionDate,
    'total_completed': totalCompleted,
  };

  factory DailyStreak.fromJson(Map<String, dynamic> json) => DailyStreak(
    currentStreak: json['current_streak'] as int? ?? 0,
    longestStreak: json['longest_streak'] as int? ?? 0,
    lastCompletionDate: json['last_completion_date'] as String?,
    totalCompleted: json['total_completed'] as int? ?? 0,
  );
}
