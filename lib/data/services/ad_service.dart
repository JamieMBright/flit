/// Ad service — a thin, network-agnostic layer that makes Flit "ready to host
/// ads" without shipping a real ad SDK.
///
/// Today the only implementation is [PlaceholderAdProvider], which simulates a
/// rewarded / interstitial view with a tasteful in-app modal so the whole
/// opt-in flow is fully testable WITHOUT a real network. A real provider
/// (Google AdMob via `google_mobile_ads`) drops in later by implementing
/// [AdProvider] and calling [AdService.configure] — no call site changes.
///
/// Responsibilities of THIS layer:
/// - Gate every placement on: not-web, not-premium, provider-available.
/// - Enforce + persist per-placement daily caps (keyed by UTC day) and the
///   interstitial frequency cap, mirroring the account's existing
///   `freeFlightCoinsToday` / `lastFreeRerollDate` daily-limit patterns.
/// - Expose `adsAvailable` so UI entry points HIDE when ads can't be shown
///   (web, or release with no real provider configured).
///
/// Reward GRANTING is intentionally NOT done here — [showRewarded] only
/// returns whether the reward should be granted, and the caller applies it
/// through the existing economy paths (account_provider `addCoins` /
/// `grantConsumable` / `grantFreeRefuel`). That keeps this service free of
/// Riverpod/account coupling and easy to unit-test.
///
/// NOTE: client-side caps are best-effort. Server-side ad-reward validation
/// (an idempotent RPC like `claim_daily_champion`) is a post-launch hardening
/// item — see docs/ADS.md.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// INTEGRATION SEAM — swapping in google_mobile_ads (do NOT do this now)
/// ═══════════════════════════════════════════════════════════════════════════
/// 1. Add `google_mobile_ads: ^<latest>` to pubspec.yaml. MOBILE ONLY — keep
///    every ad call behind `kIsWeb` guards (already the case here).
/// 2. iOS: add your AdMob app id to ios/Runner/Info.plist as
///    `GADApplicationIdentifier` (string). Android: add the AdMob
///    `com.google.android.gms.ads.APPLICATION_ID` <meta-data> to
///    AndroidManifest.xml. (Ad-UNIT ids are per-placement — see the table in
///    docs/ADS.md.)
/// 3. Write `class AdMobAdProvider implements AdProvider`:
///      - `isAvailable => !kIsWeb` once `MobileAds.instance.initialize()` ran.
///      - `showRewarded`: load a `RewardedAd` for `adUnitIdFor(placement)`,
///        show it, complete `true` in `onUserEarnedReward`, else `false`.
///      - `showInterstitial`: load + show an `InterstitialAd`, complete on
///        dismiss.
/// 4. BEFORE the first ad request, resolve consent:
///      - EEA/UK: Google UMP consent — see [ConsentGate.ensure] (stub here).
///      - iOS: App Tracking Transparency — see [AttPrompt.request] (stub here,
///        only needed if you request personalised/tracking ads).
/// 5. In main(): `AdService.instance.configure(AdMobAdProvider()..init());`
///    after `await AdService.instance.ensureLoaded();`.
/// Everything else — caps, gating, UI, reward grants — stays exactly as-is.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/flit_colors.dart';
import '../models/ad_config.dart';
import '../models/subscription.dart';

// =============================================================================
// AdProvider — the swappable ad-surface seam
// =============================================================================

/// Abstraction over the actual ad surface. The only implementation today is
/// [PlaceholderAdProvider]; a real ad network implements this same interface.
abstract class AdProvider {
  /// Whether ads (placeholder or real) can be shown right now. When false,
  /// [AdService.adsAvailable] is false and every ad entry point hides itself.
  bool get isAvailable;

  /// Show a rewarded ad. Completes `true` when the user watched to completion
  /// (reward should be granted), `false` when they skipped/dismissed it.
  Future<bool> showRewarded(BuildContext context, AdPlacement placement);

  /// Show an interstitial ad. Completes when it is dismissed.
  Future<void> showInterstitial(BuildContext context, AdPlacement placement);
}

/// The ONLY implementation today: a self-contained placeholder that simulates
/// an ad view with an in-app modal so the flow is testable with no SDK.
///
/// In release builds with no real provider configured it reports
/// [isAvailable] == false, so ad entry points stay hidden and players never
/// see a broken placeholder. In debug/profile it shows the modal.
class PlaceholderAdProvider implements AdProvider {
  PlaceholderAdProvider({bool? available})
      : _available = available ?? !kReleaseMode;

  final bool _available;

  @override
  bool get isAvailable => _available;

  @override
  Future<bool> showRewarded(BuildContext context, AdPlacement placement) async {
    final watched = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PlaceholderAdModal(placement: placement, rewarded: true),
    );
    return watched ?? false;
  }

  @override
  Future<void> showInterstitial(
    BuildContext context,
    AdPlacement placement,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _PlaceholderAdModal(placement: placement, rewarded: false),
    );
  }
}

// =============================================================================
// Consent / ATT stubs — documented no-ops until a real SDK is wired
// =============================================================================

