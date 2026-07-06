import 'package:flutter_test/flutter_test.dart';

import 'package:flit/game/economy/consumables.dart';
import 'package:flit/game/economy/fuel_tank.dart';

void main() {
  final now = DateTime.utc(2026, 7, 5, 12);

  group('bundle pricing', () {
    test('1x is full price', () {
      expect(ConsumablePricing.bundleCost(100, 1), 100);
      expect(ConsumablePricing.bundleCost(50, 1), 50);
    });

    test('3x is 10% off per unit', () {
      expect(ConsumablePricing.bundleCost(100, 3), 270);
      expect(ConsumablePricing.bundleCost(50, 3), 135);
      expect(ConsumablePricing.perUnitCost(100, 3), 90.0);
    });

    test('5x is 15% off per unit', () {
      expect(ConsumablePricing.bundleCost(100, 5), 425);
      expect(ConsumablePricing.perUnitCost(100, 5), 85.0);
    });

    test('bulk saves per unit but total spend always rises', () {
      for (final type in ConsumableType.values) {
        final one = ConsumablePricing.bundleCost(type.baseCost, 1);
        final three = ConsumablePricing.bundleCost(type.baseCost, 3);
        final five = ConsumablePricing.bundleCost(type.baseCost, 5);
        // Economy of scale: per-unit price strictly decreases…
        expect(three / 3, lessThan(one.toDouble()));
        expect(five / 5, lessThan(three / 3));
        // …but total spend strictly increases (never cheap).
        expect(three, greaterThan(one));
        expect(five, greaterThan(three));
      }
    });

    test('unknown bundle sizes get no discount', () {
      expect(ConsumablePricing.bundleCost(100, 2), 200);
      expect(ConsumablePricing.bundleCost(100, 4), 400);
    });

    test('non-positive counts cost nothing', () {
      expect(ConsumablePricing.bundleCost(100, 0), 0);
      expect(ConsumablePricing.bundleCost(100, -3), 0);
    });

    test('canister base price matches the FuelTank constant', () {
      expect(
        ConsumableType.refuelCanister.baseCost,
        FuelTank.canisterCoinCost,
      );
    });
  });

  group('inventory', () {
    test('starts empty and grants accumulate', () {
      const inv = ConsumableInventory();
      expect(inv.of(ConsumableType.goldSurge), 0);
      final after = inv
          .grant(ConsumableType.goldSurge, 3)
          .grant(ConsumableType.goldSurge);
      expect(after.of(ConsumableType.goldSurge), 4);
    });

    test('consume decrements; returns null when none held', () {
      final inv = const ConsumableInventory().grant(ConsumableType.xpSurge);
      final after = inv.consume(ConsumableType.xpSurge);
      expect(after!.of(ConsumableType.xpSurge), 0);
      expect(after.consume(ConsumableType.xpSurge), isNull);
      expect(inv.consume(ConsumableType.licensePolish), isNull);
    });

    test('json round-trip preserves counts', () {
      final inv = const ConsumableInventory()
          .grant(ConsumableType.licensePolish, 2)
          .grant(ConsumableType.goldSurge, 5);
      final restored = ConsumableInventory.fromJson(inv.toJson());
      expect(restored.of(ConsumableType.licensePolish), 2);
      expect(restored.of(ConsumableType.goldSurge), 5);
      expect(restored.of(ConsumableType.xpSurge), 0);
    });
  });

  group('active effects (expiry)', () {
    test('inactive by default; activation runs for the item duration', () {
      const effects = ActiveEffects();
      expect(effects.isActive(ConsumableType.goldSurge, now), isFalse);

      final active = effects.activate(ConsumableType.goldSurge, now);
      expect(active.isActive(ConsumableType.goldSurge, now), isTrue);
      expect(
        active.isActive(
          ConsumableType.goldSurge,
          now.add(const Duration(minutes: 59)),
        ),
        isTrue,
      );
      // Expires exactly at the boundary.
      expect(
        active.isActive(
          ConsumableType.goldSurge,
          now.add(const Duration(minutes: 60)),
        ),
        isFalse,
      );
    });

    test('license polish runs 24h', () {
      final active =
          const ActiveEffects().activate(ConsumableType.licensePolish, now);
      expect(
        active.remaining(ConsumableType.licensePolish, now),
        const Duration(hours: 24),
      );
    });

    test('re-activating while active appends the new window', () {
      final first = const ActiveEffects().activate(ConsumableType.xpSurge, now);
      // 20 minutes in, use a second surge: 40m left + 60m = 100m total.
      final later = now.add(const Duration(minutes: 20));
      final second = first.activate(ConsumableType.xpSurge, later);
      expect(
        second.remaining(ConsumableType.xpSurge, later),
        const Duration(minutes: 100),
      );
    });

    test('re-activating after expiry starts fresh from now', () {
      final first =
          const ActiveEffects().activate(ConsumableType.goldSurge, now);
      final muchLater = now.add(const Duration(hours: 5));
      final second = first.activate(ConsumableType.goldSurge, muchLater);
      expect(
        second.remaining(ConsumableType.goldSurge, muchLater),
        const Duration(minutes: 60),
      );
    });

    test('effect math: multipliers and polish bonus', () {
      final effects = const ActiveEffects()
          .activate(ConsumableType.goldSurge, now)
          .activate(ConsumableType.xpSurge, now)
          .activate(ConsumableType.licensePolish, now);
      expect(effects.coinMultiplier(now), 2.0);
      expect(effects.xpMultiplier(now), 2);
      expect(effects.licenseStatBonus(now), licensePolishStatBonus);

      final expired = now.add(const Duration(hours: 25));
      expect(effects.coinMultiplier(expired), 1.0);
      expect(effects.xpMultiplier(expired), 1);
      expect(effects.licenseStatBonus(expired), 0);
    });

    test('json round-trip preserves expiries (survives restarts)', () {
      final effects = const ActiveEffects()
          .activate(ConsumableType.goldSurge, now)
          .activate(ConsumableType.licensePolish, now);
      final restored = ActiveEffects.fromJson(
        // Simulate a JSONB round-trip through Supabase.
        Map<String, dynamic>.from(effects.toJson()),
      );
      expect(
        restored.expiryOf(ConsumableType.goldSurge),
        effects.expiryOf(ConsumableType.goldSurge),
      );
      expect(
        restored.remaining(ConsumableType.licensePolish, now),
        const Duration(hours: 24),
      );
      expect(restored.isActive(ConsumableType.xpSurge, now), isFalse);
    });

    test('malformed json degrades to no effects', () {
      final restored = ActiveEffects.fromJson({
        'gold_surge': 12345, // not a string
        'xp_surge': 'not-a-date',
      });
      expect(restored.activeAt(now), isEmpty);
    });

    test('canisters are instant-use, never timed', () {
      expect(ConsumableType.refuelCanister.isTimed, isFalse);
      final effects =
          const ActiveEffects().activate(ConsumableType.refuelCanister, now);
      expect(effects.activeAt(now), isEmpty);
    });
  });

  group('refuel pricing (scales with tank capacity)', () {
    test('base tank costs the baseline (real decision, 60-80 coins)', () {
      final cost = FuelTank.instantRefuelCost(FuelTank.baseCapacity);
      expect(cost, FuelTank.baseInstantRefuelCost);
      expect(cost, inInclusiveRange(60, 80));
    });

    test('bigger licensed tanks cost proportionally more', () {
      final base = FuelTank.instantRefuelCost(100);
      expect(FuelTank.instantRefuelCost(125), (base * 1.25).ceil());
      expect(FuelTank.instantRefuelCost(130), (base * 1.3).ceil());
      expect(
        FuelTank.instantRefuelCost(130),
        greaterThan(FuelTank.instantRefuelCost(110)),
      );
    });

    test('top-up is a quarter of the full price for +25% fuel', () {
      expect(
        FuelTank.topUpCost(100),
        (FuelTank.baseInstantRefuelCost * 0.25).ceil(),
      );
      expect(
        FuelTank.topUpCost(130),
        lessThan(FuelTank.instantRefuelCost(130)),
      );
    });

    test('topUp adds 25% of capacity, clamped at full', () {
      final empty = FuelTank(storedFuel: 0, updatedAt: now);
      expect(empty.topUp(now).currentFuel(now), closeTo(25, 0.001));
      final nearFull = FuelTank(storedFuel: 90, updatedAt: now);
      expect(nearFull.topUp(now).currentFuel(now), 100);
    });

    test('canister price is below an instant full refuel (plan ahead)', () {
      expect(
        FuelTank.canisterCoinCost,
        lessThan(FuelTank.baseInstantRefuelCost),
      );
    });
  });

  group('consumable item naming (display strings vs persistence ids)', () {
    test('supplies read as ITEM names, not effect names', () {
      // Owner spec: titles are collectible items; the effect is the subtitle.
      expect(ConsumableType.xpSurge.displayName, 'Log Book');
      expect(ConsumableType.goldSurge.displayName, 'Gold Rush');
      expect(ConsumableType.licensePolish.displayName, 'License Polish');
      expect(ConsumableType.refuelCanister.displayName, 'Refuel Canister');
    });

    test('effect labels describe what the item does', () {
      expect(
          ConsumableType.xpSurge.effectLabel, 'Doubles XP earned for 60 min');
      expect(
        ConsumableType.goldSurge.effectLabel,
        'Doubles coins earned for 60 min',
      );
    });

    test('persistence ids are UNCHANGED (saved data stays valid)', () {
      // Renaming the human-facing strings must not touch the stable ids.
      expect(ConsumableType.goldSurge.id, 'gold_surge');
      expect(ConsumableType.xpSurge.id, 'xp_surge');
      expect(ConsumableType.licensePolish.id, 'license_polish');
      expect(ConsumableType.refuelCanister.id, 'refuel_canister');
      // Round-trip through the id resolver still works.
      expect(ConsumableTypeInfo.fromId('gold_surge'), ConsumableType.goldSurge);
      expect(ConsumableTypeInfo.fromId('xp_surge'), ConsumableType.xpSurge);
    });
  });
}
