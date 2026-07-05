import 'dart:math';

/// Hot-license ("pump") state and the reroll pity/escalation economy.
///
/// Design (owner-approved, final):
/// - License base stats are PERMANENT and never decay.
/// - Big performances (daily modes, Standard Sortie) "pump" the license to a
///   HOT tier for [hotDuration] (~72h): a visual glow plus a flat
///   [hotStatBonus] on every stat. Repeat performances re-extend the window.
/// - Rerolls can land a license that is "factory hot" (arrives pumped).
/// - Reroll pricing: the first reroll of the day is free (handled by
///   `lastFreeRerollDate` in AccountState); paid rerolls after that escalate
///   within the day ([paidRerollCost]) and reset at midnight UTC.
/// - Pity: every reroll that fails to improve the license increments a pity
///   counter which (a) grants advantage rolls on the next reroll and
///   (b) raises the factory-hot chance — improved odds are guaranteed after
///   bad rolls, and the counter resets on an improved roll.
///
/// All of this state persists inside `account_state.license_data` JSONB
/// (client-owned schema) under the `heat` key.
class LicenseHeat {
  const LicenseHeat({
    this.hotUntil,
    this.pityCount = 0,
    this.paidRerollsToday = 0,
    this.rerollDay,
  });

  /// UTC instant the hot window expires. Null = never pumped.
  final DateTime? hotUntil;

  /// Consecutive rerolls that failed to improve the license.
  final int pityCount;

  /// Paid rerolls performed on [rerollDay] (drives cost escalation).
  final int paidRerollsToday;

  /// UTC day key (YYYY-MM-DD) that [paidRerollsToday] refers to.
  final String? rerollDay;

  // ---------------------------------------------------------------------------
  // Tuning constants
  // ---------------------------------------------------------------------------

  /// How long a pump keeps the license hot.
  static const Duration hotDuration = Duration(hours: 72);

  /// Flat bonus added to every license stat while hot.
  static const int hotStatBonus = 5;

  /// Fraction of the theoretical max score that triggers a pump.
  static const double pumpScoreFraction = 0.6;

  /// Base chance a reroll arrives factory hot.
  static const double factoryHotBaseChance = 0.10;

  /// Extra factory-hot chance per pity point.
  static const double factoryHotPityBonus = 0.08;

  /// Cap on the factory-hot chance.
  static const double factoryHotMaxChance = 0.50;

  /// Bad rolls before pity is considered "active" for UI messaging.
  /// (Odds improve from the very first bad roll; this is the display gate.)
  static const int pityDisplayThreshold = 3;

  /// Base cost of the first PAID reroll of the day. Costs double per paid
  /// reroll up to [paidRerollCostCap]. (The daily free reroll comes first.)
  static const int paidRerollBaseCost = 100;

  /// Ceiling on the escalating paid reroll cost.
  static const int paidRerollCostCap = 800;

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Whether the license is currently hot.
  bool isHot(DateTime now) => hotUntil != null && now.isBefore(hotUntil!);

  /// Time remaining in the hot window (zero when not hot).
  Duration hotRemaining(DateTime now) {
    if (!isHot(now)) return Duration.zero;
    return hotUntil!.difference(now);
  }

  /// Flat stat bonus currently in effect (0 when not hot).
  int statBonus(DateTime now) => isHot(now) ? hotStatBonus : 0;

  /// Extra advantage rolls granted by pity on the next reroll.
  ///
  /// Odds are guaranteed to improve with every consecutive bad roll: each
  /// pity point adds one advantage roll (roll again, keep the best).
  int get pityLuckBonus => pityCount;

  /// Chance (0..1) that the next reroll arrives factory hot.
  double get factoryHotChance => min(
        factoryHotMaxChance,
        factoryHotBaseChance + pityCount * factoryHotPityBonus,
      );

  /// Cost in coins of the next PAID reroll given [dayKey] (UTC YYYY-MM-DD).
  ///
  /// Escalates 100 -> 200 -> 400 -> 800 (cap) within a day; a new day
  /// resets the ladder.
  int nextPaidRerollCost(String dayKey) =>
      paidRerollCost(rerollDay == dayKey ? paidRerollsToday : 0);

  /// Cost of the (n+1)th paid reroll of the day, n = [paidRerollsSoFar].
  static int paidRerollCost(int paidRerollsSoFar) {
    var cost = paidRerollBaseCost;
    for (var i = 0; i < paidRerollsSoFar; i++) {
      cost *= 2;
      if (cost >= paidRerollCostCap) return paidRerollCostCap;
    }
    return cost;
  }

  /// Whether a performance of [score] out of [maxScore] qualifies for a pump.
  static bool qualifiesForPump({required int score, required int maxScore}) {
    if (maxScore <= 0) return false;
    return score >= (maxScore * pumpScoreFraction).round();
  }

  // ---------------------------------------------------------------------------
  // Transitions
  // ---------------------------------------------------------------------------

  /// Pump (or re-extend) the hot window from [now].
  ///
  /// The window never shrinks: extending always results in at least the
  /// previous [hotUntil].
  LicenseHeat pump(DateTime now) {
    final candidate = now.toUtc().add(hotDuration);
    final current = hotUntil;
    final next =
        (current != null && current.isAfter(candidate)) ? current : candidate;
    return copyWith(hotUntil: next);
  }

  /// Record a paid reroll on [dayKey], advancing the cost ladder.
  LicenseHeat recordPaidReroll(String dayKey) => copyWith(
        paidRerollsToday: rerollDay == dayKey ? paidRerollsToday + 1 : 1,
        rerollDay: dayKey,
      );

  /// Update pity after a reroll: [improved] means the new license beats the
  /// old one (higher total boost). Improvement resets pity; a bad roll
  /// increments it.
  LicenseHeat recordRollOutcome({required bool improved}) =>
      copyWith(pityCount: improved ? 0 : pityCount + 1);

  /// Roll whether this reroll arrives factory hot, and if so pump from [now].
  ///
  /// Returns the post-roll heat state; check [isHot] against the same [now]
  /// to know whether the factory-hot proc happened.
  LicenseHeat rollFactoryHot(DateTime now, {Random? rng}) {
    final random = rng ?? Random();
    if (random.nextDouble() < factoryHotChance) {
      return pump(now);
    }
    return this;
  }

  // ---------------------------------------------------------------------------
  // copyWith / serialisation
  // ---------------------------------------------------------------------------

  LicenseHeat copyWith({
    DateTime? hotUntil,
    int? pityCount,
    int? paidRerollsToday,
    String? rerollDay,
  }) =>
      LicenseHeat(
        hotUntil: hotUntil ?? this.hotUntil,
        pityCount: pityCount ?? this.pityCount,
        paidRerollsToday: paidRerollsToday ?? this.paidRerollsToday,
        rerollDay: rerollDay ?? this.rerollDay,
      );

  Map<String, dynamic> toJson() => {
        'hot_until': hotUntil?.toIso8601String(),
        'pity_count': pityCount,
        'paid_rerolls_today': paidRerollsToday,
        'reroll_day': rerollDay,
      };

  factory LicenseHeat.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LicenseHeat();
    return LicenseHeat(
      hotUntil: json['hot_until'] != null
          ? DateTime.tryParse(json['hot_until'] as String)?.toUtc()
          : null,
      pityCount: json['pity_count'] as int? ?? 0,
      paidRerollsToday: json['paid_rerolls_today'] as int? ?? 0,
      rerollDay: json['reroll_day'] as String?,
    );
  }
}
