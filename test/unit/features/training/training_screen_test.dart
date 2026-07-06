import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flit/data/providers/account_provider.dart';
import 'package:flit/features/training/training_screen.dart';
import 'package:flit/game/tutorial/mode_requirements.dart';

void main() {
  Future<ProviderContainer> pumpTrainingScreen(WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TrainingScreen()),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('level-1 pilot sees Basic Training with all three missions',
      (tester) async {
    await pumpTrainingScreen(tester);

    // Fresh pilots see the funnel surface titled BASIC TRAINING with the
    // 0/3 indicator and all three missions listed.
    expect(find.text('BASIC TRAINING'), findsWidgets);
    expect(find.text('0/3'), findsOneWidget);
    expect(find.text('Training Flight'), findsOneWidget);
    expect(find.text('Training Recon'), findsOneWidget);
    expect(find.text('Training Briefing'), findsOneWidget);

    // Each basic mission advertises the daily it unlocks.
    expect(find.text('Unlocks Daily Scramble'), findsOneWidget);
    expect(find.text('Unlocks Daily Recon'), findsOneWidget);
    expect(find.text('Unlocks Daily Briefing'), findsOneWidget);

    // The Advanced track is visible (scrolled into view) but gated.
    await tester.scrollUntilVisible(
      find.text('Opens after Basic Training'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('ADVANCED TRAINING'), findsOneWidget);
    expect(find.text('Opens after Basic Training'), findsOneWidget);
  });

  testWidgets('after the basics the surface shows the full 9-mission trail',
      (tester) async {
    final container = await pumpTrainingScreen(tester);
    final notifier = container.read(accountProvider.notifier);
    for (final id in basicTrainingMissionIds) {
      notifier.completeTrainingMission(id);
    }
    await tester.pump();

    expect(find.text('TRAINING MISSIONS'), findsOneWidget);
    expect(find.text('3/9'), findsOneWidget);

    // Advanced missions are now available on the same surface.
    await tester.scrollUntilVisible(
      find.text('First Sortie'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('First Sortie'), findsOneWidget);
    expect(
      find.text('Optional missions — one-time rewards'),
      findsOneWidget,
    );
  });
}
