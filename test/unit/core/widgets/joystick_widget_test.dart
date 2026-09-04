import 'package:flutter_test/flutter_test.dart';
import 'package:flit/core/widgets/joystick_widget.dart';

void main() {
  group('joystickTurnStrength', () {
    test('has a deadzone around the centre', () {
      expect(joystickTurnStrength(0, 50), 0);
      expect(joystickTurnStrength(3, 50), 0);
      expect(joystickTurnStrength(-3, 50), 0);
    });

    test('is signed, nonlinear, and reaches full lock at the edge', () {
      final gentle = joystickTurnStrength(20, 50);
      final sharp = joystickTurnStrength(40, 50);

      expect(gentle, greaterThan(0));
      expect(sharp, greaterThan(gentle));
      expect(joystickTurnStrength(50, 50), 1);
      expect(joystickTurnStrength(-50, 50), -1);
    });

    test('tapers sensitivity toward full deflection', () {
      final midA = joystickTurnStrength(28, 50);
      final midB = joystickTurnStrength(34, 50);
      final edgeA = joystickTurnStrength(40, 50);
      final edgeB = joystickTurnStrength(46, 50);

      expect(midB - midA, greaterThan(edgeB - edgeA));
    });

    test('clamps displacement beyond the outer radius', () {
      expect(joystickTurnStrength(100, 50), 1);
      expect(joystickTurnStrength(-100, 50), -1);
    });
  });

  group('JoystickWidget', () {
    testWidgets('tracks a held pointer and releases on cancel', (tester) async {
      final values = <double>[];
      var released = false;

      await tester.pumpWidget(
        JoystickWidget(
          size: 100,
          onChanged: values.add,
          onReleased: () => released = true,
        ),
      );

      final centre = tester.getCenter(find.byType(JoystickWidget));
      final gesture = await tester.startGesture(centre);
      await gesture.moveBy(const Offset(35, 0));
      expect(values.last, greaterThan(0));
      await gesture.cancel();
      await tester.pump();

      expect(released, isTrue);
    });

    testWidgets('reports engagement only after lateral movement',
        (tester) async {
      var engagements = 0;

      await tester.pumpWidget(
        JoystickWidget(
          onChanged: (_) {},
          onReleased: () {},
          onDirectionChanged: (_) => engagements++,
        ),
      );

      final centre = tester.getCenter(find.byType(JoystickWidget));
      final gesture = await tester.startGesture(centre);
      await tester.pump();
      await gesture.moveBy(const Offset(25, 0));
      expect(engagements, greaterThanOrEqualTo(1));
      await gesture.moveBy(const Offset(10, 0));
      expect(engagements, 1);
      await gesture.up();
    });
  });
}
