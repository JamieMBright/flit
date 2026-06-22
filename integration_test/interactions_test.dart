/// Device integration test: button and control interactions.
///
/// Run with: flutter test --device-id=<id> integration_test/interactions_test.dart
library interactions_test;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_harness.dart';

class _CounterWidget extends StatefulWidget {
  const _CounterWidget({super.key});

  @override
  State<_CounterWidget> createState() => _CounterWidgetState();
}

class _CounterWidgetState extends State<_CounterWidget> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Count: $_count', key: const Key('counter_label')),
        ElevatedButton(
          key: const Key('increment_btn'),
          onPressed: () => setState(() => _count++),
          child: const Text('Increment'),
        ),
        ElevatedButton(
          key: const Key('reset_btn'),
          onPressed: () => setState(() => _count = 0),
          child: const Text('Reset'),
        ),
      ],
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Interactions (device)', () {
    testWidgets('initial count is 0', (tester) async {
      await TestHarness.pumpApp(
        tester,
        child: const Scaffold(body: Center(child: _CounterWidget())),
      );
      expect(find.text('Count: 0'), findsOneWidget);
    });

    testWidgets('tap Increment increases count to 1', (tester) async {
      await TestHarness.pumpApp(
        tester,
        child: const Scaffold(body: Center(child: _CounterWidget())),
      );
      await TestHarness.tapKey(tester, const Key('increment_btn'));
      expect(find.text('Count: 1'), findsOneWidget);
    });

    testWidgets(
      'game quiz answer submission — requires auth',
      (tester) async {},
      skip: true, // Requires real device and authenticated Supabase session
    );
  });
}
