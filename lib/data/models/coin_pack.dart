import 'package:flutter/foundation.dart';

/// Coin-pack IAP groundwork: catalog + purchase gateway abstraction.
///
/// There is NO real store integration yet. The catalog mirrors the
/// `coin_packs` table (supabase/migrations/20260705_coin_packs.sql) so the
/// server can later validate receipts; the client ships with a hardcoded
/// copy so the shop renders before the migration is applied. All purchases
/// flow through [CoinPackGateway] so wiring StoreKit/Play Billing later is
/// a single implementation swap.
class CoinPack {
  const CoinPack({
    required this.id,
    required this.name,
    required this.coins,
    required this.usdPrice,
    this.bonusLabel,
  });

  final String id;
  final String name;

  /// Coins granted on purchase.
  final int coins;

  /// Display price in USD (real pricing comes from the store at integration
  /// time; this is catalog metadata only).
  final double usdPrice;

  /// Optional marketing label, e.g. `+25% bonus`.
  final String? bonusLabel;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'coins': coins,
        'usd_price': usdPrice,
        'bonus_label': bonusLabel,
      };

  factory CoinPack.fromJson(Map<String, dynamic> json) => CoinPack(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        coins: json['coins'] as int? ?? 0,
        usdPrice: (json['usd_price'] as num?)?.toDouble() ?? 0,
        bonusLabel: json['bonus_label'] as String?,
      );
}

/// Static catalog (kept in sync with the coin_packs migration seed rows).
abstract class CoinPackCatalog {
  static const List<CoinPack> packs = [
    CoinPack(
      id: 'coin_pack_pocket',
      name: 'Pocket Change',
      coins: 500,
      usdPrice: 1.99,
    ),
    CoinPack(
      id: 'coin_pack_duffel',
      name: 'Duffel Bag',
      coins: 1500,
      usdPrice: 4.99,
      bonusLabel: '+20% bonus',
    ),
    CoinPack(
      id: 'coin_pack_crate',
      name: 'Cargo Crate',
      coins: 4000,
      usdPrice: 9.99,
      bonusLabel: '+60% bonus',
    ),
    CoinPack(
      id: 'coin_pack_vault',
      name: 'Sky Vault',
      coins: 10000,
      usdPrice: 19.99,
      bonusLabel: 'Best value',
    ),
  ];

  static CoinPack? getById(String id) {
    for (final p in packs) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// Result of a coin-pack purchase attempt.
enum CoinPackPurchaseStatus {
  /// Purchase completed — credit [CoinPackPurchaseResult.coinsGranted].
  success,

  /// Store integration not available yet (the stub always returns this).
  unavailable,

  /// User cancelled or the store declined.
  failed,
}

class CoinPackPurchaseResult {
  const CoinPackPurchaseResult({required this.status, this.coinsGranted = 0});

  final CoinPackPurchaseStatus status;
  final int coinsGranted;
}

/// Abstraction over the platform store. Swap [CoinPackGateway.instance] for
/// a StoreKit/Play Billing implementation when IAP ships.
abstract class CoinPackGateway {
  /// Active gateway. Replaceable in tests and at IAP integration time.
  static CoinPackGateway instance = StubCoinPackGateway();

  Future<CoinPackPurchaseResult> purchase(CoinPack pack);

  /// Whether real purchases can be made on this platform right now.
  bool get isAvailable;
}

/// Placeholder gateway: no store integration yet. Always reports
/// [CoinPackPurchaseStatus.unavailable] so the UI can show a
/// "coming soon" state without any platform code.
class StubCoinPackGateway implements CoinPackGateway {
  @override
  bool get isAvailable => false;

  @override
  Future<CoinPackPurchaseResult> purchase(CoinPack pack) async {
    debugPrint('[StubCoinPackGateway] purchase(${pack.id}) — IAP not wired');
    return const CoinPackPurchaseResult(
      status: CoinPackPurchaseStatus.unavailable,
    );
  }
}
