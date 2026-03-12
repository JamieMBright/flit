import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flit/game/ui/ink_burst_overlay.dart';

void main() {
  group('InkBurstOverlay', () {
    testWidgets('renders as SizedBox.shrink when not triggered', (
      tester,
    ) async {
      final key = GlobalKey<InkBurstOverlayState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Stack(children: [InkBurstOverlay(key: key)])),
        ),
      );

      // Should not have an IgnorePointer from the overlay when idle.
      expect(
        find.descendant(
          of: find.byType(InkBurstOverlay),
          matching: find.byType(IgnorePointer),
        ),
        findsNothing,
      );
    });

    testWidgets('shows CustomPaint after trigger', (tester) async {
      final key = GlobalKey<InkBurstOverlayState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Stack(children: [InkBurstOverlay(key: key)])),
        ),
      );

      key.currentState!.trigger(const Offset(100, 100));
      await tester.pump();

      // Should now have a CustomPaint inside the overlay.
      expect(
        find.descendant(
          of: find.byType(InkBurstOverlay),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('wraps paint layer in IgnorePointer', (tester) async {
      final key = GlobalKey<InkBurstOverlayState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Stack(children: [InkBurstOverlay(key: key)])),
        ),
      );

      key.currentState!.trigger(const Offset(100, 100));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(InkBurstOverlay),
          matching: find.byType(IgnorePointer),
        ),
        findsOneWidget,
      );
    });

    testWidgets('clears particles after animation completes', (tester) async {
      final key = GlobalKey<InkBurstOverlayState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Stack(children: [InkBurstOverlay(key: key)])),
        ),
      );

      key.currentState!.trigger(const Offset(100, 100));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(InkBurstOverlay),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );

      // Advance past the 900ms animation duration.
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Particles should be cleared — back to SizedBox.shrink.
      expect(
        find.descendant(
          of: find.byType(InkBurstOverlay),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });

    testWidgets('can re-trigger while animating', (tester) async {
      final key = GlobalKey<InkBurstOverlayState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Stack(children: [InkBurstOverlay(key: key)])),
        ),
      );

      key.currentState!.trigger(const Offset(100, 100));
      await tester.pump(const Duration(milliseconds: 200));

      // Re-trigger before first burst finishes — should not throw.
      key.currentState!.trigger(const Offset(200, 200));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(InkBurstOverlay),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );

      // Let it complete.
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(
        find.descendant(
          of: find.byType(InkBurstOverlay),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });
  });
}
