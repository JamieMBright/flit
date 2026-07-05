import 'package:flit/data/services/combined_daily_scoring.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

CombinedScoreRow _row(String userId, String region, int score) =>
    CombinedScoreRow(userId: userId, region: region, score: score);

CombinedDailyScore _find(List<CombinedDailyScore> results, String userId) =>
    results.firstWhere((r) => r.userId == userId);

void main() {
  group('computeCombinedDailyScores', () {
    test('returns empty list for empty input', () {
      expect(computeCombinedDailyScores(const []), isEmpty);
    });

    test('top scorer in a mode gets 100% efficiency for that mode', () {
      final results = computeCombinedDailyScores([
        _row('alice', 'daily', 5000),
        _row('bob', 'daily', 2500),
      ]);

      expect(_find(results, 'alice').modeEfficiencyBps['daily'], 10000);
      expect(_find(results, 'bob').modeEfficiencyBps['daily'], 5000);
    });

    test('unplayed modes have no breakdown entry and count as 0%', () {
      final results = computeCombinedDailyScores([
        _row('alice', 'daily', 1000),
      ]);

      final alice = _find(results, 'alice');
      expect(alice.modeEfficiencyBps.containsKey('briefing'), isFalse);
      expect(
        alice.modeEfficiencyBps.containsKey('daily_triangulation'),
        isFalse,
      );
      // 100% in one of three modes → mean of (10000, 0, 0) = 3333.
      expect(alice.combinedBps, 3333);
    });

    test('combined score is the mean of the three mode efficiencies', () {
      final results = computeCombinedDailyScores([
        // Alice tops daily and briefing, half of top in triangulation.
        _row('alice', 'daily', 1000),
        _row('alice', 'briefing', 400),
        _row('alice', 'daily_triangulation', 300),
        _row('bob', 'daily_triangulation', 600),
      ]);

      final alice = _find(results, 'alice');
      expect(alice.modeEfficiencyBps, {
        'daily': 10000,
        'briefing': 10000,
        'daily_triangulation': 5000,
      });
      // Mean of (10000, 10000, 5000) = 8333.
      expect(alice.combinedBps, 8333);
    });

    test('only the best score per user per region counts', () {
      final results = computeCombinedDailyScores([
        _row('alice', 'daily', 3000),
        _row('alice', 'daily', 9000), // Best attempt.
        _row('alice', 'daily', 6000),
        _row('bob', 'daily', 9000),
      ]);

      // Both users hit the day-top of 9000 → both 100% in daily.
      expect(_find(results, 'alice').modeEfficiencyBps['daily'], 10000);
      expect(_find(results, 'bob').modeEfficiencyBps['daily'], 10000);
    });

    test(
        'results are ordered by combined score descending with 1-based '
        'ranks', () {
      final results = computeCombinedDailyScores([
        _row('low', 'daily', 100),
        _row('high', 'daily', 1000),
        _row('mid', 'daily', 500),
      ]);

      expect(results.map((r) => r.userId).toList(), ['high', 'mid', 'low']);
      expect(results.map((r) => r.rank).toList(), [1, 2, 3]);
    });

    test('ties keep first-seen input order (stable)', () {
      final results = computeCombinedDailyScores([
        _row('first', 'daily', 800),
        _row('second', 'daily', 800),
        _row('third', 'daily', 800),
      ]);

      expect(
        results.map((r) => r.userId).toList(),
        ['first', 'second', 'third'],
      );
      expect(results.map((r) => r.combinedBps).toSet(), {3333});
    });

    test('rows from non-daily regions are ignored', () {
      final results = computeCombinedDailyScores([
        _row('alice', 'daily', 500),
        _row('alice', 'europe', 99999), // Training flight — irrelevant.
        _row('ghost', 'uncharted_europe_countries', 12345),
      ]);

      expect(results, hasLength(1));
      expect(results.single.userId, 'alice');
      expect(results.single.modeEfficiencyBps.keys.toList(), ['daily']);
    });

    test('fractional efficiencies round to nearest basis point', () {
      final results = computeCombinedDailyScores([
        _row('top', 'daily', 3000),
        _row('third', 'daily', 1000),
      ]);

      // 1000/3000 = 33.33...% → 3333 bps; combined = 3333/3 = 1111.
      final third = _find(results, 'third');
      expect(third.modeEfficiencyBps['daily'], 3333);
      expect(third.combinedBps, 1111);
    });

    test('a zero day-top score yields 0% instead of dividing by zero', () {
      final results = computeCombinedDailyScores([
        _row('alice', 'daily', 0),
        _row('bob', 'daily', 0),
      ]);

      expect(results, hasLength(2));
      for (final r in results) {
        expect(r.modeEfficiencyBps, isEmpty);
        expect(r.combinedBps, 0);
      }
    });

    test('playing all three modes beats topping a single mode', () {
      final results = computeCombinedDailyScores([
        // Specialist: perfect daily only.
        _row('specialist', 'daily', 10000),
        // Generalist: 60% of top in every mode.
        _row('generalist', 'daily', 6000),
        _row('generalist', 'briefing', 60),
        _row('generalist', 'daily_triangulation', 600),
        // Mode toppers so the generalist isn't 100% everywhere.
        _row('bTop', 'briefing', 100),
        _row('tTop', 'daily_triangulation', 1000),
      ]);

      final specialist = _find(results, 'specialist');
      final generalist = _find(results, 'generalist');
      expect(specialist.combinedBps, 3333); // (10000+0+0)/3
      expect(generalist.combinedBps, 6000); // (6000+6000+6000)/3
      expect(generalist.rank, lessThan(specialist.rank));
    });
  });
}
