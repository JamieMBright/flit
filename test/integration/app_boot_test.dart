/// Widget-level integration test: app boot / initial render of the REAL home.
///
/// Pumps the real [HomeScreen] (with logged-in provider overrides + a dead
/// Supabase client) and asserts that the real title, PLAY button, and menu
/// tiles render. No stub widgets.
///
/// Run with: flutter test test/integration/
library app_boot_test;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flit/features/home/home_screen.dart';

import 'helpers/test_harness.dart';

void main() {
  setUpAll(() async {
    await TestHarness.ensureTestEnv();
  });

  group('App boot — real HomeScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await TestHarness.pumpRealScreen(tester, const HomeScreen());
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('home screen shows FLIT title and tagline', (tester) async {
      await TestHarness.pumpRealScreen(tester, const HomeScreen());
      // Real title block from _buildTitle().
      expect(find.text('FLIT'), findsOneWidget);
      expect(find.text('A GEOGRAPHICAL ADVENTURE'), findsOneWidget);
    });

    testWidgets('home screen shows real PLAY button', (tester) async {
      await TestHarness.pumpRealScreen(tester, const HomeScreen());
      // _PlayButton renders the literal "PLAY" label (not the stub "Play").
      expect(find.text('PLAY'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('home screen shows the secondary menu tiles', (tester) async {
      await TestHarness.pumpRealScreen(tester, const HomeScreen());
      // _MenuTile labels are upper-cased in the widget. Assert the
      // UNCONDITIONAL tiles only — SHOP and LEADERBOARD are feature-flag gated
      // and the flags resolve to false against the dead Supabase URL, so those
      // tiles are intentionally hidden here.
      expect(find.text('PROFILE'), findsOneWidget);
      expect(find.text('FRIENDS'), findsOneWidget);
      expect(find.text('CLUES'), findsOneWidget);
      expect(find.text('HOW TO PLAY'), findsOneWidget);
    });

    testWidgets('home screen shows the daily-streak card prompt',
        (tester) async {
      await TestHarness.pumpRealScreen(tester, const HomeScreen());
      // _DailyStreakCard with a zero streak shows the call-to-action.
      expect(
        find.text('Play the daily to start your streak!'),
        findsOneWidget,
      );
    });

    testWidgets('tapping PLAY opens the real game-mode sheet', (tester) async {
      await TestHarness.pumpRealScreen(tester, const HomeScreen());
      await tester.tap(find.text('PLAY'));
      await TestHarness.settle(tester, frames: 12);
      // The modal bottom sheet renders the real section labels + mode cards.
      expect(find.text('FLIGHT DECK'), findsOneWidget);
      expect(find.text('BRIEFING ROOM'), findsOneWidget);
      expect(find.text('Free Flight'), findsOneWidget);
      expect(find.text('Uncharted'), findsOneWidget);
    });

    testWidgets('fresh pilot sees the Basic Training funnel button',
        (tester) async {
      await TestHarness.pumpRealScreen(
        tester,
        const HomeScreen(),
        basicTrainingComplete: false,
      );
      // The primary affordance routes into Basic Training with the 0/3
      // wing indicator; the normal PLAY button is not shown.
      expect(find.text('BASIC TRAINING'), findsOneWidget);
      expect(find.text('Earn your wings — 0/3 missions'), findsOneWidget);
      expect(find.text('VIEW ALL MODES'), findsOneWidget);
      expect(find.text('PLAY'), findsNothing);
    });

    testWidgets('fresh pilot mode sheet shows locked modes with reasons',
        (tester) async {
      await TestHarness.pumpRealScreen(
        tester,
        const HomeScreen(),
        basicTrainingComplete: false,
      );
      await tester.tap(find.text('VIEW ALL MODES'));
      await TestHarness.settle(tester, frames: 12);
      // The sheet leads with the Basic Training card, and locked cards
      // carry the exact unlock reasons from mode_requirements.dart.
      expect(find.text('Basic Training'), findsOneWidget);
      expect(
        find.text('Complete Basic Training: Training Recon'),
        findsOneWidget,
      );
      expect(
        find.text('Reach Level 2 — finish Basic Training'),
        findsWidgets,
      );
    });

    testWidgets('screenshot helper does not throw on host runner',
        (tester) async {
      await TestHarness.pumpRealScreen(tester, const HomeScreen());
      await TestHarness.takeScreenshot(tester, 'app_boot_home');
    });

    testWidgets('settle does not deadlock on the animated globe background',
        (tester) async {
      // HomeScreen runs a 20s repeating globe controller; settle() must not
      // loop forever the way pumpAndSettle would.
      await TestHarness.pumpRealScreen(tester, const HomeScreen());
      await TestHarness.settle(tester, frames: 60);
      expect(find.text('FLIT'), findsOneWidget);
    });
  });
}
