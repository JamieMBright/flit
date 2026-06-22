/// Widget-level integration test: app boot / initial render.
///
/// Verifies that the Flit app shell renders without crashing and that key
/// widgets are present after a few animation frames.
///
/// Run with: flutter test test/integration/
library app_boot_test;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_harness.dart';

void main() {
  group('App boot', () {
    testWidgets('renders without crashing', (tester) async {
      await TestHarness.pumpApp(tester);
      expect(find.byKey(const Key('stub_home_scaffold')), findsOneWidget);
    });

    testWidgets('home screen shows FLIT title', (tester) async {
      await TestHarness.pumpApp(tester);
      expect(find.byKey(const Key('flit_title')), findsOneWidget);
      expect(find.text('FLIT'), findsOneWidget);
    });

    testWidgets('home screen shows Play button', (tester) async {
      await TestHarness.pumpApp(tester);
      expect(find.byKey(const Key('stub_play_btn')), findsOneWidget);
      expect(find.text('Play'), findsOneWidget);
    });

    testWidgets('pumpAndSettleSafely does not deadlock on animated widget',
        (tester) async {
      // Use a widget with a continuous ticker to prove safe pump doesn't block.
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: _ContinuousAnimationWidget())),
      );
      // Drive 60 frames. If pumpAndSettle were used here it would deadlock.
      await TestHarness.pumpAndSettleSafely(tester, frames: 60);
      expect(find.byType(_ContinuousAnimationWidget), findsOneWidget);
    });

    testWidgets('screenshot helper does not throw on host runner',
        (tester) async {
      await TestHarness.pumpApp(tester);
      // takeScreenshot should be a no-op (not throw) when on host runner.
      await TestHarness.takeScreenshot(tester, 'app_boot_home');
    });

    testWidgets('MaterialApp theme is applied (dark background)',
        (tester) async {
      await TestHarness.pumpApp(tester);
      final scaffold = tester.widget<Scaffold>(
        find.byKey(const Key('stub_home_scaffold')),
      );
      expect(scaffold.backgroundColor, const Color(0xFF0A0E1A));
    });

    testWidgets('custom child widget is rendered when provided',
        (tester) async {
      await TestHarness.pumpApp(
        tester,
        child: const Scaffold(
          body: Center(child: Text('Custom Child', key: Key('custom_child'))),
        ),
      );
      expect(find.byKey(const Key('custom_child')), findsOneWidget);
      expect(find.text('Custom Child'), findsOneWidget);
    });
  });
}

// ---------------------------------------------------------------------------
// Helper — widget with a continuous animation ticker.
// ---------------------------------------------------------------------------

/// A widget that ticks forever (like the Flit globe shader), used to verify
/// that pumpAndSettleSafely terminates rather than looping forever.
class _ContinuousAnimationWidget extends StatefulWidget {
  const _ContinuousAnimationWidget();

  @override
  State<_ContinuousAnimationWidget> createState() =>
      _ContinuousAnimationWidgetState();
}

class _ContinuousAnimationWidgetState extends State<_ContinuousAnimationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => const SizedBox.expand(),
    );
  }
}
