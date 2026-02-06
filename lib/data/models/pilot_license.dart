import 'dart:math';

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
/// Each license has three boost percentages (1-10) and a preferred clue type.
/// Higher stat values are exponentially rarer, making a perfect license
/// extraordinarily unlikely.
class PilotLicense {
  const PilotLicense({
    required this.coinBoost,
    required this.clueBoost,
    required this.clueChance,
    required this.fuelBoost,
    required this.preferredClueType,
  });

  /// Bonus coin percentage earned per game (1-10).
  final int coinBoost;

  /// Bonus percentage chance of receiving [preferredClueType] clues (1-10).
  final int clueBoost;

  /// Bonus percentage chance of receiving extra clues (1-10).
  final int clueChance;

  /// Bonus fuel / speed-boost duration percentage in solo play (1-10).
  final int fuelBoost;

  /// Which clue type receives the [clueBoost] bonus.
  final String preferredClueType;

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

  /// Scaling cost to lock a stat based on its current value (1-10).
  /// Low values (1-3) are cheap to lock, high values (7-10) are expensive.
  static int lockCostForValue(int statValue) {
    if (statValue <= 1) return 0;
    if (statValue <= 3) return 50;
    if (statValue <= 5) return 150;
    if (statValue <= 7) return 400;
    if (statValue <= 9) return 1000;
    return 2500; // value == 10
  }

  // ---------------------------------------------------------------------------
  // Random generation
  // ---------------------------------------------------------------------------

  /// Weighted stat roll table.
  ///
  /// Distribution:
  ///   1-3  : ~60 %  (common)
  ///   4-6  : ~25 %  (uncommon)
  ///   7-8  : ~10 %  (rare)
  ///   9    : ~4  %  (epic)
  ///   10   : ~1  %  (legendary)
  ///
  /// Implemented as a 100-entry lookup table for O(1) rolls.
  static const List<int> _weightTable = [
    // 1-3 common — 20 entries each = 60 total
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //  1 x20
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, //  2 x20
    3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, //  3 x20
    // 4-6 uncommon — ~8-9 entries each = 25 total
    4, 4, 4, 4, 4, 4, 4, 4, 4, //  4 x9
    5, 5, 5, 5, 5, 5, 5, 5,    //  5 x8
    6, 6, 6, 6, 6, 6, 6, 6,    //  6 x8
    // 7-8 rare — 5 entries each = 10 total
    7, 7, 7, 7, 7, //  7 x5
    8, 8, 8, 8, 8, //  8 x5
    // 9 epic — 4 entries
    9, 9, 9, 9, //  9 x4
    // 10 legendary — 1 entry
    10, // 10 x1
  ];

  /// Roll a single stat value (1-10) using the rarity-weighted distribution.
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
      clueBoost: rollStat(rng: rng, luckBonus: luckBonus),
      clueChance: rollStat(rng: rng, luckBonus: luckBonus),
      fuelBoost: rollStat(rng: rng, luckBonus: luckBonus),
      preferredClueType: rollClueType(rng),
    );
  }

  /// Reroll a license, keeping any stats whose keys are in [lockedStats].
  ///
  /// Valid keys for [lockedStats]: `'coinBoost'`, `'clueBoost'`,
  /// `'clueChance'`, `'fuelBoost'`.
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
      clueBoost: lockedStats.contains('clueBoost')
          ? current.clueBoost
          : rollStat(rng: rng, luckBonus: luckBonus),
      clueChance: lockedStats.contains('clueChance')
          ? current.clueChance
          : rollStat(rng: rng, luckBonus: luckBonus),
      fuelBoost: lockedStats.contains('fuelBoost')
          ? current.fuelBoost
          : rollStat(rng: rng, luckBonus: luckBonus),
      preferredClueType: lockType
          ? current.preferredClueType
          : rollClueType(rng),
    );
  }

  // ---------------------------------------------------------------------------
  // Display helpers
  // ---------------------------------------------------------------------------

  /// Human-readable coin boost, e.g. "+5% Coins".
  String get coinBoostLabel => '+$coinBoost% Coins';

  /// Human-readable clue boost including the type.
  String get clueBoostLabel {
    final typeLabel =
        '${preferredClueType[0].toUpperCase()}${preferredClueType.substring(1)}';
    return '$typeLabel Clue Type';
  }

  /// Human-readable clue chance, e.g. "+5% Clue Chance".
  String get clueChanceLabel => '+$clueChance% Clue Chance';

  /// Human-readable fuel boost, e.g. "+7% Fuel".
  String get fuelBoostLabel => '+$fuelBoost% Fuel';

  /// Sum of all four boosts (useful for ranking / comparison).
  int get totalBoost => coinBoost + clueBoost + clueChance + fuelBoost;

  /// Rarity tier derived from [totalBoost].
  ///
  ///   4-12  → Bronze
  ///   13-22 → Silver
  ///   23-32 → Gold
  ///   33-38 → Diamond
  ///   39-40 → Perfect
  String get rarityTier {
    if (totalBoost >= 39) return 'Perfect';
    if (totalBoost >= 33) return 'Diamond';
    if (totalBoost >= 23) return 'Gold';
    if (totalBoost >= 13) return 'Silver';
    return 'Bronze';
  }

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  PilotLicense copyWith({
    int? coinBoost,
    int? clueBoost,
    int? clueChance,
    int? fuelBoost,
    String? preferredClueType,
  }) =>
      PilotLicense(
        coinBoost: coinBoost ?? this.coinBoost,
        clueBoost: clueBoost ?? this.clueBoost,
        clueChance: clueChance ?? this.clueChance,
        fuelBoost: fuelBoost ?? this.fuelBoost,
        preferredClueType: preferredClueType ?? this.preferredClueType,
      );

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'coin_boost': coinBoost,
        'clue_boost': clueBoost,
        'clue_chance': clueChance,
        'fuel_boost': fuelBoost,
        'preferred_clue_type': preferredClueType,
      };

  factory PilotLicense.fromJson(Map<String, dynamic> json) => PilotLicense(
        coinBoost: json['coin_boost'] as int,
        clueBoost: json['clue_boost'] as int,
        clueChance: json['clue_chance'] as int? ?? 1,
        fuelBoost: json['fuel_boost'] as int,
        preferredClueType: json['preferred_clue_type'] as String,
      );
}
