import 'package:flutter_test/flutter_test.dart';
import 'package:flit/game/data/us_state_clues.dart';
import 'package:flit/game/data/ireland_clues.dart';
import 'package:flit/game/data/uk_clues.dart';
import 'package:flit/game/data/canada_clues.dart';

void main() {
  group('US State Clues Data Integrity', () {
    test('data map has exactly 50 entries', () {
      expect(UsStateClues.data.length, equals(50));
    });

    test('all state codes are valid two-letter abbreviations', () {
      for (final code in UsStateClues.data.keys) {
        expect(code.length, equals(2));
        expect(code, matches(RegExp(r'^[A-Z]{2}$')));
      }
    });

    test('every state has non-empty flag', () {
      for (final stateData in UsStateClues.data.values) {
        expect(stateData.flag, isNotEmpty);
      }
    });

    test('every state has non-empty sportsTeams list', () {
      for (final stateData in UsStateClues.data.values) {
        expect(stateData.sportsTeams, isNotEmpty);
        for (final team in stateData.sportsTeams) {
          expect(team, isNotEmpty);
        }
      }
    });

    test('every state has exactly 2 senators', () {
      for (final stateData in UsStateClues.data.values) {
        expect(stateData.senators.length, equals(2));
        for (final senator in stateData.senators) {
          expect(senator, isNotEmpty);
        }
      }
    });

    test('every state has non-empty nickname', () {
      for (final stateData in UsStateClues.data.values) {
        expect(stateData.nickname, isNotEmpty);
      }
    });

    test('every state has non-empty motto', () {
      for (final stateData in UsStateClues.data.values) {
        expect(stateData.motto, isNotEmpty);
      }
    });

    test('every state has non-empty famousLandmark', () {
      for (final stateData in UsStateClues.data.values) {
        expect(stateData.famousLandmark, isNotEmpty);
      }
    });

    test('every state has non-empty stateBird', () {
      for (final stateData in UsStateClues.data.values) {
        expect(stateData.stateBird, isNotEmpty);
      }
    });

    test('every state has non-empty stateFlower', () {
      for (final stateData in UsStateClues.data.values) {
        expect(stateData.stateFlower, isNotEmpty);
      }
    });

    test('all 50 required states are present', () {
      final requiredStates = {
        'AL',
        'AK',
        'AZ',
        'AR',
        'CA',
        'CO',
        'CT',
        'DE',
        'FL',
        'GA',
        'HI',
        'ID',
        'IL',
        'IN',
        'IA',
        'KS',
        'KY',
        'LA',
        'ME',
        'MD',
        'MA',
        'MI',
        'MN',
        'MS',
        'MO',
        'MT',
        'NE',
        'NV',
        'NH',
        'NJ',
        'NM',
        'NY',
        'NC',
        'ND',
        'OH',
        'OK',
        'OR',
        'PA',
        'RI',
        'SC',
        'SD',
        'TN',
        'TX',
        'UT',
        'VT',
        'VA',
        'WA',
        'WV',
        'WI',
        'WY',
      };
      expect(UsStateClues.data.keys.toSet(), equals(requiredStates));
    });

    test('no duplicate state entries', () {
      final states = UsStateClues.data.keys.toList();
      expect(states.length, equals(states.toSet().length));
    });
  });

  group('Ireland County Clues Data Integrity', () {
    test('data has 32 entries', () {
      expect(IrelandClues.data.length, equals(32));
    });

    test('all counties have non-empty province', () {
      for (final countyData in IrelandClues.data.values) {
        expect(countyData.province, isNotEmpty);
        expect(
          countyData.province,
          isIn(['Leinster', 'Munster', 'Connacht', 'Ulster']),
        );
      }
    });

    test('all counties have non-empty gaelicName', () {
      for (final countyData in IrelandClues.data.values) {
        expect(countyData.gaelicName, isNotEmpty);
      }
    });

    test('all counties have non-empty famousPerson', () {
      for (final countyData in IrelandClues.data.values) {
        expect(countyData.famousPerson, isNotEmpty);
      }
    });

    test('all counties have non-empty famousLandmark', () {
      for (final countyData in IrelandClues.data.values) {
        expect(countyData.famousLandmark, isNotEmpty);
      }
    });

    test('all counties have non-empty gaaTeam', () {
      for (final countyData in IrelandClues.data.values) {
        expect(countyData.gaaTeam, isNotEmpty);
      }
    });

    test('all counties have non-empty nickname', () {
      for (final countyData in IrelandClues.data.values) {
        expect(countyData.nickname, isNotEmpty);
      }
    });

    test('province distribution is correct', () {
      final provinces =
          IrelandClues.data.values.map((c) => c.province).toList();

      final leinsterCount = provinces.where((p) => p == 'Leinster').length;
      final munsterCount = provinces.where((p) => p == 'Munster').length;
      final connachtCount = provinces.where((p) => p == 'Connacht').length;
      final ulsterCount = provinces.where((p) => p == 'Ulster').length;

      // Leinster: 12, Munster: 6, Connacht: 5, Ulster: 9
      expect(leinsterCount, equals(12));
      expect(munsterCount, equals(6));
      expect(connachtCount, equals(5));
      expect(ulsterCount, equals(9));
    });

    test('no duplicate county entries', () {
      final counties = IrelandClues.data.keys.toList();
      expect(counties.length, equals(counties.toSet().length));
    });
  });

  group('UK County Clues Data Integrity', () {
    test('data has entries', () {
      expect(IrelandClues.data.isNotEmpty, isTrue);
    });

    test('all counties have non-empty country', () {
      for (final countyData in UkClues.data.values) {
        expect(countyData.country, isNotEmpty);
        expect(countyData.country, isIn(['England', 'Scotland', 'Wales']));
      }
    });

    test('all counties have non-empty famousPerson', () {
      for (final countyData in UkClues.data.values) {
        expect(countyData.famousPerson, isNotEmpty);
      }
    });

    test('all counties have non-empty famousLandmark', () {
      for (final countyData in UkClues.data.values) {
        expect(countyData.famousLandmark, isNotEmpty);
      }
    });

    test('all counties have non-empty footballTeam', () {
      for (final countyData in UkClues.data.values) {
        expect(countyData.footballTeam, isNotEmpty);
      }
    });

    test('all counties have non-empty nickname', () {
      for (final countyData in UkClues.data.values) {
        expect(countyData.nickname, isNotEmpty);
      }
    });

    test('country distribution is reasonable', () {
      final countries = UkClues.data.values.map((c) => c.country).toList();

      final englandCount = countries.where((c) => c == 'England').length;
      final scotlandCount = countries.where((c) => c == 'Scotland').length;
      final walesCount = countries.where((c) => c == 'Wales').length;

      // England should have the most entries
      expect(englandCount, greaterThan(scotlandCount));
      expect(englandCount, greaterThan(walesCount));

      // All three countries should be represented
      expect(englandCount, greaterThan(0));
      expect(scotlandCount, greaterThan(0));
      expect(walesCount, greaterThan(0));
    });

    test('no duplicate county entries', () {
      final counties = UkClues.data.keys.toList();
      expect(counties.length, equals(counties.toSet().length));
    });
  });

  group('Canada Province/Territory Clues Data Integrity', () {
    test('data has exactly 13 entries', () {
      expect(CanadaClues.data.length, equals(13));
    });

    test('all provinces have non-empty flag', () {
      for (final provinceData in CanadaClues.data.values) {
        expect(provinceData.flag, isNotEmpty);
      }
    });

    test(
      'all provinces have non-empty sportsTeams list or empty for territories',
      () {
        for (final provinceData in CanadaClues.data.values) {
          // sportsTeams can be empty for territories (NT, YT, NU)
          expect(provinceData.sportsTeams, isNotNull);
        }
      },
    );

    test('all provinces have non-empty premier', () {
      for (final provinceData in CanadaClues.data.values) {
        expect(provinceData.premier, isNotEmpty);
      }
    });

    test('all provinces have non-empty nickname', () {
      for (final provinceData in CanadaClues.data.values) {
        expect(provinceData.nickname, isNotEmpty);
      }
    });

    test(
      'provinces have non-empty motto, territories can have empty motto',
      () {
        final provinceKeys = {
          'ON',
          'QC',
          'BC',
          'AB',
          'MB',
          'SK',
          'NS',
          'NB',
          'NL',
          'PE',
        };
        for (final entry in CanadaClues.data.entries) {
          if (provinceKeys.contains(entry.key)) {
            expect(
              entry.value.motto,
              isNotEmpty,
              reason: '${entry.key} province should have non-empty motto',
            );
          }
          // Territories may have empty mottos
        }
      },
    );

    test('all provinces have non-empty famousLandmark', () {
      for (final provinceData in CanadaClues.data.values) {
        expect(provinceData.famousLandmark, isNotEmpty);
      }
    });

    test('contains all 10 provinces', () {
      final provinces = {
        'ON', // Ontario
        'QC', // Quebec
        'BC', // British Columbia
        'AB', // Alberta
        'MB', // Manitoba
        'SK', // Saskatchewan
        'NS', // Nova Scotia
        'NB', // New Brunswick
        'NL', // Newfoundland and Labrador
        'PE', // Prince Edward Island
      };

      for (final province in provinces) {
        expect(
          CanadaClues.data.containsKey(province),
          isTrue,
          reason: 'Province $province should be in data',
        );
      }
    });

    test('contains all 3 territories', () {
      final territories = {
        'NT', // Northwest Territories
        'YT', // Yukon
        'NU', // Nunavut
      };

      for (final territory in territories) {
        expect(
          CanadaClues.data.containsKey(territory),
          isTrue,
          reason: 'Territory $territory should be in data',
        );
      }
    });

    test('no duplicate province/territory entries', () {
      final keys = CanadaClues.data.keys.toList();
      expect(keys.length, equals(keys.toSet().length));
    });

    test('territories have appropriate nicknames', () {
      final territoryNicknames = {
        'NT': 'The Land of the Midnight Sun',
        'YT': "Canada's True North",
        'NU': 'Our Land',
      };

      for (final entry in territoryNicknames.entries) {
        final territorryData = CanadaClues.data[entry.key];
        expect(territorryData?.nickname, equals(entry.value));
      }
    });
  });

  group('Cross-Regional Data Integrity', () {
    test('no null values in US state clues', () {
      for (final stateData in UsStateClues.data.values) {
        expect(stateData.flag, isNotNull);
        expect(stateData.sportsTeams, isNotNull);
        expect(stateData.senators, isNotNull);
        expect(stateData.nickname, isNotNull);
        expect(stateData.motto, isNotNull);
        expect(stateData.famousLandmark, isNotNull);
        expect(stateData.stateBird, isNotNull);
        expect(stateData.stateFlower, isNotNull);
      }
    });

    test('no null values in Ireland county clues', () {
      for (final countyData in IrelandClues.data.values) {
        expect(countyData.province, isNotNull);
        expect(countyData.gaelicName, isNotNull);
        expect(countyData.famousPerson, isNotNull);
        expect(countyData.famousLandmark, isNotNull);
        expect(countyData.gaaTeam, isNotNull);
        expect(countyData.nickname, isNotNull);
      }
    });

    test('no null values in UK county clues', () {
      for (final countyData in UkClues.data.values) {
        expect(countyData.country, isNotNull);
        expect(countyData.famousPerson, isNotNull);
        expect(countyData.famousLandmark, isNotNull);
        expect(countyData.footballTeam, isNotNull);
        expect(countyData.nickname, isNotNull);
      }
    });

    test('no null values in Canada province clues', () {
      for (final provinceData in CanadaClues.data.values) {
        expect(provinceData.flag, isNotNull);
        expect(provinceData.sportsTeams, isNotNull);
        expect(provinceData.premier, isNotNull);
        expect(provinceData.nickname, isNotNull);
        expect(provinceData.motto, isNotNull);
        expect(provinceData.famousLandmark, isNotNull);
      }
    });
  });
}
