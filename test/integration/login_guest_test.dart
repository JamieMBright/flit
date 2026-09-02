import 'package:flit/features/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_harness.dart';

void main() {
  setUpAll(TestHarness.ensureTestEnv);

  testWidgets('priority boarding explains persistent guest runs',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await TestHarness.settle(tester, frames: 12);

    expect(find.text('PRIORITY BOARDING'), findsOneWidget);
    expect(
      find.text(
        'Play as a guest — your runs are saved on this device '
        'and can be claimed by creating an account.',
      ),
      findsOneWidget,
    );
  });
}
