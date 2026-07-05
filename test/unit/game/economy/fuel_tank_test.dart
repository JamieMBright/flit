import 'package:flutter_test/flutter_test.dart';

import 'package:flit/game/economy/fuel_tank.dart';

void main() {
  final now = DateTime.utc(2026, 7, 5, 12);

  group('capacity', () {
    test('base capacity with no boost', () {
      expect(FuelTank.capacityFor(0), FuelTank.baseCapacity);
    });

    test('license fuelBoost enlarges the tank by 1% per point', () {
      expect(FuelTank.capacityFor(25), 125.0);
      // Hot pump adds +5 effective points on top of a maxed stat.
      expect(FuelTank.capacityFor(30), 130.0);
    });
  });

  group('regeneration', () {
    test('brand-new tank starts full', () {
      const tank = FuelTank();
      expect(tank.currentFuel(now, capacity: 120), 120);
    });

    test('regenerates 25 units per hour', () {
      final tank = FuelTank(storedFuel: 0, updatedAt: now);
      expect(
        tank.currentFuel(now.add(const Duration(hours: 1))),
        closeTo(25, 0.001),
      );
      expect(
        tank.currentFuel(now.add(const Duration(hours: 2, minutes: 30))),
        closeTo(62.5, 0.001),
      );
    });

    test('regen clamps at capacity (full base tank in 4 hours)', () {
      final tank = FuelTank(storedFuel: 0, updatedAt: now);
      expect(tank.currentFuel(now.add(const Duration(hours: 4))), 100);
      expect(tank.currentFuel(now.add(const Duration(days: 3))), 100);
    });

    test('clock skew (updatedAt in the future) does not add fuel', () {
      final tank = FuelTank(
        storedFuel: 40,
        updatedAt: now.add(const Duration(hours: 1)),
      );
      expect(tank.currentFuel(now), 40);
    });
  });

  group('consume', () {
    test('consuming reduces fuel and stamps the time', () {
      final tank = FuelTank(storedFuel: 50, updatedAt: now);
      final after = tank.consume(now, FuelTank.fuelPerClue);
      expect(after.currentFuel(now), closeTo(40, 0.001));
      expect(after.updatedAt, now);
    });

    test('consume clamps at zero', () {
      final tank = FuelTank(storedFuel: 5, updatedAt: now);
      final after = tank.consume(now, 10);
      expect(after.currentFuel(now), 0);
    });

    test('consume accounts for regen since last update', () {
      final tank = FuelTank(storedFuel: 0, updatedAt: now);
      final later = now.add(const Duration(hours: 2)); // +50 regen
      final after = tank.consume(later, 10);
      expect(after.currentFuel(later), closeTo(40, 0.001));
    });
  });

  group('earn gating', () {
    test('canEarn requires one clue of fuel', () {
      expect(
        FuelTank(storedFuel: FuelTank.fuelPerClue, updatedAt: now).canEarn(now),
        isTrue,
      );
      expect(
        FuelTank(storedFuel: FuelTank.fuelPerClue - 1, updatedAt: now)
            .canEarn(now),
        isFalse,
      );
    });

    test('empty tank recovers earning ability via regen', () {
      final tank = FuelTank(storedFuel: 0, updatedAt: now);
      expect(tank.canEarn(now), isFalse);
      // 10 units at 25/h => 24 minutes.
      expect(tank.canEarn(now.add(const Duration(minutes: 24))), isTrue);
      expect(
        tank.timeUntil(now, FuelTank.fuelPerClue),
        const Duration(minutes: 24),
      );
    });
  });

  group('refuel', () {
    test('refillFull tops up to capacity', () {
      final tank = FuelTank(storedFuel: 3, updatedAt: now);
      final full = tank.refillFull(now, capacity: 125);
      expect(full.currentFuel(now, capacity: 125), 125);
    });

    test('canister is cheaper than the instant refuel', () {
      expect(
        FuelTank.canisterCoinCost,
        lessThan(FuelTank.instantRefuelCoinCost),
      );
    });
  });

  group('gauges + serialisation', () {
    test('fraction is clamped 0..1', () {
      final tank = FuelTank(storedFuel: 50, updatedAt: now);
      expect(tank.fraction(now), 0.5);
      expect(
        FuelTank(storedFuel: 500, updatedAt: now).fraction(now),
        1.0,
      );
    });

    test('round-trips through JSON', () {
      final tank = FuelTank(storedFuel: 33.5, updatedAt: now);
      final restored = FuelTank.fromJson(tank.toJson());
      expect(restored.storedFuel, 33.5);
      expect(restored.updatedAt, now);
    });

    test('null JSON yields a fresh full tank', () {
      final tank = FuelTank.fromJson(null);
      expect(tank.currentFuel(now), FuelTank.baseCapacity);
    });
  });
}
