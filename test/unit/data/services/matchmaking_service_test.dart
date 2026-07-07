import 'package:flit/data/services/matchmaking_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pure-logic tests for [MatchmakingService]'s static helpers.
///
/// Only the deterministic, Supabase-free statics are exercised here —
/// [MatchmakingService.calculateEloBand] and [MatchmakingService.estimateElo].
///
// NOTE: `_stableHash` is a PRIVATE static with no pure public caller — its only
// caller is `findMatch`, which is async and requires a live Supabase client, so
// it cannot be reached from a unit test without a network seam. It is therefore
// intentionally not covered here. If a pure public wrapper is added later
// (e.g. `int roundSeedFor(String)`), add a determinism test against it.
void main() {
  group('MatchmakingService.calculateEloBand', () {
    test('base band widens for small pools at the size boundaries', () {
      // Pool < 10 -> 500. Use a mid-range elo so the extreme-elo bonus is off.
      expect(MatchmakingService.calculateEloBand(elo: 1000, poolSize: 9), 500);
      // Pool 10..49 -> 300.
      expect(MatchmakingService.calculateEloBand(elo: 1000, poolSize: 10), 300);
      expect(MatchmakingService.calculateEloBand(elo: 1000, poolSize: 49), 300);
      // Pool 50+ -> 200.
      expect(MatchmakingService.calculateEloBand(elo: 1000, poolSize: 50), 200);
      // Far above the top tier stays 200 (still not extreme elo).
      expect(
        MatchmakingService.calculateEloBand(elo: 1000, poolSize: 5000),
        200,
      );
    });

    test('extreme elo adds +100 exactly at the 800 / 1600 boundaries', () {
      // Large pool -> base 200, so we isolate the +100 extreme-elo bonus.
      // elo < 800 triggers the bonus; elo == 800 does NOT.
      expect(MatchmakingService.calculateEloBand(elo: 799, poolSize: 50), 300);
      expect(MatchmakingService.calculateEloBand(elo: 800, poolSize: 50), 200);
      // elo > 1600 triggers the bonus; elo == 1600 does NOT.
      expect(MatchmakingService.calculateEloBand(elo: 1600, poolSize: 50), 200);
      expect(MatchmakingService.calculateEloBand(elo: 1601, poolSize: 50), 300);
    });

    test('extreme-elo bonus stacks on top of the small-pool base band', () {
      // Pool < 10 -> base 500, plus extreme-elo +100 -> 600.
      expect(MatchmakingService.calculateEloBand(elo: 200, poolSize: 5), 600);
      expect(MatchmakingService.calculateEloBand(elo: 2000, poolSize: 5), 600);
    });
  });

  group('MatchmakingService.estimateElo', () {
    test('base rating with level 1 and no score', () {
      // 1000 + 1*50 + 0 = 1050.
      expect(MatchmakingService.estimateElo(level: 1), 1050);
    });

    test('level and best score both contribute', () {
      // 1000 + 10*50 + (399 ~/ 20 = 19) = 1519.
      expect(
        MatchmakingService.estimateElo(level: 10, bestScore: 399),
        1519,
      );
    });

    test('best score uses integer floor division by 20', () {
      // 19 // 20 == 0 -> no contribution below the first full step.
      expect(MatchmakingService.estimateElo(level: 1, bestScore: 19), 1050);
      // 20 // 20 == 1 -> exactly one point.
      expect(MatchmakingService.estimateElo(level: 1, bestScore: 20), 1051);
      // 39 // 20 == 1 -> floors, no rounding up.
      expect(MatchmakingService.estimateElo(level: 1, bestScore: 39), 1051);
      // 40 // 20 == 2.
      expect(MatchmakingService.estimateElo(level: 1, bestScore: 40), 1052);
    });
  });
}
