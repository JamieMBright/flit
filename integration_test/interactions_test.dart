/// Device integration test: the REAL menu screens and their controls.
///
/// Run with: flutter test --device-id=<id> integration_test/interactions_test.dart
library interactions_test;

import 'package:flutter_test/flutter_test.dart';

import 'package:flit/features/explore/country_clues_screen.dart';
import 'package:flit/features/guide/gameplay_guide_screen.dart';

import 'helpers/test_harness.dart';

void main() {
  setUpAll(() async {
    await TestHarness.ensureTestEnv();
  });

  group('Menu screens (device)', () {
    testWidgets('Country Clues renders tabs and switches to Regions',
        (tester) async {
      await TestHarness.pumpRealScreen(tester, const CountryCluesScreen());
      expect(find.text('All World'), findsOneWidget);
      expect(find.text('Regions'), findsOneWidget);
      await tester.tap(find.text('Regions'));
      await TestHarness.settle(tester, frames: 10);
      expect(find.byType(CountryCluesScreen), findsOneWidget);
      await TestHarness.takeScreenshot(tester, 'device_country_clues');
    });

    testWidgets('Gameplay Guide renders and switches tabs', (tester) async {
      await TestHarness.pumpRealScreen(tester, const GameplayGuideScreen());
      expect(find.text('How to Play'), findsWidgets);
      await tester.tap(find.text('Daily Scramble').first);
      await TestHarness.settle(tester, frames: 10);
      expect(find.byType(GameplayGuideScreen), findsOneWidget);
      await TestHarness.takeScreenshot(tester, 'device_guide');
    });
  });
}
