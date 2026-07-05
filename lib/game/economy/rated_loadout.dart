/// Boost policy for rated vs daily play (owner's explicit final ruling).
///
/// ## The policy
///
/// - **DAILY modes** (Scramble, Recon, Briefing) ARE affected by owned items,
///   license stats, and speed boosts. Dailies are once-per-day boards;
///   spending coins legitimately improves your daily score.
/// - **RATED play** (Standard Sortie, H2H challenges) is boost-NORMALIZED:
///   everyone flies the fixed standard loadout below — standard license
///   stats, standard plane physics. Money must never buy rating.
///   Cosmetics (plane skin, contrail colours, companions) still show;
///   only the numbers are normalized.
///
/// Every rated launch site must build its `FlitGame`/`PlayScreen` physics
/// parameters from [RatedLoadout.standard] instead of the player's equipped
/// plane stats or license multipliers.
class RatedLoadout {
  const RatedLoadout._();

  /// The single standard loadout used by ALL rated play.
  static const RatedLoadout standard = RatedLoadout._();

  /// Standard plane handling multiplier (baseline aircraft).
  double get planeHandling => 1.0;

  /// Standard plane speed multiplier.
  double get planeSpeed => 1.0;

  /// Standard plane fuel-efficiency multiplier.
  double get planeFuelEfficiency => 1.0;

  /// Standard license fuel-boost multiplier (no license bonus in rated play).
  double get fuelBoostMultiplier => 1.0;
}
