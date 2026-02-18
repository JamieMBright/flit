import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flit/game/gameplay/landing_detector.dart';

void main() {
  late LandingDetector detector;

  setUp(() {
    detector = const LandingDetector();
  });

  group('LandingDetector.checkLanding', () {
    test('same position at low altitude is a landing', () {
      final pos = Vector2(10.0, 50.0);
      expect(detector.checkLanding(pos, pos, isLowAltitude: true), isTrue);
    });

    test('same position at high altitude is NOT a landing', () {
      final pos = Vector2(10.0, 50.0);
      expect(detector.checkLanding(pos, pos, isLowAltitude: false), isFalse);
    });

    test('within threshold at low altitude is a landing', () {
      // 5 degrees apart, threshold is 8
      final plane = Vector2(0.0, 0.0);
      final target = Vector2(5.0, 0.0);
      expect(detector.checkLanding(plane, target, isLowAltitude: true), isTrue);
    });

    test('beyond threshold is NOT a landing', () {
      // 20 degrees apart, threshold is 8
      final plane = Vector2(0.0, 0.0);
      final target = Vector2(20.0, 0.0);
      expect(
        detector.checkLanding(plane, target, isLowAltitude: true),
        isFalse,
      );
    });

    test('exactly at threshold boundary at low altitude is a landing', () {
      // Place target exactly 8 degrees away along equator
      final plane = Vector2(0.0, 0.0);
      final target = Vector2(8.0, 0.0);
      expect(detector.checkLanding(plane, target, isLowAltitude: true), isTrue);
    });
  });

  group('LandingDetector.getProximity', () {
    test('same position at low altitude returns landing', () {
      final pos = Vector2(0.0, 0.0);
      expect(
        detector.getProximity(pos, pos, isLowAltitude: true),
        equals(LandingProximity.landing),
      );
    });

    test('same position at high altitude returns near (not landing)', () {
      final pos = Vector2(0.0, 0.0);
      // Within 8 degrees but NOT low altitude: should be "near"
      expect(
        detector.getProximity(pos, pos, isLowAltitude: false),
        equals(LandingProximity.near),
      );
    });

    test('10 degrees away returns near', () {
      final plane = Vector2(0.0, 0.0);
      final target = Vector2(10.0, 0.0);
      expect(
        detector.getProximity(plane, target),
        equals(LandingProximity.near),
      );
    });

    test('20 degrees away returns approaching', () {
      final plane = Vector2(0.0, 0.0);
      final target = Vector2(20.0, 0.0);
      expect(
        detector.getProximity(plane, target),
        equals(LandingProximity.approaching),
      );
    });

    test('50 degrees away returns far', () {
      final plane = Vector2(0.0, 0.0);
      final target = Vector2(50.0, 0.0);
      expect(
        detector.getProximity(plane, target),
        equals(LandingProximity.far),
      );
    });

    test('180 degrees away returns far', () {
      final plane = Vector2(0.0, 0.0);
      final target = Vector2(180.0, 0.0);
      expect(
        detector.getProximity(plane, target),
        equals(LandingProximity.far),
      );
    });
  });

  group('LandingDetector.greatCircleDistanceDeg', () {
    test('same point has zero distance', () {
      final a = Vector2(10.0, 45.0);
      expect(LandingDetector.greatCircleDistanceDeg(a, a), closeTo(0.0, 1e-10));
    });

    test('equator distance is correct for known values', () {
      // Points on equator: 90 degrees apart in longitude = 90 degrees GC distance
      final a = Vector2(0.0, 0.0);
      final b = Vector2(90.0, 0.0);
      expect(LandingDetector.greatCircleDistanceDeg(a, b), closeTo(90.0, 0.01));
    });

    test('antipodal points are 180 degrees apart', () {
      final a = Vector2(0.0, 0.0);
      final b = Vector2(180.0, 0.0);
      expect(
        LandingDetector.greatCircleDistanceDeg(a, b),
        closeTo(180.0, 0.01),
      );
    });

    test('pole to equator is 90 degrees', () {
      // North pole to equator at any longitude
      final pole = Vector2(0.0, 90.0);
      final equator = Vector2(0.0, 0.0);
      expect(
        LandingDetector.greatCircleDistanceDeg(pole, equator),
        closeTo(90.0, 0.01),
      );
    });

    test('pole to pole is 180 degrees', () {
      final north = Vector2(0.0, 90.0);
      final south = Vector2(0.0, -90.0);
      expect(
        LandingDetector.greatCircleDistanceDeg(north, south),
        closeTo(180.0, 0.01),
      );
    });

    test('distance is symmetric', () {
      final a = Vector2(-73.9, 40.7); // NYC
      final b = Vector2(-0.1, 51.5); // London
      expect(
        LandingDetector.greatCircleDistanceDeg(a, b),
        closeTo(LandingDetector.greatCircleDistanceDeg(b, a), 1e-10),
      );
    });

    test('known distance: New York to London', () {
      // NYC: lng=-73.94, lat=40.67; London: lng=-0.12, lat=51.51
      // Great circle distance ~ 50.08 degrees (approximately 5585 km / 111.32 km per deg)
      final nyc = Vector2(-73.94, 40.67);
      final london = Vector2(-0.12, 51.51);
      final dist = LandingDetector.greatCircleDistanceDeg(nyc, london);

      // Expected: ~50.08 degrees (actual Haversine result)
      expect(dist, inInclusiveRange(49.5, 50.5));
    });

    test('date line crossing is handled correctly', () {
      // Points on opposite sides of the date line
      final a = Vector2(179.0, 0.0);
      final b = Vector2(-179.0, 0.0);
      // These are 2 degrees apart via Haversine (lng diff = 358 which wraps)
      // Actually Haversine handles this: dLng = -358 degrees in radians,
      // sin(dLng/2)^2 uses the trig identity, which still works correctly.
      final dist = LandingDetector.greatCircleDistanceDeg(a, b);
      expect(dist, closeTo(2.0, 0.1));
    });

    test('poles have same distance to any equator point', () {
      final pole = Vector2(0.0, 90.0);
      final eq1 = Vector2(0.0, 0.0);
      final eq2 = Vector2(90.0, 0.0);
      final eq3 = Vector2(-150.0, 0.0);

      final d1 = LandingDetector.greatCircleDistanceDeg(pole, eq1);
      final d2 = LandingDetector.greatCircleDistanceDeg(pole, eq2);
      final d3 = LandingDetector.greatCircleDistanceDeg(pole, eq3);

      expect(d1, closeTo(90.0, 0.01));
      expect(d2, closeTo(90.0, 0.01));
      expect(d3, closeTo(90.0, 0.01));
    });
  });

  group('LandingDetector with custom thresholds', () {
    test('custom landing threshold works', () {
      const custom = LandingDetector(landingThresholdDeg: 2.0);
      final plane = Vector2(0.0, 0.0);
      final target = Vector2(5.0, 0.0);

      // 5 degrees > 2 degree threshold
      expect(custom.checkLanding(plane, target, isLowAltitude: true), isFalse);

      // 1 degree < 2 degree threshold
      final closeTarget = Vector2(1.0, 0.0);
      expect(
        custom.checkLanding(plane, closeTarget, isLowAltitude: true),
        isTrue,
      );
    });
  });
}
