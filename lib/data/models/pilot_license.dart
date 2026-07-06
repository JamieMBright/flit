import 'dart:math';

import '../../game/economy/license_heat.dart';

/// Valid clue types a pilot can specialize in.
const List<String> clueTypes = [
  'flag',
  'outline',
  'borders',
  'capital',
  'stats',
];

/// A pilot license with gacha-rolled stat boosts.
///
/// Each license has three boost percentages (1-25) and a preferred clue type.
/// Higher stat values are exponentially rarer, making a perfect license
/// extraordinarily unlikely.
///
/// Base stats are PERMANENT — they never decay. On top of them sits the
/// [heat] state: big performances pump the license HOT for ~72h, adding
/// [LicenseHeat.hotStatBonus] to every stat (see `effectiveCoinBoost` etc.).
class PilotLicense {
  const PilotLicense({
    required this.coinBoost,
    required this.clueChance,
    required this.fuelBoost,
    required this.preferredClueType,
    this.nationality,
    this.heat = const LicenseHeat(),
  });

  /// Bonus coin percentage earned per game (1-25).
  final int coinBoost;

  /// Bonus percentage chance of receiving extra clues (1-25).
  final int clueChance;

  /// Fuel efficiency bonus percentage in solo play (1-25).
  /// Reduces fuel burn rate: effective efficiency = plane × (1 + fuelBoost/100).
  final int fuelBoost;

  /// Which clue type the pilot prefers.
  final String preferredClueType;

  /// Player's nationality as ISO 3166-1 alpha-2 code (e.g. 'GB', 'US', 'JP').
  /// null means not set.
  final String? nationality;

  /// Hot-license pump state + reroll pity/escalation counters.
  /// Persisted alongside the stats inside `license_data` JSONB.
  final LicenseHeat heat;

  // ---------------------------------------------------------------------------
  // Effective (hot-adjusted) stats
  // ---------------------------------------------------------------------------

  /// Whether the license is currently pumped HOT.
  bool isHot(DateTime now) => heat.isHot(now);

  /// Coin boost including the hot pump bonus.
  int effectiveCoinBoost(DateTime now) => coinBoost + heat.statBonus(now);

  /// Clue chance including the hot pump bonus.
  int effectiveClueChance(DateTime now) => clueChance + heat.statBonus(now);

  /// Fuel boost including the hot pump bonus.
  int effectiveFuelBoost(DateTime now) => fuelBoost + heat.statBonus(now);

  // ---------------------------------------------------------------------------
  // Reroll costs (in coins)
  // ---------------------------------------------------------------------------

  /// Cost to reroll all 3 stats and the clue type.
  static const int rerollAllCost = 100;

  /// Cost to lock 1 stat and reroll the other 2 stats (+ clue type if unlocked).
  static const int lockOneCost = 250;

  /// Cost to lock 2 stats and reroll the remaining 1 stat (+ clue type if unlocked).
  static const int lockTwoCost = 500;

  /// Additional cost to lock the preferred clue type during a reroll.
  static const int lockTypeCost = 150;

  /// Scaling cost to lock a stat based on its current value (1-25).
  /// Low values (1-5) are cheap to lock, high values (21-25) are expensive.
  static int lockCostForValue(int statValue) {
    if (statValue <= 1) return 0;
    if (statValue <= 5) return 50;
    if (statValue <= 10) return 150;
    if (statValue <= 15) return 400;
    if (statValue <= 20) return 1000;
    return 2500; // value 21-25
  }

  // ---------------------------------------------------------------------------
  // Random generation
  // ---------------------------------------------------------------------------

  /// Weighted stat roll table (steep — the license is a long-term chase).
  ///
  /// Approx per-stat probability (denominator 950):
  ///   1-5  : ~65 %   (common — the overwhelming majority of rolls)
  ///   6-10 : ~25 %   (uncommon)
  ///   11-15: ~7 %    (rare)
  ///   16-19: ~1.9 %  (epic)
  ///   20-22: ~0.7 %  (legendary — a single 20+ stat is a ~1% tail event)
  ///   23-24: ~0.2 %  (near-mythical)
  ///   25   : ~0.1 %  (perfect — roughly 1 in 950 per stat draw)
  ///
  /// Steepened hard after playtesting showed a 23/25 landing by the third
  /// reroll — good outcomes must be RARE and slow so rerolling stays a
  /// meaningful (spend-encouraging) grind rather than solved in a few tries.
  /// Combined with stat-locking + hot-pump + pity, a top-tier license is a
  /// genuine long game. Implemented as a lookup table for O(1) rolls.
  static final List<int> _weightTable = [
    for (var i = 0; i < 140; i++) 1,
    for (var i = 0; i < 135; i++) 2,
    for (var i = 0; i < 125; i++) 3,
    for (var i = 0; i < 115; i++) 4,
    for (var i = 0; i < 105; i++) 5,
    for (var i = 0; i < 65; i++) 6,
    for (var i = 0; i < 55; i++) 7,
    for (var i = 0; i < 45; i++) 8,
    for (var i = 0; i < 38; i++) 9,
    for (var i = 0; i < 32; i++) 10,
    for (var i = 0; i < 20; i++) 11,
    for (var i = 0; i < 16; i++) 12,
    for (var i = 0; i < 13; i++) 13,
    for (var i = 0; i < 10; i++) 14,
    for (var i = 0; i < 8; i++) 15,
    for (var i = 0; i < 6; i++) 16,
    for (var i = 0; i < 5; i++) 17,
    for (var i = 0; i < 4; i++) 18,
    for (var i = 0; i < 3; i++) 19,
    for (var i = 0; i < 3; i++) 20,
    for (var i = 0; i < 2; i++) 21,
    for (var i = 0; i < 2; i++) 22,
    23,
    24,
    25,
  ];

