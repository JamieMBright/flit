import 'package:flutter_test/flutter_test.dart';
import 'package:flit/game/data/osm_features.dart';

void main() {
  group('OsmFeatures', () {
    group('Rivers', () {
      test('rivers list is non-empty', () {
        expect(OsmFeatures.rivers, isNotEmpty);
      });

      test('every river has a non-empty name', () {
        for (final river in OsmFeatures.rivers) {
          expect(river.name, isNotEmpty);
          expect(river.name.trim(), isNotEmpty);
        }
      });

      test('every river has at least 2 points', () {
        for (final river in OsmFeatures.rivers) {
          expect(
            river.points.length,
            greaterThanOrEqualTo(2),
            reason: 'River "${river.name}" has fewer than 2 points',
          );
        }
      });

      test('every river point has valid coordinates', () {
        for (final river in OsmFeatures.rivers) {
          for (final point in river.points) {
            expect(
              point.x,
              inInclusiveRange(-180.0, 180.0),
              reason: 'River "${river.name}" has longitude out of range: ${point.x}',
            );
            expect(
              point.y,
              inInclusiveRange(-90.0, 90.0),
              reason: 'River "${river.name}" has latitude out of range: ${point.y}',
            );
          }
        }
      });

      test('no duplicate names in rivers', () {
        final names = <String>{};
        for (final river in OsmFeatures.rivers) {
          expect(
            names.add(river.name),
            isTrue,
            reason: 'Duplicate river name: "${river.name}"',
          );
        }
      });
    });

    group('Lakes', () {
      test('lakes list is non-empty', () {
        expect(OsmFeatures.lakes, isNotEmpty);
      });

      test('every lake has a non-empty name', () {
        for (final lake in OsmFeatures.lakes) {
          expect(lake.name, isNotEmpty);
          expect(lake.name.trim(), isNotEmpty);
        }
      });

      test('every lake has valid center coordinates', () {
        for (final lake in OsmFeatures.lakes) {
          expect(
            lake.center.x,
            inInclusiveRange(-180.0, 180.0),
            reason: 'Lake "${lake.name}" has longitude out of range: ${lake.center.x}',
          );
          expect(
            lake.center.y,
            inInclusiveRange(-90.0, 90.0),
            reason: 'Lake "${lake.name}" has latitude out of range: ${lake.center.y}',
          );
        }
      });

      test('every lake has positive radius', () {
        for (final lake in OsmFeatures.lakes) {
          expect(
            lake.radiusDegrees,
            greaterThan(0),
            reason: 'Lake "${lake.name}" has non-positive radius: ${lake.radiusDegrees}',
          );
        }
      });

      test('no duplicate names in lakes', () {
        final names = <String>{};
        for (final lake in OsmFeatures.lakes) {
          expect(
            names.add(lake.name),
            isTrue,
            reason: 'Duplicate lake name: "${lake.name}"',
          );
        }
      });
    });

    group('Peaks', () {
      test('peaks list is non-empty', () {
        expect(OsmFeatures.peaks, isNotEmpty);
      });

      test('every peak has a non-empty name', () {
        for (final peak in OsmFeatures.peaks) {
          expect(peak.name, isNotEmpty);
          expect(peak.name.trim(), isNotEmpty);
        }
      });

      test('every peak has valid coordinates', () {
        for (final peak in OsmFeatures.peaks) {
          expect(
            peak.location.x,
            inInclusiveRange(-180.0, 180.0),
            reason: 'Peak "${peak.name}" has longitude out of range: ${peak.location.x}',
          );
          expect(
            peak.location.y,
            inInclusiveRange(-90.0, 90.0),
            reason: 'Peak "${peak.name}" has latitude out of range: ${peak.location.y}',
          );
        }
      });

      test('every peak has positive elevation', () {
        for (final peak in OsmFeatures.peaks) {
          expect(
            peak.elevationMeters,
            greaterThan(0),
            reason: 'Peak "${peak.name}" has non-positive elevation: ${peak.elevationMeters}',
          );
        }
      });

      test('no duplicate names in peaks', () {
        final names = <String>{};
        for (final peak in OsmFeatures.peaks) {
          expect(
            names.add(peak.name),
            isTrue,
            reason: 'Duplicate peak name: "${peak.name}"',
          );
        }
      });
    });

    group('Airports', () {
      test('airports list is non-empty', () {
        expect(OsmFeatures.airports, isNotEmpty);
      });

      test('every airport has a non-empty name', () {
        for (final airport in OsmFeatures.airports) {
          expect(airport.name, isNotEmpty);
          expect(airport.name.trim(), isNotEmpty);
        }
      });

      test('every airport has a non-empty code', () {
        for (final airport in OsmFeatures.airports) {
          expect(airport.iataCode, isNotEmpty);
          expect(airport.iataCode.trim(), isNotEmpty);
        }
      });

      test('every airport has valid coordinates', () {
        for (final airport in OsmFeatures.airports) {
          expect(
            airport.location.x,
            inInclusiveRange(-180.0, 180.0),
            reason: 'Airport "${airport.name}" (${airport.iataCode}) has longitude out of range: ${airport.location.x}',
          );
          expect(
            airport.location.y,
            inInclusiveRange(-90.0, 90.0),
            reason: 'Airport "${airport.name}" (${airport.iataCode}) has latitude out of range: ${airport.location.y}',
          );
        }
      });

      test('no duplicate names in airports', () {
        final names = <String>{};
        for (final airport in OsmFeatures.airports) {
          expect(
            names.add(airport.name),
            isTrue,
            reason: 'Duplicate airport name: "${airport.name}"',
          );
        }
      });

      test('no duplicate codes in airports', () {
        final codes = <String>{};
        for (final airport in OsmFeatures.airports) {
          expect(
            codes.add(airport.iataCode),
            isTrue,
            reason: 'Duplicate airport code: "${airport.iataCode}"',
          );
        }
      });
    });

    group('Volcanoes', () {
      test('volcanoes list is non-empty', () {
        expect(OsmFeatures.volcanoes, isNotEmpty);
      });

      test('every volcano has a non-empty name', () {
        for (final volcano in OsmFeatures.volcanoes) {
          expect(volcano.name, isNotEmpty);
          expect(volcano.name.trim(), isNotEmpty);
        }
      });

      test('every volcano has valid coordinates', () {
        for (final volcano in OsmFeatures.volcanoes) {
          expect(
            volcano.location.x,
            inInclusiveRange(-180.0, 180.0),
            reason: 'Volcano "${volcano.name}" has longitude out of range: ${volcano.location.x}',
          );
          expect(
            volcano.location.y,
            inInclusiveRange(-90.0, 90.0),
            reason: 'Volcano "${volcano.name}" has latitude out of range: ${volcano.location.y}',
          );
        }
      });

      test('every volcano has an isActive boolean', () {
        for (final volcano in OsmFeatures.volcanoes) {
          expect(volcano.isActive, isA<bool>());
        }
      });

      test('no duplicate names in volcanoes', () {
        final names = <String>{};
        for (final volcano in OsmFeatures.volcanoes) {
          expect(
            names.add(volcano.name),
            isTrue,
            reason: 'Duplicate volcano name: "${volcano.name}"',
          );
        }
      });
    });

    group('Sea Labels', () {
      test('seas list is non-empty', () {
        expect(OsmFeatures.seas, isNotEmpty);
      });

      test('every sea label has a non-empty name', () {
        for (final sea in OsmFeatures.seas) {
          expect(sea.name, isNotEmpty);
          expect(sea.name.trim(), isNotEmpty);
        }
      });

      test('every sea label has valid center coordinates', () {
        for (final sea in OsmFeatures.seas) {
          expect(
            sea.center.x,
            inInclusiveRange(-180.0, 180.0),
            reason: 'Sea label "${sea.name}" has longitude out of range: ${sea.center.x}',
          );
          expect(
            sea.center.y,
            inInclusiveRange(-90.0, 90.0),
            reason: 'Sea label "${sea.name}" has latitude out of range: ${sea.center.y}',
          );
        }
      });

      test('no duplicate names in sea labels', () {
        final names = <String>{};
        for (final sea in OsmFeatures.seas) {
          expect(
            names.add(sea.name),
            isTrue,
            reason: 'Duplicate sea label name: "${sea.name}"',
          );
        }
      });
    });

    group('Cross-category consistency', () {
      test('no duplicate names across all categories', () {
        final allNames = <String>{};

        for (final river in OsmFeatures.rivers) {
          expect(allNames.add(river.name), isTrue,
              reason: 'Name "${river.name}" appears in multiple categories');
        }

        for (final lake in OsmFeatures.lakes) {
          expect(allNames.add(lake.name), isTrue,
              reason: 'Name "${lake.name}" appears in multiple categories');
        }

        for (final peak in OsmFeatures.peaks) {
          expect(allNames.add(peak.name), isTrue,
              reason: 'Name "${peak.name}" appears in multiple categories');
        }

        for (final airport in OsmFeatures.airports) {
          expect(allNames.add(airport.name), isTrue,
              reason: 'Name "${airport.name}" appears in multiple categories');
        }

        for (final volcano in OsmFeatures.volcanoes) {
          expect(allNames.add(volcano.name), isTrue,
              reason: 'Name "${volcano.name}" appears in multiple categories');
        }

        for (final sea in OsmFeatures.seas) {
          expect(allNames.add(sea.name), isTrue,
              reason: 'Name "${sea.name}" appears in multiple categories');
        }
      });
    });
  });
}
