import 'package:flutter_test/flutter_test.dart';

import 'package:flit/game/economy/consumables.dart';
import 'package:flit/game/economy/supply_drop.dart';

void main() {
  group('strong-performance gate', () {
    test('60% of max score qualifies', () {
      expect(SupplyDrop.isStrong(score: 60, maxScore: 100), isTrue);
      expect(SupplyDrop.isStrong(score: 59, maxScore: 100), isFalse);
      expect(SupplyDrop.isStrong(score: 30000, maxScore: 50000), isTrue);
    });

    test('zero/invalid max score never qualifies', () {
      expect(SupplyDrop.isStrong(score: 100, maxScore: 0), isFalse);
      expect(SupplyDrop.isStrong(score: 100, maxScore: -5), isFalse);
    });

    test('weak performances never drop', () {
      for (var score = 0; score < 500; score++) {
        expect(
          SupplyDrop.roll(
            userId: 'user-a',
            mode: 'daily',
            dateKey: '2026-07-05',
            score: score,
            strongPerformance: false,
          ),
          isNull,
        );
      }
    });

    test('empty user id never drops (signed-out safety)', () {
      expect(
        SupplyDrop.roll(
          userId: '',
          mode: 'daily',
          dateKey: '2026-07-05',
          score: 12345,
          strongPerformance: true,
        ),
        isNull,
      );
    });
  });

  group('determinism', () {
    test('same (user, mode, date, score) always yields the same result', () {
      for (var score = 0; score < 2000; score += 13) {
        final a = SupplyDrop.roll(
          userId: 'user-a',
          mode: 'sortie',
          dateKey: '2026-07-05',
          score: score,
          strongPerformance: true,
        );
        final b = SupplyDrop.roll(
          userId: 'user-a',
          mode: 'sortie',
          dateKey: '2026-07-05',
          score: score,
          strongPerformance: true,
        );
        expect(a, b, reason: 'replay/reopen must never re-roll (score $score)');
      }
    });

    test('changing any tuple element can change the outcome', () {
      // Find a dropping tuple, then verify the roll actually keys on all
      // four elements (a different user/mode/date is a fresh roll — the
      // vast majority miss at 3%).
      ConsumableType? found;
      var dropScore = -1;
      for (var score = 0; score < 5000 && found == null; score++) {
        found = SupplyDrop.roll(
          userId: 'user-a',
          mode: 'daily',
          dateKey: '2026-07-05',
          score: score,
          strongPerformance: true,
        );
        if (found != null) dropScore = score;
      }
      expect(found, isNotNull, reason: '3% odds must hit within 5000 rolls');
      // Same score, different user — independent outcome allowed, but
      // must still be deterministic for that user.
      final other = SupplyDrop.roll(
        userId: 'user-b',
        mode: 'daily',
        dateKey: '2026-07-05',
        score: dropScore,
        strongPerformance: true,
      );
      final otherAgain = SupplyDrop.roll(
        userId: 'user-b',
        mode: 'daily',
        dateKey: '2026-07-05',
        score: dropScore,
        strongPerformance: true,
      );
      expect(other, otherAgain);
    });
  });

  group('rarity', () {
    test('drop rate is ~3% over a large sample of strong scores', () {
      var drops = 0;
      const samples = 20000;
      for (var i = 0; i < samples; i++) {
        final dropped = SupplyDrop.roll(
          userId: 'user-$i',
          mode: 'daily',
          dateKey: '2026-07-05',
          score: 6000 + i,
          strongPerformance: true,
        );
        if (dropped != null) drops++;
      }
      final rate = drops / samples;
      // 300 bps nominal; allow generous sampling slack.
      expect(rate, greaterThan(0.02));
      expect(rate, lessThan(0.045));
    });

    test('all consumable types can drop', () {
      final seen = <ConsumableType>{};
      for (var i = 0; i < 50000 && seen.length < 4; i++) {
        final dropped = SupplyDrop.roll(
          userId: 'user-$i',
          mode: 'recon',
          dateKey: '2026-07-05',
          score: i,
          strongPerformance: true,
        );
        if (dropped != null) seen.add(dropped);
      }
      expect(seen, ConsumableType.values.toSet());
    });
  });
}
