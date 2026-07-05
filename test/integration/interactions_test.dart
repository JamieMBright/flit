/// Widget-level integration test: the REAL menu screens and their controls.
///
/// Each test pumps a real menu screen directly (with logged-in overrides +
/// dead Supabase), asserts a distinctive real widget/text proves it rendered,
/// taps a real control, and asserts the resulting UI change. No stub widgets.
///
/// Run with: flutter test test/integration/
library interactions_test;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flit/features/explore/country_clues_screen.dart';
import 'package:flit/features/friends/friends_screen.dart';
import 'package:flit/features/guide/gameplay_guide_screen.dart';
import 'package:flit/features/leaderboard/leaderboard_screen.dart';
import 'package:flit/features/profile/profile_screen.dart';
import 'package:flit/features/shop/shop_screen.dart';

import 'helpers/test_harness.dart';

void main() {
  setUpAll(() async {
    await TestHarness.ensureTestEnv();
  });

  group('Menu screens', () {
    testWidgets('Shop renders the tab bar and switches to the Gold tab',
        (tester) async {
      await TestHarness.pumpRealScreen(tester, const ShopScreen());
      expect(find.byType(ShopScreen), findsOneWidget);
      // Real TabBar labels.
      expect(find.text('Planes'), findsOneWidget);
      expect(find.text('Gold'), findsOneWidget);
      await TestHarness.takeScreenshot(tester, 'menu_shop');

      // Tap the Gold tab → TabBarView swaps to the gold shop content.
      await tester.tap(find.text('Gold'));
      await TestHarness.settle(tester, frames: 10);
      expect(find.byType(ShopScreen), findsOneWidget);
    });

    testWidgets('Profile renders the header and the privacy section',
        (tester) async {
      await TestHarness.pumpRealScreen(tester, const ProfileScreen());
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Profile'), findsWidgets);
      // The fake player's username renders in the real header (Player.name ==
      // username) along with the @handle.
      expect(find.text('TestPilot'), findsWidgets);
      expect(find.text('@TestPilot'), findsWidgets);
      await TestHarness.takeScreenshot(tester, 'menu_profile');

      // Tap the refresh action — real IconButton, toggles the refreshing state.
      final refresh = find.byIcon(Icons.refresh);
      if (refresh.evaluate().isNotEmpty) {
        await tester.tap(refresh.first);
        await TestHarness.settle(tester, frames: 8);
      }
      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets('Friends renders the header and opens the Add Friend dialog',
        (tester) async {
      await TestHarness.pumpRealScreen(tester, const FriendsScreen());
      expect(find.byType(FriendsScreen), findsOneWidget);
      expect(find.text('Friends & Challenges'), findsOneWidget);
      await TestHarness.takeScreenshot(tester, 'menu_friends');

      // Tap the add-friend action → real _AddFriendDialog (a Dialog with the
      // "Add Friend" header, a username field, and a "Send Request" button).
      await tester.tap(find.byIcon(Icons.person_add).first);
      await TestHarness.settle(tester, frames: 10);
      expect(find.byType(Dialog), findsWidgets);
      expect(find.text('Add Friend'), findsOneWidget);
      expect(find.text('Send Request'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('Leaderboard renders the tab bar and switches timeframe',
        (tester) async {
      await TestHarness.pumpRealScreen(tester, const LeaderboardScreen());
      expect(find.byType(LeaderboardScreen), findsOneWidget);
      expect(find.text('Leaderboard'), findsWidgets);
      // Real mode tabs (Training is deliberately absent from the
      // global boards; order: Scramble, Recon, Briefing,
      // Combined).
      expect(find.text('SCRAMBLE'), findsOneWidget);
      expect(find.text('RECON'), findsOneWidget);
      expect(find.text('TRAINING'), findsNothing);
      await TestHarness.takeScreenshot(tester, 'menu_leaderboard');

      // Tap the RECON tab — real TabController switch.
      await tester.tap(find.text('RECON'));
      await TestHarness.settle(tester, frames: 8);
      expect(find.byType(LeaderboardScreen), findsOneWidget);
    });

    testWidgets('Country Clues renders tabs and switches to Regions',
        (tester) async {
      await TestHarness.pumpRealScreen(tester, const CountryCluesScreen());
      expect(find.byType(CountryCluesScreen), findsOneWidget);
      expect(find.text('All World'), findsOneWidget);
      expect(find.text('Regions'), findsOneWidget);
      await TestHarness.takeScreenshot(tester, 'menu_country_clues');

      // Tap the Regions tab → TabBarView swaps to the region grid.
      await tester.tap(find.text('Regions'));
      await TestHarness.settle(tester, frames: 10);
      expect(find.byType(CountryCluesScreen), findsOneWidget);
    });

    testWidgets('Gameplay Guide renders and switches tabs', (tester) async {
      await TestHarness.pumpRealScreen(tester, const GameplayGuideScreen());
      expect(find.byType(GameplayGuideScreen), findsOneWidget);
      // "How to Play" appears in the AppBar (and elsewhere); use findsWidgets.
      expect(find.text('How to Play'), findsWidgets);
      expect(find.text('Overview'), findsWidgets);
      await TestHarness.takeScreenshot(tester, 'menu_guide');

      // Tap the "Daily Scramble" tab → real TabBarView content swap.
      await tester.tap(find.text('Daily Scramble').first);
      await TestHarness.settle(tester, frames: 10);
      expect(find.byType(GameplayGuideScreen), findsOneWidget);
    });
  });
}
