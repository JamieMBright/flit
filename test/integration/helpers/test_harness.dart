// ignore_for_file: avoid_print

/// Reusable test harness for Flit widget-level integration tests.
///
/// Runs under plain `flutter test` (no device required).
///
/// Key design decisions:
/// - [pumpApp] wraps widgets in [ProviderScope] + [MaterialApp] matching [FlitApp].
/// - [pumpAndSettleSafely] pumps fixed frames instead of [pumpAndSettle], which
///   deadlocks on apps with continuous animations (the Flit globe shader ticks forever).
/// - [takeScreenshot] silently no-ops on the host runner (no device support).
library test_harness;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reusable helpers for Flit widget-level integration tests (host runner).
class TestHarness {
  TestHarness._();

  // ---------------------------------------------------------------------------
  // App pump helpers
  // ---------------------------------------------------------------------------

  /// Pump a widget under the standard Flit app shell (ProviderScope + dark MaterialApp).
  ///
  /// [child] defaults to [StubHomeShell] when omitted.
  /// [overrides] allows injecting Riverpod provider stubs.
  ///
  /// Note: Supabase, AudioManager, and shader initialisation are intentionally
  /// excluded — those require a physical device and are tested by build-level
  /// tests in scripts/test.sh integration.
  static Future<void> pumpApp(
    WidgetTester tester, {
    Widget? child,
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          title: 'Flit Test',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: child ?? const StubHomeShell(),
        ),
      ),
    );
    await pumpFrames(tester);
  }

  // ---------------------------------------------------------------------------
  // Safe pump — NEVER calls pumpAndSettle
  // ---------------------------------------------------------------------------

  /// Pump [frames] animation frames, each of [frameDuration].
  ///
  /// Use this instead of [WidgetTester.pumpAndSettle] — Flit has a
  /// continuously-animated globe shader, so pumpAndSettle loops forever.
  static Future<void> pumpFrames(
    WidgetTester tester, {
    int frames = 10,
    Duration frameDuration = const Duration(milliseconds: 16),
  }) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(frameDuration);
    }
  }

  /// Alias for [pumpFrames] — preferred name in test bodies for clarity.
  static Future<void> pumpAndSettleSafely(
    WidgetTester tester, {
    int frames = 10,
  }) =>
      pumpFrames(tester, frames: frames);

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
    await pumpFrames(tester, frames: frames);
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
    await pumpFrames(tester, frames: frames);
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
    await pumpFrames(tester, frames: frames);
  }

  // ---------------------------------------------------------------------------
  // Screenshot helper (best-effort; no-op on host runner)
  // ---------------------------------------------------------------------------

  /// Best-effort screenshot. Silently no-ops when not on a real device.
  static Future<void> takeScreenshot(
    WidgetTester tester,
    String name,
  ) async {
    // On the host (plain flutter test) there is no screenshot support.
    // On real devices, callers should use IntegrationTestWidgetsFlutterBinding
    // directly from integration_test/ tests.
    print('[screenshot] $name — no-op on host runner');
  }
}

// ---------------------------------------------------------------------------
// Stub widgets
// ---------------------------------------------------------------------------

/// Minimal home-screen stub that matches Flit's colour palette with no network
/// dependencies. Exported so integration tests can import it.
class StubHomeShell extends StatelessWidget {
  const StubHomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('stub_home_scaffold'),
      backgroundColor: const Color(0xFF0A0E1A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'FLIT',
              key: Key('flit_title'),
              style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              key: const Key('stub_play_btn'),
              onPressed: () {},
              child: const Text('Play'),
            ),
          ],
        ),
      ),
    );
  }
}
