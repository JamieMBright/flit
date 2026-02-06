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
    required this.fuelBoost,
    required this.preferredClueType,
  });

  /// Bonus coin percentage earned per game (1-10).
  final int coinBoost;

  /// Bonus percentage chance of receiving [preferredClueType] clues (1-10).
  final int clueBoost;

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
  static int rollStat([Random? rng]) {
    final random = rng ?? Random();
    return _weightTable[random.nextInt(_weightTable.length)];
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
  factory PilotLicense.random([Random? rng]) {
    return PilotLicense(
      coinBoost: rollStat(rng),
      clueBoost: rollStat(rng),
      fuelBoost: rollStat(rng),
      preferredClueType: rollClueType(rng),
    );
  }

  /// Reroll a license, keeping any stats whose keys are in [lockedStats].
  ///
  /// Valid keys for [lockedStats]: `'coinBoost'`, `'clueBoost'`, `'fuelBoost'`.
  /// If [lockType] is true the [preferredClueType] is preserved.
  factory PilotLicense.reroll(
    PilotLicense current, {
    Set<String> lockedStats = const {},
    bool lockType = false,
    Random? rng,
  }) {
    return PilotLicense(
      coinBoost: lockedStats.contains('coinBoost')
          ? current.coinBoost
          : rollStat(rng),
      clueBoost: lockedStats.contains('clueBoost')
          ? current.clueBoost
          : rollStat(rng),
      fuelBoost: lockedStats.contains('fuelBoost')
          ? current.fuelBoost
          : rollStat(rng),
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

  /// Human-readable clue boost including the type, e.g. "+3% Flag Clues".
  String get clueBoostLabel {
    final typeLabel =
        '${preferredClueType[0].toUpperCase()}${preferredClueType.substring(1)}';
    return '+$clueBoost% $typeLabel Clues';
  }

  /// Human-readable fuel boost, e.g. "+7% Fuel".
  String get fuelBoostLabel => '+$fuelBoost% Fuel';

  /// Sum of all three boosts (useful for ranking / comparison).
  int get totalBoost => coinBoost + clueBoost + fuelBoost;

  /// Rarity tier derived from [totalBoost].
  ///
  ///   3-9   → Bronze
  ///   10-17 → Silver
  ///   18-24 → Gold
  ///   25-29 → Diamond
  ///   30    → Perfect
  String get rarityTier {
    if (totalBoost >= 30) return 'Perfect';
    if (totalBoost >= 25) return 'Diamond';
    if (totalBoost >= 18) return 'Gold';
    if (totalBoost >= 10) return 'Silver';
    return 'Bronze';
  }

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  PilotLicense copyWith({
    int? coinBoost,
    int? clueBoost,
    int? fuelBoost,
    String? preferredClueType,
  }) =>
      PilotLicense(
        coinBoost: coinBoost ?? this.coinBoost,
        clueBoost: clueBoost ?? this.clueBoost,
        fuelBoost: fuelBoost ?? this.fuelBoost,
        preferredClueType: preferredClueType ?? this.preferredClueType,
      );

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'coin_boost': coinBoost,
        'clue_boost': clueBoost,
        'fuel_boost': fuelBoost,
        'preferred_clue_type': preferredClueType,
      };

  factory PilotLicense.fromJson(Map<String, dynamic> json) => PilotLicense(
        coinBoost: json['coin_boost'] as int,
        clueBoost: json['clue_boost'] as int,
        fuelBoost: json['fuel_boost'] as int,
        preferredClueType: json['preferred_clue_type'] as String,
      );
}
