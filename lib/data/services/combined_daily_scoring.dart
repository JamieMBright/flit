/// Pure scoring logic for the combined daily leaderboard.
///
/// The three daily challenges (Scramble, Briefing, Triangulation) use very
/// different scoring scales, so raw scores cannot be summed. Instead each
/// mode is normalised to an *efficiency*: the user's best score that day
/// divided by the day's top score in that mode (top scorer = 100%). The
/// combined score is the mean of the three efficiencies, with unplayed modes
/// counting as 0%.
///
/// All percentages are stored as integer basis points (1% = 100 bps, so
/// 10000 bps = 100%) to keep the maths deterministic and comparisons exact.
library;

/// The `scores.region` values that make up the combined daily leaderboard,
/// in display order: Scramble, Briefing, Triangulation.
const List<String> kCombinedDailyRegions = [
  'daily',
  'briefing',
  'daily_triangulation',
];

/// A minimal score row used as input to [computeCombinedDailyScores].
class CombinedScoreRow {
  const CombinedScoreRow({
    required this.userId,
    required this.region,
    required this.score,
  });

  final String userId;
  final String region;
  final int score;
}

/// One user's combined daily result.
class CombinedDailyScore {
  const CombinedDailyScore({
    required this.rank,
    required this.userId,
    required this.combinedBps,
    required this.modeEfficiencyBps,
  });

  /// 1-based rank ordered by [combinedBps] descending.
  final int rank;

  final String userId;

  /// Combined efficiency in basis points (0–10000), e.g. 8740 = 87.40%.
  final int combinedBps;

  /// Per-region efficiency in basis points, keyed by `scores.region`.
  /// A missing key means the user did not play that mode (0%).
  final Map<String, int> modeEfficiencyBps;
}

/// Compute the ranked combined daily leaderboard from raw score rows.
///
/// For each region in [regions], a user's efficiency is their best score in
/// that region divided by the day's top score in that region, as basis
/// points. The combined score is the mean of the per-region efficiencies
/// (unplayed regions contribute 0). Rows whose region is not in [regions]
/// are ignored.
///
/// Results are ordered by combined score descending; ties keep the order in
/// which users first appear in [rows] (stable).
List<CombinedDailyScore> computeCombinedDailyScores(
  Iterable<CombinedScoreRow> rows, {
  List<String> regions = kCombinedDailyRegions,
}) {
  // Best score per user per region, remembering first-seen order for
  // deterministic tie-breaking.
  final bestByUser = <String, Map<String, int>>{};
  final firstSeen = <String, int>{};
  var seen = 0;
  for (final row in rows) {
    if (!regions.contains(row.region)) continue;
    firstSeen.putIfAbsent(row.userId, () => seen++);
    final byRegion = bestByUser.putIfAbsent(row.userId, () => {});
    final prev = byRegion[row.region];
    if (prev == null || row.score > prev) {
      byRegion[row.region] = row.score;
    }
  }

  // The day's top score per region.
  final topByRegion = <String, int>{};
  for (final byRegion in bestByUser.values) {
    for (final entry in byRegion.entries) {
      final top = topByRegion[entry.key];
      if (top == null || entry.value > top) {
        topByRegion[entry.key] = entry.value;
      }
    }
  }

  final results = <CombinedDailyScore>[];
  for (final entry in bestByUser.entries) {
    final effBps = <String, int>{};
    var totalBps = 0;
    for (final region in regions) {
      final best = entry.value[region];
      final top = topByRegion[region] ?? 0;
      // Unplayed mode = 0%. A non-positive day-top would make the ratio
      // meaningless, so it also counts as 0%.
      if (best == null || top <= 0) continue;
      final bps = ((best / top) * 10000).round().clamp(0, 10000);
      effBps[region] = bps;
      totalBps += bps;
    }
    results.add(
      CombinedDailyScore(
        rank: 0, // Assigned after sorting.
        userId: entry.key,
        combinedBps: (totalBps / regions.length).round(),
        modeEfficiencyBps: effBps,
      ),
    );
  }

  // Sort by combined score descending; break ties by first-seen order so
  // the result is stable and deterministic.
  results.sort((a, b) {
    final c = b.combinedBps.compareTo(a.combinedBps);
    return c != 0 ? c : firstSeen[a.userId]!.compareTo(firstSeen[b.userId]!);
  });

  return [
    for (var i = 0; i < results.length; i++)
      CombinedDailyScore(
        rank: i + 1,
        userId: results[i].userId,
        combinedBps: results[i].combinedBps,
        modeEfficiencyBps: results[i].modeEfficiencyBps,
      ),
  ];
}
