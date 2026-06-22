// ignore_for_file: avoid_print

/// Reusable test harness for Flit device integration tests.
///
/// Run with: flutter test --device-id=<id> integration_test/
///
/// For host-runner (no device) tests, see test/integration/helpers/test_harness.dart.
library test_harness;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

IntegrationTestWidgetsFlutterBinding? _binding;

/// Reusable helpers for Flit device integration tests.
class TestHarness {
  TestHarness._();

  static void ensureInitialized() {
    _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  }

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

  static Future<void> pumpFrames(
    WidgetTester tester, {
    int frames = 10,
    Duration frameDuration = const Duration(milliseconds: 16),
  }) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(frameDuration);
    }
  }

  static Future<void> pumpAndSettleSafely(
    WidgetTester tester, {
    int frames = 10,
  }) =>
      pumpFrames(tester, frames: frames);

  static Future<void> tapText(
    WidgetTester tester,
    String text, {
    int frames = 5,
  }) async {
    final finder = find.text(text);
    expect(finder, findsAtLeastNWidgets(1), reason: 'Could not find text "$text"');
    await tester.tap(finder.first);
    await pumpFrames(tester, frames: frames);
  }

  static Future<void> tapKey(
    WidgetTester tester,
    Key key, {
    int frames = 5,
  }) async {
    final finder = find.byKey(key);
    expect(finder, findsOneWidget, reason: 'Could not find widget with key $key');
    await tester.tap(finder);
    await pumpFrames(tester, frames: frames);
  }

  static Future<void> tapIcon(
    WidgetTester tester,
    IconData icon, {
    int frames = 5,
  }) async {
    final finder = find.byIcon(icon);
    expect(finder, findsAtLeastNWidgets(1), reason: 'Could not find Icon($icon)');
    await tester.tap(finder.first);
    await pumpFrames(tester, frames: frames);
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
              style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
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
