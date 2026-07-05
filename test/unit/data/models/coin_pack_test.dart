import 'package:flutter_test/flutter_test.dart';

import 'package:flit/data/models/coin_pack.dart';

void main() {
  group('CoinPackCatalog', () {
    test('has packs with ascending value', () {
      expect(CoinPackCatalog.packs, isNotEmpty);
      for (var i = 1; i < CoinPackCatalog.packs.length; i++) {
        expect(
          CoinPackCatalog.packs[i].coins,
          greaterThan(CoinPackCatalog.packs[i - 1].coins),
        );
        expect(
          CoinPackCatalog.packs[i].usdPrice,
          greaterThan(CoinPackCatalog.packs[i - 1].usdPrice),
        );
      }
    });

    test('bigger packs give more coins per dollar', () {
      final first = CoinPackCatalog.packs.first;
      final last = CoinPackCatalog.packs.last;
      expect(
        last.coins / last.usdPrice,
        greaterThan(first.coins / first.usdPrice),
      );
    });

    test('getById resolves ids', () {
      expect(CoinPackCatalog.getById('coin_pack_pocket')?.coins, 500);
      expect(CoinPackCatalog.getById('nope'), isNull);
    });

    test('round-trips through JSON', () {
      final pack = CoinPackCatalog.packs[1];
      final restored = CoinPack.fromJson(pack.toJson());
      expect(restored.id, pack.id);
      expect(restored.coins, pack.coins);
      expect(restored.usdPrice, pack.usdPrice);
      expect(restored.bonusLabel, pack.bonusLabel);
    });
  });

  group('CoinPackGateway stub', () {
    test('is not available and never grants coins', () async {
      final gateway = StubCoinPackGateway();
      expect(gateway.isAvailable, isFalse);
      final result = await gateway.purchase(CoinPackCatalog.packs.first);
      expect(result.status, CoinPackPurchaseStatus.unavailable);
      expect(result.coinsGranted, 0);
    });

    test('gateway is swappable behind the abstraction', () async {
      final original = CoinPackGateway.instance;
      addTearDown(() => CoinPackGateway.instance = original);
      CoinPackGateway.instance = _FakeGateway();
      final result =
          await CoinPackGateway.instance.purchase(CoinPackCatalog.packs.first);
      expect(result.status, CoinPackPurchaseStatus.success);
      expect(result.coinsGranted, 500);
    });
  });
}

class _FakeGateway implements CoinPackGateway {
  @override
  bool get isAvailable => true;

  @override
  Future<CoinPackPurchaseResult> purchase(CoinPack pack) async =>
      CoinPackPurchaseResult(
        status: CoinPackPurchaseStatus.success,
        coinsGranted: pack.coins,
      );
}