  /// Roll a single stat value (1-25) using the rarity-weighted distribution.
  ///
  /// When [luckBonus] > 0, the roll is attempted multiple times and the
  /// best result is kept. This simulates "advantage" — rarer avatars give
  /// better licence odds.
  static int rollStat({Random? rng, int luckBonus = 0}) {
    final random = rng ?? Random();
    var best = _weightTable[random.nextInt(_weightTable.length)];
    for (var i = 0; i < luckBonus; i++) {
      final roll = _weightTable[random.nextInt(_weightTable.length)];
      if (roll > best) best = roll;
    }
    return best;
  }

  /// Roll a random clue type string.
  static String rollClueType([Random? rng]) {
    final random = rng ?? Random();
    return clueTypes[random.nextInt(clueTypes.length)];
  }

  // ---------------------------------------------------------------------------
  // Factory constructors
  // ---------------------------------------------------------------------------

  /// Generate a completely random license.
  ///
  /// When [luckBonus] > 0, each stat is rolled multiple times and the best
  /// result is kept (rarer avatars give better licence odds).
  factory PilotLicense.random({Random? rng, int luckBonus = 0}) {
    return PilotLicense(
      coinBoost: rollStat(rng: rng, luckBonus: luckBonus),
      clueChance: rollStat(rng: rng, luckBonus: luckBonus),
      fuelBoost: rollStat(rng: rng, luckBonus: luckBonus),
      preferredClueType: rollClueType(rng),
    );
  }

  /// Reroll a license, keeping any stats whose keys are in [lockedStats].
  ///
  /// Valid keys for [lockedStats]: `'coinBoost'`, `'clueChance'`, `'fuelBoost'`.
  /// If [lockType] is true the [preferredClueType] is preserved.
  /// When [luckBonus] > 0, unlocked stats get advantage rolls.
  factory PilotLicense.reroll(
    PilotLicense current, {
    Set<String> lockedStats = const {},
    bool lockType = false,
    Random? rng,
    int luckBonus = 0,
  }) {
    return PilotLicense(
      coinBoost: lockedStats.contains('coinBoost')
          ? current.coinBoost
          : rollStat(rng: rng, luckBonus: luckBonus),
      clueChance: lockedStats.contains('clueChance')
          ? current.clueChance
          : rollStat(rng: rng, luckBonus: luckBonus),
      fuelBoost: lockedStats.contains('fuelBoost')
          ? current.fuelBoost
          : rollStat(rng: rng, luckBonus: luckBonus),
      preferredClueType:
          lockType ? current.preferredClueType : rollClueType(rng),
      nationality: current.nationality, // Preserve across rerolls
      heat: current.heat, // Heat/pity state survives rerolls too
    );
  }

  // ---------------------------------------------------------------------------
  // Display helpers
  // ---------------------------------------------------------------------------

  /// Human-readable coin boost, e.g. "+5% Extra Coins".
  String get coinBoostLabel => '+$coinBoost% Extra Coins';

  /// Human-readable clue type, e.g. "Clue Type: Flag".
  String get clueTypeLabel {
    final typeLabel =
        '${preferredClueType[0].toUpperCase()}${preferredClueType.substring(1)}';
    return 'Clue Type: $typeLabel';
  }

  /// Human-readable clue chance, e.g. "+5% Clue Chance".
  String get clueChanceLabel => '+$clueChance% Clue Chance';

  /// Human-readable fuel boost, e.g. "+7% Fuel Efficiency".
  String get fuelBoostLabel => '+$fuelBoost% Fuel Efficiency';

  /// Sum of all three boosts (useful for ranking / comparison).
  int get totalBoost => coinBoost + clueChance + fuelBoost;

  /// Rarity tier derived from [totalBoost].
  ///
  ///   3-18  → Bronze
  ///   19-37 → Silver
  ///   38-56 → Gold
  ///   57-68 → Diamond
  ///   69-75 → Perfect
  String get rarityTier {
    if (totalBoost >= 69) return 'Perfect';
    if (totalBoost >= 57) return 'Diamond';
    if (totalBoost >= 38) return 'Gold';
    if (totalBoost >= 19) return 'Silver';
    return 'Bronze';
  }

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  PilotLicense copyWith({
    int? coinBoost,
    int? clueChance,
    int? fuelBoost,
    String? preferredClueType,
    String? nationality,
    LicenseHeat? heat,
  }) =>
      PilotLicense(
        coinBoost: coinBoost ?? this.coinBoost,
        clueChance: clueChance ?? this.clueChance,
        fuelBoost: fuelBoost ?? this.fuelBoost,
        preferredClueType: preferredClueType ?? this.preferredClueType,
        nationality: nationality ?? this.nationality,
        heat: heat ?? this.heat,
      );

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'coin_boost': coinBoost,
        'clue_chance': clueChance,
        'fuel_boost': fuelBoost,
        'preferred_clue_type': preferredClueType,
        'nationality': nationality,
        'heat': heat.toJson(),
      };

  factory PilotLicense.fromJson(Map<String, dynamic> json) => PilotLicense(
        coinBoost: json['coin_boost'] as int,
        clueChance: json['clue_chance'] as int? ?? 1,
        fuelBoost: json['fuel_boost'] as int,
        preferredClueType: json['preferred_clue_type'] as String,
        nationality: json['nationality'] as String?,
        heat: LicenseHeat.fromJson(
          json['heat'] is Map
              ? Map<String, dynamic>.from(json['heat'] as Map)
              : null,
        ),
      );
}
