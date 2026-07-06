# Ads in Flit

Flit is "ready to host ads" but ships **no real ad SDK**. Everything below is a
placeholder layer designed so a real network (Google AdMob via
[`google_mobile_ads`](https://pub.dev/packages/google_mobile_ads)) can be
dropped in later with minimal change.

## Principles

- **Mobile only.** Every ad path is guarded by `kIsWeb` — no ads render on web.
- **Opt-in and tasteful.** Rewarded placements are player-initiated; the one
  interstitial is frequency-capped.
- **Premium removes all ads.** Gated on `SubscriptionTier` via
  `AdConfig.shouldShowAds` (see `lib/data/providers/subscription_provider.dart`).
- **No broken placeholders in production.** In release with no real provider
  configured, `AdService.adsAvailable` is `false` and every entry point hides.

## Placements (owner spec)

| # | Placement enum | Type | Cap | Entry point |
|---|----------------|------|-----|-------------|
| 1 | `AdPlacement.rewardedFuelRefill` | rewarded | ~2 / UTC day | Out-of-fuel dialog — "WATCH AD · FREE REFUEL" (`lib/features/play/out_of_fuel_dialog.dart`). Grants a full refuel via `AccountNotifier.grantFreeRefuel`. |
| 2 | `AdPlacement.rewardedDailyDrop` | rewarded | 1 / UTC day | Home screen + shop SUPPLIES tab — shared `DailyAdRewardCard` (`lib/core/widgets/daily_ad_reward_card.dart`). Grants coins (`addCoins`) or a random consumable (`grantConsumable`). |
| 3 | `AdPlacement.preH2HResult` | interstitial | `minInterstitialInterval` (5 min) + `maxInterstitialsPerSession` (3) | Before the H2H result reveal animation (`lib/features/quiz/h2h_results_screen.dart` — gates `_animController.forward()`). |

The unused legacy placements (`homeScreenBanner`, `rewardedPlayAgain`,
`rewardedBonusCoins`) remain in the enum as planned future slots.

## Architecture

```
UI entry point
  → AdService (gating + daily/frequency caps + persistence)   lib/data/services/ad_service.dart
      → AdProvider (the swappable ad surface)
          → PlaceholderAdProvider  (only impl today — in-app modal)
          → AdMobAdProvider        (future — google_mobile_ads)
  → reward applied by the caller via the economy layer
      (AccountNotifier.addCoins / grantConsumable / grantFreeRefuel)
```

- `AdService.showRewarded(context, placement, tier:)` returns **whether to
  grant** — the caller applies the reward. Caps are recorded on a completed
  watch.
- `AdService.showInterstitial(context, placement, tier:)` shows the ad if the
  frequency caps allow, else no-ops immediately.
- `AdService.canOfferRewarded` / `canOfferInterstitial` are sync gates for
  `build()` — they drive whether an entry point renders.

### Persistence

Caps are persisted with `shared_preferences` under `flit_ad_caps_v1`
(per-placement `count` + `date`, plus the last-interstitial timestamp), keyed
by **UTC day** — mirroring the account's `freeFlightCoinsToday` /
`lastFreeRerollDate` pattern. Counters reset when the stored date != today.
`AdService.instance.ensureLoaded()` is called once in `main()`.

> **Post-launch hardening:** client-side caps are best-effort. Move
> ad-reward validation server-side (an idempotent RPC like
> `claim_daily_champion`) before ads carry real economic value.

## Swapping in `google_mobile_ads`

1. **Dependency:** add `google_mobile_ads: ^<latest>` to `pubspec.yaml`.
   Keep every call behind the existing `kIsWeb` guards.
2. **iOS** (`ios/Runner/Info.plist`):
   ```xml
   <key>GADApplicationIdentifier</key>
   <string>ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY</string>
   ```
   If you request tracking/personalised ads, also add `NSUserTrackingUsageDescription`.
3. **Android** (`android/app/src/main/AndroidManifest.xml`, inside `<application>`):
   ```xml
   <meta-data
       android:name="com.google.android.gms.ads.APPLICATION_ID"
       android:value="ca-app-pub-XXXXXXXXXXXXXXXX~ZZZZZZZZZZ"/>
   ```
4. **Ad-unit ids** (one per placement) live in your `AdMobAdProvider` — map
   `AdPlacement` → unit id. Use Google's test unit ids in debug.
5. **Implement the provider:**
   ```dart
   class AdMobAdProvider implements AdProvider {
     bool get isAvailable => !kIsWeb; // once MobileAds initialized
     Future<bool> showRewarded(ctx, p) async { /* RewardedAd, complete
        true in onUserEarnedReward */ }
     Future<void> showInterstitial(ctx, p) async { /* InterstitialAd */ }
   }
   ```
6. **Consent / ATT** — resolve BEFORE the first ad request:
   - EEA/UK: Google UMP — implement `ConsentGate.ensure()`
     (`lib/data/services/ad_service.dart`, currently a documented no-op).
   - iOS: App Tracking Transparency — implement `AttPrompt.request()`
     (iOS only, only if requesting tracking ads).
7. **Register** in `main()` after `ensureLoaded()`:
   ```dart
   await AdService.instance.ensureLoaded();
   AdService.instance.configure(AdMobAdProvider()..init());
   ```

Nothing else changes — caps, gating, UI, and reward grants stay as-is.

## Settings hooks (future)

A Settings screen should own:
- **Remove ads / Manage subscription / Restore purchases** →
  `SubscriptionNotifier.setTier(...)` after a successful purchase/restore.
- **Reset ad consent** → `ConsentGate.reset()`.

See `lib/data/providers/subscription_provider.dart`.