/// Google UMP (User Messaging Platform) consent gate for EEA/UK users.
///
/// STUB: real implementation lives with `google_mobile_ads`. Call [ensure]
/// once at startup (or before the first ad) to gather/refresh consent, and
/// [reset] from a Settings "Reset ad consent" control. See docs/ADS.md.
abstract final class ConsentGate {
  /// Gather or refresh consent if required. No-op today.
  static Future<void> ensure() async {
    // TODO(ads): drive ConsentInformation / ConsentForm from google_mobile_ads.
  }

  /// Reset consent (Settings hook). No-op today.
  static Future<void> reset() async {
    // TODO(ads): ConsentInformation.reset().
  }
}

/// iOS App Tracking Transparency prompt.
///
/// STUB: only needed if you request personalised/tracking ads. Call [request]
/// (iOS only) before initialising the ad SDK. No-op today.
abstract final class AttPrompt {
  static Future<void> request() async {
    // TODO(ads): AppTrackingTransparency.requestTrackingAuthorization() —
    // iOS only, and only if requesting tracking ads.
  }
}

// =============================================================================
// AdService — gating + cap bookkeeping + persistence
// =============================================================================

class AdService {
  /// [clock] returns "now" in UTC (injectable for tests). [isWeb] defaults to
  /// [kIsWeb]; override in tests to exercise the web-disabled path.
  AdService({
    AdProvider? provider,
    DateTime Function()? clock,
    bool? isWeb,
  })  : _provider = provider ?? PlaceholderAdProvider(),
        _clock = clock ?? (() => DateTime.now().toUtc()),
        _isWeb = isWeb ?? kIsWeb;

  /// App-wide singleton used by the Riverpod [adServiceProvider].
  static final AdService instance = AdService();

  AdProvider _provider;
  final DateTime Function() _clock;
  final bool _isWeb;

  /// SharedPreferences key for persisted cap state (versioned).
  static const String prefsKey = 'flit_ad_caps_v1';

  bool _loaded = false;

  // Per-placement daily counters, keyed by placement.name.
  final Map<String, int> _dailyCount = {};
  final Map<String, String> _dailyDate = {};
  // Interstitial frequency caps.
  DateTime? _lastInterstitialAt;
  int _interstitialsThisSession = 0;

  /// Swap in a real ad provider (e.g. `AdMobAdProvider`). See class docs.
  void configure(AdProvider provider) => _provider = provider;

  /// Whether ad entry points should render at all. False on web and whenever
  /// the provider reports unavailable (release with no real provider). Does
  /// NOT consider premium — that is the caller's per-placement concern via
  /// [canOfferRewarded] / [canOfferInterstitial].
  bool get adsAvailable => !_isWeb && _provider.isAvailable;

  // ---------------------------------------------------------------------------
  // UTC-day helpers (mirror AccountState._todayStr)
  // ---------------------------------------------------------------------------

