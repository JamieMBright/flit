/// Device integration test: the REAL game-launch screens.
///
/// Run with: flutter test --device-id=<id> integration_test/navigation_test.dart
library navigation_test;

import 'package:flutter_test/flutter_test.dart';

import 'package:flit/features/campaign/campaign_screen.dart';
import 'package:flit/features/play/free_flight_setup_screen.dart';
import 'package:flit/features/play/practice_screen.dart';
import 'package:flit/features/quiz/uncharted_setup_screen.dart';
import 'package:flit/game/map/region.dart';

import 'helpers/test_harness.dart';

void main() {
  setUpAll(() async {
    await TestHarness.ensureTestEnv();
  });

  group('Launch screens (device)', () {
    testWidgets('Campaign renders the real Pilot Training list',
        (tester) async {
      await TestHarness.pumpRealScreen(tester, const CampaignScreen());
      expect(find.text('PILOT TRAINING'), findsOneWidget);
      await TestHarness.takeScreenshot(tester, 'device_campaign');
    });

    testWidgets('Free Flight setup renders and round chip updates the CTA',
        (tester) async {
      await TestHarness.pumpRealScreen(
        tester,
        const FreeFlightSetupScreen(region: GameRegion.world),
      );
      expect(find.text('FREE FLIGHT'), findsWidgets);
      await tester.tap(find.text('10').first);
      await TestHarness.settle(tester, frames: 8);
      expect(find.textContaining('×10'), findsWidgets);
    });

    testWidgets('Practice renders the unranked notice', (tester) async {
      await TestHarness.pumpRealScreen(tester, const PracticeScreen());
      expect(find.text('Not ranked on the global leaderboard'), findsOneWidget);
      await TestHarness.takeScreenshot(tester, 'device_practice');
    });

    testWidgets('Uncharted setup renders the region picker', (tester) async {
      await TestHarness.pumpRealScreen(tester, const UnchartedSetupScreen());
      expect(find.text('SELECT REGION'), findsOneWidget);
      await TestHarness.takeScreenshot(tester, 'device_uncharted');
    });
  });
}
