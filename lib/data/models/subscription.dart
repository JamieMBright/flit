/// Subscription model for Flit Premium.
///
/// Flit is a freemium geography game. A small monthly subscription
/// ("Flit Premium" / "Flit+") removes all ads and unlocks the exclusive
/// "Live Group" game mode (GeoGuessr-style live multiplayer).
/// Subscriptions can also be gifted to friends.
library;

enum SubscriptionTier { free, monthly, annual, lifetime }

class Subscription {
  final SubscriptionTier tier;
  final DateTime? expiresAt;
  final bool isGifted;
  final String? giftedBy;
  final DateTime? purchasedAt;

  const Subscription({
    this.tier = SubscriptionTier.free,
    this.expiresAt,
    this.isGifted = false,
    this.giftedBy,
    this.purchasedAt,
  });

  // ---------------------------------------------------------------------------
  // Status helpers
  // ---------------------------------------------------------------------------

  /// Whether the subscription is currently active.
  ///
  /// Free tier is always "active" (it never expires).
  /// Lifetime tier never expires once purchased.
  /// Monthly and annual tiers are active only while [expiresAt] is in the
  /// future.
  bool get isActive {
    switch (tier) {
      case SubscriptionTier.free:
        return true;
      case SubscriptionTier.lifetime:
        return purchasedAt != null;
      case SubscriptionTier.monthly:
      case SubscriptionTier.annual:
        if (expiresAt == null) return false;
        return expiresAt!.isAfter(DateTime.now());
    }
  }

  /// Whether the user currently has premium perks (ad-free + Live Group).
  bool get isPremium => tier != SubscriptionTier.free && isActive;

  /// Number of days remaining on the subscription, or `null` for free /
  /// lifetime tiers.
  int? get daysRemaining {
    if (tier == SubscriptionTier.free || tier == SubscriptionTier.lifetime) {
      return null;
    }
    if (expiresAt == null) return 0;
    final remaining = expiresAt!.difference(DateTime.now()).inDays;
    return remaining < 0 ? 0 : remaining;
  }

  // ---------------------------------------------------------------------------
  // Premium perks
  // ---------------------------------------------------------------------------

  /// Premium removes ALL ad types (banner, interstitial, rewarded).
  static const bool premiumRemovesAds = true;

  /// Premium unlocks the "Live Group" multiplayer game mode.
  static const bool premiumUnlocksLiveGroup = true;

  // ---------------------------------------------------------------------------
  // Pricing (USD)
  // ---------------------------------------------------------------------------

  /// Price in USD for each paid tier. Free tier has no price entry.
  static const Map<SubscriptionTier, double> pricing = {
    SubscriptionTier.monthly: 2.99,
    SubscriptionTier.annual: 24.99,
    SubscriptionTier.lifetime: 49.99,
  };

  /// Human-readable names for each tier.
  static const Map<SubscriptionTier, String> tierNames = {
    SubscriptionTier.free: 'Flit Free',
    SubscriptionTier.monthly: 'Flit+ Monthly',
    SubscriptionTier.annual: 'Flit+ Annual',
    SubscriptionTier.lifetime: 'Flit+ Lifetime',
  };

  /// Short marketing descriptions shown on the paywall.
  static const Map<SubscriptionTier, String> tierDescriptions = {
    SubscriptionTier.free: 'Play free with ads',
    SubscriptionTier.monthly: r'$2.99/month - cancel anytime',
    SubscriptionTier.annual: r'$24.99/year - save ~30%',
    SubscriptionTier.lifetime: r'$49.99 one-time - yours forever',
  };

  // ---------------------------------------------------------------------------
  // Gifting
  // ---------------------------------------------------------------------------

  /// Create a gifted subscription from a donor username.
  Subscription asGift({required String fromUsername}) {
    return Subscription(
      tier: tier,
      expiresAt: expiresAt,
      isGifted: true,
      giftedBy: fromUsername,
      purchasedAt: purchasedAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() {
    return {
      'tier': tier.name,
      'expiresAt': expiresAt?.toIso8601String(),
      'isGifted': isGifted,
      'giftedBy': giftedBy,
      'purchasedAt': purchasedAt?.toIso8601String(),
    };
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      tier: SubscriptionTier.values.firstWhere(
        (t) => t.name == json['tier'],
        orElse: () => SubscriptionTier.free,
      ),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      isGifted: json['isGifted'] as bool? ?? false,
      giftedBy: json['giftedBy'] as String?,
      purchasedAt: json['purchasedAt'] != null
          ? DateTime.parse(json['purchasedAt'] as String)
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Equality & toString
  // ---------------------------------------------------------------------------

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Subscription &&
          runtimeType == other.runtimeType &&
          tier == other.tier &&
          expiresAt == other.expiresAt &&
          isGifted == other.isGifted &&
          giftedBy == other.giftedBy &&
          purchasedAt == other.purchasedAt;

  @override
  int get hashCode =>
      Object.hash(tier, expiresAt, isGifted, giftedBy, purchasedAt);

  @override
  String toString() {
    final name = tierNames[tier] ?? tier.name;
    if (tier == SubscriptionTier.free) return 'Subscription($name)';
    final status = isActive ? 'active' : 'expired';
    final gift = isGifted ? ', gifted by $giftedBy' : '';
    return 'Subscription($name, $status$gift)';
  }
}
