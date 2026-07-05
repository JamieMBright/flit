/// Meta-level fuel tank: gates FREE-FLIGHT coin EARNING only.
///
/// Policy (owner-approved, final):
/// - Fuel NEVER gates daily mode entry, rated Sortie attempts, or H2H.
/// - When the tank is empty you can still fly free-flight — coin earnings
///   simply stop until fuel regenerates or you refuel.
/// - The tank regenerates over time; instant refuels cost coins or a
///   refuel-canister item; the license `fuelBoost` stat (plus the hot pump)
///   enlarges the tank.
///
/// This is separate from the in-round fuel mechanic in `FlitGame` (which is
/// a per-round scoring resource). The meta tank persists across sessions in
/// `account_state.license_data` JSONB under the `fuel` key.
class FuelTank {
  const FuelTank({this.storedFuel = baseCapacity, this.updatedAt});

  /// Fuel units stored at [updatedAt] (before regeneration since then).
  final double storedFuel;

  /// UTC instant [storedFuel] was recorded. Null = brand-new tank (treated
  /// as full at first use).
  final DateTime? updatedAt;

  // ---------------------------------------------------------------------------
  // Tuning constants
  // ---------------------------------------------------------------------------

  /// Base tank capacity in fuel units.
  static const double baseCapacity = 100.0;

  /// Regeneration in units per hour (full base tank in 4 hours).
  static const double regenPerHour = 25.0;

  /// Fuel consumed per free-flight coin find.
  static const double fuelPerClue = 10.0;

  /// Coin price of an instant full refuel.
  static const int instantRefuelCoinCost = 25;

  /// Coin price of one refuel canister in the shop (cheaper than an
  /// instant refuel — the reward for planning ahead).
  static const int canisterCoinCost = 20;

  // ---------------------------------------------------------------------------
  // Capacity
  // ---------------------------------------------------------------------------

  /// Tank capacity for an effective fuel-boost stat (license fuelBoost plus
  /// any hot-pump bonus): +1% capacity per point.
  static double capacityFor(int effectiveFuelBoost) =>
      baseCapacity * (1 + effectiveFuelBoost / 100.0);

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Current fuel at [now], including regeneration, clamped to [capacity].
  double currentFuel(DateTime now, {double capacity = baseCapacity}) {
    final at = updatedAt;
    if (at == null) return capacity; // New tank starts full.
    final hours = now.toUtc().difference(at).inSeconds / 3600.0;
    if (hours <= 0) return storedFuel.clamp(0.0, capacity);
    return (storedFuel + hours * regenPerHour).clamp(0.0, capacity);
  }

  /// Whether at least one clue's worth of fuel is available.
  bool canEarn(DateTime now, {double capacity = baseCapacity}) =>
      currentFuel(now, capacity: capacity) >= fuelPerClue;

  /// Fraction full (0..1) for gauges.
  double fraction(DateTime now, {double capacity = baseCapacity}) {
    if (capacity <= 0) return 0;
    return (currentFuel(now, capacity: capacity) / capacity).clamp(0.0, 1.0);
  }

  /// Time until the tank has at least [target] units (zero if already there).
  Duration timeUntil(
    DateTime now,
    double target, {
    double capacity = baseCapacity,
  }) {
    final current = currentFuel(now, capacity: capacity);
    if (current >= target) return Duration.zero;
    final needed = target - current;
    return Duration(seconds: (needed / regenPerHour * 3600).ceil());
  }

  // ---------------------------------------------------------------------------
  // Transitions
  // ---------------------------------------------------------------------------

  /// Consume [amount] units at [now]. Clamps at zero — callers should check
  /// [canEarn] first; consuming never throws.
  FuelTank consume(
    DateTime now,
    double amount, {
    double capacity = baseCapacity,
  }) {
    final current = currentFuel(now, capacity: capacity);
    return FuelTank(
      storedFuel: (current - amount).clamp(0.0, capacity),
      updatedAt: now.toUtc(),
    );
  }

  /// Instantly refill to [capacity] at [now].
  FuelTank refillFull(DateTime now, {double capacity = baseCapacity}) =>
      FuelTank(storedFuel: capacity, updatedAt: now.toUtc());

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'fuel': storedFuel,
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory FuelTank.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FuelTank();
    return FuelTank(
      storedFuel: (json['fuel'] as num?)?.toDouble() ?? baseCapacity,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)?.toUtc()
          : null,
    );
  }
}
