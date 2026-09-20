import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

import 'package:flit/game/flit_game.dart';
import 'package:flit/game/components/plane_component.dart';

void main() {
  group('FlightThrottle', () {
    test('preserves legacy slow, medium, and fast calibration anchors', () {
      expect(
        FlightThrottle.multiplier(0, flatMap: false),
        FlightThrottle.slowMultiplier,
      );
      expect(
        FlightThrottle.multiplier(0.5, flatMap: false),
        FlightThrottle.mediumMultiplier,
      );
      expect(
        FlightThrottle.multiplier(1, flatMap: false),
        FlightThrottle.fastMultiplier,
      );
    });

    test('interpolation is monotonic and continuous at the anchor', () {
      var previous = 0.0;
      for (var i = 0; i <= 100; i++) {
        final throttle = i / 100;
        final current = FlightThrottle.multiplier(
          throttle,
          flatMap: false,
        );
        expect(current, greaterThanOrEqualTo(previous));
        previous = current;
      }

      final below = FlightThrottle.multiplier(
        0.5 - 1e-6,
        flatMap: false,
      );
      final above = FlightThrottle.multiplier(
        0.5 + 1e-6,
        flatMap: false,
      );
      expect((above - below).abs(), lessThan(0.00002));
    });

    test('throttle acceleration is frame-rate independent', () {
      var atSixtyHz = 0.0;
      for (var i = 0; i < 60; i++) {
        atSixtyHz = FlightThrottle.applyInput(atSixtyHz, 1, 1 / 60);
      }

      var atThirtyHz = 0.0;
      for (var i = 0; i < 30; i++) {
        atThirtyHz = FlightThrottle.applyInput(atThirtyHz, 1, 1 / 30);
      }

      expect(atSixtyHz, closeTo(atThirtyHz, 0.000001));
      expect(
        FlightThrottle.applyInput(atSixtyHz, 0, 2),
        closeTo(atSixtyHz, 0.000001),
      );
    });

    test('throttle is clamped at both endpoints', () {
      expect(FlightThrottle.applyInput(0, -1, 1), 0);
      expect(FlightThrottle.applyInput(1, 1, 1), 1);
      expect(FlightThrottle.applyInput(0.5, 1, 0), 0.5);
    });

    test('launch defaults can start slow or full speed', () {
      expect(
        FlightThrottle.launchDefault(fullSpeed: false),
        FlightThrottle.min,
      );
      expect(
        FlightThrottle.launchDefault(fullSpeed: true),
        FlightThrottle.max,
      );
    });

    test('flat map curves retain their medium calibration anchor', () {
      expect(
        FlightThrottle.multiplier(0.5, flatMap: true),
        FlightThrottle.flatMediumMultiplier,
      );
    });

    test('maximum throttle preserves the legacy top speed', () {
      final globeTopSpeed =
          PlaneComponent.normalFlightSpeed *
          FlightThrottle.multiplier(1, flatMap: false);
      final flatMapTopSpeed =
          PlaneComponent.normalFlightSpeed *
          FlightThrottle.multiplier(1, flatMap: true);

      expect(
        globeTopSpeed,
        closeTo(
          PlaneComponent.normalFlightSpeed * FlightThrottle.fastMultiplier,
          0.000001,
        ),
      );
      expect(
        flatMapTopSpeed,
        closeTo(
          PlaneComponent.normalFlightSpeed * FlightThrottle.flatFastMultiplier,
          0.000001,
        ),
      );
    });

    test('turn rate preserves the legacy maximum turn circle', () {
      final slow = PlaneComponent.turnRateForSpeed(18);
      final medium = PlaneComponent.turnRateForSpeed(36);
      final fast = PlaneComponent.turnRateForSpeed(90);

      expect(slow, greaterThan(medium));
      expect(medium, closeTo(PlaneComponent.turnRate, 0.000001));
      expect(fast, closeTo(PlaneComponent.turnRate, 0.000001));
    });

    test('arrow key events are handled without an altitude action', () {
      final game = FlitGame();
      expect(
        () => game.onKeyEvent(
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.arrowUp,
            logicalKey: LogicalKeyboardKey.arrowUp,
            timeStamp: Duration.zero,
          ),
          {LogicalKeyboardKey.arrowUp},
        ),
        returnsNormally,
      );
      expect(
        () => game.onKeyEvent(
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.arrowDown,
            logicalKey: LogicalKeyboardKey.arrowDown,
            timeStamp: Duration.zero,
          ),
          {LogicalKeyboardKey.arrowDown},
        ),
        returnsNormally,
      );
    });
  });
}
