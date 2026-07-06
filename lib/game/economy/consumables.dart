/// Consumable supplies: refuel canisters plus timed boost items.
///
/// Design (owner-approved):
/// - Supplies live in their own SHOP section — nothing consumable is sold in
///   the gold/cosmetic sections.
/// - Bundle pricing gives an economy of scale WITHOUT being cheap: 1x is
///   full price, 3x is ~10% off per unit, 5x is ~15% off per unit — bulk
///   saves per unit but total spend still rises.
/// - Timed effects persist across restarts by storing UTC expiry timestamps
///   in `account_state.license_data` JSONB (client-owned schema) under the
///   `active_effects` key; inventory counts under `consumables`.
///
/// Effect math (kept deliberately simple, per owner spec):
/// - License Polish: +[licensePolishStatBonus] on every license stat for
///   24h. It stacks ADDITIVELY with the HOT pump — if HOT (+5) is active,
///   polish adds its +3 on top for a total of +8. Neither timer touches
///   the other.
/// - Gold Surge: 2x coin earnings for 60 minutes (multiplies the final
///   boosted amount).
/// - XP Surge: 2x XP for 60 minutes.
/// - Activating an effect that is already running extends it: the new
///   window is appended to the remaining time (no waste, no overlap math).
library;

import 'fuel_tank.dart';

/// A consumable supply item.
enum ConsumableType {
  /// One instant full tank for free-flight earning.
  refuelCanister,

  /// +3 all license stats for 24 hours (stacks on top of HOT).
  licensePolish,

  /// 2x coin earnings for 60 minutes.
  goldSurge,

  /// 2x XP for 60 minutes.
  xpSurge,
}

/// Flat license-stat bonus granted while License Polish is active.
const int licensePolishStatBonus = 3;

extension ConsumableTypeInfo on ConsumableType {
  /// Stable string id used for persistence and server reward keys.
  String get id => switch (this) {
        ConsumableType.refuelCanister => 'refuel_canister',
        ConsumableType.licensePolish => 'license_polish',
        ConsumableType.goldSurge => 'gold_surge',
        ConsumableType.xpSurge => 'xp_surge',
      };

  /// Human-facing ITEM name (owner spec: supplies read as collectible items,
  /// e.g. "Log Book", with the effect in [effectLabel] — not "Double XP" as
  /// the title). The stable persistence [id] is unchanged, so these strings
  /// can be reworded freely without breaking saved inventories.
  String get displayName => switch (this) {
        ConsumableType.refuelCanister => 'Refuel Canister',
        ConsumableType.licensePolish => 'License Polish',
        ConsumableType.goldSurge => 'Gold Rush',
        ConsumableType.xpSurge => 'Log Book',
      };

  /// One-line effect description for shop cards and drop toasts.
  String get effectLabel => switch (this) {
        ConsumableType.refuelCanister => 'Instant full earning tank',
        ConsumableType.licensePolish => '+3 all license stats for 24h',
        ConsumableType.goldSurge => 'Doubles coins earned for 60 min',
        ConsumableType.xpSurge => 'Doubles XP earned for 60 min',
      };

  /// Base per-unit coin price (bundles discount from this).
  int get baseCost => switch (this) {
        ConsumableType.refuelCanister => FuelTank.canisterCoinCost,
        ConsumableType.licensePolish => 120,
        ConsumableType.goldSurge => 150,
        ConsumableType.xpSurge => 100,
      };

  /// Effect duration; null for instant-use items (canister).
  Duration? get duration => switch (this) {
        ConsumableType.refuelCanister => null,
        ConsumableType.licensePolish => const Duration(hours: 24),
        ConsumableType.goldSurge => const Duration(minutes: 60),
        ConsumableType.xpSurge => const Duration(minutes: 60),
      };

  /// Whether activating this item starts a timed effect.
  bool get isTimed => duration != null;

  static ConsumableType? fromId(String id) {
    for (final t in ConsumableType.values) {
      if (t.id == id) return t;
    }
    return null;
  }
}

/// Bundle pricing: per-unit discounts that never beat buying less overall.
abstract final class ConsumablePricing {
  /// Supported bundle sizes → per-unit discount fraction.
  /// 1x full price, 3x ~10% off per unit, 5x ~15% off per unit.
  static const Map<int, double> bundleDiscounts = {
    1: 0.0,
    3: 0.10,
    5: 0.15,
  };