  String _todayKey() {
    final d = _clock();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  int _countToday(AdPlacement p) {
    // A stored date that isn't today means the counter reset at UTC midnight.
    if (_dailyDate[p.name] != _todayKey()) return 0;
    return _dailyCount[p.name] ?? 0;
  }

  /// Rewarded watches still available today for [placement].
  int remainingToday(AdPlacement placement) {
    final cap = AdConfig.dailyCap(placement);
    final left = cap - _countToday(placement);
    return left < 0 ? 0 : left;
  }

  bool get _interstitialIntervalOk {
    final last = _lastInterstitialAt;
    if (last == null) return true;
    return _clock().difference(last) >= AdConfig.minInterstitialInterval;
  }

  bool get _interstitialSessionOk =>
      _interstitialsThisSession < AdConfig.maxInterstitialsPerSession;

  // ---------------------------------------------------------------------------
  // Public gating (sync — safe to call from build())
  // ---------------------------------------------------------------------------

  /// Whether a rewarded ad for [placement] can be offered to a [tier] player
  /// right now (available + free-tier + under today's cap).
  bool canOfferRewarded(AdPlacement placement, SubscriptionTier tier) {
    if (!adsAvailable) return false;
    if (!AdConfig.shouldShowAds(tier)) return false;
    return remainingToday(placement) > 0;
  }

  /// Whether an interstitial can be shown now (available + free-tier + within
  /// the frequency + per-session caps).
  bool canOfferInterstitial(SubscriptionTier tier) {
    if (!adsAvailable) return false;
    if (!AdConfig.shouldShowAds(tier)) return false;
    return _interstitialIntervalOk && _interstitialSessionOk;
  }

  // ---------------------------------------------------------------------------
  // Show flows
  // ---------------------------------------------------------------------------

  /// Show a rewarded ad for [placement]. Returns whether the reward should be
  /// granted (true only if the user watched to completion AND the placement
  /// was eligible). The caller applies the reward via the economy layer.
  Future<bool> showRewarded(
    BuildContext context,
    AdPlacement placement, {
    required SubscriptionTier tier,
  }) async {
    if (!canOfferRewarded(placement, tier)) return false;
    final watched = await _provider.showRewarded(context, placement);
    if (watched) {
      await _recordRewarded(placement);
    }
    return watched;
  }

  /// Show an interstitial for [placement] if the frequency caps allow. No-ops
  /// silently (and immediately) when capped, premium, or unavailable, so
  /// callers can always `await` this before proceeding.
  Future<void> showInterstitial(
    BuildContext context,
    AdPlacement placement, {
    required SubscriptionTier tier,
  }) async {
    if (!canOfferInterstitial(tier)) return;
    await _provider.showInterstitial(context, placement);
    _lastInterstitialAt = _clock();
    _interstitialsThisSession++;
    await _persist();
  }

  Future<void> _recordRewarded(AdPlacement p) async {
    final today = _todayKey();
    final current = _countToday(p); // resets across UTC midnight
    _dailyCount[p.name] = current + 1;
    _dailyDate[p.name] = today;
    await _persist();
  }

  // ---------------------------------------------------------------------------
  // Persistence (SharedPreferences — mirrors alias_service usage)
  // ---------------------------------------------------------------------------

  /// Hydrate cap state from disk. Call once during app startup. Safe to call
  /// repeatedly; only the first call does work. No-op on web.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    if (_isWeb) return; // No ads on web — nothing to load.
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKey);
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final counts = data['counts'] as Map<String, dynamic>? ?? const {};
      final dates = data['dates'] as Map<String, dynamic>? ?? const {};
      counts.forEach((k, v) => _dailyCount[k] = (v as num).toInt());
      dates.forEach((k, v) => _dailyDate[k] = v as String);
      final lastMs = data['lastInterstitialMs'];
      if (lastMs is num) {
        _lastInterstitialAt = DateTime.fromMillisecondsSinceEpoch(
          lastMs.toInt(),
          isUtc: true,
        );
      }
    } catch (_) {
      // Best-effort: on any parse error, caps simply start fresh.
    }
  }

  Future<void> _persist() async {
    if (_isWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        prefsKey,
        jsonEncode({
          'counts': _dailyCount,
          'dates': _dailyDate,
          'lastInterstitialMs': _lastInterstitialAt?.millisecondsSinceEpoch,
        }),
      );
    } catch (_) {
      // Best-effort persistence; caps still enforced in-memory this session.
    }
  }

  /// Test-only: reset in-memory state so each test starts clean.
  @visibleForTesting
  void resetForTest() {
    _loaded = false;
    _dailyCount.clear();
    _dailyDate.clear();
    _lastInterstitialAt = null;
    _interstitialsThisSession = 0;
  }
}

/// App-wide [AdService] (the singleton). UI reads gating via this provider.
final adServiceProvider = Provider<AdService>((ref) => AdService.instance);

// =============================================================================
// Placeholder ad modal — tasteful, on-aesthetic stand-in for a real creative
// =============================================================================

class _PlaceholderAdModal extends StatefulWidget {
  const _PlaceholderAdModal({required this.placement, required this.rewarded});

  final AdPlacement placement;
  final bool rewarded;

  @override
  State<_PlaceholderAdModal> createState() => _PlaceholderAdModalState();
}

class _PlaceholderAdModalState extends State<_PlaceholderAdModal> {
  static const Duration _watchDuration = Duration(seconds: 2);
  bool _watching = false;
  double _progress = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startWatch() {
    setState(() => _watching = true);
    const tick = Duration(milliseconds: 100);
    final steps = _watchDuration.inMilliseconds / tick.inMilliseconds;
    var i = 0;
    _timer = Timer.periodic(tick, (t) {
      i++;
      setState(() => _progress = (i / steps).clamp(0, 1).toDouble());
      if (i >= steps) {
        t.cancel();
        if (mounted) Navigator.of(context).pop(true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final label = AdConfig.placementLabels[widget.placement] ?? 'Ad';
    return AlertDialog(
      backgroundColor: FlitColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: FlitColors.cardBorder),
      ),
      title: const Row(
        children: [
          Icon(Icons.smart_display_outlined,
              color: FlitColors.accent, size: 22),
          SizedBox(width: 8),
          Text(
            'AD PLACEHOLDER',
            style: TextStyle(
              color: FlitColors.accent,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(
              color: FlitColors.backgroundMid,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                _watching ? 'Playing ad…' : 'Your ad would play here',
                style: const TextStyle(
                  color: FlitColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          if (_watching) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 6,
                backgroundColor: FlitColors.backgroundDark,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(FlitColors.accent),
              ),
            ),
          ],
        ],
      ),
      actions: _watching
          ? const []
          : widget.rewarded
              ? [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text(
                      'Skip',
                      style:
                          TextStyle(color: FlitColors.textMuted, fontSize: 13),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _startWatch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlitColors.accent,
                      foregroundColor: FlitColors.textPrimary,
                    ),
                    child: const Text('Watch 15s'),
                  ),
                ]
              : [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlitColors.accent,
                      foregroundColor: FlitColors.textPrimary,
                    ),
                    child: const Text('Continue'),
                  ),
                ],
    );
  }
}
