/// Device integration test: app boot / initial render of the REAL HomeScreen.
///
/// Run with: flutter test --device-id=<id> integration_test/app_boot_test.dart
library app_boot_test;

import 'package:flutter_test/flutter_test.dart';

import 'package:flit/features/home/home_screen.dart';

import 'helpers/test_harness.dart';

void main() {
  setUpAll(() async {
    await TestHarness.ensureTestEnv();
  });

  group('App boot (device) — real HomeScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await TestHarness.pumpRealScreen(tester, const HomeScreen());
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('home screen shows FLIT title and PLAY', (tester) async {
      await TestHarness.pumpRealScreen(tester, const HomeScreen());
      expect(find.text('FLIT'), findsOneWidget);
      expect(find.text('PLAY'), findsOneWidget);
    });

    testWidgets('tapping PLAY opens the real game-mode sheet', (tester) async {
      await TestHarness.pumpRealScreen(tester, const HomeScreen());
      await tester.tap(find.text('PLAY'));
      await TestHarness.settle(tester, frames: 12);
      expect(find.text('FLIGHT DECK'), findsOneWidget);
      expect(find.text('Free Flight'), findsOneWidget);
    });

    testWidgets('settle does not deadlock on the animated globe',
        (tester) async {
      await TestHarness.pumpRealScreen(tester, const HomeScreen());
      await TestHarness.settle(tester, frames: 60);
      expect(find.text('FLIT'), findsOneWidget);
    });

    testWidgets('screenshot helper does not throw', (tester) async {
      await TestHarness.pumpRealScreen(tester, const HomeScreen());
      await TestHarness.takeScreenshot(tester, 'device_app_boot_home');
    });
  });
}
