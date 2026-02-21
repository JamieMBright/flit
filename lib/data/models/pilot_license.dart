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
/// Each license has three boost percentages (1-25) and a preferred clue type.
/// Higher stat values are exponentially rarer, making a perfect license
/// extraordinarily unlikely.
class PilotLicense {
  const PilotLicense({
    required this.coinBoost,
    required this.clueBoost,
    required this.clueChance,
    required this.fuelBoost,
    required this.preferredClueType,
    this.nationality,
  });

  /// Bonus coin percentage earned per game (1-25).
  final int coinBoost;

  /// Bonus percentage chance of receiving [preferredClueType] clues (1-25).
  final int clueBoost;

  /// Bonus percentage chance of receiving extra clues (1-25).
  final int clueChance;

  /// Bonus fuel / speed-boost duration percentage in solo play (1-25).
  final int fuelBoost;

  /// Which clue type receives the [clueBoost] bonus.
  final String preferredClueType;

  /// Player's nationality as ISO 3166-1 alpha-2 code (e.g. 'GB', 'US', 'JP').
  /// null means not set.
  final String? nationality;

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

  /// Weighted stat roll table.
  ///
  /// Distribution:
  ///   1-5  : ~50 %  (common)
  ///   6-10 : ~25 %  (uncommon)
  ///   11-15: ~15 %  (rare)
  ///   16-20: ~8  %  (epic)
  ///   21-24: ~1.75% (legendary — 0.44% each)
  ///   25   : ~0.25% (perfect)
  ///
  /// Implemented as a 400-entry lookup table for O(1) rolls.
  static final List<int> _weightTable = [
    for (var i = 0; i < 40; i++) 1,
    for (var i = 0; i < 40; i++) 2,
    for (var i = 0; i < 40; i++) 3,
    for (var i = 0; i < 40; i++) 4,
    for (var i = 0; i < 40; i++) 5,
    for (var i = 0; i < 20; i++) 6,
    for (var i = 0; i < 20; i++) 7,
    for (var i = 0; i < 20; i++) 8,
    for (var i = 0; i < 20; i++) 9,
    for (var i = 0; i < 20; i++) 10,
    for (var i = 0; i < 12; i++) 11,
    for (var i = 0; i < 12; i++) 12,
    for (var i = 0; i < 12; i++) 13,
    for (var i = 0; i < 12; i++) 14,
    for (var i = 0; i < 12; i++) 15,
    for (var i = 0; i < 7; i++) 16,
    for (var i = 0; i < 7; i++) 17,
    for (var i = 0; i < 6; i++) 18,
    for (var i = 0; i < 6; i++) 19,
    for (var i = 0; i < 6; i++) 20,
    for (var i = 0; i < 2; i++) 21,
    for (var i = 0; i < 2; i++) 22,
    for (var i = 0; i < 2; i++) 23,
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
      nationality: current.nationality, // Preserve across rerolls
    );
  }

  // ---------------------------------------------------------------------------
  // Display helpers
  // ---------------------------------------------------------------------------

  /// Human-readable coin boost, e.g. "+5% Extra Coins".
  String get coinBoostLabel => '+$coinBoost% Extra Coins';

  /// Human-readable clue type, e.g. "Clue Type: Flag".
  String get clueBoostLabel {
    final typeLabel =
        '${preferredClueType[0].toUpperCase()}${preferredClueType.substring(1)}';
    return 'Clue Type: $typeLabel';
  }

  /// Human-readable clue chance, e.g. "+5% Clue Chance".
  String get clueChanceLabel => '+$clueChance% Clue Chance';

  /// Human-readable fuel boost, e.g. "+7% Fuel Efficiency".
  String get fuelBoostLabel => '+$fuelBoost% Fuel Efficiency';

  /// Sum of all four boosts (useful for ranking / comparison).
  int get totalBoost => coinBoost + clueBoost + clueChance + fuelBoost;

  /// Rarity tier derived from [totalBoost].
  ///
  ///   4-25  → Bronze
  ///   26-50 → Silver
  ///   51-75 → Gold
  ///   76-90 → Diamond
  ///   91-100 → Perfect
  String get rarityTier {
    if (totalBoost >= 91) return 'Perfect';
    if (totalBoost >= 76) return 'Diamond';
    if (totalBoost >= 51) return 'Gold';
    if (totalBoost >= 26) return 'Silver';
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
    String? nationality,
  }) => PilotLicense(
    coinBoost: coinBoost ?? this.coinBoost,
    clueBoost: clueBoost ?? this.clueBoost,
    clueChance: clueChance ?? this.clueChance,
    fuelBoost: fuelBoost ?? this.fuelBoost,
    preferredClueType: preferredClueType ?? this.preferredClueType,
    nationality: nationality ?? this.nationality,
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
    'nationality': nationality,
  };

  factory PilotLicense.fromJson(Map<String, dynamic> json) => PilotLicense(
    coinBoost: json['coin_boost'] as int,
    clueBoost: json['clue_boost'] as int,
    clueChance: json['clue_chance'] as int? ?? 1,
    fuelBoost: json['fuel_boost'] as int,
    preferredClueType: json['preferred_clue_type'] as String,
    nationality: json['nationality'] as String?,
  );
}
