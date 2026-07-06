import 'package:flutter_test/flutter_test.dart';

import 'package:flit/data/models/avatar_config.dart';
import 'package:flit/data/models/daily_streak.dart';
import 'package:flit/data/models/player.dart';
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

    test('Gold Surge multiplies ACTIVE grind but NOT fixed lump sums', () {
      final notifier = fundedNotifier();
      notifier.grantConsumable(ConsumableType.goldSurge);
      notifier.activateConsumable(ConsumableType.goldSurge);
      // The Surge doubles the non-surge multiplier (whatever the licence
      // baseline is). Excluding it must therefore HALVE the payout.
      final total = notifier.totalGoldMultiplier;
      final nonSurge = notifier.nonSurgeGoldMultiplier;
      expect(total, closeTo(nonSurge * 2, 1e-9));
      expect(nonSurge, lessThan(total));

      // Active grind (free-flight clue, ordinary game completion) gets surge.
      expect(
        notifier.addCoins(100, source: 'free_flight_clue'),
        (100 * total).round(),
      );
      expect(
        notifier.addCoins(100, source: 'game_completion'),
        (100 * total).round(),
      );
      // Fixed lump payouts are NOT surged: explicit opt-out …
      expect(
        notifier.addCoins(100, source: 'game_completion', applySurge: false),
        (100 * nonSurge).round(),
      );
      // … and the source-detected lumps (Flight School / Briefing, campaign).
      expect(notifier.addCoins(100, source: 'flight_school'),
          (100 * nonSurge).round());
      expect(notifier.addCoins(100, source: 'campaign_mission'),
          (100 * nonSurge).round());
      notifier.dispose();
    });

    test('recordGameCompletion withholds surge from daily lumps', () async {
      final notifier = fundedNotifier();
      notifier.grantConsumable(ConsumableType.goldSurge);
      notifier.activateConsumable(ConsumableType.goldSurge);

      // Daily scramble: fixedReward flag → no surge on the 150 lump.
      var nonSurge = notifier.nonSurgeGoldMultiplier;
      var before = notifier.state.currentPlayer.coins;
      await notifier.recordGameCompletion(
        elapsed: Duration.zero,
        score: 0,
        roundsCompleted: 1,
        coinReward: 150,
        fixedReward: true,
      );
      expect(notifier.state.currentPlayer.coins - before,
          (150 * nonSurge).round());

      // Daily triangulation: detected by region, no flag needed.
      nonSurge = notifier.nonSurgeGoldMultiplier;
      before = notifier.state.currentPlayer.coins;
      await notifier.recordGameCompletion(
        elapsed: Duration.zero,
        score: 0,
        roundsCompleted: 1,
        coinReward: 150,
        region: 'daily_triangulation',
      );
      expect(notifier.state.currentPlayer.coins - before,
          (150 * nonSurge).round());

      // Ordinary region completion DOES get the surge (strictly more).
      final total = notifier.totalGoldMultiplier;
      before = notifier.state.currentPlayer.coins;
      await notifier.recordGameCompletion(
        elapsed: Duration.zero,
        score: 0,
        roundsCompleted: 1,
        coinReward: 150,
        region: 'world',
      );
      final surgedDelta = notifier.state.currentPlayer.coins - before;
      expect(surgedDelta, (150 * total).round());
      expect(surgedDelta, greaterThan((150 * nonSurge).round()));
      notifier.dispose();
    });

    test('Gold Surge lifts the free-flight daily cap (count of clues)', () {
      final notifier = fundedNotifier();
      notifier.grantConsumable(ConsumableType.goldSurge);
      notifier.activateConsumable(ConsumableType.goldSurge);

      // Ungated (no fuel limit) isolates the CAP. Normally 150/15 = 10 clues
      // max per day; with the cap lifted a focused grind blows past that.
      var clues = 0;
      for (var i = 0; i < 30; i++) {
        if (notifier.awardFreeFlightClue(perClueReward: 15, dailyCap: 150) >
            0) {
          clues++;
        }
      }
      expect(clues, greaterThan(10),
          reason: 'surge should lift the free-flight daily cap');
      notifier.dispose();
    });

    test('without a Surge the free-flight daily cap still binds at 10 clues',
        () {
      final notifier = fundedNotifier();
      var clues = 0;
      for (var i = 0; i < 30; i++) {
        if (notifier.awardFreeFlightClue(perClueReward: 15, dailyCap: 150) >
            0) {
          clues++;
        }
      }
      // Cap counts PRE-boost reward (15/clue) → exactly 10 earning clues.
      expect(clues, 10, reason: 'no surge → hard 150/day cap (10 clues)');
      notifier.dispose();
    });

    test('Gold Surge break-even is TIGHT (fuel bounds the grind)', () {
      // A full base tank (100u) at 10u/clue = 10 fuel-limited clues in a
      // focused window. The Surge's MARGINAL bonus is the doubled half
      // (= perClueReward), so ~10 × 15 = 150 coins ≈ the 150-coin Surge cost.
      // That is the wafer-thin gamble the owner asked for — not free money.
      final notifier = fundedNotifier();
      notifier.grantConsumable(ConsumableType.goldSurge);
      notifier.activateConsumable(ConsumableType.goldSurge);

      const perClue = 15;
      var clues = 0;
      var guard = 0;
      while (notifier.canEarnFreeFlightCoins && guard < 100) {
        final earned = notifier.awardFreeFlightClue(
          perClueReward: perClue,
          dailyCap: 150,
          gateFuel: true,
        );
        if (earned > 0) clues++;
        guard++;
      }
      expect(clues, 10, reason: 'full base tank = 10 fuel-limited clues');
      final marginalSurgeBonus = clues * perClue; // doubled half per clue
      expect(
        marginalSurgeBonus,
        closeTo(ConsumableType.goldSurge.baseCost.toDouble(), 1.0),
      );
      notifier.dispose();
    });

    test('equipped companion coin bonus rides boost-affected earning',
        () async {
      final notifier = fundedNotifier();
      final before = notifier.nonSurgeGoldMultiplier;
      await notifier.updateAvatar(
        const AvatarConfig(companion: AvatarCompanion.charizard),
      );
      // Charizard = +15% coins, folded multiplicatively into the multiplier.
      expect(notifier.companionCoinMultiplier, closeTo(1.15, 1e-9));
      expect(notifier.nonSurgeGoldMultiplier, closeTo(before * 1.15, 1e-9));
      // Boost-affected earning reflects the equipped companion …
      expect(
        notifier.addCoins(100, source: 'free_flight_clue'),
        (100 * notifier.nonSurgeGoldMultiplier).round(),
      );
      // … but the rated payout path (applyBoost:false) excludes it entirely.
      expect(notifier.addCoins(100, applyBoost: false), 100);
      notifier.dispose();
    });

    test('equipped companion clue bonus feeds effectiveClueChance', () async {
      final notifier = fundedNotifier();
      final before = notifier.effectiveClueChance;
      await notifier.updateAvatar(
        const AvatarConfig(companion: AvatarCompanion.eagle),
      );
      // Eagle = +6 clue-chance points.
      expect(notifier.effectiveClueChance, before + 6);
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

  // ---------------------------------------------------------------------------
  // Item B7: daily-streak completion must use the dateKey captured at
  // screen-open time, not "today" recomputed at completion time (UTC
  // midnight boundary bug).
  // ---------------------------------------------------------------------------

  group('AccountState.computeStreakAfterCompletion (item B7)', () {
    test('first-ever completion starts the streak at 1', () {
      const streak = DailyStreak();
      final result =
          AccountState.computeStreakAfterCompletion(streak, '2026-07-06');

      expect(result.currentStreak, 1);
      expect(result.longestStreak, 1);
      expect(result.lastCompletionDate, '2026-07-06');
      expect(result.totalCompleted, 1);
    });

    test('consecutive-day completion increments the streak', () {
      const streak = DailyStreak(
        currentStreak: 3,
        longestStreak: 3,
        lastCompletionDate: '2026-07-05',
        totalCompleted: 3,
      );
      final result =
          AccountState.computeStreakAfterCompletion(streak, '2026-07-06');

      expect(result.currentStreak, 4);
      expect(result.longestStreak, 4);
      expect(result.lastCompletionDate, '2026-07-06');
    });

    test('a gap of more than one day resets the streak to 1', () {
      const streak = DailyStreak(
        currentStreak: 5,
        longestStreak: 10,
        lastCompletionDate: '2026-07-01',
        totalCompleted: 20,
      );
      final result =
          AccountState.computeStreakAfterCompletion(streak, '2026-07-06');

      expect(result.currentStreak, 1);
      expect(result.longestStreak, 10); // All-time max is preserved.
    });

    test(
      'UTC-midnight boundary: completing right after midnight with the '
      'dateKey captured BEFORE midnight still stamps the earlier day and '
      'keeps the streak alive',
      () {
        // Player completed yesterday (7/5) and started a new run just before
        // midnight on 7/6, finishing just after — the captured dateKey is
        // 7/6 (the day the run started on), which is one day after the last
        // completion, so the streak must extend to 2, NOT reset to 1 as it
        // would if the wall-clock date at completion time (7/7) were used
        // instead of the captured dateKey.
        const streak = DailyStreak(
          currentStreak: 1,
          longestStreak: 1,
          lastCompletionDate: '2026-07-05',
          totalCompleted: 1,
        );
        const capturedDateKey = '2026-07-06'; // captured at screen-open

        final result = AccountState.computeStreakAfterCompletion(
          streak,
          capturedDateKey,
        );

        expect(result.currentStreak, 2);
        expect(result.lastCompletionDate, '2026-07-06');
      },
    );

    test(
      'completing again for the same dateKey does not double-increment',
      () {
        const streak = DailyStreak(
          currentStreak: 2,
          longestStreak: 2,
          lastCompletionDate: '2026-07-06',
          totalCompleted: 2,
        );
        final result =
            AccountState.computeStreakAfterCompletion(streak, '2026-07-06');

        expect(result.currentStreak, 2); // Unchanged — already done today.
      },
    );
  });

  group('AccountNotifier.recordDailyChallengeCompletion (item B7)', () {
    test('threading an explicit dateKey stamps that day, not "now"', () {
      final notifier = AccountNotifier();
      notifier.switchAccount(
        notifier.state.currentPlayer.copyWith(id: 'u1', username: 'pilot'),
      );

      notifier.recordDailyChallengeCompletion(dateKey: '2020-01-01');

      expect(notifier.state.lastDailyChallengeDate, '2020-01-01');
      expect(notifier.state.dailyStreak.lastCompletionDate, '2020-01-01');
      expect(notifier.state.dailyStreak.currentStreak, 1);
      notifier.dispose();
    });

    test('omitting dateKey falls back to recomputing "today"', () {
      final notifier = AccountNotifier();
      final today = AccountState.todayDateKey();

      notifier.recordDailyChallengeCompletion();

      expect(notifier.state.lastDailyChallengeDate, today);
      notifier.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Item B8: coin lost-update race — applying a server snapshot while a
  // spend is in-flight must not clobber optimistic local state, and owned
  // sets must be unioned (never replaced) with the server's view.
  // ---------------------------------------------------------------------------

  group('AccountState.mergeServerSnapshot (item B8)', () {
    const localPlayer = Player(id: 'u1', username: 'pilot', coins: 40);
    const serverPlayer = Player(id: 'u1', username: 'pilot', coins: 100);

    test('returns null (skips) when a spend is in flight', () {
      final local = AccountState(
        currentPlayer: localPlayer,
        ownedCosmetics: const {'plane_default', 'plane_freshly_bought'},
      );

      final merged = AccountState.mergeServerSnapshot(
        local: local,
        resolvedPlayer: serverPlayer,
        serverOwnedCosmetics: const {'plane_default'},
        serverOwnedAvatarParts: const {},
        sameUser: true,
        spendInFlight: true,
      );

      expect(merged, isNull);
    });

    test(
      'unions owned cosmetics/avatar parts with local state instead of '
      'replacing them when sameUser is true',
      () {
        final local = AccountState(
          currentPlayer: localPlayer,
          ownedCosmetics: const {'plane_default', 'plane_freshly_bought'},
          ownedAvatarParts: const {'hat_freshly_bought'},
        );

        final merged = AccountState.mergeServerSnapshot(
          local: local,
          resolvedPlayer: serverPlayer,
          serverOwnedCosmetics: const {'plane_default', 'plane_server_owned'},
          serverOwnedAvatarParts: const {'hat_server_owned'},
          sameUser: true,
          spendInFlight: false,
        );

        expect(merged, isNotNull);
        // The freshly-bought item (not yet reflected server-side) survives.
        expect(merged!.ownedCosmetics, contains('plane_freshly_bought'));
        // The server's own item is present too — a true union.
        expect(merged.ownedCosmetics, contains('plane_server_owned'));
        expect(merged.ownedAvatarParts, contains('hat_freshly_bought'));
        expect(merged.ownedAvatarParts, contains('hat_server_owned'));
        expect(merged.currentPlayer.coins, 100);
      },
    );

    test(
      'replaces owned sets wholesale on a different user / fresh login '
      '(sameUser is false) so a previous account cannot leak in',
      () {
        final local = AccountState(
          currentPlayer: localPlayer,
          ownedCosmetics: const {'plane_previous_user_item'},
        );

        final merged = AccountState.mergeServerSnapshot(
          local: local,
          resolvedPlayer: serverPlayer,
          serverOwnedCosmetics: const {'plane_server_owned'},
          serverOwnedAvatarParts: const {},
          sameUser: false,
          spendInFlight: false,
        );

        expect(merged!.ownedCosmetics, equals({'plane_server_owned'}));
        expect(
          merged.ownedCosmetics,
          isNot(contains('plane_previous_user_item')),
        );
      },
    );
  });

  group('AccountNotifier purchase revert on server rejection (item B8)', () {
    test(
      'purchaseRpcRejected identifies an explicit success:false result',
      () {
        expect(
          AccountState.purchaseRpcRejected(
            {'success': false, 'error': 'nope'},
          ),
          isTrue,
        );
        expect(AccountState.purchaseRpcRejected({'success': true}), isFalse);
        expect(AccountState.purchaseRpcRejected(null), isFalse);
      },
    );

    test(
      'revertOptimisticCosmeticPurchase restores coins and removes the '
      'granted cosmetic',
      () {
        final state = AccountState(
          currentPlayer: const Player(id: 'u1', username: 'pilot', coins: 400),
          ownedCosmetics: const {'plane_default', 'plane_new_purchase'},
        );

        final reverted = AccountState.revertOptimisticCosmeticPurchase(
          state,
          cosmeticId: 'plane_new_purchase',
          cost: 500,
        );

        expect(reverted.currentPlayer.coins, 900);
        expect(
          reverted.ownedCosmetics,
          isNot(contains('plane_new_purchase')),
        );
        expect(reverted.ownedCosmetics, contains('plane_default'));
      },
    );

    test(
      'revertOptimisticAvatarPartPurchase restores coins and removes the '
      'granted part',
      () {
        final state = AccountState(
          currentPlayer: const Player(id: 'u1', username: 'pilot', coins: 100),
          ownedAvatarParts: const {'hat_new_purchase'},
        );

        final reverted = AccountState.revertOptimisticAvatarPartPurchase(
          state,
          partKey: 'hat_new_purchase',
          cost: 200,
        );

        expect(reverted.currentPlayer.coins, 300);
        expect(
          reverted.ownedAvatarParts,
          isNot(contains('hat_new_purchase')),
        );
      },
    );

    test(
      'purchaseCosmetic followed by an unreachable server validation keeps '
      'the optimistic purchase (network errors do not revert)',
      () async {
        final notifier = AccountNotifier();
        notifier.switchAccount(
          notifier.state.currentPlayer.copyWith(id: 'u1', username: 'pilot'),
        );
        notifier.addCoins(1000, applyBoost: false, source: 'test_grant');

        final coinsBefore = notifier.state.currentPlayer.coins;
        expect(notifier.purchaseCosmetic('plane_new_purchase', 500), isTrue);
        // Optimistic apply happened immediately.
        expect(notifier.state.currentPlayer.coins, coinsBefore - 500);
        expect(
          notifier.state.ownedCosmetics,
          contains('plane_new_purchase'),
        );

        // Supabase isn't initialized in unit tests, so the fire-and-forget
        // server validation call throws and is caught internally (this
        // exercises the same code path as an unreachable backend). Give the
        // microtask queue a turn so the catch branch runs.
        await Future<void>.delayed(Duration.zero);

        // No live RPC ran, so nothing was confirmed OR rejected — the
        // optimistic purchase remains (network-error path intentionally does
        // NOT revert; see _serverValidatePurchase doc).
        expect(notifier.state.currentPlayer.coins, coinsBefore - 500);
        expect(
          notifier.state.ownedCosmetics,
          contains('plane_new_purchase'),
        );
        notifier.dispose();
      },
    );
  });
}
