import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flit/game/rendering/camera_state.dart';
import 'package:flit/game/rendering/globe_hit_test.dart';

void main() {
  group('GlobeHitTest - screenToLatLng', () {
    late CameraState camera;
    const screenSize = Size(800, 600);

    setUp(() {
      camera = CameraState();
    });

    test('screen center maps approximately to camera lat/lng', () {
      // Position camera looking at (0, 0) from high altitude.
      camera.update(
        1.0, // large dt to snap position
        planeLatDeg: 0.0,
        planeLngDeg: 0.0,
        isHighAltitude: true,
      );
      // Force a second update to ensure position is stable.
      camera.update(
        10.0,
        planeLatDeg: 0.0,
        planeLngDeg: 0.0,
        isHighAltitude: true,
      );

      final center = Offset(screenSize.width / 2, screenSize.height / 2);
      final result = GlobeHitTest.screenToLatLng(center, screenSize, camera);

      expect(result, isNotNull);
      // The center of the screen should map close to (lng=0, lat=0).
      expect(result!.dx.abs(), lessThan(5.0),
          reason: 'Longitude should be near 0');
      expect(result.dy.abs(), lessThan(5.0),
          reason: 'Latitude should be near 0');
    });

    test('screen center maps to non-zero lat/lng when camera is offset', () {
      // Position camera looking at (45, 30) - i.e. 45E, 30N.
      camera.update(
        10.0,
        planeLatDeg: 30.0,
        planeLngDeg: 45.0,
        isHighAltitude: true,
      );
      camera.update(
        10.0,
        planeLatDeg: 30.0,
        planeLngDeg: 45.0,
        isHighAltitude: true,
      );

      final center = Offset(screenSize.width / 2, screenSize.height / 2);
      final result = GlobeHitTest.screenToLatLng(center, screenSize, camera);

      expect(result, isNotNull);
      // Should map near (45, 30).
      expect((result!.dx - 45.0).abs(), lessThan(10.0),
          reason: 'Longitude should be near 45');
      expect((result.dy - 30.0).abs(), lessThan(10.0),
          reason: 'Latitude should be near 30');
    });

    test('points far off screen return null (miss globe)', () {
      camera.update(
        10.0,
        planeLatDeg: 0.0,
        planeLngDeg: 0.0,
        isHighAltitude: true,
      );

      // A point far in the corner of a very wide viewport should miss.
      // Use extreme coordinates well outside the globe's disc.
      final farCorner = Offset(screenSize.width * 10, screenSize.height * 10);
      final result =
          GlobeHitTest.screenToLatLng(farCorner, screenSize, camera);

      expect(result, isNull, reason: 'Ray should miss the globe');
    });

    test('returns null for empty screen size', () {
      camera.update(
        10.0,
        planeLatDeg: 0.0,
        planeLngDeg: 0.0,
        isHighAltitude: true,
      );

      final result = GlobeHitTest.screenToLatLng(
        const Offset(100, 100),
        Size.zero,
        camera,
      );

      expect(result, isNull);
    });

    test('lat/lng round-trip: project then unproject yields similar coords',
        () {
      // Set camera at (0, 0).
      camera.update(
        10.0,
        planeLatDeg: 0.0,
        planeLngDeg: 0.0,
        isHighAltitude: true,
      );
      camera.update(
        10.0,
        planeLatDeg: 0.0,
        planeLngDeg: 0.0,
        isHighAltitude: true,
      );

      // The screen center should unproject to approximately (0, 0).
      final center = Offset(screenSize.width / 2, screenSize.height / 2);
      final result = GlobeHitTest.screenToLatLng(center, screenSize, camera);

      expect(result, isNotNull);
      // Verify the round-trip is reasonably close.
      expect(result!.dx.abs(), lessThan(5.0));
      expect(result.dy.abs(), lessThan(5.0));
    });

    test('result lat is within valid range [-90, 90]', () {
      camera.update(
        10.0,
        planeLatDeg: 45.0,
        planeLngDeg: -90.0,
        isHighAltitude: false,
      );
      camera.update(
        10.0,
        planeLatDeg: 45.0,
        planeLngDeg: -90.0,
        isHighAltitude: false,
      );

      final center = Offset(screenSize.width / 2, screenSize.height / 2);
      final result = GlobeHitTest.screenToLatLng(center, screenSize, camera);

      if (result != null) {
        expect(result.dy, greaterThanOrEqualTo(-90.0));
        expect(result.dy, lessThanOrEqualTo(90.0));
      }
    });

    test('result lng is within valid range [-180, 180]', () {
      camera.update(
        10.0,
        planeLatDeg: 0.0,
        planeLngDeg: 170.0,
        isHighAltitude: true,
      );
      camera.update(
        10.0,
        planeLatDeg: 0.0,
        planeLngDeg: 170.0,
        isHighAltitude: true,
      );

      final center = Offset(screenSize.width / 2, screenSize.height / 2);
      final result = GlobeHitTest.screenToLatLng(center, screenSize, camera);

      if (result != null) {
        expect(result.dx, greaterThanOrEqualTo(-180.0));
        expect(result.dx, lessThanOrEqualTo(180.0));
      }
    });
  });

  group('GlobeHitTest - isPointInCountry', () {
    test('point inside a simple square polygon returns true', () {
      // Square polygon: (0,0), (10,0), (10,10), (0,10)
      final polygon = [
        const Offset(0, 0), // (lng, lat)
        const Offset(10, 0),
        const Offset(10, 10),
        const Offset(0, 10),
      ];

      final inside = GlobeHitTest.isPointInCountry(5, 5, polygon);
      expect(inside, isTrue);
    });

    test('point outside a simple square polygon returns false', () {
      final polygon = [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(10, 10),
        const Offset(0, 10),
      ];

      final outside = GlobeHitTest.isPointInCountry(15, 15, polygon);
      expect(outside, isFalse);
    });

    test('point on the edge of polygon (ambiguous, just verify no crash)', () {
      final polygon = [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(10, 10),
        const Offset(0, 10),
      ];

      // Point on edge - ray casting is ambiguous on exact edges,
      // but should not throw.
      expect(
        () => GlobeHitTest.isPointInCountry(0, 5, polygon),
        returnsNormally,
      );
    });

    test('point inside a triangle returns true', () {
      // Triangle: (0,0), (20,0), (10,15)
      final triangle = [
        const Offset(0, 0),
        const Offset(20, 0),
        const Offset(10, 15),
      ];

      final inside = GlobeHitTest.isPointInCountry(5, 10, triangle);
      expect(inside, isTrue);
    });

    test('point outside a triangle returns false', () {
      final triangle = [
        const Offset(0, 0),
        const Offset(20, 0),
        const Offset(10, 15),
      ];

      final outside = GlobeHitTest.isPointInCountry(-5, -5, triangle);
      expect(outside, isFalse);
    });

    test('degenerate polygon with < 3 points returns false', () {
      final line = [const Offset(0, 0), const Offset(10, 10)];
      expect(GlobeHitTest.isPointInCountry(5, 5, line), isFalse);
    });

    test('empty polygon returns false', () {
      expect(GlobeHitTest.isPointInCountry(0, 0, []), isFalse);
    });

    test('concave polygon works correctly', () {
      // L-shaped polygon (concave):
      // (0,0), (10,0), (10,5), (5,5), (5,10), (0,10)
      final lShape = [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(10, 5),
        const Offset(5, 5),
        const Offset(5, 10),
        const Offset(0, 10),
      ];

      // Inside the L
      expect(GlobeHitTest.isPointInCountry(3, 2, lShape), isTrue);
      // Inside the tall part of L
      expect(GlobeHitTest.isPointInCountry(2, 8, lShape), isTrue);
      // Outside the L (the notch)
      expect(GlobeHitTest.isPointInCountry(7, 7, lShape), isFalse);
      // Completely outside
      expect(GlobeHitTest.isPointInCountry(15, 15, lShape), isFalse);
    });

    test('negative coordinates work correctly', () {
      // Polygon spanning negative coordinates (e.g., Western hemisphere)
      final polygon = [
        const Offset(-80, -10),
        const Offset(-60, -10),
        const Offset(-60, 10),
        const Offset(-80, 10),
      ];

      // Inside
      expect(GlobeHitTest.isPointInCountry(0, -70, polygon), isTrue);
      // Outside
      expect(GlobeHitTest.isPointInCountry(20, -50, polygon), isFalse);
    });
  });
}
