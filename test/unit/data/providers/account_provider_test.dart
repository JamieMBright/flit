import 'package:flutter_test/flutter_test.dart';

import 'package:flit/data/models/avatar_config.dart';
import 'package:flit/data/models/season.dart';
import 'package:flit/data/providers/account_provider.dart';
import 'package:flit/game/economy/consumables.dart';
import 'package:flit/game/economy/fuel_tank.dart';
import 'package:flit/game/economy/license_heat.dart';

void main() {
  group('AccountNotifier.loadFromSupabase', () {
    test('keeps default state when cloud snapshot cannot be loaded', () async {
      final notifier = AccountNotifier();

      await notifier.loadFromSupabase('user-123');

      expect(notifier.state.currentPlayer.id, isEmpty);
      expect(notifier.state.currentPlayer.level, equals(1));
      expect(notifier.state.currentPlayer.coins, equals(0));
      expect(notifier.state.currentPlayer.gamesPlayed, equals(0));

      notifier.dispose();
    });
  });

  group('AccountNotifier local state updates', () {
    test('recordGameCompletion updates profile stats in-memory', () async {
      final notifier = AccountNotifier();

      await notifier.recordGameCompletion(
        elapsed: const Duration(seconds: 30),
        score: 500,
        roundsCompleted: 2,
      );

      final player = notifier.state.currentPlayer;
      expect(player.gamesPlayed, equals(1));
      expect(player.bestScore, equals(500));
      expect(player.bestTime, equals(const Duration(seconds: 30)));
      expect(player.totalFlightTime, equals(const Duration(seconds: 30)));
      expect(player.countriesFound, equals(2));
      expect(player.level, equals(1));
      expect(player.xp, equals(75));

      notifier.dispose();
    });

    test('updateAvatar updates in-memory avatar config', () async {
      final notifier = AccountNotifier();
      const avatar = AvatarConfig(
        style: AvatarStyle.avataaars,
        eyes: AvatarEyes.variant05,
      );

      await notifier.updateAvatar(avatar);

      expect(notifier.state.avatar, equals(avatar));
      notifier.dispose();
    });

    test('spendCoins supports explicit source/logActivity flags', () {
      final notifier = AccountNotifier();
      notifier.switchAccount(
        notifier.state.currentPlayer.copyWith(id: 'u1', username: 'pilot'),
      );
      notifier.addCoins(100, applyBoost: false, source: 'test_grant');

      final spent = notifier.spendCoins(
        25,
        source: 'test_purchase',
        logActivity: false,
      );

      expect(spent, isTrue);
      expect(notifier.state.currentPlayer.coins, equals(75));
      notifier.dispose();
    });
  });

  group('Meta fuel tank', () {
    AccountNotifier fundedNotifier({int coins = 1000}) {
      final notifier = AccountNotifier();
      notifier.switchAccount(
        notifier.state.currentPlayer.copyWith(id: 'u1', username: 'pilot'),
      );
      notifier.addCoins(coins, applyBoost: false, source: 'test_grant');
      return notifier;
    }

    test('free-flight earning consumes fuel when gated', () {
      final notifier = fundedNotifier();
      final before = notifier.currentFuel;

      final earned = notifier.awardFreeFlightClue(
        perClueReward: 10,
        dailyCap: 500,
        gateFuel: true,
      );

      expect(earned, greaterThan(0));
      expect(notifier.currentFuel, lessThan(before));
      notifier.dispose();
    });

    test('empty tank pauses earnings but never blocks anything else', () {
      final notifier = fundedNotifier();
      // Drain the tank.
      var guard = 0;
      while (notifier.canEarnFreeFlightCoins && guard < 50) {
        notifier.awardFreeFlightClue(
          perClueReward: 1,
          dailyCap: 100000,
          gateFuel: true,
        );
        guard++;
      }
      expect(notifier.canEarnFreeFlightCoins, isFalse);

      final coinsBefore = notifier.state.currentPlayer.coins;
      final earned = notifier.awardFreeFlightClue(
        perClueReward: 10,
        dailyCap: 100000,
        gateFuel: true,
      );
      expect(earned, 0);
      expect(notifier.state.currentPlayer.coins, coinsBefore);

      // Ungated earning (dailies/H2H paths) is never fuel-blocked.
      final ungated = notifier.awardFreeFlightClue(
        perClueReward: 10,
        dailyCap: 100000,
      );
      expect(ungated, greaterThan(0));
      notifier.dispose();
    });

    test('refuelWithCoins refills and charges', () {
      final notifier = fundedNotifier();
      var guard = 0;
      while (notifier.canEarnFreeFlightCoins && guard < 50) {
        notifier.awardFreeFlightClue(
          perClueReward: 1,
          dailyCap: 100000,
          gateFuel: true,
        );
        guard++;
      }
      final coinsBefore = notifier.state.currentPlayer.coins;

      // Pricing scales with the player's tank capacity (item repricing).
      final expectedCost = notifier.instantRefuelCost;
      expect(notifier.refuelWithCoins(), isTrue);
      expect(
        notifier.state.currentPlayer.coins,
        coinsBefore - expectedCost,
      );
      expect(notifier.canEarnFreeFlightCoins, isTrue);
      notifier.dispose();
    });

    test('canisters: buy then use for a full refuel', () {
      final notifier = fundedNotifier();
      final coinsBefore = notifier.state.currentPlayer.coins;

      expect(notifier.buyRefuelCanisters(2), isTrue);
      expect(notifier.state.refuelCanisters, 2);
      // 2x is not a discounted bundle size — full per-unit price.
      expect(
        notifier.state.currentPlayer.coins,
        coinsBefore - 2 * FuelTank.canisterCoinCost,
      );

      expect(notifier.useRefuelCanister(), isTrue);
      expect(notifier.state.refuelCanisters, 1);
      notifier.dispose();
    });

    test('useRefuelCanister fails with none owned', () {
      final notifier = fundedNotifier();
      expect(notifier.useRefuelCanister(), isFalse);
      notifier.dispose();
    });

    test('license fuelBoost enlarges capacity', () {
      final notifier = fundedNotifier();
      notifier.updateLicense(
        notifier.state.license.copyWith(fuelBoost: 20),
      );
      expect(notifier.fuelCapacity, 120.0);
      notifier.dispose();
    });
  });

  group('Consumables', () {
    AccountNotifier fundedNotifier({int coins = 10000}) {
      final notifier = AccountNotifier();
      notifier.switchAccount(
        notifier.state.currentPlayer.copyWith(id: 'u1', username: 'pilot'),
      );
      notifier.addCoins(coins, applyBoost: false, source: 'test_grant');
      return notifier;
    }

    test('buyConsumable charges bundle pricing (3x = 10% off per unit)', () {
      final notifier = fundedNotifier();
      final before = notifier.state.currentPlayer.coins;

      expect(notifier.buyConsumable(ConsumableType.goldSurge, 3), isTrue);
      expect(notifier.consumableCount(ConsumableType.goldSurge), 3);
      expect(
        notifier.state.currentPlayer.coins,
        before -
            ConsumablePricing.bundleCost(
              ConsumableType.goldSurge.baseCost,
              3,
            ),
      );
      notifier.dispose();
    });

    test('buyConsumable fails when unaffordable', () {
      final notifier = fundedNotifier(coins: 10);
      expect(notifier.buyConsumable(ConsumableType.licensePolish, 1), isFalse);
      expect(notifier.consumableCount(ConsumableType.licensePolish), 0);
      notifier.dispose();
    });

    test('activateConsumable consumes one and starts the timed effect', () {
      final notifier = fundedNotifier();
      final now = DateTime.now().toUtc();

      expect(notifier.activateConsumable(ConsumableType.xpSurge), isFalse);
      notifier.grantConsumable(ConsumableType.xpSurge);
      expect(notifier.activateConsumable(ConsumableType.xpSurge), isTrue);
      expect(notifier.consumableCount(ConsumableType.xpSurge), 0);
      expect(
        notifier.state.activeEffects.isActive(ConsumableType.xpSurge, now),
        isTrue,
      );
      notifier.dispose();
    });

    test('Gold Surge doubles boosted coin earnings', () {
      final notifier = fundedNotifier();
      final baseline = notifier.totalGoldMultiplier;

      notifier.grantConsumable(ConsumableType.goldSurge);
      notifier.activateConsumable(ConsumableType.goldSurge);
      expect(notifier.totalGoldMultiplier, closeTo(baseline * 2, 1e-9));
      notifier.dispose();
    });

    test('XP Surge doubles XP gains', () {
      final notifier = fundedNotifier();
      notifier.grantConsumable(ConsumableType.xpSurge);
      notifier.activateConsumable(ConsumableType.xpSurge);

      final xpBefore = notifier.state.currentPlayer.xp;
      notifier.addXp(10);
      expect(notifier.state.currentPlayer.xp, xpBefore + 20);
      notifier.dispose();
    });

    test('License Polish adds +3 to effective stats (stacks with HOT)', () {
      final notifier = fundedNotifier();
      final before = notifier.effectiveClueChance;
      final capacityBefore = notifier.fuelCapacity;

      notifier.grantConsumable(ConsumableType.licensePolish);
      notifier.activateConsumable(ConsumableType.licensePolish);
      expect(notifier.effectiveClueChance, before + licensePolishStatBonus);
      // Capacity grows with the polished fuelBoost (+3 points = +3 units
      // on a base tank).
      expect(notifier.fuelCapacity, greaterThan(capacityBefore));
      notifier.dispose();
    });

    test('rollSupplyDrop grants and persists the dropped item', () {
      final notifier = fundedNotifier();
      // Find a score that deterministically drops for this user/mode/date.
      ConsumableType? dropped;
      for (var score = 0; score < 10000 && dropped == null; score++) {
        dropped = notifier.rollSupplyDrop(
          mode: 'test_mode',
          score: score,
          strongPerformance: true,
        );
      }
      expect(dropped, isNotNull);
      expect(notifier.consumableCount(dropped!), greaterThanOrEqualTo(1));
      notifier.dispose();
    });
  });

  group('Hot license pump', () {
    test('qualifying performance pumps; weak one does not', () {
      final notifier = AccountNotifier();
      final now = DateTime.now().toUtc();

      expect(
        notifier.pumpLicenseFromPerformance(score: 10000, maxScore: 50000),
        isFalse,
      );
      expect(notifier.state.license.isHot(now), isFalse);

      expect(
        notifier.pumpLicenseFromPerformance(score: 40000, maxScore: 50000),
        isTrue,
      );
      expect(notifier.state.license.isHot(now), isTrue);

      // Hot pump raises the earn multipliers (dailies benefit).
      expect(
        notifier.coinBoostMultiplier,
        closeTo(
          1.0 +
              (notifier.state.license.coinBoost + LicenseHeat.hotStatBonus) /
                  100.0,
          1e-9,
        ),
      );
      notifier.dispose();
    });
  });

  group('Reroll economy', () {
    test('paid reroll cost escalates within the day', () {
      final notifier = AccountNotifier();
      notifier.switchAccount(
        notifier.state.currentPlayer.copyWith(id: 'u1', username: 'pilot'),
      );
      notifier.addCoins(5000, applyBoost: false, source: 'test_grant');

      expect(notifier.paidRerollCost(), 100);
      expect(notifier.rerollLicense(), isTrue);
      expect(notifier.paidRerollCost(), 200);
      expect(notifier.rerollLicense(), isTrue);
      expect(notifier.paidRerollCost(), 400);
      expect(notifier.rerollLicense(), isTrue);
      expect(notifier.paidRerollCost(), 800);
      expect(notifier.rerollLicense(), isTrue);
      expect(notifier.paidRerollCost(), 800); // Capped.
      notifier.dispose();
    });

    test('free reroll stays free and does not advance the paid ladder', () {
      final notifier = AccountNotifier();
      notifier.switchAccount(
        notifier.state.currentPlayer.copyWith(id: 'u1', username: 'pilot'),
      );

      expect(notifier.state.hasFreeRerollToday, isTrue);
      expect(notifier.useFreeReroll(), isTrue);
      expect(notifier.state.currentPlayer.coins, 0); // Nothing charged.
      expect(notifier.paidRerollCost(), 100); // Ladder untouched.
      expect(notifier.state.hasFreeRerollToday, isFalse);
      notifier.dispose();
    });

    test('rerolls update pity bookkeeping', () {
      final notifier = AccountNotifier();
      notifier.switchAccount(
        notifier.state.currentPlayer.copyWith(id: 'u1', username: 'pilot'),
      );
      notifier.addCoins(10000, applyBoost: false, source: 'test_grant');

      final oldTotal = notifier.state.license.totalBoost;
      expect(notifier.rerollLicense(), isTrue);
      final newTotal = notifier.state.license.totalBoost;
      final pity = notifier.state.license.heat.pityCount;
      if (newTotal > oldTotal) {
        expect(pity, 0);
      } else {
        expect(pity, 1);
      }
      notifier.dispose();
    });

    test('insufficient coins rejects a paid reroll', () {
      final notifier = AccountNotifier();
      expect(notifier.rerollLicense(), isFalse);
      notifier.dispose();
    });
  });

  group('Trophy case', () {
    test('recordSeasonTrophy stores idempotent snapshots', () {
      final notifier = AccountNotifier();
      notifier.recordSeasonTrophy(
        const Trophy(
          seasonId: '2026-Q3',
          gameMode: 'sortie',
          tierName: 'Silver Wings',
          rating: 1150,
        ),
      );
      notifier.recordSeasonTrophy(
        const Trophy(
          seasonId: '2026-Q3',
          gameMode: 'sortie',
          tierName: 'Gold Wings',
          rating: 1320,
        ),
      );
      expect(notifier.state.trophyCase.trophies.length, 1);
      expect(
        notifier.state.trophyCase.trophies.single.tierName,
        'Gold Wings',
      );
      notifier.dispose();
    });
  });
}
