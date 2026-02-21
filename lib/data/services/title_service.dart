import '../models/social_title.dart';
import '../providers/account_provider.dart';

/// Progress snapshot for a single [SocialTitle].
///
/// [progress] is a value between 0.0 (not started) and 1.0 (unlocked).
/// When [isUnlocked] is true, [progress] is exactly 1.0.
class TitleProgress {
  const TitleProgress({
    required this.title,
    required this.currentValue,
    required this.isUnlocked,
  });

  /// The title this snapshot describes.
  final SocialTitle title;

  /// The player's current stat value for this title's category.
  ///
  /// For count-based categories this is the raw count. For speed titles it is
  /// the player's best time in seconds (lower is better). For streak titles it
  /// is the best streak count.
  final int currentValue;

  /// Whether the player has met the unlock threshold.
  final bool isUnlocked;

  /// Progress toward unlocking this title, clamped to [0.0, 1.0].
  ///
  /// For speed titles the direction is inverted: a lower time is better, so
  /// progress increases as the time approaches the threshold from above.
  double get progressFraction {
    if (isUnlocked) return 1.0;
    if (title.category == TitleCategory.speed) {
      // Speed: currentValue starts high (slow) and must go below threshold.
      // A value of 0 means no time recorded — treat as 0 progress.
      if (currentValue <= 0) return 0.0;
      // Map [2 * threshold .. threshold] to [0 .. 1].
      // Players start far above threshold; fraction climbs as they get faster.
      final ceiling = title.threshold * 2.0;
      final fraction = (ceiling - currentValue) / ceiling;
      return fraction.clamp(0.0, 1.0);
    }
    // Count-based (flag, capital, outline, borders, stats, general, streak).
    return (currentValue / title.threshold).clamp(0.0, 1.0);
  }
}

/// Service that checks player stats against the [SocialTitleCatalog] and
/// returns unlock status and progress information.
///
/// This is a pure, stateless service — it takes an [AccountState] and returns
/// derived data. No async calls, no side effects.
abstract class TitleService {
  TitleService._();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns every [SocialTitle] the player has earned.
  ///
  /// Derived from the player's clue progress stored in [AccountState].
  static List<SocialTitle> getUnlockedTitles(AccountState state) {
    final progress = _progressFrom(state);
    return const PlayerTitles().earnedTitles(progress);
  }

  /// Returns [TitleProgress] for every title in the catalog, ordered by
  /// category and then by ascending threshold within each category.
  ///
  /// Use this to render progress bars for locked titles and checkmarks for
  /// unlocked ones.
  static List<TitleProgress> getTitleProgress(AccountState state) {
    final progress = _progressFrom(state);
    return SocialTitleCatalog.all.map((title) {
      final isUnlocked = _isUnlocked(title, progress);
      final currentValue = _currentValueFor(title, progress);
      return TitleProgress(
        title: title,
        currentValue: currentValue,
        isUnlocked: isUnlocked,
      );
    }).toList();
  }

  /// Returns the currently equipped [SocialTitle], or `null` if none is set
  /// or the equipped title has not been earned.
  ///
  /// Validates that the equipped title is in the player's earned set — a
  /// title that was previously earned but whose requirements changed (future
  /// edge-case) won't be shown.
  static SocialTitle? getEquippedTitle(AccountState state) {
    final id = state.equippedTitleId;
    if (id == null) return null;
    final title = SocialTitleCatalog.getById(id);
    if (title == null) return null;
    // Ensure the player has actually earned it.
    final earned = getUnlockedTitles(state);
    if (!earned.any((t) => t.id == id)) return null;
    return title;
  }

  /// Returns the next [TitleProgress] entries the player is closest to
  /// earning, limited to [limit] results.
  ///
  /// Useful for "coming up next" UI sections. Locked titles are sorted by
  /// progress fraction descending so the most achievable ones appear first.
  static List<TitleProgress> getNextTitles(
    AccountState state, {
    int limit = 3,
  }) {
    final all = getTitleProgress(state);
    final locked = all.where((tp) => !tp.isUnlocked).toList()
      ..sort((a, b) => b.progressFraction.compareTo(a.progressFraction));
    return locked.take(limit).toList();
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Build a [PlayerClueProgress] from the current [AccountState].
  ///
  /// The [AccountState] doesn't directly store per-clue-type breakdowns —
  /// those live in the [Player] model where they are tracked via gameplay
  /// events. Fields not tracked per-category (flags, capitals, etc.) fall
  /// back to partial proxies based on [countriesFound] until the per-type
  /// stats are wired up from gameplay.
  ///
  /// Current mapping:
  /// - flagsCorrect      ← player.flagsCorrect (tracked per-session)
  /// - capitalsCorrect   ← player.capitalsCorrect
  /// - outlinesCorrect   ← player.outlinesCorrect
  /// - bordersCorrect    ← player.bordersCorrect
  /// - statsCorrect      ← player.statsCorrect
  /// - totalGamesPlayed  ← player.gamesPlayed
  /// - bestTimeSeconds   ← player.bestTime?.inSeconds
  /// - bestStreak        ← player.bestStreak
  static PlayerClueProgress _progressFrom(AccountState state) {
    final p = state.currentPlayer;
    return PlayerClueProgress(
      flagsCorrect: p.flagsCorrect,
      capitalsCorrect: p.capitalsCorrect,
      outlinesCorrect: p.outlinesCorrect,
      bordersCorrect: p.bordersCorrect,
      statsCorrect: p.statsCorrect,
      totalGamesPlayed: p.gamesPlayed,
      bestTimeSeconds: p.bestTime?.inSeconds ?? 0,
      bestStreak: p.bestStreak,
    );
  }

  /// Whether [title] has been earned given [progress].
  static bool _isUnlocked(SocialTitle title, PlayerClueProgress progress) {
    switch (title.category) {
      case TitleCategory.flag:
        return progress.flagsCorrect >= title.threshold;
      case TitleCategory.capital:
        return progress.capitalsCorrect >= title.threshold;
      case TitleCategory.outline:
        return progress.outlinesCorrect >= title.threshold;
      case TitleCategory.borders:
        return progress.bordersCorrect >= title.threshold;
      case TitleCategory.stats:
        return progress.statsCorrect >= title.threshold;
      case TitleCategory.general:
        return progress.totalGamesPlayed >= title.threshold;
      case TitleCategory.speed:
        return progress.bestTimeSeconds > 0 &&
            progress.bestTimeSeconds < title.threshold;
      case TitleCategory.streak:
        return progress.bestStreak >= title.threshold;
    }
  }

  /// Returns the player's current stat value for [title]'s category.
  static int _currentValueFor(SocialTitle title, PlayerClueProgress progress) {
    switch (title.category) {
      case TitleCategory.flag:
        return progress.flagsCorrect;
      case TitleCategory.capital:
        return progress.capitalsCorrect;
      case TitleCategory.outline:
        return progress.outlinesCorrect;
      case TitleCategory.borders:
        return progress.bordersCorrect;
      case TitleCategory.stats:
        return progress.statsCorrect;
      case TitleCategory.general:
        return progress.totalGamesPlayed;
      case TitleCategory.speed:
        return progress.bestTimeSeconds;
      case TitleCategory.streak:
        return progress.bestStreak;
    }
  }
}
