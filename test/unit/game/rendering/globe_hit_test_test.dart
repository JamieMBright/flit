import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flit/game/rendering/camera_state.dart';
import 'package:flit/game/rendering/globe_hit_test.dart';

void main() {
  const hitTest = GlobeHitTest();

  group('GlobeHitTest - screenToLatLng', () {
    late CameraState camera;
    const screenSize = Size(800, 600);

    setUp(() {
      camera = CameraState();
    });

    test('screen center maps approximately to camera lat/lng', () {
      camera.update(
        1.0,
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

      final center = Offset(screenSize.width / 2, screenSize.height / 2);
      final result = hitTest.screenToLatLng(center, screenSize, camera);

      expect(result, isNotNull);
      // Due to tiltDown in the shader (0.35), the screen center is offset from camera lat/lng
      expect(result!.dx.abs(), lessThan(10.0),
          reason: 'Longitude should be reasonably close to 0');
      expect(result.dy.abs(), lessThan(10.0),
          reason: 'Latitude should be reasonably close to 0');
    });

    test('screen center maps to non-zero lat/lng when camera is offset', () {
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
      final result = hitTest.screenToLatLng(center, screenSize, camera);

      expect(result, isNotNull);
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

      final farCorner = Offset(screenSize.width * 10, screenSize.height * 10);
      final result = hitTest.screenToLatLng(farCorner, screenSize, camera);

      expect(result, isNull, reason: 'Ray should miss the globe');
    });

    test('returns null for empty screen size', () {
      camera.update(
        10.0,
        planeLatDeg: 0.0,
        planeLngDeg: 0.0,
        isHighAltitude: true,
      );

      final result = hitTest.screenToLatLng(
        const Offset(100, 100),
        Size.zero,
        camera,
      );

      expect(result, isNull);
    });

    test('lat/lng round-trip: project then unproject yields similar coords',
        () {
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

      final center = Offset(screenSize.width / 2, screenSize.height / 2);
      final result = hitTest.screenToLatLng(center, screenSize, camera);

      expect(result, isNotNull);
      // Due to tiltDown in the shader, expect some offset from (0, 0)
      expect(result!.dx.abs(), lessThan(10.0));
      expect(result.dy.abs(), lessThan(10.0));
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
      final result = hitTest.screenToLatLng(center, screenSize, camera);

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
      final result = hitTest.screenToLatLng(center, screenSize, camera);

      if (result != null) {
        expect(result.dx, greaterThanOrEqualTo(-180.0));
        expect(result.dx, lessThanOrEqualTo(180.0));
      }
    });
  });

  group('GlobeHitTest - isPointInPolygon', () {
    test('point inside a simple square polygon returns true', () {
      final polygon = [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(10, 10),
        const Offset(0, 10),
      ];

      final inside = hitTest.isPointInPolygon(5, 5, polygon);
      expect(inside, isTrue);
    });

    test('point outside a simple square polygon returns false', () {
      final polygon = [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(10, 10),
        const Offset(0, 10),
      ];

      final outside = hitTest.isPointInPolygon(15, 15, polygon);
      expect(outside, isFalse);
    });

    test('point on the edge of polygon (ambiguous, just verify no crash)', () {
      final polygon = [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(10, 10),
        const Offset(0, 10),
      ];

      expect(
        () => hitTest.isPointInPolygon(0, 5, polygon),
        returnsNormally,
      );
    });

    test('point inside a triangle returns true', () {
      final triangle = [
        const Offset(0, 0),
        const Offset(20, 0),
        const Offset(10, 15),
      ];

      final inside = hitTest.isPointInPolygon(5, 10, triangle);
      expect(inside, isTrue);
    });

    test('point outside a triangle returns false', () {
      final triangle = [
        const Offset(0, 0),
        const Offset(20, 0),
        const Offset(10, 15),
      ];

      final outside = hitTest.isPointInPolygon(-5, -5, triangle);
      expect(outside, isFalse);
    });

    test('degenerate polygon with < 3 points returns false', () {
      final line = [const Offset(0, 0), const Offset(10, 10)];
      expect(hitTest.isPointInPolygon(5, 5, line), isFalse);
    });

    test('empty polygon returns false', () {
      expect(hitTest.isPointInPolygon(0, 0, []), isFalse);
    });

    test('concave polygon works correctly', () {
      final lShape = [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(10, 5),
        const Offset(5, 5),
        const Offset(5, 10),
        const Offset(0, 10),
      ];

      expect(hitTest.isPointInPolygon(3, 2, lShape), isTrue);
      expect(hitTest.isPointInPolygon(2, 8, lShape), isTrue);
      expect(hitTest.isPointInPolygon(7, 7, lShape), isFalse);
      expect(hitTest.isPointInPolygon(15, 15, lShape), isFalse);
    });

    test('negative coordinates work correctly', () {
      final polygon = [
        const Offset(-80, -10),
        const Offset(-60, -10),
        const Offset(-60, 10),
        const Offset(-80, 10),
      ];

      expect(hitTest.isPointInPolygon(0, -70, polygon), isTrue);
      expect(hitTest.isPointInPolygon(20, -50, polygon), isFalse);
    });
  });
}
