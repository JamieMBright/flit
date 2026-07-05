import 'package:flutter_test/flutter_test.dart';

import 'package:flit/data/models/cosmetic.dart';

void main() {
  group('Cosmetic', () {
    test('all plane cosmetics have wing spans defined', () {
      const planes = CosmeticCatalog.planes;

      for (final plane in planes) {
        expect(
          plane.wingSpan,
          isNotNull,
          reason: 'Plane ${plane.id} should have a wing span defined',
        );
        expect(
          plane.wingSpan,
          greaterThan(0),
          reason: 'Plane ${plane.id} wing span should be positive',
        );
      }
    });

    test('wing spans vary across different plane types', () {
      const planes = CosmeticCatalog.planes;
      final wingSpans = planes.map((p) => p.wingSpan).toSet();

      // Should have variety - at least 5 different wing spans
      expect(
        wingSpans.length,
        greaterThanOrEqualTo(5),
        reason: 'Different plane types should have different wing spans',
      );
    });

    test('default plane has baseline wing span', () {
      final defaultPlane = CosmeticCatalog.getById('plane_default');

      expect(defaultPlane, isNotNull);
      expect(defaultPlane!.wingSpan, equals(26.0));
    });

    test('contrail cosmetics do not require wing spans', () {
      const contrails = CosmeticCatalog.contrails;

      // Contrails may or may not have wing spans - just verify they exist
      expect(contrails.isNotEmpty, isTrue);
    });

    test('wing span serialization works correctly', () {
      const cosmetic = Cosmetic(
        id: 'test_plane',
        name: 'Test Plane',
        type: CosmeticType.plane,
        price: 100,
        wingSpan: 30.0,
      );

      final json = cosmetic.toJson();
      expect(json['wing_span'], equals(30.0));

      final deserialized = Cosmetic.fromJson(json);
      expect(deserialized.wingSpan, equals(30.0));
    });

    test('wing span deserialization handles null', () {
      final json = {
        'id': 'test',
        'name': 'Test',
        'type': 'plane',
        'price': 0,
        'rarity': 'common',
      };

      final cosmetic = Cosmetic.fromJson(json);
      expect(cosmetic.wingSpan, isNull);
    });
  });

  group('unlock ladder (owner spec: spread levels, no clustering)', () {
    test('no two planes unlock at the same level', () {
      final levels = <int, String>{};
      for (final plane in CosmeticCatalog.planes) {
        final level = plane.requiredLevel;
        if (level == null) continue;
        expect(
          levels.containsKey(level),
          isFalse,
          reason: 'Planes ${levels[level]} and ${plane.id} both unlock '
              'at level $level — spread them out',
        );
        levels[level] = plane.id;
      }
      // The ladder actually exists (not trivially empty).
      expect(levels.length, greaterThanOrEqualTo(8));
    });

    test('plane prices ascend with unlock level (coherent progression)', () {
      final gated = CosmeticCatalog.planes
          .where((p) => p.requiredLevel != null)
          .toList()
        ..sort((a, b) => a.requiredLevel!.compareTo(b.requiredLevel!));
      for (var i = 1; i < gated.length; i++) {
        expect(
          gated[i].price,
          greaterThan(gated[i - 1].price),
          reason: '${gated[i].id} (L${gated[i].requiredLevel}) should not '
              'be cheaper than ${gated[i - 1].id} '
              '(L${gated[i - 1].requiredLevel})',
        );
      }
    });

    test('no two companions unlock at the same level', () {
      final levels = <int>{};
      for (final companion in CosmeticCatalog.companions) {
        final level = companion.requiredLevel;
        if (level == null) continue;
        expect(levels.add(level), isTrue,
            reason: 'duplicate companion unlock level $level');
      }
    });

    test('early/mid game has an item unlock at least every other level', () {
      // Region unlocks (region.dart) ladder 3-19; item unlocks interleave
      // so nearly every early level-up has something. Guard the spacing:
      // no gap of more than 2 levels between item unlocks through L16.
      final itemLevels = CosmeticCatalog.all
          .map((c) => c.requiredLevel)
          .whereType<int>()
          .where((l) => l <= 16)
          .toSet()
          .toList()
        ..sort();
      expect(itemLevels.first, lessThanOrEqualTo(3));
      for (var i = 1; i < itemLevels.length; i++) {
        expect(
          itemLevels[i] - itemLevels[i - 1],
          lessThanOrEqualTo(2),
          reason: 'gap between item unlocks at L${itemLevels[i - 1]} and '
              'L${itemLevels[i]} is too wide',
        );
      }
      expect(itemLevels.last, greaterThanOrEqualTo(16));
    });
  });
}
