import 'package:flutter_test/flutter_test.dart';

import 'package:flit/game/flit_game.dart';
import 'package:flit/game/components/plane_component.dart';

void main() {
  group('FlightThrottle', () {
    test('preserves legacy slow, medium, and fast calibration anchors', () {
      expect(
        FlightThrottle.multiplier(0, lowAltitude: false, flatMap: false),
        FlightThrottle.slowMultiplier,
      );
      expect(
        FlightThrottle.multiplier(0.5, lowAltitude: false, flatMap: false),
        FlightThrottle.mediumMultiplier,
      );
      expect(
        FlightThrottle.multiplier(1, lowAltitude: false, flatMap: false),
        FlightThrottle.fastMultiplier,
      );
    });

    test('interpolation is monotonic and continuous at the anchor', () {
      var previous = 0.0;
      for (var i = 0; i <= 100; i++) {
        final throttle = i / 100;
        final current = FlightThrottle.multiplier(
          throttle,
          lowAltitude: false,
          flatMap: false,
        );
        expect(current, greaterThanOrEqualTo(previous));
        previous = current;
      }

      final below = FlightThrottle.multiplier(
        0.5 - 1e-6,
        lowAltitude: false,
        flatMap: false,
      );
      final above = FlightThrottle.multiplier(
        0.5 + 1e-6,
        lowAltitude: false,
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

    test('low altitude and flat map curves retain their own endpoints', () {
      expect(
        FlightThrottle.multiplier(0, lowAltitude: true, flatMap: false),
        FlightThrottle.lowSlowMultiplier,
      );
      expect(
        FlightThrottle.multiplier(0.5, lowAltitude: true, flatMap: false),
        FlightThrottle.lowMediumMultiplier,
      );
      expect(
        FlightThrottle.multiplier(1, lowAltitude: true, flatMap: false),
        FlightThrottle.lowFastMultiplier,
      );
      expect(
        FlightThrottle.multiplier(0.5, lowAltitude: false, flatMap: true),
        FlightThrottle.flatMediumMultiplier,
      );
    });

    test('turn rate changes continuously with actual movement speed', () {
      final slow = PlaneComponent.turnRateForSpeed(18);
      final medium = PlaneComponent.turnRateForSpeed(36);
      final fast = PlaneComponent.turnRateForSpeed(90);

      expect(slow, greaterThan(medium));
      expect(medium, greaterThan(fast));
      expect(medium, closeTo(PlaneComponent.turnRate, 0.000001));
    });
  });
}
