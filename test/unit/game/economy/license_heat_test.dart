import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:flit/data/models/pilot_license.dart';
import 'package:flit/game/economy/license_heat.dart';

void main() {
  final now = DateTime.utc(2026, 7, 5, 12);

  group('hot window', () {
    test('fresh heat is not hot', () {
      const heat = LicenseHeat();
      expect(heat.isHot(now), isFalse);
      expect(heat.statBonus(now), 0);
      expect(heat.hotRemaining(now), Duration.zero);
    });

    test('pump makes the license hot for 72h', () {
      final heat = const LicenseHeat().pump(now);
      expect(heat.isHot(now), isTrue);
      expect(heat.statBonus(now), LicenseHeat.hotStatBonus);
      expect(heat.hotUntil, now.add(const Duration(hours: 72)));
      expect(
        heat.isHot(now.add(const Duration(hours: 71, minutes: 59))),
        isTrue,
      );
      expect(heat.isHot(now.add(const Duration(hours: 72))), isFalse);
    });

    test('re-pump extends the window from now', () {
      final first = const LicenseHeat().pump(now);
      final later = now.add(const Duration(hours: 48));
      final extended = first.pump(later);
      expect(extended.hotUntil, later.add(const Duration(hours: 72)));
    });

    test('pump never shortens an existing window', () {
      final longWindow = LicenseHeat(
        hotUntil: now.add(const Duration(hours: 200)),
      );
      final pumped = longWindow.pump(now);
      expect(pumped.hotUntil, now.add(const Duration(hours: 200)));
    });

    test('expiry only ends the pump, never the base stats', () {
      // Base stats live on PilotLicense and are untouched by heat expiry.
      const license = PilotLicense(
        coinBoost: 10,
        clueChance: 12,
        fuelBoost: 8,
        preferredClueType: 'flag',
      );
      final hot = license.copyWith(heat: license.heat.pump(now));
      final afterExpiry = now.add(const Duration(hours: 100));
      expect(hot.effectiveCoinBoost(now), 15);
      expect(hot.effectiveCoinBoost(afterExpiry), 10);
      expect(hot.coinBoost, 10); // Permanent — never decays.
    });
  });

  group('pump qualification', () {
    test('requires 60% of the max score', () {
      expect(
        LicenseHeat.qualifiesForPump(score: 30000, maxScore: 50000),
        isTrue,
      );
      expect(
        LicenseHeat.qualifiesForPump(score: 29999, maxScore: 50000),
        isFalse,
      );
      expect(
        LicenseHeat.qualifiesForPump(score: 50000, maxScore: 50000),
        isTrue,
      );
    });

    test('never qualifies with a zero/invalid max', () {
      expect(LicenseHeat.qualifiesForPump(score: 100, maxScore: 0), isFalse);
    });
  });

  group('reroll cost escalation', () {
    test('paid cost ladder doubles then caps', () {
      expect(LicenseHeat.paidRerollCost(0), 100);
      expect(LicenseHeat.paidRerollCost(1), 200);
      expect(LicenseHeat.paidRerollCost(2), 400);
      expect(LicenseHeat.paidRerollCost(3), 800);
      expect(LicenseHeat.paidRerollCost(4), 800); // Capped.
      expect(LicenseHeat.paidRerollCost(10), 800);
    });

    test('nextPaidRerollCost escalates within one day', () {
      var heat = const LicenseHeat();
      expect(heat.nextPaidRerollCost('2026-07-05'), 100);
      heat = heat.recordPaidReroll('2026-07-05');
      expect(heat.nextPaidRerollCost('2026-07-05'), 200);
      heat = heat.recordPaidReroll('2026-07-05');
      expect(heat.nextPaidRerollCost('2026-07-05'), 400);
    });

    test('a new day resets the ladder', () {
      var heat = const LicenseHeat();
      heat = heat.recordPaidReroll('2026-07-05');
      heat = heat.recordPaidReroll('2026-07-05');
      expect(heat.nextPaidRerollCost('2026-07-06'), 100);
      heat = heat.recordPaidReroll('2026-07-06');
      expect(heat.paidRerollsToday, 1);
      expect(heat.rerollDay, '2026-07-06');
    });
  });

  group('pity', () {
    test('bad rolls increment pity; an improvement resets it', () {
      var heat = const LicenseHeat();
      heat = heat.recordRollOutcome(improved: false);
      heat = heat.recordRollOutcome(improved: false);
      expect(heat.pityCount, 2);
      expect(heat.pityLuckBonus, 2);
      heat = heat.recordRollOutcome(improved: true);
      expect(heat.pityCount, 0);
    });

    test('pity guarantees improved odds after every bad roll', () {
      var heat = const LicenseHeat();
      var lastChance = heat.factoryHotChance;
      var lastLuck = heat.pityLuckBonus;
      for (var i = 0; i < 4; i++) {
        heat = heat.recordRollOutcome(improved: false);
        expect(heat.factoryHotChance, greaterThan(lastChance));
        expect(heat.pityLuckBonus, greaterThan(lastLuck));
        lastChance = heat.factoryHotChance;
        lastLuck = heat.pityLuckBonus;
      }
    });

    test('factory-hot chance is capped', () {
      var heat = const LicenseHeat();
      for (var i = 0; i < 50; i++) {
        heat = heat.recordRollOutcome(improved: false);
      }
      expect(heat.factoryHotChance, LicenseHeat.factoryHotMaxChance);
    });
  });

  group('factory hot', () {
    test('rollFactoryHot pumps when the rng procs', () {
      // Find a seed that procs at base 10% chance, and one that doesn't.
      const heat = LicenseHeat();
      var procced = false;
      var missed = false;
      for (var seed = 0; seed < 200 && !(procced && missed); seed++) {
        final rolled = heat.rollFactoryHot(now, rng: Random(seed));
        if (rolled.isHot(now)) {
          procced = true;
        } else {
          missed = true;
        }
      }
      expect(procced, isTrue);
      expect(missed, isTrue);
    });

    test('proc rate roughly matches factoryHotChance', () {
      const heat = LicenseHeat(pityCount: 5); // 10% + 40% = 50% chance.
      final rng = Random(42);
      var hits = 0;
      const trials = 2000;
      for (var i = 0; i < trials; i++) {
        if (heat.rollFactoryHot(now, rng: rng).isHot(now)) hits++;
      }
      expect(hits / trials, closeTo(heat.factoryHotChance, 0.05));
    });
  });

  group('serialisation', () {
    test('round-trips through JSON', () {
      final heat = LicenseHeat(
        hotUntil: now.add(const Duration(hours: 10)),
        pityCount: 3,
        paidRerollsToday: 2,
        rerollDay: '2026-07-05',
      );
      final restored = LicenseHeat.fromJson(heat.toJson());
      expect(restored.hotUntil, heat.hotUntil);
      expect(restored.pityCount, 3);
      expect(restored.paidRerollsToday, 2);
      expect(restored.rerollDay, '2026-07-05');
    });

    test('null/missing json yields cold defaults', () {
      final heat = LicenseHeat.fromJson(null);
      expect(heat.isHot(now), isFalse);
      expect(heat.pityCount, 0);
      expect(heat.paidRerollsToday, 0);
    });
  });

  group('PilotLicense integration', () {
    test('heat survives license serialisation round-trip', () {
      final license = PilotLicense(
        coinBoost: 5,
        clueChance: 7,
        fuelBoost: 9,
        preferredClueType: 'capital',
        heat: const LicenseHeat(pityCount: 4).pump(now),
      );
      final restored = PilotLicense.fromJson(license.toJson());
      expect(restored.heat.pityCount, 4);
      expect(restored.heat.hotUntil, license.heat.hotUntil);
      expect(restored.effectiveFuelBoost(now), 9 + LicenseHeat.hotStatBonus);
    });

    test('legacy license JSON without heat parses cold', () {
      final restored = PilotLicense.fromJson({
        'coin_boost': 3,
        'clue_chance': 4,
        'fuel_boost': 5,
        'preferred_clue_type': 'flag',
      });
      expect(restored.isHot(now), isFalse);
      expect(restored.effectiveCoinBoost(now), 3);
    });

    test('reroll preserves heat and pity', () {
      final license = PilotLicense(
        coinBoost: 5,
        clueChance: 7,
        fuelBoost: 9,
        preferredClueType: 'capital',
        heat: const LicenseHeat(pityCount: 2).pump(now),
      );
      final rerolled = PilotLicense.reroll(license, rng: Random(1));
      expect(rerolled.heat.pityCount, 2);
      expect(rerolled.heat.hotUntil, license.heat.hotUntil);
    });
  });
}
