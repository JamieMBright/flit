// Economy configuration data models.
//
// These models are used to configure the in-game economy including:
// - Gold earnings for game modes
// - Shop price overrides per cosmetic
// - Timed and manual promotions
// - Gold package definitions for the store

// ignore_for_file: avoid_redundant_argument_values

/// Type of promotion, determining which economy systems it affects.
enum PromotionType {
  earningsBoost,
  shopDiscount,
  both;

  String toJson() => name;

  static PromotionType fromJson(String value) {
    return PromotionType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PromotionType.earningsBoost,
    );
  }
}

/// A timed or manual promotion that modifies earnings or shop prices.
class Promotion {
  final String name;
  final PromotionType type;

  /// Multiplier applied to all gold earnings while this promotion is active.
  /// A value of 1.5 means +50% earnings. Defaults to 1.0 (no change).
  final double earningsMultiplier;

  /// Percentage discount applied to shop cosmetic prices while active.
  /// A value of 20 means 20% off. Defaults to 0 (no discount).
  final int shopDiscountPercent;

  /// Optional start of the promotion window. Null means no time gating.
  final DateTime? startDate;

  /// Optional end of the promotion window. Null means no time gating.
  final DateTime? endDate;

  /// When true, the promotion is active regardless of the date range.
  final bool manualActive;

  const Promotion({
    required this.name,
    required this.type,
    this.earningsMultiplier = 1.0,
    this.shopDiscountPercent = 0,
    this.startDate,
    this.endDate,
    this.manualActive = false,
  });

  /// True if the promotion is currently active.
  ///
  /// Active when [manualActive] is true, OR when the current time falls
  /// within [[startDate], [endDate]] (inclusive). Both conditions are honored
  /// independently — either one suffices.
  bool get isActive {
    if (manualActive) return true;
    final now = DateTime.now();
    final afterStart = startDate == null || !now.isBefore(startDate!);
    final beforeEnd = endDate == null || !now.isAfter(endDate!);
    return afterStart && beforeEnd;
  }

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      name: json['name'] as String? ?? '',
      type: PromotionType.fromJson(json['type'] as String? ?? 'earningsBoost'),
      earningsMultiplier:
          (json['earningsMultiplier'] as num?)?.toDouble() ?? 1.0,
      shopDiscountPercent: json['shopDiscountPercent'] as int? ?? 0,
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'] as String)
          : null,
      manualActive: json['manualActive'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'type': type.toJson(),
      'earningsMultiplier': earningsMultiplier,
      'shopDiscountPercent': shopDiscountPercent,
      if (startDate != null) 'startDate': startDate!.toIso8601String(),
      if (endDate != null) 'endDate': endDate!.toIso8601String(),
      'manualActive': manualActive,
    };
  }
}

/// Configuration for how much gold players earn in various game modes.
class EarningsConfig {
  /// Base gold reward for completing a daily scramble puzzle.
  final int dailyScrambleBaseReward;

  /// Gold earned per clue discovered during free flight mode.
  final int freeFlightPerClueReward;

  /// Maximum gold earnable from free flight per day.
  final int freeFlightDailyCap;

  const EarningsConfig({
    this.dailyScrambleBaseReward = 150,
    this.freeFlightPerClueReward = 15,
    this.freeFlightDailyCap = 150,
  });

  factory EarningsConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const EarningsConfig();
    return EarningsConfig(
      dailyScrambleBaseReward: json['dailyScrambleBaseReward'] as int? ?? 150,
      freeFlightPerClueReward: json['freeFlightPerClueReward'] as int? ?? 15,
      freeFlightDailyCap: json['freeFlightDailyCap'] as int? ?? 150,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'dailyScrambleBaseReward': dailyScrambleBaseReward,
      'freeFlightPerClueReward': freeFlightPerClueReward,
      'freeFlightDailyCap': freeFlightDailyCap,
    };
  }
}

/// A gold package available for purchase in the store.
class GoldPackageConfig {
  /// Amount of gold coins the player receives.
  final int coins;

  /// Regular (non-promotional) price in USD.
  final double basePrice;

  /// Promotional price in USD. Null when no active promotion applies.
  final double? promoPrice;

  /// Whether this package should be highlighted as the best value option.
  final bool isBestValue;

  const GoldPackageConfig({
    required this.coins,
    required this.basePrice,
    this.promoPrice,
    this.isBestValue = false,
  });

  factory GoldPackageConfig.fromJson(Map<String, dynamic> json) {
    return GoldPackageConfig(
      coins: json['coins'] as int? ?? 0,
      basePrice: (json['basePrice'] as num?)?.toDouble() ?? 0.0,
      promoPrice: (json['promoPrice'] as num?)?.toDouble(),
      isBestValue: json['isBestValue'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'coins': coins,
      'basePrice': basePrice,
      if (promoPrice != null) 'promoPrice': promoPrice,
      'isBestValue': isBestValue,
    };
  }

  /// Returns a copy of this package with [promoPrice] set.
  GoldPackageConfig withPromoPrice(double? price) {
    return GoldPackageConfig(
      coins: coins,
      basePrice: basePrice,
      promoPrice: price,
      isBestValue: isBestValue,
    );
  }
}

/// Top-level economy configuration.
///
/// Controls earnings rates, shop prices, active promotions, and gold packages.
/// Use [EconomyConfig.defaults()] for compiled-in fallback values and
/// [EconomyConfig.fromJson()] to merge server-provided config with those defaults.
class EconomyConfig {
  final EarningsConfig earnings;

  /// Per-cosmetic price overrides keyed by cosmeticId.
  /// When present, the override replaces the catalog price before any
  /// promotional discounts are applied.
  final Map<String, int> shopPriceOverrides;

