/// Widget-level integration test: button and control interactions.
///
/// Exercises tap events, text input, toggle behaviour, and state mutations.
///
/// Run with: flutter test test/integration/
library interactions_test;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

class _ToggleWidget extends StatefulWidget {
  const _ToggleWidget({super.key});

  @override
  State<_ToggleWidget> createState() => _ToggleWidgetState();
}

class _ToggleWidgetState extends State<_ToggleWidget> {
  bool _on = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(_on ? 'ON' : 'OFF', key: const Key('toggle_label')),
        Switch(
          key: const Key('toggle_switch'),
          value: _on,
          onChanged: (v) => setState(() => _on = v),
        ),
      ],
    );
  }
}

class _InputWidget extends StatefulWidget {
  const _InputWidget({super.key});

  @override
  State<_InputWidget> createState() => _InputWidgetState();
}

class _InputWidgetState extends State<_InputWidget> {
  final _ctrl = TextEditingController();
  String _submitted = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextField(
          key: const Key('text_input'),
          controller: _ctrl,
          decoration: const InputDecoration(hintText: 'Enter country name...'),
        ),
        ElevatedButton(
          key: const Key('submit_btn'),
          onPressed: () => setState(() => _submitted = _ctrl.text),
          child: const Text('Submit'),
        ),
        if (_submitted.isNotEmpty)
          Text('Submitted: $_submitted', key: const Key('submitted_label')),
      ],
    );
  }
}

void main() {
  group('Interactions', () {
    group('Counter widget', () {
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

      testWidgets('tap Increment three times reaches count 3', (tester) async {
        await TestHarness.pumpApp(
          tester,
          child: const Scaffold(body: Center(child: _CounterWidget())),
        );
        for (var i = 0; i < 3; i++) {
          await TestHarness.tapKey(tester, const Key('increment_btn'),
              frames: 3);
        }
        expect(find.text('Count: 3'), findsOneWidget);
      });

      testWidgets('tap Reset returns count to 0 after incrementing',
          (tester) async {
        await TestHarness.pumpApp(
          tester,
          child: const Scaffold(body: Center(child: _CounterWidget())),
        );
        await TestHarness.tapKey(tester, const Key('increment_btn'));
        await TestHarness.tapKey(tester, const Key('increment_btn'));
        expect(find.text('Count: 2'), findsOneWidget);
        await TestHarness.tapKey(tester, const Key('reset_btn'));
        expect(find.text('Count: 0'), findsOneWidget);
      });
    });

    group('Toggle widget', () {
      testWidgets('initial state is OFF', (tester) async {
        await TestHarness.pumpApp(
          tester,
          child: const Scaffold(body: Center(child: _ToggleWidget())),
        );
        expect(find.text('OFF'), findsOneWidget);
        expect(find.text('ON'), findsNothing);
      });

      testWidgets('tap switch toggles to ON', (tester) async {
        await TestHarness.pumpApp(
          tester,
          child: const Scaffold(body: Center(child: _ToggleWidget())),
        );
        await tester.tap(find.byKey(const Key('toggle_switch')));
        await TestHarness.pumpAndSettleSafely(tester);
        expect(find.text('ON'), findsOneWidget);
        expect(find.text('OFF'), findsNothing);
      });

      testWidgets('tap switch twice returns to OFF', (tester) async {
        await TestHarness.pumpApp(
          tester,
          child: const Scaffold(body: Center(child: _ToggleWidget())),
        );
        await tester.tap(find.byKey(const Key('toggle_switch')));
        await TestHarness.pumpAndSettleSafely(tester);
        await tester.tap(find.byKey(const Key('toggle_switch')));
        await TestHarness.pumpAndSettleSafely(tester);
        expect(find.text('OFF'), findsOneWidget);
      });
    });

    group('Text input widget', () {
      testWidgets('submitting text shows submitted label', (tester) async {
        await TestHarness.pumpApp(
          tester,
          child: const Scaffold(body: Center(child: _InputWidget())),
        );
        await tester.enterText(find.byKey(const Key('text_input')), 'France');
        await TestHarness.pumpAndSettleSafely(tester);
        await TestHarness.tapKey(tester, const Key('submit_btn'));
        expect(find.text('Submitted: France'), findsOneWidget);
      });

      testWidgets('empty submit does not show submitted label', (tester) async {
        await TestHarness.pumpApp(
          tester,
          child: const Scaffold(body: Center(child: _InputWidget())),
        );
        await TestHarness.tapKey(tester, const Key('submit_btn'));
        expect(find.byKey(const Key('submitted_label')), findsNothing);
      });

      testWidgets('entering and clearing text field works', (tester) async {
        await TestHarness.pumpApp(
          tester,
          child: const Scaffold(body: Center(child: _InputWidget())),
        );
        await tester.enterText(find.byKey(const Key('text_input')), 'Germany');
        await TestHarness.pumpAndSettleSafely(tester);
        expect(find.text('Germany'), findsOneWidget);
        await tester.enterText(find.byKey(const Key('text_input')), '');
        await TestHarness.pumpAndSettleSafely(tester);
        expect(find.text('Germany'), findsNothing);
      });

      testWidgets('submitting another country after France shows new label',
          (tester) async {
        await TestHarness.pumpApp(
          tester,
          child: const Scaffold(body: Center(child: _InputWidget())),
        );
        await tester.enterText(find.byKey(const Key('text_input')), 'France');
        await TestHarness.tapKey(tester, const Key('submit_btn'));
        expect(find.text('Submitted: France'), findsOneWidget);
        await tester.enterText(find.byKey(const Key('text_input')), 'Brazil');
        await TestHarness.tapKey(tester, const Key('submit_btn'));
        expect(find.text('Submitted: Brazil'), findsOneWidget);
        expect(find.text('Submitted: France'), findsNothing);
      });
    });

    group('Icon tap interactions', () {
      testWidgets('tapping info icon shows dialog', (tester) async {
        await TestHarness.pumpApp(
          tester,
          child: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => IconButton(
                  key: const Key('info_icon_btn'),
                  icon: const Icon(Icons.info_outline),
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => const AlertDialog(
                        title: Text('Info'),
                        content: Text('This is a test dialog.'),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await TestHarness.tapIcon(tester, Icons.info_outline);
        expect(find.text('Info'), findsOneWidget);
        expect(find.text('This is a test dialog.'), findsOneWidget);
      });

      testWidgets('dismiss dialog with tap outside restores background',
          (tester) async {
        await TestHarness.pumpApp(
          tester,
          child: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => IconButton(
                  key: const Key('info_icon_btn2'),
                  icon: const Icon(Icons.info_outline),
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => const AlertDialog(
                        title: Text('Info'),
                        content: Text('Tap outside to dismiss.'),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await TestHarness.tapIcon(tester, Icons.info_outline);
        expect(find.text('Info'), findsOneWidget);
        await tester.tapAt(const Offset(10, 10));
        await TestHarness.pumpAndSettleSafely(tester, frames: 15);
        expect(find.text('Info'), findsNothing);
      });
    });

    testWidgets(
      'game quiz answer submission — requires real device and Supabase',
      (tester) async {},
      skip: true, // Requires real device and authenticated Supabase session
    );
  });
}
