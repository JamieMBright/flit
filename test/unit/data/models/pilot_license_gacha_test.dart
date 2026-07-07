import 'dart:math';

import 'package:flit/data/models/pilot_license.dart';
import 'package:flutter_test/flutter_test.dart';

/// Distribution tests for the license stat-roll gacha.
///
/// `rollStat` and its backing `_weightTable` are exercised through the public
/// `PilotLicense.rollStat` entry point with a seeded [Random] so the assertions
/// are stable across runs and platforms.
///
// NOTE: `_weightTable` and `luckBonus`'s internal loop are private; they are
// covered indirectly here via the observable distribution of `rollStat`.
void main() {
  // Bucket a roll (1-25) into the five rarity tiers used by the weight table.
  int bucketOf(int roll) {
    if (roll <= 5) return 0; // common
    if (roll <= 10) return 1; // uncommon
    if (roll <= 15) return 2; // rare
    if (roll <= 19) return 3; // epic
    return 4; // legendary (20-25)
  }

  group('PilotLicense.rollStat distribution', () {
    test('all rolls fall within the 1..25 range', () {
      final rng = Random(1234);
      for (var i = 0; i < 50000; i++) {
        final roll = PilotLicense.rollStat(rng: rng);
        expect(roll, inInclusiveRange(1, 25));
      }
    });

    test('rarity tiers are strictly monotonically decreasing in frequency', () {
      final rng = Random(42);
      final counts = List<int>.filled(5, 0);
      const n = 200000;
      for (var i = 0; i < n; i++) {
        counts[bucketOf(PilotLicense.rollStat(rng: rng))]++;
      }

      // P(1-5) >> P(6-10) >> P(11-15) >> P(16-19) >> P(20-25).
      // The underlying weights are 620, 235, 67, 18, 10 out of 950, so each
      // tier is strictly rarer than the one before it.
      for (var i = 0; i < counts.length - 1; i++) {
        expect(
          counts[i],
          greaterThan(counts[i + 1]),
          reason: 'tier $i (${counts[i]}) should exceed '
              'tier ${i + 1} (${counts[i + 1]})',
        );
      }

      // The common tier should dominate — it is ~65% of the mass.
      expect(counts[0] / n, greaterThan(0.55));
      // The legendary tier (20+) is a rare tail — well under ~2%.
      expect(counts[4] / n, lessThan(0.03));
    });

    test('a perfect 25 is possible but extremely rare', () {
      final rng = Random(7);
      var perfect = 0;
      const n = 200000;
      for (var i = 0; i < n; i++) {
        if (PilotLicense.rollStat(rng: rng) == 25) perfect++;
      }
      // ~1 in 950 per draw. Assert it occurs at all, but stays a sliver.
      expect(perfect, greaterThan(0));
      expect(perfect / n, lessThan(0.01));
    });
  });

  group('PilotLicense.rollStat luckBonus (advantage)', () {
    double meanOf({required int luckBonus, required int seed, int n = 100000}) {
      final rng = Random(seed);
      var sum = 0;
      for (var i = 0; i < n; i++) {
        sum += PilotLicense.rollStat(rng: rng, luckBonus: luckBonus);
      }
      return sum / n;
    }

    test('luckBonus raises the mean roll (keep-the-best advantage)', () {
      final baseMean = meanOf(luckBonus: 0, seed: 99);
      final luckyMean = meanOf(luckBonus: 5, seed: 99);
      expect(luckyMean, greaterThan(baseMean));
    });

    test('luckBonus raises the probability of a 20+ result', () {
      const n = 200000;
      var baseHigh = 0;
      var luckyHigh = 0;
      final baseRng = Random(555);
      final luckyRng = Random(555);
      for (var i = 0; i < n; i++) {
        if (PilotLicense.rollStat(rng: baseRng) >= 20) baseHigh++;
        if (PilotLicense.rollStat(rng: luckyRng, luckBonus: 5) >= 20) {
          luckyHigh++;
        }
      }
      expect(luckyHigh, greaterThan(baseHigh));
    });

    test('advantage rolls never leave the 1..25 range', () {
      final rng = Random(2026);
      for (var i = 0; i < 20000; i++) {
        expect(
          PilotLicense.rollStat(rng: rng, luckBonus: 8),
          inInclusiveRange(1, 25),
        );
      }
    });
  });
}
