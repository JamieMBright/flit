/// Season identity + end-of-season trophy case (groundwork).
///
/// Seasons are calendar quarters. At season end a [Trophy] snapshot of the
/// player's tier/rating/best score per rated mode is appended to the trophy
/// case, which persists in `account_state.license_data` JSONB (client-owned)
/// under the `trophy_case` key.
///
/// Owned items NEVER decay across seasons. Rating placement/soft-reset at
/// season rollover is ladder-only and intentionally deferred:
/// TODO(seasons): server-side season rollover job for rating placement.
class Season {
  Season._();

  /// Quarterly season id for [date] (UTC), e.g. `2026-Q3`.
  static String idFor(DateTime date) {
    final utc = date.toUtc();
    final quarter = ((utc.month - 1) ~/ 3) + 1;
    return '${utc.year}-Q$quarter';
  }

  /// The current season id.
  static String current() => idFor(DateTime.now());

  /// First instant (UTC, inclusive) of the season containing [date].
  static DateTime startOf(DateTime date) {
    final utc = date.toUtc();
    final quarter = (utc.month - 1) ~/ 3;
    return DateTime.utc(utc.year, quarter * 3 + 1, 1);
  }

  /// First instant (UTC) of the NEXT season — i.e. exclusive end of this one.
  static DateTime endOf(DateTime date) {
    final start = startOf(date);
    return start.month == 10
        ? DateTime.utc(start.year + 1, 1, 1)
        : DateTime.utc(start.year, start.month + 3, 1);
  }
}

/// One end-of-season achievement snapshot.
class Trophy {
  const Trophy({
    required this.seasonId,
    required this.gameMode,
    required this.tierName,
    required this.rating,
    this.bestScore = 0,
  });

  /// Season the trophy was earned in (e.g. `2026-Q3`).
  final String seasonId;

  /// Rated mode (`sortie`, `flight`, ...).
  final String gameMode;

  /// Display tier at season end (e.g. `Gold Wings`).
  final String tierName;

  /// Rating at season end.
  final int rating;

  /// Best single-run score achieved during the season.
  final int bestScore;

  Map<String, dynamic> toJson() => {
        'season_id': seasonId,
        'game_mode': gameMode,
        'tier': tierName,
        'rating': rating,
        'best_score': bestScore,
      };

  factory Trophy.fromJson(Map<String, dynamic> json) => Trophy(
        seasonId: json['season_id'] as String? ?? '',
        gameMode: json['game_mode'] as String? ?? '',
        tierName: json['tier'] as String? ?? '',
        // jsonb numeric columns can round-trip as a double (e.g. `1500.0`)
        // rather than an int, which would throw with a plain `as int?` cast.
        rating: (json['rating'] as num?)?.toInt() ?? 0,
        bestScore: (json['best_score'] as num?)?.toInt() ?? 0,
      );
}

/// The player's trophy case: immutable list of season-end snapshots.
class TrophyCase {
  const TrophyCase({this.trophies = const []});

  final List<Trophy> trophies;

  /// Trophies for one season, newest season first overall.
  List<Trophy> forSeason(String seasonId) =>
      trophies.where((t) => t.seasonId == seasonId).toList();

  /// Whether a trophy for ([seasonId], [gameMode]) already exists.
  bool has(String seasonId, String gameMode) =>
      trophies.any((t) => t.seasonId == seasonId && t.gameMode == gameMode);

  /// Add a trophy, replacing any existing one for the same season+mode
  /// (keeps the snapshot idempotent if recorded twice).
  TrophyCase record(Trophy trophy) => TrophyCase(
        trophies: [
          ...trophies.where(
            (t) => !(t.seasonId == trophy.seasonId &&
                t.gameMode == trophy.gameMode),
          ),
          trophy,
        ],
      );

  List<dynamic> toJson() => trophies.map((t) => t.toJson()).toList();

  factory TrophyCase.fromJson(List<dynamic>? json) {
    if (json == null) return const TrophyCase();
    return TrophyCase(
      trophies: json
          .whereType<Map>()
          .map((t) => Trophy.fromJson(Map<String, dynamic>.from(t)))
          .toList(),
    );
  }
}
