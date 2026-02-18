import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flit/game/map/region.dart';
import 'package:flit/game/rendering/flat_map_renderer.dart';

void main() {
  group('GameRegion enum', () {
    test('has all expected enum values', () {
      const values = GameRegion.values;
      expect(values.length, equals(6));
      expect(values, contains(GameRegion.world));
      expect(values, contains(GameRegion.usStates));
      expect(values, contains(GameRegion.ukCounties));
      expect(values, contains(GameRegion.caribbean));
      expect(values, contains(GameRegion.ireland));
      expect(values, contains(GameRegion.canadianProvinces));
    });

    test('each region has a non-empty displayName', () {
      for (final region in GameRegion.values) {
        expect(
          region.displayName,
          isNotEmpty,
          reason: 'Region ${region.name} should have a displayName',
        );
      }
    });

    test('each region has correct displayName values', () {
      expect(GameRegion.world.displayName, equals('World'));
      expect(GameRegion.usStates.displayName, equals('US States'));
      expect(GameRegion.ukCounties.displayName, equals('British Counties'));
      expect(GameRegion.caribbean.displayName, equals('Caribbean'));
      expect(GameRegion.ireland.displayName, equals('Ireland'));
      expect(GameRegion.canadianProvinces.displayName, equals('Canada'));
    });

    test('each region has requiredLevel >= 0', () {
      for (final region in GameRegion.values) {
        expect(
          region.requiredLevel,
          greaterThanOrEqualTo(0),
          reason: 'Region ${region.name} should have requiredLevel >= 0',
        );
      }
    });

    test('each region has correct requiredLevel values', () {
      expect(GameRegion.world.requiredLevel, equals(1));
      expect(GameRegion.usStates.requiredLevel, equals(3));
      expect(GameRegion.ukCounties.requiredLevel, equals(5));
      expect(GameRegion.caribbean.requiredLevel, equals(7));
      expect(GameRegion.ireland.requiredLevel, equals(10));
      expect(GameRegion.canadianProvinces.requiredLevel, equals(4));
    });
  });

  group('isRegionalFlatMap and isFlatMap', () {
    test('isFlatMap returns true for regional modes', () {
      expect(GameRegion.usStates.isFlatMap, isTrue);
      expect(GameRegion.ukCounties.isFlatMap, isTrue);
      expect(GameRegion.ireland.isFlatMap, isTrue);
      expect(GameRegion.canadianProvinces.isFlatMap, isTrue);
    });

    test('isFlatMap returns false for world and caribbean', () {
      expect(GameRegion.world.isFlatMap, isFalse);
      expect(GameRegion.caribbean.isFlatMap, isFalse);
    });

    test('isRegionalFlatMap function matches isFlatMap property', () {
      for (final region in GameRegion.values) {
        expect(
          isRegionalFlatMap(region),
          equals(region.isFlatMap),
          reason: 'isRegionalFlatMap should match isFlatMap for ${region.name}',
        );
      }
    });
  });

  group('RegionalData.getAreas', () {
    test('usStates returns exactly 50 areas', () {
      final areas = RegionalData.getAreas(GameRegion.usStates);
      expect(areas.length, equals(50));
    });

    test('ireland returns exactly 32 areas', () {
      final areas = RegionalData.getAreas(GameRegion.ireland);
      expect(areas.length, equals(32));
    });

    test('ukCounties returns exactly 97 areas', () {
      final areas = RegionalData.getAreas(GameRegion.ukCounties);
      expect(areas.length, equals(97));
    });

    test('canadianProvinces returns exactly 13 areas', () {
      final areas = RegionalData.getAreas(GameRegion.canadianProvinces);
      expect(areas.length, equals(13));
    });

    test('caribbean returns non-empty areas', () {
      final areas = RegionalData.getAreas(GameRegion.caribbean);
      expect(areas, isNotEmpty);
    });

    test('world returns areas (countries)', () {
      final areas = RegionalData.getAreas(GameRegion.world);
      expect(areas, isNotEmpty);
    });
  });

  group('RegionalArea properties', () {
    test('all usStates areas have non-empty names and codes', () {
      final areas = RegionalData.getAreas(GameRegion.usStates);
      for (final area in areas) {
        expect(
          area.name,
          isNotEmpty,
          reason: 'State ${area.code} should have a non-empty name',
        );
        expect(
          area.code,
          isNotEmpty,
          reason: 'State ${area.name} should have a non-empty code',
        );
      }
    });

    test('all usStates areas have at least 3 points', () {
      final areas = RegionalData.getAreas(GameRegion.usStates);
      for (final area in areas) {
        expect(
          area.points.length,
          greaterThanOrEqualTo(3),
          reason: 'State ${area.code} should have at least 3 boundary points',
        );
      }
    });

    test('all usStates areas have valid coordinates', () {
      final areas = RegionalData.getAreas(GameRegion.usStates);
      for (final area in areas) {
        for (final point in area.points) {
          expect(
            point.x,
            greaterThanOrEqualTo(-180),
            reason: 'State ${area.code} has invalid longitude ${point.x}',
          );
          expect(
            point.x,
            lessThanOrEqualTo(180),
            reason: 'State ${area.code} has invalid longitude ${point.x}',
          );
          expect(
            point.y,
            greaterThanOrEqualTo(-90),
            reason: 'State ${area.code} has invalid latitude ${point.y}',
          );
          expect(
            point.y,
            lessThanOrEqualTo(90),
            reason: 'State ${area.code} has invalid latitude ${point.y}',
          );
        }
      }
    });

    test('all ireland areas have non-empty names and codes', () {
      final areas = RegionalData.getAreas(GameRegion.ireland);
      for (final area in areas) {
        expect(
          area.name,
          isNotEmpty,
          reason: 'County ${area.code} should have a non-empty name',
        );
        expect(
          area.code,
          isNotEmpty,
          reason: 'County ${area.name} should have a non-empty code',
        );
      }
    });

    test('all ireland areas have at least 3 points', () {
      final areas = RegionalData.getAreas(GameRegion.ireland);
      for (final area in areas) {
        expect(
          area.points.length,
          greaterThanOrEqualTo(3),
          reason: 'County ${area.code} should have at least 3 boundary points',
        );
      }
    });

    test('all ireland areas have valid coordinates', () {
      final areas = RegionalData.getAreas(GameRegion.ireland);
      for (final area in areas) {
        for (final point in area.points) {
          expect(
            point.x,
            greaterThanOrEqualTo(-180),
            reason: 'County ${area.code} has invalid longitude ${point.x}',
          );
          expect(
            point.x,
            lessThanOrEqualTo(180),
            reason: 'County ${area.code} has invalid longitude ${point.x}',
          );
          expect(
            point.y,
            greaterThanOrEqualTo(-90),
            reason: 'County ${area.code} has invalid latitude ${point.y}',
          );
          expect(
            point.y,
            lessThanOrEqualTo(90),
            reason: 'County ${area.code} has invalid latitude ${point.y}',
          );
        }
      }
    });

    test('all ukCounties areas have non-empty names and codes', () {
      final areas = RegionalData.getAreas(GameRegion.ukCounties);
      for (final area in areas) {
        expect(
          area.name,
          isNotEmpty,
          reason: 'County ${area.code} should have a non-empty name',
        );
        expect(
          area.code,
          isNotEmpty,
          reason: 'County ${area.name} should have a non-empty code',
        );
      }
    });

    test('all canadianProvinces areas have non-empty names and codes', () {
      final areas = RegionalData.getAreas(GameRegion.canadianProvinces);
      for (final area in areas) {
        expect(
          area.name,
          isNotEmpty,
          reason: 'Province ${area.code} should have a non-empty name',
        );
        expect(
          area.code,
          isNotEmpty,
          reason: 'Province ${area.name} should have a non-empty code',
        );
      }
    });
  });

  group('GameRegion.bounds and center', () {
    test('all regions have valid bounds', () {
      for (final region in GameRegion.values) {
        final bounds = region.bounds;
        expect(bounds.length, equals(4));
        final minLng = bounds[0];
        final minLat = bounds[1];
        final maxLng = bounds[2];
        final maxLat = bounds[3];

        expect(
          minLng,
          lessThan(maxLng),
          reason: 'Region ${region.name} should have minLng < maxLng',
        );
        expect(
          minLat,
          lessThan(maxLat),
          reason: 'Region ${region.name} should have minLat < maxLat',
        );
      }
    });

    test('all regions have a valid center', () {
      for (final region in GameRegion.values) {
        final center = region.center;
        expect(center.x, greaterThanOrEqualTo(-180));
        expect(center.x, lessThanOrEqualTo(180));
        expect(center.y, greaterThanOrEqualTo(-90));
        expect(center.y, lessThanOrEqualTo(90));
      }
    });
  });

  group('FlatMapRenderer.worldToScreen', () {
    test('converts points within bounds to screen coordinates', () {
      final renderer = FlatMapRenderer(region: GameRegion.usStates);
      renderer.onMount();

      // Use a point within the US bounds
      final usCenter = GameRegion.usStates.center;
      const screenW = 800.0;
      const screenH = 600.0;

      final screenCoords = renderer.worldToScreen(usCenter, screenW, screenH);

      // Should return valid screen coordinates (not off-screen)
      expect(screenCoords.x, greaterThanOrEqualTo(0));
      expect(screenCoords.x, lessThanOrEqualTo(screenW));
      expect(screenCoords.y, greaterThanOrEqualTo(0));
      expect(screenCoords.y, lessThanOrEqualTo(screenH));
    });

    test('returns off-screen marker for points far outside bounds', () {
      final renderer = FlatMapRenderer(region: GameRegion.usStates);
      renderer.onMount();

      const screenW = 800.0;
      const screenH = 600.0;

      // Point at North Pole (definitely outside US bounds)
      final offScreenCoords = renderer.worldToScreen(
        Vector2(0, 85),
        screenW,
        screenH,
      );

      // Should return the off-screen marker
      expect(offScreenCoords.x, equals(-9999));
      expect(offScreenCoords.y, equals(-9999));
    });

    test('screenToWorld is inverse of worldToScreen', () {
      final renderer = FlatMapRenderer(region: GameRegion.ireland);
      renderer.onMount();

      const screenW = 1024.0;
      const screenH = 768.0;

      final originalWorldPos = GameRegion.ireland.center;

      // Convert world to screen
      final screenPos = renderer.worldToScreen(
        originalWorldPos,
        screenW,
        screenH,
      );

      // Only test if the point was on-screen
      if (screenPos.x != -9999 && screenPos.y != -9999) {
        // Convert screen back to world
        final reconstructedWorldPos = renderer.screenToWorld(
          screenPos,
          screenW,
          screenH,
        );

        // Should be close to the original (within floating point precision)
        expect(reconstructedWorldPos.x, closeTo(originalWorldPos.x, 0.1));
        expect(reconstructedWorldPos.y, closeTo(originalWorldPos.y, 0.1));
      }
    });

    test('worldToScreen produces consistent results for same input', () {
      final renderer = FlatMapRenderer(region: GameRegion.canadianProvinces);
      renderer.onMount();

      const screenW = 1280.0;
      const screenH = 720.0;

      final testPoint = GameRegion.canadianProvinces.center;

      final result1 = renderer.worldToScreen(testPoint, screenW, screenH);
      final result2 = renderer.worldToScreen(testPoint, screenW, screenH);

      expect(result1.x, equals(result2.x));
      expect(result1.y, equals(result2.y));
    });

    test('worldToScreen handles edge cases within bounds', () {
      final renderer = FlatMapRenderer(region: GameRegion.ireland);
      renderer.onMount();

      const screenW = 800.0;
      const screenH = 600.0;

      // Test multiple points to ensure no crashes
      final testPoints = [
        GameRegion.ireland.center,
        Vector2(-8, 53),
        Vector2(-6, 54),
      ];

      for (final point in testPoints) {
        final result = renderer.worldToScreen(point, screenW, screenH);
        // Should return either valid coordinates or the off-screen marker
        expect(
          result.x != -9999 || result.y == -9999,
          isTrue,
          reason: 'worldToScreen should handle point $point gracefully',
        );
      }
    });
  });

  group('RegionalData.getRandomArea', () {
    test('getRandomArea returns a valid area for each region', () {
      for (final region in GameRegion.values) {
        final randomArea = RegionalData.getRandomArea(region);
        expect(randomArea, isNotNull);
        expect(randomArea.name, isNotEmpty);
        expect(randomArea.code, isNotEmpty);
      }
    });

    test('getRandomArea returns areas from the correct region', () {
      final usStates = RegionalData.getAreas(GameRegion.usStates);
      final randomUsArea = RegionalData.getRandomArea(GameRegion.usStates);

      expect(
        usStates,
        contains(randomUsArea),
        reason: 'Random area should be from the requested region',
      );
    });
  });
}
