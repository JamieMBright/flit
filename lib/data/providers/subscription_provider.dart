/// Subscription state provider — the single source of truth for the
/// "remove ads" premium gate.
///
/// Today this defaults every player to [SubscriptionTier.free]. It exists so
/// that ad entry points, the paywall, and the Live Group unlock can all read
/// one place. When real in-app purchases land, hydrate this provider from the
/// purchase/receipt layer (or from the account snapshot) and everything that
/// watches it — including every ad placement — updates automatically.
///
/// ─────────────────────────────────────────────────────────────────────────
/// FUTURE HOOK — "Remove ads" / manage subscription
/// ─────────────────────────────────────────────────────────────────────────
/// A Settings entry ("Remove ads" / "Manage subscription" / "Restore
/// purchases") should call [SubscriptionNotifier.setTier] after a successful
/// purchase/restore. The same screen is the natural home for the consent /
/// ATT reset control (see docs/ADS.md and AdService's ConsentGate stub).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/subscription.dart';

/// Holds the player's current [Subscription]. Free by default.
class SubscriptionNotifier extends StateNotifier<Subscription> {
  SubscriptionNotifier() : super(const Subscription());

  /// Replace the whole subscription (e.g. after a purchase or restore).
  void set(Subscription subscription) => state = subscription;

  /// Convenience: switch tier, keeping other fields. A `null`/absent expiry
  /// leaves lifetime and free tiers valid; paid tiers should pass [expiresAt].
  void setTier(SubscriptionTier tier, {DateTime? expiresAt}) {
    state = Subscription(
      tier: tier,
      expiresAt: expiresAt ?? state.expiresAt,
      isGifted: state.isGifted,
      giftedBy: state.giftedBy,
      purchasedAt: tier == SubscriptionTier.free
          ? null
          : (state.purchasedAt ?? DateTime.now().toUtc()),
    );
  }

  /// Reset to the free tier (e.g. subscription lapsed).
  void clear() => state = const Subscription();
}

/// The player's live subscription. Watch this for the ad-free gate.
final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, Subscription>(
  (ref) => SubscriptionNotifier(),
);

/// The player's effective [SubscriptionTier] for ad gating. Premium tiers that
/// have lapsed collapse back to [SubscriptionTier.free] so ads reappear.
final adTierProvider = Provider<SubscriptionTier>((ref) {
  final sub = ref.watch(subscriptionProvider);
  return sub.isPremium ? sub.tier : SubscriptionTier.free;
});
