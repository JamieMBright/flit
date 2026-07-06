import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flit/data/models/ad_config.dart';
import 'package:flit/data/models/subscription.dart';
import 'package:flit/data/services/ad_service.dart';

/// A no-UI [AdProvider] so we can drive AdService flows without a real modal.
class _FakeProvider implements AdProvider {
  _FakeProvider({this.available = true, this.watched = true});

  bool available;
  bool watched;
  int rewardedShown = 0;
  int interstitialShown = 0;

  @override
  bool get isAvailable => available;

  @override
  Future<bool> showRewarded(BuildContext context, AdPlacement placement) async {
    rewardedShown++;
    return watched;
  }

  @override
  Future<void> showInterstitial(
      BuildContext context, AdPlacement placement) async {
    interstitialShown++;
  }
}

/// Pump a trivial widget and hand its BuildContext to [body].
Future<void> withContext(
  WidgetTester tester,
  Future<void> Function(BuildContext context) body,
) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          ctx = context;
          return const SizedBox();
        },
      ),
    ),
  );
  await body(ctx);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  const free = SubscriptionTier.free;
  const premium = SubscriptionTier.monthly;

  group('daily cap enforcement + UTC-midnight reset', () {
    testWidgets('fuel-refill rewarded caps at 2/day then resets', (t) async {
      var now = DateTime.utc(2026, 7, 6, 10);
      final fake = _FakeProvider();
      final ads = AdService(provider: fake, clock: () => now, isWeb: false);

      await withContext(t, (ctx) async {
        const p = AdPlacement.rewardedFuelRefill;
        expect(ads.remainingToday(p), 2);

        expect(await ads.showRewarded(ctx, p, tier: free), isTrue);
        expect(await ads.showRewarded(ctx, p, tier: free), isTrue);
        expect(ads.remainingToday(p), 0);
        expect(ads.canOfferRewarded(p, free), isFalse);

        // Third attempt is blocked — provider never invoked a third time.
        expect(await ads.showRewarded(ctx, p, tier: free), isFalse);
        expect(fake.rewardedShown, 2);

        // Cross UTC midnight -> counter resets.
        now = DateTime.utc(2026, 7, 7, 0, 1);
        expect(ads.remainingToday(p), 2);
        expect(ads.canOfferRewarded(p, free), isTrue);
      });
    });

    testWidgets('daily-drop rewarded caps at 1/day', (t) async {
      final now = DateTime.utc(2026, 7, 6, 10);
      final fake = _FakeProvider();
      final ads = AdService(provider: fake, clock: () => now, isWeb: false);
      await withContext(t, (ctx) async {
        const p = AdPlacement.rewardedDailyDrop;
        expect(ads.remainingToday(p), 1);
        expect(await ads.showRewarded(ctx, p, tier: free), isTrue);
        expect(ads.canOfferRewarded(p, free), isFalse);
      });
    });
  });

  group('interstitial frequency cap', () {
    testWidgets('respects the minimum interval', (t) async {
      var now = DateTime.utc(2026, 7, 6, 10);
      final fake = _FakeProvider();
      final ads = AdService(provider: fake, clock: () => now, isWeb: false);
      await withContext(t, (ctx) async {
        const p = AdPlacement.preH2HResult;
        expect(ads.canOfferInterstitial(free), isTrue);
        await ads.showInterstitial(ctx, p, tier: free);
        expect(fake.interstitialShown, 1);

        // Within the interval -> blocked (no-op show).
        now = now
            .add(AdConfig.minInterstitialInterval - const Duration(minutes: 1));
        expect(ads.canOfferInterstitial(free), isFalse);
        await ads.showInterstitial(ctx, p, tier: free);
        expect(fake.interstitialShown, 1);

        // Past the interval -> allowed again.
        now = now.add(const Duration(minutes: 2));
        expect(ads.canOfferInterstitial(free), isTrue);
        await ads.showInterstitial(ctx, p, tier: free);
        expect(fake.interstitialShown, 2);
      });
    });

    testWidgets('respects the per-session cap', (t) async {
      // Advance well past the interval each time so only the session cap bites.
      var now = DateTime.utc(2026, 7, 6, 10);
      final fake = _FakeProvider();
      final ads = AdService(provider: fake, clock: () => now, isWeb: false);
      await withContext(t, (ctx) async {
        const p = AdPlacement.preH2HResult;
        for (var i = 0; i < AdConfig.maxInterstitialsPerSession; i++) {
          expect(ads.canOfferInterstitial(free), isTrue);
          await ads.showInterstitial(ctx, p, tier: free);
          now = now.add(const Duration(hours: 1));
        }
        expect(fake.interstitialShown, AdConfig.maxInterstitialsPerSession);
        expect(ads.canOfferInterstitial(free), isFalse);
      });
    });
  });

  group('reward-grant decision', () {
    testWidgets('skipped ad grants nothing and does not spend the cap',
        (t) async {
      final now = DateTime.utc(2026, 7, 6, 10);
      final fake = _FakeProvider(watched: false);
      final ads = AdService(provider: fake, clock: () => now, isWeb: false);
      await withContext(t, (ctx) async {
        const p = AdPlacement.rewardedFuelRefill;
        expect(await ads.showRewarded(ctx, p, tier: free), isFalse); // skipped
        expect(fake.rewardedShown, 1); // was shown
        expect(ads.remainingToday(p), 2); // but no cap consumed
      });
    });
  });

  group('premium + adsAvailable gating', () {
    testWidgets('premium never sees rewarded or interstitial', (t) async {
      final now = DateTime.utc(2026, 7, 6, 10);
      final fake = _FakeProvider();
      final ads = AdService(provider: fake, clock: () => now, isWeb: false);
      await withContext(t, (ctx) async {
        expect(ads.canOfferRewarded(AdPlacement.rewardedFuelRefill, premium),
            isFalse);
        expect(ads.canOfferInterstitial(premium), isFalse);
        expect(
            await ads.showRewarded(ctx, AdPlacement.rewardedFuelRefill,
                tier: premium),
            isFalse);
        expect(fake.rewardedShown, 0);
      });
    });

    test('unavailable provider hides UI (adsAvailable=false)', () {
      final ads = AdService(
        provider: _FakeProvider(available: false),
        isWeb: false,
      );
      expect(ads.adsAvailable, isFalse);
      expect(
          ads.canOfferRewarded(AdPlacement.rewardedFuelRefill, free), isFalse);
      expect(ads.canOfferInterstitial(free), isFalse);
    });

    test('placeholder provider is unavailable in release builds', () {
      // Simulate release-with-no-real-provider.
      final ads = AdService(
        provider: PlaceholderAdProvider(available: false),
        isWeb: false,
      );
      expect(ads.adsAvailable, isFalse);
    });
  });

  group('web', () {
    testWidgets('web reports unavailable and shows nothing', (t) async {
      final fake = _FakeProvider();
      final ads = AdService(provider: fake, isWeb: true);
      expect(ads.adsAvailable, isFalse);
      expect(
          ads.canOfferRewarded(AdPlacement.rewardedFuelRefill, free), isFalse);
      expect(ads.canOfferInterstitial(free), isFalse);
      await withContext(t, (ctx) async {
        expect(
            await ads.showRewarded(ctx, AdPlacement.rewardedFuelRefill,
                tier: free),
            isFalse);
        await ads.showInterstitial(ctx, AdPlacement.preH2HResult, tier: free);
        expect(fake.rewardedShown, 0);
        expect(fake.interstitialShown, 0);
      });
    });
  });

  group('persistence', () {
    testWidgets('daily counts survive an AdService restart', (t) async {
      final now = DateTime.utc(2026, 7, 6, 10);
      await withContext(t, (ctx) async {
        final first = AdService(
            provider: _FakeProvider(), clock: () => now, isWeb: false);
        await first.ensureLoaded();
        await first.showRewarded(ctx, AdPlacement.rewardedDailyDrop,
            tier: free);
        expect(first.remainingToday(AdPlacement.rewardedDailyDrop), 0);

        // A fresh instance hydrates the persisted count for the same day.
        final second = AdService(
            provider: _FakeProvider(), clock: () => now, isWeb: false);
        await second.ensureLoaded();
        expect(second.remainingToday(AdPlacement.rewardedDailyDrop), 0);
        expect(second.canOfferRewarded(AdPlacement.rewardedDailyDrop, free),
            isFalse);
      });
    });
  });

  group('AdConfig caps', () {
    test('per-placement daily caps match owner spec', () {
      expect(AdConfig.dailyCap(AdPlacement.rewardedFuelRefill), 2);
      expect(AdConfig.dailyCap(AdPlacement.rewardedDailyDrop), 1);
      // Unlisted rewarded placement falls back to the global cap.
      expect(AdConfig.dailyCap(AdPlacement.rewardedBonusCoins),
          AdConfig.maxRewardedPerDay);
    });
  });
}
