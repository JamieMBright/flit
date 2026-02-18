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
}
