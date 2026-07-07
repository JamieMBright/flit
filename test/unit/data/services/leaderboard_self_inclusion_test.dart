import 'package:flit/data/services/combined_daily_scoring.dart';
import 'package:flit/data/services/leaderboard_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests the pure ranking + self-pick core extracted from
/// [LeaderboardService.fetchOwnCombinedDailyScore]. The point of the extraction
/// is that the signed-in user's own combined entry is always resolvable — with
/// its *true* rank across the whole field — even when they rank outside the
/// top slice the board UI shows.
void main() {
  group('LeaderboardService.selfCombinedDailyScore', () {
    // Build a field where each user played only the 'daily' region with a
    // distinct score, so combined rank == score order.
    List<CombinedScoreRow> dailyField(Map<String, int> scoresByUser) => [
          for (final e in scoresByUser.entries)
            CombinedScoreRow(userId: e.key, region: 'daily', score: e.value),
        ];

    test(
        'a user ranked outside a small limit is still returned with '
        'its true rank', () {
      // 12 players; "me" has the lowest daily score => rank 12.
      final scores = <String, int>{
        for (var i = 0; i < 11; i++) 'u$i': 1000 - i * 10,
      };
      scores['me'] = 1; // dead last

      final result = LeaderboardService.selfCombinedDailyScore(
        dailyField(scores),
        'me',
      );

      expect(result, isNotNull);
      expect(result!.self.userId, 'me');
      expect(result.self.rank, 12,
          reason: 'true rank across the full field, not a clipped top-N');
      expect(result.totalPlayers, 12);
    });

    test('totalPlayers is the full distinct-user count', () {
      final result = LeaderboardService.selfCombinedDailyScore(
        dailyField({'a': 500, 'b': 400, 'me': 300}),
        'me',
      );
      expect(result, isNotNull);
      expect(result!.totalPlayers, 3);
    });

    test('a user with rows in multiple regions is counted once', () {
      final rows = <CombinedScoreRow>[
        // "me" appears in all three regions.
        const CombinedScoreRow(userId: 'me', region: 'daily', score: 100),
        const CombinedScoreRow(userId: 'me', region: 'briefing', score: 100),
        const CombinedScoreRow(
            userId: 'me', region: 'daily_triangulation', score: 100),
        // Two other single-region players.
        const CombinedScoreRow(userId: 'a', region: 'daily', score: 200),
        const CombinedScoreRow(userId: 'b', region: 'briefing', score: 200),
      ];

      final result = LeaderboardService.selfCombinedDailyScore(rows, 'me');

      expect(result, isNotNull);
      // 3 distinct users (me, a, b), not 5 rows.
      expect(result!.totalPlayers, 3);
      // "me" played all three modes.
      expect(result.self.modeEfficiencyBps.keys,
          containsAll(kCombinedDailyRegions));
    });

    test('returns null when the user has no rows that day', () {
      final result = LeaderboardService.selfCombinedDailyScore(
        dailyField({'a': 500, 'b': 400}),
        'ghost',
      );
      expect(result, isNull);
    });

    test('returns null for an empty field', () {
      final result = LeaderboardService.selfCombinedDailyScore(
        const <CombinedScoreRow>[],
        'me',
      );
      expect(result, isNull);
    });
  });
}
