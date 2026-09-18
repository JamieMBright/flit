import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flit/core/services/game_settings.dart';
import 'package:flit/core/widgets/flight_control_widgets.dart';

void main() {
  group('joystickAxisResponse', () {
    test('keeps fine corrections near centre and reaches lock at travel', () {
      final fine = joystickAxisResponse(75, 300);
      final strong = joystickAxisResponse(240, 300);

      expect(fine.abs(), lessThan(0.01));
      expect(strong, greaterThan(fine));
      expect(joystickAxisResponse(300, 300), 1);
      expect(joystickAxisResponse(-300, 300), -1);
    });

    test('has independent deadzones for each axis', () {
      expect(joystickAxisResponse(60, 300, deadzone: 0.22), 0);
      expect(joystickAxisResponse(70, 300, deadzone: 0.1), greaterThan(0));
    });
  });

  group('FlightControlSurface', () {
    testWidgets('center tap toggles altitude after double-tap window',
        (tester) async {
      var altitudeToggles = 0;
      var clues = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: FlightControlSurface(
              mode: ControlMode.dPad,
              onSteeringChanged: (_) {},
              onThrottleChanged: (_) {},
              onReleased: () {},
              onAltitudeToggle: () => altitudeToggles++,
              onDoubleTap: () => clues++,
            ),
          ),
        ),
      );

      final centre = tester.getCenter(find.byType(FlightControlSurface));
      final gesture = await tester.startGesture(centre);
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 281));

      expect(altitudeToggles, 1);
      expect(clues, 0);
    });

    testWidgets('double tap invokes clue without toggling altitude',
        (tester) async {
      var altitudeToggles = 0;
      var clues = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: FlightControlSurface(
              mode: ControlMode.joystick,
              onSteeringChanged: (_) {},
              onThrottleChanged: (_) {},
              onReleased: () {},
              onAltitudeToggle: () => altitudeToggles++,
              onDoubleTap: () => clues++,
            ),
          ),
        ),
      );

      final centre = tester.getCenter(find.byType(FlightControlSurface));
      final first = await tester.startGesture(centre);
      await first.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final second = await tester.startGesture(centre);
      await second.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(clues, 1);
      expect(altitudeToggles, 0);
    });

    testWidgets('D-pad tap steps throttle and hold uses continuous input',
        (tester) async {
      final inputs = <double>[];
      final steps = <double>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: FlightControlSurface(
              mode: ControlMode.dPad,
              onSteeringChanged: (_) {},
              onThrottleChanged: inputs.add,
              onReleased: () {},
              onThrottleStep: steps.add,
            ),
          ),
        ),
      );

      final box = tester.getRect(find.byType(FlightControlSurface));
      final upper = Offset(box.center.dx, box.top + 12);
      final tap = await tester.startGesture(upper);
      await tap.up();
      await tester.pump();
      expect(steps, [0.08]);

      final hold = await tester.startGesture(upper);
      await tester.pump(const Duration(milliseconds: 180));
      expect(inputs, contains(1));
      await hold.up();
      await tester.pump();
    });

    testWidgets('joystick reports diagonal steering and throttle',
        (tester) async {
      final steering = <double>[];
      final throttle = <double>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: FlightControlSurface(
              mode: ControlMode.joystick,
              travelDistance: 200,
              onSteeringChanged: steering.add,
              onThrottleChanged: throttle.add,
              onReleased: () {},
            ),
          ),
        ),
      );

      final centre = tester.getCenter(find.byType(FlightControlSurface));
      final gesture = await tester.startGesture(centre);
      await gesture.moveBy(const Offset(180, -180));
      expect(steering.last, greaterThan(0));
      expect(throttle.last, greaterThan(0));
      await gesture.cancel();
    });
  });
}
