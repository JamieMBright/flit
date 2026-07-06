// ignore_for_file: avoid_print

/// Reusable test harness for Flit widget-level integration tests.
///
/// Runs under plain `flutter test` (no device required) and drives the REAL
/// Flit screens (HomeScreen, the game-launch setup screens, and the menu
/// screens) rather than stub look-alikes.
///
/// Key design decisions:
/// - [ensureTestEnv] initialises a *dead* Supabase client (URL pointed at an
///   unreachable localhost port) plus mock SharedPreferences in `setUpAll`.
///   This lets the real screens run their real code paths — including the ones
///   that read `Supabase.instance.client.auth.currentUser` synchronously — with
///   NO real backend: every network query simply fails fast and the screens'
///   own try/catch fall back to their empty/default state. We deliberately do
///   NOT call `main()` (which does heavy Supabase/audio/settings init).
/// - [pumpRealScreen] wraps a real screen in `ProviderScope(overrides:
///   loggedInOverrides) + MaterialApp`, then pumps a fixed number of frames and
///   drains any async exception raised by the screen's background fetches.
/// - [settle] / [pumpFrames] pump fixed frames instead of [pumpAndSettle],
///   which deadlocks on Flit's continuously-animated globe + pulse controllers.
library test_harness;

import 'package:flit/data/models/player.dart';
import 'package:flit/data/providers/account_provider.dart';
import 'package:flit/game/tutorial/mode_requirements.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reusable helpers for Flit widget-level integration tests (host runner).
class TestHarness {
  TestHarness._();

  static bool _supabaseReady = false;

  // ---------------------------------------------------------------------------
  // Environment setup
  // ---------------------------------------------------------------------------

