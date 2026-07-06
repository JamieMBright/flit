/// Ad configuration for Flit.
///
/// Design philosophy: ads should be **tasteful and infrequent**. Free-tier
/// players see a small banner on the home screen and a short interstitial
/// before head-to-head results. They can also opt-in to rewarded ads for
/// extra plays or bonus coins. Premium subscribers see NO ads at all.
library;

import 'subscription.dart';

// -----------------------------------------------------------------------------
// Enums
// -----------------------------------------------------------------------------

/// The format of an ad creative.
enum AdType { banner, interstitial, rewarded }

/// Named placements where an ad can appear in the game.
enum AdPlacement {
  /// Small banner anchored at the bottom of the home screen.
  homeScreenBanner,

  /// Short interstitial shown before revealing a head-to-head result.
  preH2HResult,

  /// Opt-in rewarded ad: grants one free play.
  rewardedPlayAgain,

  /// Opt-in rewarded ad: grants bonus coins.
  rewardedBonusCoins,

  /// Opt-in rewarded ad: grants one free full fuel refill. Surfaced on the
  /// out-of-fuel dialog / fuel card. Daily-limited (see [AdConfig.maxPerDay]).
  rewardedFuelRefill,

  /// Opt-in rewarded ad: daily supply/coin drop. Surfaced on the home screen
  /// and the shop SUPPLIES tab. Once per UTC day (see [AdConfig.maxPerDay]).
  rewardedDailyDrop,
}

// -----------------------------------------------------------------------------
// Ad configuration
// -----------------------------------------------------------------------------

class AdConfig {
  // Private constructor -- this class is a static-only utility.
  AdConfig._();

  // ---------------------------------------------------------------------------
  // Core gate: premium users never see ads
  // ---------------------------------------------------------------------------

  /// Returns `true` when ads should be shown for the given [tier].
  ///
  /// Premium subscribers (monthly, annual, lifetime) see **no** ads.
  static bool shouldShowAds(SubscriptionTier tier) {
    return tier == SubscriptionTier.free;
  }

  // ---------------------------------------------------------------------------
  // Frequency / rate limits
  // ---------------------------------------------------------------------------

  /// Minimum time between two interstitial ads.
  static const Duration minInterstitialInterval = Duration(minutes: 5);

  /// Maximum number of interstitial ads shown in a single session.
  static const int maxInterstitialsPerSession = 3;

  /// Maximum number of rewarded ads a user may watch per calendar day.
  /// Used as the fallback cap for any rewarded placement not listed in
  /// [maxPerDay].
  static const int maxRewardedPerDay = 5;

  /// Per-placement daily watch caps, keyed by UTC day. Placements not listed
  /// fall back to [maxRewardedPerDay]. Enforced (and persisted) by AdService.
  ///
  /// Owner spec: free refuel ~2/day, daily supply drop 1/day.
  static const Map<AdPlacement, int> maxPerDay = {
    AdPlacement.rewardedFuelRefill: 2,
    AdPlacement.rewardedDailyDrop: 1,
  };

  /// Daily cap for [placement] (falls back to [maxRewardedPerDay]).
  static int dailyCap(AdPlacement placement) =>
      maxPerDay[placement] ?? maxRewardedPerDay;

  // ---------------------------------------------------------------------------
  // Reward values
  // ---------------------------------------------------------------------------

  /// Number of free plays granted for watching [AdPlacement.rewardedPlayAgain].
  static const int rewardedPlayAgainValue = 1;

  /// Number of bonus coins granted for watching [AdPlacement.rewardedBonusCoins].
  static const int rewardedBonusCoinsAmount = 50;

  /// Coins granted by the daily-drop ad when the drop roll lands on coins
  /// (rather than a consumable).
  static const int dailyDropCoins = 40;

  // ---------------------------------------------------------------------------
  // Placement helpers
  // ---------------------------------------------------------------------------

  /// Maps each [AdPlacement] to its corresponding [AdType].
  static AdType typeForPlacement(AdPlacement placement) {
    switch (placement) {
      case AdPlacement.homeScreenBanner:
        return AdType.banner;
      case AdPlacement.preH2HResult:
        return AdType.interstitial;
      case AdPlacement.rewardedPlayAgain:
      case AdPlacement.rewardedBonusCoins:
      case AdPlacement.rewardedFuelRefill:
      case AdPlacement.rewardedDailyDrop:
        return AdType.rewarded;
    }
  }

  /// Whether an ad should be displayed at [placement] for a user with the
  /// given subscription [tier].
  ///
  /// Premium users always return `false`. Free-tier users are eligible for
  /// every placement.
  static bool shouldShow(AdPlacement placement, SubscriptionTier tier) {
    // Premium users never see ads.
    if (!shouldShowAds(tier)) return false;

    // All placements are valid for free-tier users. Runtime frequency limits
    // (interstitial interval, daily rewarded cap) are enforced by the ad
    // service layer, not here -- this method answers the static policy
    // question only.
    return true;
  }

  // ---------------------------------------------------------------------------
  // Descriptive metadata (useful for analytics / UI labels)
  // ---------------------------------------------------------------------------

  /// Human-readable label for each placement, handy for analytics events and
  /// debug overlays.
  static const Map<AdPlacement, String> placementLabels = {
    AdPlacement.homeScreenBanner: 'Home Banner',
    AdPlacement.preH2HResult: 'Pre-H2H Interstitial',
    AdPlacement.rewardedPlayAgain: 'Rewarded: Play Again',
    AdPlacement.rewardedBonusCoins: 'Rewarded: Bonus Coins',
    AdPlacement.rewardedFuelRefill: 'Rewarded: Free Refuel',
    AdPlacement.rewardedDailyDrop: 'Rewarded: Daily Drop',
  };
}
