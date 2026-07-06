import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flit/features/triangulation/recon_tutorial_screen.dart';
import 'package:flit/game/tutorial/mode_requirements.dart';
import 'package:flit/game/tutorial/training_missions.dart';

/// Behavioural gate for the guided Training Recon lesson. No golden images
/// (those are local scratch under test/golden) — this drives the flow and
/// asserts the teaching beats, the forgiving wrong-guess handling, and that
/// completion still reports a score for the campaign/unlock path.
void main() {
  Widget app(void Function(int) onComplete) => MaterialApp(
        home: ReconTutorialScreen(onComplete: onComplete),
      );

  // Pump the lesson on a tall phone surface so the scrolling content
  // (compass + neighbour chips) is laid out on-screen for taps.
  Future<void> pumpLesson(
    WidgetTester tester,
    void Function(int) onComplete,
  ) async {
    await tester.binding.setSurfaceSize(const Size(440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(onComplete));
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('Training Recon is coached by Saint-Exupéry', (tester) async {
    // The mission definition points at the recon-flavoured Saint-Exupéry.
    final recon =
        basicTrainingMissions.firstWhere((m) => m.id == trainingReconMissionId);
    expect(recon.coach.id, 'saint_exupery_recon');
    expect(recon.coach.name, contains('Saint-Exupéry'));
    expect(recon.coach.imageAsset, isNotNull);

    await pumpLesson(tester, (_) {});
    expect(find.textContaining('Saint-Exupéry'), findsWidgets);
    expect(find.text('BEGIN'), findsOneWidget);
  });

  testWidgets('walks five neighbour clues then teaches the compass',
      (tester) async {
    await pumpLesson(tester, (_) {});

    await tapText(tester, 'BEGIN'); // Spain
    expect(find.textContaining('Spain'), findsWidgets);
    for (var i = 0; i < 4; i++) {
      await tapText(tester, 'CONTINUE'); // UK, Algeria, Germany, Belgium
    }
    await tapText(tester, 'CONTINUE'); // -> compass intro
    // The compass labels every neighbour that locates the target.
    for (final name in [
      'Spain',
      'United Kingdom',
      'Algeria',
      'Germany',
      'Belgium'
    ]) {
      expect(find.text(name), findsWidgets, reason: name);
    }
    expect(find.text('TARGET'), findsOneWidget); // compass centre label
  });

  testWidgets('tap practice gates on inspecting all five neighbours',
      (tester) async {
    await pumpLesson(tester, (_) {});
    await tapText(tester, 'BEGIN');
    for (var i = 0; i < 5; i++) {
      await tapText(tester, 'CONTINUE');
    }
    // compassIntro -> tapPractice
    await tapText(tester, 'CONTINUE');
    expect(find.text('TAP ALL FIVE NEIGHBOURS'), findsOneWidget);

    // Inspect each neighbour chip (last match = chip, not compass label).
    for (final name in [
      'Spain',
      'United Kingdom',
      'Algeria',
      'Germany',
      'Belgium'
    ]) {
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
    }
    expect(find.text('CONTINUE'), findsOneWidget);
    // A bearing/distance read-out appears for the inspected neighbour.
    expect(find.textContaining('Bearing'), findsOneWidget);
    expect(find.textContaining('km away'), findsWidgets);
  });

  testWidgets('demonstrates the Andorra wrong guess before the real guess',
      (tester) async {
    await pumpLesson(tester, (_) {});
    await tapText(tester, 'BEGIN');
    for (var i = 0; i < 5; i++) {
      await tapText(tester, 'CONTINUE');
    }
    await tapText(tester, 'CONTINUE'); // -> tap practice
    for (final name in [
      'Spain',
      'United Kingdom',
      'Algeria',
      'Germany',
      'Belgium'
    ]) {
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
    }
    await tapText(tester, 'CONTINUE'); // -> wrong demo
    expect(find.textContaining('Andorra'), findsWidgets);
    expect(find.textContaining('WRONG guess'), findsOneWidget);
  });

  testWidgets('forgiving guess: wrong stays, France completes with a score',
      (tester) async {
    var score = -1;
    await pumpLesson(tester, (s) => score = s);
    await tapText(tester, 'BEGIN');
    for (var i = 0; i < 5; i++) {
      await tapText(tester, 'CONTINUE');
    }
    await tapText(tester, 'CONTINUE'); // -> tap practice
    for (final name in [
      'Spain',
      'United Kingdom',
      'Algeria',
      'Germany',
      'Belgium'
    ]) {
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
    }
    await tapText(tester, 'CONTINUE'); // -> wrong demo
    await tapText(tester, 'CONTINUE'); // -> guess prompt
    expect(find.text('Where do all the arrows point?'), findsOneWidget);

    // Wrong pick does not complete or advance.
    await tester.tap(find.text('Spain').last);
    await tester.pumpAndSettle();
    expect(score, -1);
    expect(find.text('Where do all the arrows point?'), findsOneWidget);

    // Correct pick -> solved, with a generous positive score.
    await tester.tap(find.text('France').last);
    await tester.pumpAndSettle();
    expect(find.text('TARGET LOCATED!'), findsOneWidget);
    await tapText(tester, 'COMPLETE LESSON');
    expect(score, greaterThan(0));
  });

  test('Training Recon still gates Daily Recon and Basic Training', () {
    // Completing Training Recon unlocks Daily Recon.
    expect(
      getModeRequirement('daily_triangulation')!
          .isUnlocked(1, {trainingReconMissionId}),
      isTrue,
    );
    // Recon is one of the three Basic Training missions that grant Level 2.
    expect(basicTrainingMissionIds.contains(trainingReconMissionId), isTrue);
  });
}
