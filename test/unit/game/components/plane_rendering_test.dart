import 'package:flutter_test/flutter_test.dart';

import 'package:flit/data/models/cosmetic.dart';
import 'package:flit/game/components/plane_component.dart';

void main() {
  group('PlaneComponent rendering variants', () {
    test('all plane cosmetics can be instantiated with their IDs', () {
      const planes = CosmeticCatalog.planes;

      for (final plane in planes) {
        // Should not throw when creating a PlaneComponent with any plane ID
        expect(
          () => PlaneComponent(
            onAltitudeChanged: (_) {},
            colorScheme: plane.colorScheme,
            wingSpan: plane.wingSpan ?? 26.0,
            equippedPlaneId: plane.id,
          ),
          returnsNormally,
          reason: 'PlaneComponent should accept ${plane.id}',
        );
      }
    });

    test('paper plane uses correct cosmetic ID', () {
      final paperPlane = CosmeticCatalog.getById('plane_paper');
      expect(paperPlane, isNotNull);
      expect(paperPlane!.id, equals('plane_paper'));
      expect(paperPlane.colorScheme!['primary'], equals(0xFFF5F5F5));
    });

    test('jet plane uses correct cosmetic ID', () {
      final jet = CosmeticCatalog.getById('plane_jet');
      expect(jet, isNotNull);
      expect(jet!.id, equals('plane_jet'));
      expect(jet.colorScheme!['primary'], equals(0xFFC0C0C0));
    });

    test('stealth bomber uses correct cosmetic ID', () {
      final stealth = CosmeticCatalog.getById('plane_stealth');
      expect(stealth, isNotNull);
      expect(stealth!.id, equals('plane_stealth'));
      expect(stealth.colorScheme!['primary'], equals(0xFF2A2A2A));
    });

    test('red baron triplane uses correct cosmetic ID', () {
      final redBaron = CosmeticCatalog.getById('plane_red_baron');
      expect(redBaron, isNotNull);
      expect(redBaron!.id, equals('plane_red_baron'));
      expect(redBaron.colorScheme!['primary'], equals(0xFFCC3333));
    });

    test('concorde uses correct cosmetic ID', () {
      final concorde = CosmeticCatalog.getById('plane_concorde_classic');
      expect(concorde, isNotNull);
      expect(concorde!.id, equals('plane_concorde_classic'));
      expect(concorde.wingSpan, equals(20.0));
    });

    test('seaplane uses correct cosmetic ID', () {
      final seaplane = CosmeticCatalog.getById('plane_seaplane');
      expect(seaplane, isNotNull);
      expect(seaplane!.id, equals('plane_seaplane'));
      expect(seaplane.wingSpan, equals(30.0));
    });

    test('airliner uses correct cosmetic ID', () {
      final bryanair = CosmeticCatalog.getById('plane_bryanair');
      expect(bryanair, isNotNull);
      expect(bryanair!.id, equals('plane_bryanair'));
      expect(bryanair.wingSpan, equals(32.0));
    });

    test('PlaneComponent stores equippedPlaneId correctly', () {
      final plane = PlaneComponent(
        onAltitudeChanged: (_) {},
        equippedPlaneId: 'plane_paper',
      );

      expect(plane.equippedPlaneId, equals('plane_paper'));
    });

    test('PlaneComponent defaults to plane_default when not specified', () {
      final plane = PlaneComponent(
        onAltitudeChanged: (_) {},
      );

      expect(plane.equippedPlaneId, equals('plane_default'));
    });

    test('PlaneComponent uses colorScheme from cosmetic', () {
      final paperPlane = CosmeticCatalog.getById('plane_paper');
      final plane = PlaneComponent(
        onAltitudeChanged: (_) {},
        colorScheme: paperPlane!.colorScheme,
        equippedPlaneId: paperPlane.id,
      );

      expect(plane.colorScheme, equals(paperPlane.colorScheme));
      expect(plane.colorScheme!['primary'], equals(0xFFF5F5F5));
    });

    test('PlaneComponent uses wingSpan from cosmetic', () {
      final rocket = CosmeticCatalog.getById('plane_rocket');
      final plane = PlaneComponent(
        onAltitudeChanged: (_) {},
        wingSpan: rocket!.wingSpan!,
        equippedPlaneId: rocket.id,
      );

      expect(plane.wingSpan, equals(18.0));
    });

    test('distinctive planes have unique IDs', () {
      final distinctivePlaneIds = {
        'plane_paper',
        'plane_jet',
        'plane_rocket',
        'plane_stealth',
        'plane_red_baron',
        'plane_concorde_classic',
        'plane_diamond_concorde',
        'plane_seaplane',
        'plane_bryanair',
        'plane_air_force_one',
        'plane_golden_jet',
      };

      for (final id in distinctivePlaneIds) {
        final plane = CosmeticCatalog.getById(id);
        expect(
          plane,
          isNotNull,
          reason: 'Distinctive plane $id should exist in catalog',
        );
      }
    });
  });
}
