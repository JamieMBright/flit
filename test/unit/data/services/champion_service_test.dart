import 'package:flutter_test/flutter_test.dart';

import 'package:flit/data/services/champion_service.dart';
import 'package:flit/game/economy/consumables.dart';

void main() {
  setUp(() => ChampionService.instance.resetSessionGuard());

  group('client fallback (RPC missing / Supabase unavailable)', () {
    // In unit tests Supabase is never initialised, which throws on first
    // touch — the exact same degrade path as an undeployed RPC or a
    // network failure. The service must swallow it and return "no reward".
    test('claimDailyChampion returns null instead of throwing', () async {
      final reward = await ChampionService.instance.claimDailyChampion(
        gameMode: 'daily',
        date: DateTime.utc(2026, 7, 4),
      );
      expect(reward, isNull);
    });

    test('checkAndClaimYesterday returns empty instead of throwing', () async {
      final rewards = await ChampionService.instance.checkAndClaimYesterday();
      expect(rewards, isEmpty);
    });

    test('checkAndClaimYesterday only checks once per day per session',
        () async {
      // First call performs the (failing) checks; the second short-circuits
      // on the day guard. Both must be safe no-ops.
      final first = await ChampionService.instance.checkAndClaimYesterday();
      final second = await ChampionService.instance.checkAndClaimYesterday();
      expect(first, isEmpty);
      expect(second, isEmpty);
    });
  });

  group('reward mapping', () {
    test('server reward ids map to consumable types', () {
      expect(
        ConsumableTypeInfo.fromId('license_polish'),
        ConsumableType.licensePolish,
      );
      expect(
        ConsumableTypeInfo.fromId('gold_surge'),
        ConsumableType.goldSurge,
      );
      expect(ConsumableTypeInfo.fromId('xp_surge'), ConsumableType.xpSurge);
      expect(
        ConsumableTypeInfo.fromId('refuel_canister'),
        ConsumableType.refuelCanister,
      );
      // Unknown ids (future rewards) degrade to null, never crash.
      expect(ConsumableTypeInfo.fromId('mystery_item'), isNull);
    });

    test('board labels are player-facing', () {
      const reward = ChampionReward(
        gameMode: 'daily_triangulation',
        date: '2026-07-04',
        reward: ConsumableType.goldSurge,
      );
      expect(reward.boardLabel, 'Daily Recon');
    });
  });
}
