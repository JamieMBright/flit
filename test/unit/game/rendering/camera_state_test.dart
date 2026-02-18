import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:flit/game/rendering/region_camera_presets.dart';
import 'package:flit/game/map/region.dart';

void main() {
  group('CameraPreset', () {
    test('world preset has valid default position', () {
      final preset = RegionCameraPresets.getPreset(GameRegion.world);
      expect(preset.centerLat, inInclusiveRange(-90.0, 90.0));
      expect(preset.centerLng, inInclusiveRange(-180.0, 180.0));
      expect(preset.altitudeDistance, greaterThan(0.0));
    });

    test('all regions have valid presets', () {
      for (final region in GameRegion.values) {
        final preset = RegionCameraPresets.getPreset(region);
        expect(
          preset.centerLat,
          inInclusiveRange(-90.0, 90.0),
          reason: '${region.name} lat out of range',
        );
        expect(
          preset.centerLng,
          inInclusiveRange(-180.0, 180.0),
          reason: '${region.name} lng out of range',
        );
        expect(
          preset.altitudeDistance,
          greaterThan(0.0),
          reason: '${region.name} altitude must be positive',
        );
        expect(
          preset.maxBoundsLat,
          greaterThan(0.0),
          reason: '${region.name} lat bounds must be positive',
        );
        expect(
          preset.maxBoundsLng,
          greaterThan(0.0),
          reason: '${region.name} lng bounds must be positive',
        );
      }
    });

    test('world preset has highest altitude', () {
      final worldAlt =
          RegionCameraPresets.getPreset(GameRegion.world).altitudeDistance;
      for (final region in GameRegion.values) {
        if (region == GameRegion.world) continue;
        final regionAlt =
            RegionCameraPresets.getPreset(region).altitudeDistance;
        expect(
          worldAlt,
          greaterThan(regionAlt),
          reason: 'World should be higher than ${region.name}',
        );
      }
    });

    test('regional presets have FOV overrides', () {
      for (final region in GameRegion.values) {
        if (region == GameRegion.world) {
          expect(
            RegionCameraPresets.getPreset(region).fovOverride,
            isNull,
            reason: 'World should not have FOV override',
          );
        } else {
          expect(
            RegionCameraPresets.getPreset(region).fovOverride,
            isNotNull,
            reason: '${region.name} should have FOV override',
          );
        }
      }
    });

    test('altitude distances are ordered by region scope', () {
      // World > US > Caribbean > UK > Ireland
      final world =
          RegionCameraPresets.getPreset(GameRegion.world).altitudeDistance;
      final us =
          RegionCameraPresets.getPreset(GameRegion.usStates).altitudeDistance;
      final uk =
          RegionCameraPresets.getPreset(GameRegion.ukCounties).altitudeDistance;
      final ireland =
          RegionCameraPresets.getPreset(GameRegion.ireland).altitudeDistance;

      expect(world, greaterThan(us));
      expect(us, greaterThan(uk));
      expect(ireland, lessThan(uk));
    });
  });

  group('CameraPreset bounds checking', () {
    test('center position is always within bounds', () {
      for (final region in GameRegion.values) {
        final preset = RegionCameraPresets.getPreset(region);
        expect(
          RegionCameraPresets.isWithinBounds(
            preset.centerLat,
            preset.centerLng,
            region,
          ),
          isTrue,
          reason: '${region.name} center should be within its own bounds',
        );
      }
    });

    test('position far from center is out of bounds for regional views', () {
      // A point in Asia should not be within the UK bounds
      expect(
        RegionCameraPresets.isWithinBounds(35.0, 135.0, GameRegion.ukCounties),
        isFalse,
      );
      // A point in Africa should not be within the US bounds
      expect(
        RegionCameraPresets.isWithinBounds(0.0, 30.0, GameRegion.usStates),
        isFalse,
      );
    });

    test('world bounds contain any reasonable position', () {
      expect(
        RegionCameraPresets.isWithinBounds(0.0, 0.0, GameRegion.world),
        isTrue,
      );
      expect(
        RegionCameraPresets.isWithinBounds(45.0, -100.0, GameRegion.world),
        isTrue,
      );
      expect(
        RegionCameraPresets.isWithinBounds(-30.0, 150.0, GameRegion.world),
        isTrue,
      );
    });

    test('clampToBounds clamps correctly', () {
      // A position far north of Ireland should be clamped
      final clamped = RegionCameraPresets.clampToBounds(
        70.0,
        -7.5,
        GameRegion.ireland,
      );
      final preset = RegionCameraPresets.getPreset(GameRegion.ireland);
      expect(
        clamped[0],
        closeTo(preset.centerLat + preset.maxBoundsLat, 0.001),
      );
      expect(clamped[1], closeTo(-7.5, 0.001));
    });
  });

  group('CameraPreset lat/lng to 3D conversion', () {
    // These tests verify the mathematical properties that the globe
    // renderer will rely on. The actual CameraState class will implement
    // the conversion; here we verify the expected math.

    test('equator/prime meridian maps to (1, 0, 0) on unit sphere', () {
      // lat=0, lng=0 should map to the positive X axis.
      const lat = 0.0;
      const lng = 0.0;
      const latRad = lat * pi / 180.0;
      const lngRad = lng * pi / 180.0;

      final x = cos(latRad) * cos(lngRad);
      final y = sin(latRad);
      final z = cos(latRad) * sin(lngRad);

      expect(x, closeTo(1.0, 1e-10));
      expect(y, closeTo(0.0, 1e-10));
      expect(z, closeTo(0.0, 1e-10));
    });

    test('north pole maps to (0, 1, 0) on unit sphere', () {
      const lat = 90.0;
      const lng = 0.0;
      const latRad = lat * pi / 180.0;
      const lngRad = lng * pi / 180.0;

      final x = cos(latRad) * cos(lngRad);
      final y = sin(latRad);
      final z = cos(latRad) * sin(lngRad);

      expect(x, closeTo(0.0, 1e-10));
      expect(y, closeTo(1.0, 1e-10));
      expect(z, closeTo(0.0, 1e-10));
    });

    test('lng=90 on equator maps to (0, 0, 1) on unit sphere', () {
      const lat = 0.0;
      const lng = 90.0;
      const latRad = lat * pi / 180.0;
      const lngRad = lng * pi / 180.0;

      final x = cos(latRad) * cos(lngRad);
      final y = sin(latRad);
      final z = cos(latRad) * sin(lngRad);

      expect(x, closeTo(0.0, 1e-10));
      expect(y, closeTo(0.0, 1e-10));
      expect(z, closeTo(1.0, 1e-10));
    });

    test('all 3D conversions produce unit-length vectors', () {
      // Test several random lat/lng and verify the result is on the unit sphere.
      final random = Random(42);
      for (int i = 0; i < 100; i++) {
        final lat = random.nextDouble() * 180.0 - 90.0;
        final lng = random.nextDouble() * 360.0 - 180.0;
        final latRad = lat * pi / 180.0;
        final lngRad = lng * pi / 180.0;

        final x = cos(latRad) * cos(lngRad);
        final y = sin(latRad);
        final z = cos(latRad) * sin(lngRad);

        final length = sqrt(x * x + y * y + z * z);
        expect(
          length,
          closeTo(1.0, 1e-10),
          reason: 'Point ($lat, $lng) should be on unit sphere',
        );
      }
    });

    test('camera update does not produce NaN', () {
      // Simulate a camera update cycle and check for NaN values.
      // This tests the math that CameraState.update() will use.
      final testCases = <List<double>>[
        [0.0, 0.0], // origin
        [90.0, 0.0], // north pole
        [-90.0, 0.0], // south pole
        [0.0, 180.0], // date line
        [0.0, -180.0], // date line (other side)
        [85.0, 170.0], // near pole, near date line
      ];

      for (final tc in testCases) {
        final lat = tc[0];
        final lng = tc[1];
        final latRad = lat * pi / 180.0;
        final lngRad = lng * pi / 180.0;

        final x = cos(latRad) * cos(lngRad);
        final y = sin(latRad);
        final z = cos(latRad) * sin(lngRad);

        expect(x.isNaN, isFalse, reason: 'x is NaN for lat=$lat, lng=$lng');
        expect(y.isNaN, isFalse, reason: 'y is NaN for lat=$lat, lng=$lng');
        expect(z.isNaN, isFalse, reason: 'z is NaN for lat=$lat, lng=$lng');
        expect(
          x.isInfinite,
          isFalse,
          reason: 'x is infinite for lat=$lat, lng=$lng',
        );
        expect(
          y.isInfinite,
          isFalse,
          reason: 'y is infinite for lat=$lat, lng=$lng',
        );
        expect(
          z.isInfinite,
          isFalse,
          reason: 'z is infinite for lat=$lat, lng=$lng',
        );
      }
    });
  });

  group('CameraPreset FOV and speed', () {
    test('FOV overrides are narrower than default 60 degrees', () {
      const defaultFov = 60.0;
      for (final region in GameRegion.values) {
        final preset = RegionCameraPresets.getPreset(region);
        if (preset.fovOverride != null) {
          expect(
            preset.fovOverride!,
            lessThan(defaultFov),
            reason: '${region.name} FOV should be narrower than default',
          );
          expect(
            preset.fovOverride!,
            greaterThan(20.0),
            reason: '${region.name} FOV should not be too narrow',
          );
        }
      }
    });
  });
}