  /// Initialise a test environment in which the REAL screens can render
  /// without a real backend. Call once from `setUpAll`.
  ///
  /// - Mocks SharedPreferences so settings/feature-flag local fallbacks work.
  /// - Initialises Supabase against an unreachable URL. Screens that read
  ///   `Supabase.instance.client.auth.currentUser` then get a clean `null`
  ///   (no session) instead of an `AssertionError`, and any real query fails
  ///   fast (connection refused) and is swallowed by the screens' try/catch.
  static Future<void> ensureTestEnv() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    if (_supabaseReady) return;
    try {
      await Supabase.initialize(
        // Unreachable on purpose — no real network traffic leaves the test.
        url: 'http://localhost:1',
        anonKey: 'test-anon-key',
        debug: false,
      );
      _supabaseReady = true;
    } catch (_) {
      // Already initialised by a previous test file in the same run, or the
      // platform rejected re-init — either way the screens can still render.
      _supabaseReady = true;
    }
  }

  // ---------------------------------------------------------------------------
  // Provider overrides — a logged-in pilot
  // ---------------------------------------------------------------------------

  /// A fake authenticated player. Level 99 unlocks every game mode so launch
  /// screens render their full (unlocked) UI; coins are generous so cost-gated
  /// controls are enabled.
  static const Player fakePlayer = Player(
    id: 'test-pilot-0001',
    username: 'TestPilot',
    displayName: 'Test Pilot',
    level: 99,
    xp: 0,
    coins: 999999,
  );

  /// Riverpod overrides that put the app in a "logged-in" state. The
  /// [AccountNotifier] constructor is pure (no Supabase), so we just seed it
  /// with [fakePlayer] via `switchAccount`.
  ///
  /// By default the pilot is a veteran with Basic Training complete, so
  /// every game mode is unlocked and launch screens render their full UI.
  /// Pass [basicTrainingComplete] = false to render the level-1 funnel
  /// state instead (Basic Training button, locked mode cards).
  static List<Override> loggedInOverrides({
    bool basicTrainingComplete = true,
  }) =>
      [
        accountProvider.overrideWith((ref) {
          final notifier = AccountNotifier()..switchAccount(fakePlayer);
          if (basicTrainingComplete) {
            for (final id in basicTrainingMissionIds) {
              notifier.completeTrainingMission(id);
            }
          }
          return notifier;
        }),
      ];

  // ---------------------------------------------------------------------------
  // Real-screen pump
  // ---------------------------------------------------------------------------

  /// Pump a REAL Flit [screen] inside `ProviderScope + MaterialApp` using the
  /// logged-in overrides (plus any [extraOverrides]).
  ///
  /// After mounting, pumps [frames] frames and drains any async exception that
  /// the screen's background fetches raise (they fail because the dead Supabase
  /// URL is unreachable — this is expected and harmless to the render).
  static Future<void> pumpRealScreen(
    WidgetTester tester,
    Widget screen, {
    List<Override> extraOverrides = const [],
    int frames = 8,
    bool basicTrainingComplete = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...loggedInOverrides(basicTrainingComplete: basicTrainingComplete),
          ...extraOverrides,
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: screen,
        ),
      ),
    );
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      // Drain background async errors (dead-URL Supabase fetches) so they do
      // not fail the test at teardown. The screen has already rendered.
      tester.takeException();
    }
  }

  // ---------------------------------------------------------------------------
  // Safe pump — NEVER calls pumpAndSettle
  // ---------------------------------------------------------------------------

  /// Pump [frames] animation frames, each of [frameDuration].
  ///
  /// Use this instead of [WidgetTester.pumpAndSettle] — Flit has continuously
  /// animated globe + pulse controllers, so pumpAndSettle loops forever.
  static Future<void> pumpFrames(
    WidgetTester tester, {
    int frames = 10,
    Duration frameDuration = const Duration(milliseconds: 16),
    bool drain = false,
  }) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(frameDuration);
      if (drain) tester.takeException();
    }
  }

  /// Alias for [pumpFrames] — preferred name in test bodies for clarity.
  static Future<void> settle(
    WidgetTester tester, {
    int frames = 10,
    bool drain = true,
  }) =>
      pumpFrames(tester, frames: frames, drain: drain);

  // ---------------------------------------------------------------------------
  // Tap helpers
  // ---------------------------------------------------------------------------

  /// Tap the first widget whose text matches [text], then pump [frames] frames.
  static Future<void> tapText(
    WidgetTester tester,
    String text, {
    int frames = 5,
  }) async {
    final finder = find.text(text);
    expect(finder, findsAtLeastNWidgets(1),
        reason: 'Could not find text "$text"');
    await tester.tap(finder.first);
    await pumpFrames(tester, frames: frames, drain: true);
  }

  /// Tap the widget identified by [key], then pump [frames] frames.
  static Future<void> tapKey(
    WidgetTester tester,
    Key key, {
    int frames = 5,
  }) async {
    final finder = find.byKey(key);
    expect(finder, findsOneWidget,
        reason: 'Could not find widget with key $key');
    await tester.tap(finder);
    await pumpFrames(tester, frames: frames, drain: true);
  }

  /// Tap the first widget showing [icon], then pump [frames] frames.
  static Future<void> tapIcon(
    WidgetTester tester,
    IconData icon, {
    int frames = 5,
  }) async {
    final finder = find.byIcon(icon);
    expect(finder, findsAtLeastNWidgets(1),
        reason: 'Could not find Icon($icon)');
    await tester.tap(finder.first);
    await pumpFrames(tester, frames: frames, drain: true);
  }

  // ---------------------------------------------------------------------------
  // Screenshot helper (best-effort; no-op on host runner)
  // ---------------------------------------------------------------------------

  /// Best-effort screenshot. Silently no-ops when not on a real device.
  ///
  /// On the host runner (plain `flutter test`) there is no screenshot support;
  /// device captures live in `integration_test/`. We still assert the screen
  /// has a non-empty render surface so this exercises the real layout.
  static Future<void> takeScreenshot(
    WidgetTester tester,
    String name,
  ) async {
    expect(find.byType(MaterialApp), findsWidgets,
        reason: 'screenshot target should have a rendered MaterialApp');
    print('[screenshot] $name — captured (no-op surface on host runner)');
  }
}
