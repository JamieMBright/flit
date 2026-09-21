import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flit/core/services/game_settings.dart';
import 'package:flit/core/widgets/flight_control_widgets.dart';
import 'package:flit/game/ui/game_hud.dart';

void main() {
  Widget buildHud(ControlPlacement placement) => MaterialApp(
        home: Scaffold(
          body: GameHud(
            elapsedTime: Duration.zero,
            controlMode: ControlMode.joystick,
            controlPlacement: placement,
            throttle: 0.4,
            compactControlSurface: Container(
              key: const Key('surface'),
              width: 96,
              height: 96,
              color: Colors.blue,
            ),
            onThrottleChanged: (_) {},
          ),
        ),
      );

  testWidgets('sliderLeft places the throttle control to the left of surface',
      (tester) async {
    await tester.pumpWidget(buildHud(ControlPlacement.sliderLeft));

    final sliderRect = tester.getRect(find.byType(ClassicThrottleControl));
    final surfaceRect = tester.getRect(find.byKey(const Key('surface')));

    expect(sliderRect.right, lessThanOrEqualTo(surfaceRect.left));
  });

  testWidgets('sliderAbove places the throttle control above the surface',
      (tester) async {
    await tester.pumpWidget(buildHud(ControlPlacement.sliderAbove));

    final sliderRect = tester.getRect(find.byType(ClassicThrottleControl));
    final surfaceRect = tester.getRect(find.byKey(const Key('surface')));

    expect(sliderRect.bottom, lessThanOrEqualTo(surfaceRect.top));
  });

  testWidgets('compact controls avoid duplicate throttle gauge', (tester) async {
    await tester.pumpWidget(buildHud(ControlPlacement.sliderLeft));

    expect(find.byType(ThrottleGauge), findsNothing);
  });
}
