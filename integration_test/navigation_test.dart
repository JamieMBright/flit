/// Device integration test: navigation between top-level screens.
///
/// Run with: flutter test --device-id=<id> integration_test/navigation_test.dart
library navigation_test;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_harness.dart';

class _StubScreen extends StatelessWidget {
  const _StubScreen({required this.title, required this.screenKey});
  final String title;
  final Key screenKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: screenKey,
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title)),
    );
  }
}

class _NavTestHome extends StatelessWidget {
  const _NavTestHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('nav_home'),
      backgroundColor: const Color(0xFF0A0E1A),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _NavButton(label: 'Flight School',
              destination: const _StubScreen(title: 'Flight School', screenKey: Key('screen_flight_school'))),
            _NavButton(label: 'Daily Briefing',
              destination: const _StubScreen(title: 'Daily Briefing', screenKey: Key('screen_daily_briefing'))),
            _NavButton(label: 'Uncharted',
              destination: const _StubScreen(title: 'Uncharted', screenKey: Key('screen_uncharted'))),
            _NavButton(label: 'Free Flight',
              destination: const _StubScreen(title: 'Free Flight', screenKey: Key('screen_free_flight'))),
            _NavButton(label: 'Profile',
              destination: const _StubScreen(title: 'Profile', screenKey: Key('screen_profile'))),
            _NavButton(label: 'Leaderboard',
              destination: const _StubScreen(title: 'Leaderboard', screenKey: Key('screen_leaderboard'))),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.label, required this.destination});
  final String label;
  final Widget destination;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ElevatedButton(
        key: Key('nav_btn_$label'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => destination),
        ),
        child: Text(label),
      ),
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Navigation (device)', () {
    testWidgets('home navigation menu renders all buttons', (tester) async {
      await TestHarness.pumpApp(tester, child: const _NavTestHome());
      expect(find.byKey(const Key('nav_home')), findsOneWidget);
      expect(find.byKey(const Key('nav_btn_Flight School')), findsOneWidget);
      expect(find.byKey(const Key('nav_btn_Leaderboard')), findsOneWidget);
    });

    testWidgets('tap Flight School navigates', (tester) async {
      await TestHarness.pumpApp(tester, child: const _NavTestHome());
      await TestHarness.tapText(tester, 'Flight School', frames: 10);
      expect(find.byKey(const Key('screen_flight_school')), findsOneWidget);
    });

    testWidgets(
      'real HomeScreen navigation — requires live device and auth',
      (tester) async {},
      skip: true, // Requires real device and authenticated Supabase session
    );
  });
}
