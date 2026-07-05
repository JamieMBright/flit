import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flit/game/map/region.dart';
import 'package:flit/game/rendering/flat_map_renderer.dart';

void main() {
  group('GameRegion enum', () {
    test('has all expected enum values', () {
      const values = GameRegion.values;
      expect(values.length, equals(20));
      expect(values, contains(GameRegion.world));
      expect(values, contains(GameRegion.usStates));
      expect(values, contains(GameRegion.ukCounties));
      expect(values, contains(GameRegion.caribbean));
      expect(values, contains(GameRegion.ireland));
      expect(values, contains(GameRegion.canadianProvinces));
      expect(values, contains(GameRegion.europe));
      expect(values, contains(GameRegion.africa));
      expect(values, contains(GameRegion.asia));
      expect(values, contains(GameRegion.latinAmerica));
      expect(values, contains(GameRegion.oceania));
      expect(values, contains(GameRegion.australia));
      expect(values, contains(GameRegion.france));
      expect(values, contains(GameRegion.germany));
      expect(values, contains(GameRegion.japan));
      expect(values, contains(GameRegion.spain));
      expect(values, contains(GameRegion.italy));
      expect(values, contains(GameRegion.brazil));
      expect(values, contains(GameRegion.india));
      expect(values, contains(GameRegion.newZealand));
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

    test('ukCounties returns exactly 108 areas', () {
      final areas = RegionalData.getAreas(GameRegion.ukCounties);
      expect(areas.length, equals(108));
    });

    test('canadianProvinces returns exactly 13 areas', () {
      final areas = RegionalData.getAreas(GameRegion.canadianProvinces);
      expect(areas.length, equals(13));
    });

    test('caribbean returns non-empty areas', () {
      final areas = RegionalData.getAreas(GameRegion.caribbean);
      expect(areas, isNotEmpty);
    });

    test('new country maps return the expected division counts', () {
      expect(RegionalData.getAreas(GameRegion.australia).length, 8);
      expect(RegionalData.getAreas(GameRegion.france).length, 13);
      expect(RegionalData.getAreas(GameRegion.germany).length, 16);
      expect(RegionalData.getAreas(GameRegion.japan).length, 47);
      expect(RegionalData.getAreas(GameRegion.spain).length, 16);
      expect(RegionalData.getAreas(GameRegion.italy).length, 20);
      expect(RegionalData.getAreas(GameRegion.brazil).length, 27);
      expect(RegionalData.getAreas(GameRegion.india).length, 34);
      expect(RegionalData.getAreas(GameRegion.newZealand).length, 16);
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

  group('Region tessellation sanity', () {
    // Signed shoelace area over all rings, in square degrees. Interior
    // holes are wound opposite to exteriors so they subtract correctly.
    double areaSqDeg(RegionalArea area) {
      final rings = area.polygons ?? [area.points];
      var total = 0.0;
      for (final ring in rings) {
        var signed = 0.0;
        for (var i = 0; i < ring.length; i++) {
          final a = ring[i];
          final b = ring[(i + 1) % ring.length];
          signed += a.x * b.y - b.x * a.y;
        }
        total += signed / 2;
      }
      return total.abs();
    }

    Set<String> vertexKeys(RegionalArea area) => {
          for (final p in area.points) '${p.x},${p.y}',
        };

    test('every Ireland county has a plausible area', () {
      final areas = RegionalData.getAreas(GameRegion.ireland);
      for (final area in areas) {
        // Smallest real county (Louth, 826 km2) is ~0.11 sq deg; anything
        // below 0.05 means the polygon regressed to a city-sized blob.
        expect(
          areaSqDeg(area),
          greaterThan(0.05),
          reason: 'County ${area.name} is implausibly small — polygon data '
              'may have regressed to non-tessellating captures',
        );
      }
    });

    test('Ireland counties sum to the area of the island', () {
      final areas = RegionalData.getAreas(GameRegion.ireland);
      final sum = areas.map(areaSqDeg).reduce((a, b) => a + b);
      // Island of Ireland is ~11.3 sq deg in equirectangular terms. A sum
      // far below means gaps/undersized counties; far above means overlaps.
      expect(sum, greaterThan(10.0));
      expect(sum, lessThan(12.5));
    });

    test('every Ireland county shares border vertices with a neighbour', () {
      final areas = RegionalData.getAreas(GameRegion.ireland);
      final keys = areas.map(vertexKeys).toList();
      for (var i = 0; i < areas.length; i++) {
        var shared = 0;
        for (var j = 0; j < areas.length && shared < 2; j++) {
          if (i == j) continue;
          shared = keys[i].intersection(keys[j]).length;
        }
        // Tessellating data shares exact vertex coordinates along county
        // borders. No Irish county is an island, so all must share >= 2.
        expect(
          shared,
          greaterThanOrEqualTo(2),
          reason: 'County ${areas[i].name} shares no border vertices with '
              'any neighbour — polygons no longer tessellate',
        );
      }
    });

    test('UK counties sum to the area of Great Britain + NI', () {
      final areas = RegionalData.getAreas(GameRegion.ukCounties);
      final sum = areas.map(areaSqDeg).reduce((a, b) => a + b);
      // UK admin areas total ~33.5 sq deg equirectangular.
      expect(sum, greaterThan(30.0));
      expect(sum, lessThan(37.0));
    });

    test('mainland UK counties share border vertices with a neighbour', () {
      final areas = RegionalData.getAreas(GameRegion.ukCounties);
      // Genuine islands with no land border to another area.
      const islands = {
        'Isle of Wight',
        'Isle of Anglesey',
        'Orkney Islands',
        'Shetland Islands',
        'Eilean Siar',
      };
      final keys = areas.map(vertexKeys).toList();
      for (var i = 0; i < areas.length; i++) {
        if (islands.contains(areas[i].name)) continue;
        var shared = 0;
        for (var j = 0; j < areas.length && shared < 2; j++) {
          if (i == j) continue;
          shared = keys[i].intersection(keys[j]).length;
        }
        expect(
          shared,
          greaterThanOrEqualTo(2),
          reason: 'County ${areas[i].name} shares no border vertices with '
              'any neighbour — polygons no longer tessellate',
        );
      }
    });

    test('grossly undersized regression check: County Dublin', () {
      final areas = RegionalData.getAreas(GameRegion.ireland);
      final dublin = areas.firstWhere((a) => a.name == 'Dublin');
      // County Dublin is ~922 km2 (~0.12 sq deg). The old broken data was
      // a city-sized blob of ~0.01 sq deg.
      expect(areaSqDeg(dublin), greaterThan(0.08));
    });

    // ── New country maps (same NE 10m shared-arc pipeline) ────────────────
    // Per-region sanity: every division has a plausible minimum area, the
    // divisions sum to the country's equirectangular area (no gaps, no
    // overlaps), and every non-island division shares exact border
    // vertices with a neighbour (tessellation). Bounds derive from the
    // generated data ±~5%; `islands` lists divisions with no land border.
    final tessellationCases = <({
      GameRegion region,
      double minArea,
      double sumLo,
      double sumHi,
      Set<String> islands,
    })>[
      (
        region: GameRegion.australia,
        minArea: 0.15, // ACT is ~0.22 sq deg
        sumLo: 660,
        sumHi: 730,
        islands: {'Tasmania'},
      ),
      (
        region: GameRegion.france,
        minArea: 0.5, // Corse is ~0.95 sq deg
        sumLo: 61,
        sumHi: 68,
        islands: {'Corse'},
      ),
      (
        region: GameRegion.germany,
        minArea: 0.03, // Bremen is ~0.05 sq deg
        sumLo: 43,
        sumHi: 48,
        islands: <String>{},
      ),
      (
        region: GameRegion.japan,
        minArea: 0.1, // Kagawa is ~0.18 sq deg
        sumLo: 36,
        sumHi: 41,
        islands: {'Hokkaido', 'Okinawa'},
      ),
      (
        region: GameRegion.spain,
        minArea: 0.3, // Balearic Islands are ~0.54 sq deg
        sumLo: 50,
        sumHi: 56,
        islands: {'Balearic Islands'},
      ),
      (
        region: GameRegion.italy,
        minArea: 0.2, // Aosta Valley is ~0.38 sq deg
        sumLo: 31,
        sumHi: 35,
        islands: {'Sicily', 'Sardinia'},
      ),
      (
        region: GameRegion.brazil,
        minArea: 0.3, // Distrito Federal is ~0.49 sq deg
        sumLo: 670,
        sumHi: 740,
        islands: <String>{},
      ),
      (
        region: GameRegion.india,
        minArea: 0.005, // Chandigarh is ~0.01 sq deg
        sumLo: 264,
        sumHi: 292,
        islands: <String>{},
      ),
      (
        region: GameRegion.newZealand,
        minArea: 0.02, // Nelson is ~0.04 sq deg
        sumLo: 27,
        sumHi: 31,
        islands: <String>{},
      ),
    ];

    for (final c in tessellationCases) {
      test('${c.region.name}: divisions have plausible areas and sum', () {
        final areas = RegionalData.getAreas(c.region);
        for (final area in areas) {
          expect(
            areaSqDeg(area),
            greaterThan(c.minArea),
            reason: '${c.region.name}/${area.name} is implausibly small — '
                'polygon data may have regressed',
          );
        }
        final sum = areas.map(areaSqDeg).reduce((a, b) => a + b);
        expect(
          sum,
          greaterThan(c.sumLo),
          reason: '${c.region.name} area sum too low — gaps or undersized '
              'divisions',
        );
        expect(
          sum,
          lessThan(c.sumHi),
          reason: '${c.region.name} area sum too high — overlapping '
              'divisions',
        );
      });

      test('${c.region.name}: non-island divisions share border vertices', () {
        final areas = RegionalData.getAreas(c.region);
        final keys = areas.map(vertexKeys).toList();
        for (var i = 0; i < areas.length; i++) {
          if (c.islands.contains(areas[i].name)) continue;
          var shared = 0;
          for (var j = 0; j < areas.length && shared < 2; j++) {
            if (i == j) continue;
            shared = keys[i].intersection(keys[j]).length;
          }
          expect(
            shared,
            greaterThanOrEqualTo(2),
            reason: '${c.region.name}/${areas[i].name} shares no border '
                'vertices with any neighbour — polygons no longer '
                'tessellate',
          );
        }
      });

      test('${c.region.name}: codes unique, metadata complete', () {
        final areas = RegionalData.getAreas(c.region);
        final codes = areas.map((a) => a.code).toSet();
        expect(codes.length, areas.length,
            reason: 'duplicate area codes in ${c.region.name}');
        for (final area in areas) {
          expect(area.code, isNotEmpty);
          expect(area.name, isNotEmpty);
          expect(area.capital, isNotNull);
          expect(area.capital, isNotEmpty,
              reason: '${c.region.name}/${area.name} missing capital');
          expect(area.population, isNotNull);
          expect(area.population, greaterThan(0));
          expect(area.funFact, isNotNull);
          expect(area.funFact, isNotEmpty,
              reason: '${c.region.name}/${area.name} missing funFact');
        }
      });
    }
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
