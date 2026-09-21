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
    testWidgets('center tap is inert when no clue double-tap follows',
        (tester) async {
      var clues = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: FlightControlSurface(
              mode: ControlMode.dPad,
              onSteeringChanged: (_) {},
              onThrottleChanged: (_) {},
              onReleased: () {},
              onDoubleTap: () => clues++,
            ),
          ),
        ),
      );

      final centre = tester.getCenter(find.byType(FlightControlSurface));
      final gesture = await tester.startGesture(centre);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));

      expect(clues, 0);
    });

    testWidgets('double tap invokes clue without altitude side effects',
        (tester) async {
      var clues = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: FlightControlSurface(
              mode: ControlMode.joystick,
              onSteeringChanged: (_) {},
              onThrottleChanged: (_) {},
              onReleased: () {},
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
    });

    testWidgets('D-pad handles left and right steering only',
        (tester) async {
      final steering = <double>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: FlightControlSurface(
              mode: ControlMode.dPad,
              onSteeringChanged: steering.add,
              onThrottleChanged: (_) {},
              onReleased: () {},
            ),
          ),
        ),
      );

      final box = tester.getRect(find.byType(FlightControlSurface));
      final left = Offset(box.left + 12, box.center.dy);
      final right = Offset(box.right - 12, box.center.dy);

      final leftPress = await tester.startGesture(left);
      await tester.pump();
      expect(steering.last, -1);
      await leftPress.up();
      await tester.pump();

      final rightPress = await tester.startGesture(right);
      await tester.pump();
      expect(steering.last, 1);
      await rightPress.up();
      await tester.pump();
    });

    testWidgets('joystick reports horizontal steering only',
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
      expect(throttle.last, 0);
      await gesture.moveBy(const Offset(-180, 260));
      expect(throttle.last, 0);
      await gesture.cancel();
    });
  });

  testWidgets('classic throttle control accepts taps at both extremes',
      (tester) async {
    final value = ValueNotifier<double>(0.4);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ValueListenableBuilder<double>(
              valueListenable: value,
              builder: (context, throttle, _) => SizedBox(
                width: 220,
                child: ClassicThrottleControl(
                  value: throttle,
                  onChanged: (next) => value.value = next,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final slider = find.byType(Slider);
    final rect = tester.getRect(slider);

    await tester.tapAt(Offset(rect.left + 4, rect.center.dy));
    await tester.pump();
    expect(value.value, closeTo(0, 0.02));

    await tester.tapAt(Offset(rect.right - 4, rect.center.dy));
    await tester.pump();
    expect(value.value, closeTo(1, 0.02));
  });

  testWidgets('classic throttle control responds to keyboard arrows',
      (tester) async {
    final value = ValueNotifier<double>(0.4);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ValueListenableBuilder<double>(
              valueListenable: value,
              builder: (context, throttle, _) => SizedBox(
                width: 220,
                child: ClassicThrottleControl(
                  value: throttle,
                  onChanged: (next) => value.value = next,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(value.value, closeTo(0.48, 0.001));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(value.value, closeTo(0.4, 0.001));
  });

  testWidgets('classic throttle control preset buttons jump to endpoints',
      (tester) async {
    final value = ValueNotifier<double>(0.4);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ValueListenableBuilder<double>(
              valueListenable: value,
              builder: (context, throttle, _) => SizedBox(
                width: 220,
                child: ClassicThrottleControl(
                  value: throttle,
                  onChanged: (next) => value.value = next,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('FULL'));
    await tester.pump();
    expect(value.value, 1);

    await tester.tap(find.text('IDLE'));
    await tester.pump();
    expect(value.value, 0);
  });
}