  /// Total coin cost for [count] units at [unitCost] each.
  ///
  /// Unknown bundle sizes get no discount (defensive — the shop only
  /// offers the sizes in [bundleDiscounts]).
  static int bundleCost(int unitCost, int count) {
    if (count <= 0) return 0;
    final discount = bundleDiscounts[count] ?? 0.0;
    return (unitCost * count * (1 - discount)).round();
  }

  /// Per-unit price within a bundle (for "45/each" shop labels).
  static double perUnitCost(int unitCost, int count) {
    if (count <= 0) return 0;
    return bundleCost(unitCost, count) / count;
  }
}

/// Immutable inventory of timed consumables.
///
/// Refuel canisters are NOT stored here — they predate this system and
/// keep their dedicated `refuel_canisters` slot in `license_data` (see
/// AccountState.refuelCanisters) so existing player stock is untouched.
class ConsumableInventory {
  const ConsumableInventory([this._counts = const {}]);

  final Map<String, int> _counts;

  int of(ConsumableType type) => _counts[type.id] ?? 0;

  /// Total items held (excludes canisters, which live elsewhere).
  int get totalItems => _counts.values.fold(0, (a, b) => a + (b > 0 ? b : 0));

  ConsumableInventory grant(ConsumableType type, [int count = 1]) {
    if (count <= 0) return this;
    return ConsumableInventory({
      ..._counts,
      type.id: of(type) + count,
    });
  }

  /// Consume one item; returns null when none are held.
  ConsumableInventory? consume(ConsumableType type) {
    final have = of(type);
    if (have <= 0) return null;
    return ConsumableInventory({..._counts, type.id: have - 1});
  }

  Map<String, dynamic> toJson() =>
      {for (final e in _counts.entries) e.key: e.value};

  factory ConsumableInventory.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ConsumableInventory();
    return ConsumableInventory({
      for (final e in json.entries)
        if (e.value is num) e.key: (e.value as num).toInt(),
    });
  }
}

/// Active timed effects, persisted as UTC expiry timestamps so they
/// survive restarts.
class ActiveEffects {
  const ActiveEffects([this._expiries = const {}]);

  /// Consumable id → UTC expiry instant.
  final Map<String, DateTime> _expiries;

  DateTime? expiryOf(ConsumableType type) => _expiries[type.id];

  bool isActive(ConsumableType type, DateTime now) {
    final until = _expiries[type.id];
    return until != null && now.isBefore(until);
  }

  Duration remaining(ConsumableType type, DateTime now) {
    final until = _expiries[type.id];
    if (until == null || !now.isBefore(until)) return Duration.zero;
    return until.difference(now);
  }

  /// All effects active at [now] (for badge/timer chips).
  List<ConsumableType> activeAt(DateTime now) => [
        for (final t in ConsumableType.values)
          if (t.isTimed && isActive(t, now)) t,
      ];

  /// Start (or extend) [type]'s effect at [now].
  ///
  /// Re-activating while active APPENDS the new window to the remaining
  /// time — a second Gold Surge with 20 min left yields 80 min total.
  ActiveEffects activate(ConsumableType type, DateTime now) {
    final duration = type.duration;
    if (duration == null) return this;
    final current = _expiries[type.id];
    final base = (current != null && current.isAfter(now)) ? current : now;
    return ActiveEffects({
      ..._expiries,
      type.id: base.toUtc().add(duration),
    });
  }

  // ---------------------------------------------------------------------------
  // Effect queries (single source of truth for the multiplier math)
  // ---------------------------------------------------------------------------

  /// Coin earnings multiplier (2x while Gold Surge is active).
  double coinMultiplier(DateTime now) =>
      isActive(ConsumableType.goldSurge, now) ? 2.0 : 1.0;

  /// XP multiplier (2x while XP Surge is active).
  int xpMultiplier(DateTime now) =>
      isActive(ConsumableType.xpSurge, now) ? 2 : 1;

  /// Flat license-stat bonus (+3 while License Polish is active). Stacks
  /// additively on top of the HOT pump bonus.
  int licenseStatBonus(DateTime now) =>
      isActive(ConsumableType.licensePolish, now) ? licensePolishStatBonus : 0;

  Map<String, dynamic> toJson() => {
        for (final e in _expiries.entries) e.key: e.value.toIso8601String(),
      };

  factory ActiveEffects.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ActiveEffects();
    final map = <String, DateTime>{};
    for (final e in json.entries) {
      if (e.value is String) {
        final parsed = DateTime.tryParse(e.value as String);
        if (parsed != null) map[e.key] = parsed.toUtc();
      }
    }
    return ActiveEffects(map);
  }
}
