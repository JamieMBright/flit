import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flit/core/services/game_settings.dart';
import 'package:flit/features/campaign/tutorial_overlay.dart';
import 'package:flit/game/clues/clue_types.dart';
import 'package:flit/game/tutorial/campaign_mission.dart';
import 'package:flit/game/tutorial/coach.dart';

void main() {
  testWidgets('walks the complete control sequence before committing choice',
      (tester) async {
    final key = GlobalKey<TutorialOverlayState>();
    final demoModes = <ControlMode>[];
    var completed = false;

    const mission = CampaignMission(
      id: 'control_test',
      order: 1,
      title: 'Control Test',
      subtitle: 'Control Test',
      description: 'Control Test',
      coach: coachJRDTata,
      allowedClues: {ClueType.flag},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TutorialOverlay(
          key: key,
          mission: mission,
          onComplete: () => completed = true,
          onDemoControlModeChanged: demoModes.add,
        ),
      ),
    );

    await tester.tap(find.byType(TextButton).first);
    await tester.pump();

    key.currentState!.onTurnPressed();
    key.currentState!.onTurnPressed();
    key.currentState!.onTurnPressed();
    key.currentState!.onThrottleChanged(0.3);
    key.currentState!.onJoystickDragged(-1);
    key.currentState!.onJoystickDragged(1);
    key.currentState!.onControlSteering(0.1);
    key.currentState!.onControlSteering(0.8);
    key.currentState!.onThrottleChanged(0.5);
    key.currentState!.onControlReleased();
    key.currentState!.onDoubleTapClue();
    await tester.pump();

    expect(demoModes,
        containsAllInOrder([ControlMode.dPad, ControlMode.joystick]));
    expect(find.text('CLASSIC'), findsOneWidget);

    await tester.tap(find.text('CLASSIC'));
    await tester.pump();
    await tester.tap(find.text('BUTTON'));
    await tester.pump(const Duration(milliseconds: 3200));

    expect(completed, isTrue);
    expect(GameSettings.instance.controlMode, ControlMode.classic);
    expect(GameSettings.instance.clueTrigger, ClueTrigger.button);
  });
}
