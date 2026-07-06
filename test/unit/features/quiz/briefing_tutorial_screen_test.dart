import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flit/features/quiz/briefing_tutorial_screen.dart';
import 'package:flit/features/quiz/widgets/briefing_tutorial_map.dart';
import 'package:flit/game/map/country_data.dart';
import 'package:flit/game/tutorial/mode_requirements.dart';
import 'package:flit/game/tutorial/training_missions.dart';

/// Behavioural gate for the guided Training Briefing lesson. Mirrors the
/// Training Recon lesson test: it drives the teaching beats, the forgiving
/// tap handling, the demonstrated wrong tap, and that completion still reports
/// a score for the campaign/unlock path (Daily Briefing + Basic Training).
void main() {
  Widget app(void Function(int) onComplete) => MaterialApp(
        home: BriefingTutorialScreen(onComplete: onComplete),
      );

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

  /// Tap the map at the projected location of [code]'s capital.
  Future<void> tapCountry(WidgetTester tester, String code) async {
    final size = tester.getSize(find.byType(BriefingTutorialMap));
    final topLeft = tester.getTopLeft(find.byType(BriefingTutorialMap));
    final Vector2 cap = CountryData.getCapital(code)!.location;
    final local = BriefingTutorialMap.projectLocal(size, cap.x, cap.y);
    await tester.tapAt(topLeft + local);
    await tester.pumpAndSettle();
  }

  /// Advance from intro to the guided Egypt tap beat.
  Future<void> reachWalkEgypt(WidgetTester tester) async {
    await tapText(tester, 'BEGIN'); // -> learnRegion
    await tapText(tester, 'CONTINUE'); // -> walkEgypt
  }

  testWidgets('Training Briefing is coached by Lotfia El Nadi', (tester) async {
    final briefing = basicTrainingMissions
        .firstWhere((m) => m.id == trainingBriefingMissionId);
    expect(briefing.coach.id, 'lotfia_briefing');
    expect(briefing.coach.name, contains('Lotfia'));
    expect(briefing.coach.imageAsset, isNotNull);

    await pumpLesson(tester, (_) {});
    expect(find.textContaining('Lotfia'), findsWidgets);
    expect(find.text('BEGIN'), findsOneWidget);
  });

  testWidgets('walks the region then guides the first tap (Egypt)',
      (tester) async {
    await pumpLesson(tester, (_) {});
    await reachWalkEgypt(tester);
    // The guided beat asks for Egypt and gates on it.
    expect(find.text('TAP EGYPT'), findsOneWidget);
    expect(find.textContaining('Find: Egypt'), findsOneWidget);

    await tapCountry(tester, 'EG');
    // Found — the gate opens.
    expect(find.text('CONTINUE'), findsOneWidget);
    expect(find.textContaining('Found Egypt'), findsOneWidget);
  });

  testWidgets('demonstrates a wrong tap before the solo taps', (tester) async {
    await pumpLesson(tester, (_) {});
    await reachWalkEgypt(tester);
    await tapCountry(tester, 'EG');
    await tapText(tester, 'CONTINUE'); // -> wrongDemo
    expect(find.textContaining('red flash'), findsOneWidget);
    expect(find.textContaining('SAUDI ARABIA'), findsOneWidget);
  });

  testWidgets('forgiving solo tap: a wrong tap corrects, never punishes',
      (tester) async {
    await pumpLesson(tester, (_) {});
    await reachWalkEgypt(tester);
    await tapCountry(tester, 'EG');
    await tapText(tester, 'CONTINUE'); // -> wrongDemo
    await tapText(tester, 'CONTINUE'); // -> tapLibya
    expect(find.text('TAP LIBYA'), findsOneWidget);

    // Wrong tap (Egypt instead of Libya) does not advance; it gently corrects.
    await tapCountry(tester, 'EG');
    expect(find.text('TAP LIBYA'), findsOneWidget);
    expect(find.textContaining('Not quite'), findsOneWidget);

    // Correct tap opens the gate.
    await tapCountry(tester, 'LY');
    expect(find.text('CONTINUE'), findsOneWidget);
    expect(find.textContaining('Found Libya'), findsOneWidget);
  });

  testWidgets('completes with a generous score after all three finds',
      (tester) async {
    var score = -1;
    await pumpLesson(tester, (s) => score = s);
    await reachWalkEgypt(tester);
    await tapCountry(tester, 'EG');
    await tapText(tester, 'CONTINUE'); // -> wrongDemo
    await tapText(tester, 'CONTINUE'); // -> tapLibya
    await tapCountry(tester, 'LY');
    await tapText(tester, 'CONTINUE'); // -> tapSudan
    expect(find.text('TAP SUDAN'), findsOneWidget);
    await tapCountry(tester, 'SD');
    await tapText(tester, 'CONTINUE'); // -> solved

    expect(find.text('BRIEFING COMPLETE!'), findsOneWidget);
    expect(score, -1); // not reported until the pilot completes the lesson
    await tapText(tester, 'COMPLETE LESSON');
    expect(score, greaterThan(0));
  });

  test('Training Briefing still gates Daily Briefing and Basic Training', () {
    expect(
      getModeRequirement('daily_briefing')!
          .isUnlocked(1, {trainingBriefingMissionId}),
      isTrue,
    );
    expect(
      basicTrainingMissionIds.contains(trainingBriefingMissionId),
      isTrue,
    );
  });
}
