import 'package:flit/data/providers/account_provider.dart';
import 'package:flit/features/auth/login_screen.dart';
import 'package:flit/features/home/home_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_harness.dart';

void main() {
  setUpAll(TestHarness.ensureTestEnv);

  testWidgets('priority boarding clearly bypasses login', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LoginScreen(),
      ),
    );
    await TestHarness.settle(tester, frames: 12);

    expect(find.text('PRIORITY BOARDING'), findsOneWidget);
    expect(
      find.text('Play as a guest — no login required. Guest progress is not saved.'),
      findsOneWidget,
    );

    await tester.tap(find.text('PRIORITY BOARDING'));
    await TestHarness.settle(tester, frames: 12);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(container.read(accountProvider).currentPlayer.username, 'Guest Pilot');
    expect(find.text("TODAY'S DAILY GAMES"), findsOneWidget);
  });
}