  final List<Promotion> promotions;

  final List<GoldPackageConfig> goldPackages;

  const EconomyConfig({
    required this.earnings,
    required this.shopPriceOverrides,
    required this.promotions,
    required this.goldPackages,
  });

  /// Compiled-in default economy configuration.
  ///
  /// These values are used when no server-provided config is available, and
  /// serve as fallback for any field missing from partial server responses.
  factory EconomyConfig.defaults() {
    return const EconomyConfig(
      earnings: EarningsConfig(
        dailyScrambleBaseReward: 150,
        freeFlightPerClueReward: 15,
        freeFlightDailyCap: 150,
      ),
      shopPriceOverrides: <String, int>{},
      promotions: <Promotion>[],
      goldPackages: <GoldPackageConfig>[
        GoldPackageConfig(coins: 450, basePrice: 0.99),
        GoldPackageConfig(coins: 2000, basePrice: 3.99),
        GoldPackageConfig(coins: 5000, basePrice: 8.99),
        GoldPackageConfig(coins: 15000, basePrice: 19.99, isBestValue: true),
      ],
    );
  }

  /// Deserializes an [EconomyConfig] from [json], merging with [defaults()]
  /// for any missing fields so partial server responses degrade gracefully.
  factory EconomyConfig.fromJson(Map<String, dynamic> json) {
    final defaults = EconomyConfig.defaults();

    final earningsJson = json['earnings'] as Map<String, dynamic>?;
    final earnings = earningsJson != null
        ? EarningsConfig.fromJson(earningsJson)
        : defaults.earnings;

    final overridesJson = json['shopPriceOverrides'] as Map<String, dynamic>?;
    final shopPriceOverrides = overridesJson != null
        ? overridesJson.map((k, v) => MapEntry(k, (v as num).toInt()))
        : defaults.shopPriceOverrides;

    final promotionsJson = json['promotions'] as List<dynamic>?;
    final promotions = promotionsJson != null
        ? promotionsJson
              .whereType<Map<String, dynamic>>()
              .map(Promotion.fromJson)
              .toList()
        : defaults.promotions;

    final packagesJson = json['goldPackages'] as List<dynamic>?;
    final goldPackages = packagesJson != null
        ? packagesJson
              .whereType<Map<String, dynamic>>()
              .map(GoldPackageConfig.fromJson)
              .toList()
        : defaults.goldPackages;

    return EconomyConfig(
      earnings: earnings,
      shopPriceOverrides: shopPriceOverrides,
      promotions: promotions,
      goldPackages: goldPackages,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'earnings': earnings.toJson(),
      'shopPriceOverrides': shopPriceOverrides,
      'promotions': promotions.map((p) => p.toJson()).toList(),
      'goldPackages': goldPackages.map((g) => g.toJson()).toList(),
    };
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// All promotions that are currently active.
  ///
  /// A promotion is included if [Promotion.isActive] returns true, which means
  /// either [Promotion.manualActive] is true or the current time falls within
  /// the [[Promotion.startDate], [Promotion.endDate]] window.
  List<Promotion> get activePromotions =>
      promotions.where((p) => p.isActive).toList();

  /// Combined earnings multiplier from all active promotions.
  ///
  /// Returns the product of [Promotion.earningsMultiplier] across all active
  /// promotions of type [PromotionType.earningsBoost] or [PromotionType.both].
  /// Returns 1.0 when no applicable promotions are active.
  double get earningsMultiplier {
    final applicable = activePromotions.where(
      (p) =>
          p.type == PromotionType.earningsBoost || p.type == PromotionType.both,
    );
    return applicable.fold(1.0, (product, p) => product * p.earningsMultiplier);
  }

  /// Effective shop price for a cosmetic item.
  ///
  /// Resolution order:
  /// 1. If [shopPriceOverrides] contains [cosmeticId], use that value.
  /// 2. Otherwise, apply the best (largest) active shop discount to
  ///    [catalogPrice] and return the discounted price (minimum 0).
  int effectivePrice(String cosmeticId, int catalogPrice) {
    if (shopPriceOverrides.containsKey(cosmeticId)) {
      return shopPriceOverrides[cosmeticId]!;
    }

    final discounts = activePromotions
        .where(
          (p) =>
              p.type == PromotionType.shopDiscount ||
              p.type == PromotionType.both,
        )
        .map((p) => p.shopDiscountPercent);

    if (discounts.isEmpty) return catalogPrice;

    final bestDiscount = discounts.reduce((a, b) => a > b ? a : b);
    final discounted = catalogPrice * (1.0 - bestDiscount / 100.0);
    return discounted.round().clamp(0, catalogPrice);
  }

  /// Gold packages with promotional prices applied where applicable.
  ///
  /// For each package, finds the best (largest) active shop discount and
  /// calculates a [GoldPackageConfig.promoPrice]. If no discount applies,
  /// [promoPrice] is null.
  List<GoldPackageConfig> get effectiveGoldPackages {
    final discounts = activePromotions
        .where(
          (p) =>
              p.type == PromotionType.shopDiscount ||
              p.type == PromotionType.both,
        )
        .map((p) => p.shopDiscountPercent);

    if (discounts.isEmpty) {
      return goldPackages.map((g) => g.withPromoPrice(null)).toList();
    }

    final bestDiscount = discounts.reduce((a, b) => a > b ? a : b);

    return goldPackages.map((g) {
      final discountedPrice = g.basePrice * (1.0 - bestDiscount / 100.0);
      // Round to two decimal places for display.
      final rounded = (discountedPrice * 100).round() / 100.0;
      return g.withPromoPrice(rounded);
    }).toList();
  }
}
