// ignore_for_file: avoid_print

/// Reusable test harness for Flit DEVICE integration tests.
///
/// Run with: flutter test --device-id=<id> integration_test/
///
/// Drives the REAL Flit screens (same approach as the host harness in
/// test/integration/helpers/test_harness.dart) but wraps the
/// [IntegrationTestWidgetsFlutterBinding] so screenshots work on a real device.
///
/// Like the host harness, it initialises a *dead* Supabase client + mock
/// SharedPreferences so the real screens render without a real backend, and
/// never calls `main()`.
library test_harness;

import 'package:flit/data/models/player.dart';
import 'package:flit/data/providers/account_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reusable helpers for Flit device integration tests.
class TestHarness {
  TestHarness._();

  static IntegrationTestWidgetsFlutterBinding? _binding;
  static bool _supabaseReady = false;

  static void ensureInitialized() {
    _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  }

  /// Initialise mock prefs + a dead Supabase client so the real screens render
  /// without a backend. Call once from `setUpAll`.
  static Future<void> ensureTestEnv() async {
    ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    if (_supabaseReady) return;
    try {
      await Supabase.initialize(
        url: 'http://localhost:1',
        anonKey: 'test-anon-key',
        debug: false,
      );
      _supabaseReady = true;
    } catch (_) {
      _supabaseReady = true;
    }
  }

  /// A fake authenticated player (level 99 unlocks all modes; coins generous).
  static const Player fakePlayer = Player(
    id: 'test-pilot-0001',
    username: 'TestPilot',
    displayName: 'Test Pilot',
    level: 99,
    xp: 0,
    coins: 999999,
  );

  /// Riverpod overrides that put the app in a logged-in state.
  static List<Override> loggedInOverrides() => [
        accountProvider.overrideWith(
          (ref) => AccountNotifier()..switchAccount(fakePlayer),
        ),
      ];

  /// Pump a REAL Flit [screen] with logged-in overrides; drain background async
  /// errors raised by the dead-URL Supabase fetches.
  static Future<void> pumpRealScreen(
    WidgetTester tester,
    Widget screen, {
    List<Override> extraOverrides = const [],
    int frames = 8,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...loggedInOverrides(), ...extraOverrides],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: screen,
        ),
      ),
    );
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      tester.takeException();
    }
  }

  /// Pump [frames] fixed frames — NEVER pumpAndSettle (Flit animates forever).
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

  static Future<void> settle(
    WidgetTester tester, {
    int frames = 10,
    bool drain = true,
  }) =>
      pumpFrames(tester, frames: frames, drain: drain);

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

  static Future<void> takeScreenshot(
    WidgetTester tester,
    String name,
  ) async {
    if (_binding == null) return;
    try {
      await _binding!.takeScreenshot(name);
      print('[screenshot] $name captured');
    } catch (e) {
      print('[screenshot] $name skipped: $e');
    }
  }
}
