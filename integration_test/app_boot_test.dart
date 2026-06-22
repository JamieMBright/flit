/// Device integration test: app boot / initial render.
///
/// Run with: flutter test --device-id=<id> integration_test/app_boot_test.dart
library app_boot_test;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App boot (device)', () {
    testWidgets('renders without crashing', (tester) async {
      await TestHarness.pumpApp(tester);
      expect(find.byKey(const Key('stub_home_scaffold')), findsOneWidget);
    });

    testWidgets('home screen shows FLIT title', (tester) async {
      await TestHarness.pumpApp(tester);
      expect(find.text('FLIT'), findsOneWidget);
    });

    testWidgets('home screen shows Play button', (tester) async {
      await TestHarness.pumpApp(tester);
      expect(find.text('Play'), findsOneWidget);
    });

    testWidgets('pumpAndSettleSafely does not deadlock', (tester) async {
      await TestHarness.pumpApp(tester);
      await TestHarness.pumpAndSettleSafely(tester, frames: 60);
      expect(find.text('FLIT'), findsOneWidget);
    });

    testWidgets('screenshot helper does not throw', (tester) async {
      await TestHarness.pumpApp(tester);
      await TestHarness.takeScreenshot(tester, 'device_app_boot_home');
    });

    testWidgets('dark background colour is applied', (tester) async {
      await TestHarness.pumpApp(tester);
      final scaffold = tester.widget<Scaffold>(
        find.byKey(const Key('stub_home_scaffold')),
      );
      expect(scaffold.backgroundColor, const Color(0xFF0A0E1A));
    });
  });
}
