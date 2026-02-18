import 'package:flutter_test/flutter_test.dart';
import 'package:flit/game/clues/clue_types.dart';

void main() {
  group('ClueType Enum', () {
    test('ClueType.values contains all expected types', () {
      const expectedTypes = {
        'flag',
        'outline',
        'borders',
        'capital',
        'stats',
        'sportsTeam',
        'leader',
        'nickname',
        'landmark',
        'flagDescription',
      };

      final actualNames = ClueType.values.map((t) => t.name).toSet();

      expect(actualNames, equals(expectedTypes));
      expect(ClueType.values.length, equals(10));
    });

    test('All ClueType values are unique', () {
      final typeNames = ClueType.values.map((t) => t.name).toList();
      final uniqueNames = typeNames.toSet();

      expect(typeNames.length, equals(uniqueNames.length));
    });
  });

  group('Clue Class - Basic Instantiation', () {
    test('Clue can be instantiated with flag type', () {
      const clue = const Clue(
        type: ClueType.flag,
        targetCountryCode: 'US',
        displayData: {'flagEmoji': '🇺🇸'},
      );

      expect(clue.type, equals(ClueType.flag));
      expect(clue.targetCountryCode, equals('US'));
      expect(clue.displayData, equals({'flagEmoji': '🇺🇸'}));
    });

    test('Clue can be instantiated with outline type', () {
      const clue = const Clue(
        type: ClueType.outline,
        targetCountryCode: 'FR',
        displayData: {'polygons': []},
      );

      expect(clue.type, equals(ClueType.outline));
      expect(clue.targetCountryCode, equals('FR'));
    });

    test('Clue can be instantiated with borders type', () {
      const clue = const Clue(
        type: ClueType.borders,
        targetCountryCode: 'CA',
        displayData: {
          'neighbors': ['United States'],
        },
      );

      expect(clue.type, equals(ClueType.borders));
      expect(clue.displayData['neighbors'], equals(['United States']));
    });

    test('Clue can be instantiated with capital type', () {
      const clue = const Clue(
        type: ClueType.capital,
        targetCountryCode: 'UK',
        displayData: {'capitalName': 'London'},
      );

      expect(clue.type, equals(ClueType.capital));
      expect(clue.displayData['capitalName'], equals('London'));
    });

    test('Clue can be instantiated with stats type', () {
      const clue = const Clue(
        type: ClueType.stats,
        targetCountryCode: 'DE',
        displayData: {'population': '83M', 'continent': 'Europe'},
      );

      expect(clue.type, equals(ClueType.stats));
      expect(clue.displayData['population'], equals('83M'));
    });

    test('Clue can be instantiated with sportsTeam type', () {
      const clue = const Clue(
        type: ClueType.sportsTeam,
        targetCountryCode: 'TX',
        displayData: {'team': 'Dallas Cowboys'},
      );

      expect(clue.type, equals(ClueType.sportsTeam));
      expect(clue.displayData['team'], equals('Dallas Cowboys'));
    });

    test('Clue can be instantiated with leader type', () {
      const clue = const Clue(
        type: ClueType.leader,
        targetCountryCode: 'CA',
        displayData: {'leader': 'Premier: John Horgan'},
      );

      expect(clue.type, equals(ClueType.leader));
      expect(clue.displayData['leader'], equals('Premier: John Horgan'));
    });

    test('Clue can be instantiated with nickname type', () {
      const clue = const Clue(
        type: ClueType.nickname,
        targetCountryCode: 'TX',
        displayData: {'nickname': 'The Lone Star State'},
      );

      expect(clue.type, equals(ClueType.nickname));
      expect(clue.displayData['nickname'], equals('The Lone Star State'));
    });

    test('Clue can be instantiated with landmark type', () {
      const clue = const Clue(
        type: ClueType.landmark,
        targetCountryCode: 'CA',
        displayData: {'landmark': 'Niagara Falls'},
      );

      expect(clue.type, equals(ClueType.landmark));
      expect(clue.displayData['landmark'], equals('Niagara Falls'));
    });

    test('Clue can be instantiated with flagDescription type', () {
      const clue = const Clue(
        type: ClueType.flagDescription,
        targetCountryCode: 'US',
        displayData: {'flagDesc': 'Red, white, and blue stripes'},
      );

      expect(clue.type, equals(ClueType.flagDescription));
      expect(
        clue.displayData['flagDesc'],
        equals('Red, white, and blue stripes'),
      );
    });
  });

  group('Clue.displayText - Non-empty text for all types', () {
    test('flag displayText is non-empty', () {
      const clue = const Clue(
        type: ClueType.flag,
        targetCountryCode: 'US',
        displayData: {'flagEmoji': '🇺🇸'},
      );

      expect(clue.displayText, isNotEmpty);
      expect(clue.displayText, equals('🇺🇸'));
    });

    test('outline displayText is non-empty', () {
      const clue = const Clue(
        type: ClueType.outline,
        targetCountryCode: 'FR',
        displayData: {'polygons': []},
      );

      expect(clue.displayText, isNotEmpty);
      expect(clue.displayText, equals('[Country Outline]'));
    });

    test('borders displayText is non-empty', () {
      const clue = const Clue(
        type: ClueType.borders,
        targetCountryCode: 'US',
        displayData: {
          'neighbors': ['Canada', 'Mexico'],
        },
      );

      expect(clue.displayText, isNotEmpty);
      expect(clue.displayText.contains('Borders:'), isTrue);
      expect(clue.displayText.contains('Canada'), isTrue);
      expect(clue.displayText.contains('Mexico'), isTrue);
    });

    test('capital displayText is non-empty', () {
      const clue = const Clue(
        type: ClueType.capital,
        targetCountryCode: 'UK',
        displayData: {'capitalName': 'London'},
      );

      expect(clue.displayText, isNotEmpty);
      expect(clue.displayText, equals('Capital: London'));
    });

    test('stats displayText is non-empty', () {
      const clue = const Clue(
        type: ClueType.stats,
        targetCountryCode: 'DE',
        displayData: {
          'population': '83M',
          'continent': 'Europe',
          'language': 'German',
        },
      );

      expect(clue.displayText, isNotEmpty);
      expect(clue.displayText.contains('Pop: 83M'), isTrue);
      expect(clue.displayText.contains('Continent: Europe'), isTrue);
      expect(clue.displayText.contains('Language: German'), isTrue);
    });

    test('sportsTeam displayText is non-empty', () {
      const clue = const Clue(
        type: ClueType.sportsTeam,
        targetCountryCode: 'TX',
        displayData: {'team': 'Dallas Cowboys'},
      );

      expect(clue.displayText, isNotEmpty);
      expect(clue.displayText, equals('Dallas Cowboys'));
    });

    test('leader displayText is non-empty', () {
      const clue = const Clue(
        type: ClueType.leader,
        targetCountryCode: 'CA',
        displayData: {'leader': 'Premier: John Horgan'},
      );

      expect(clue.displayText, isNotEmpty);
      expect(clue.displayText, equals('Premier: John Horgan'));
    });

    test('nickname displayText is non-empty', () {
      const clue = const Clue(
        type: ClueType.nickname,
        targetCountryCode: 'TX',
        displayData: {'nickname': 'The Lone Star State'},
      );

      expect(clue.displayText, isNotEmpty);
      expect(clue.displayText, equals('The Lone Star State'));
    });

    test('landmark displayText is non-empty', () {
      const clue = const Clue(
        type: ClueType.landmark,
        targetCountryCode: 'CA',
        displayData: {'landmark': 'Niagara Falls'},
      );

      expect(clue.displayText, isNotEmpty);
      expect(clue.displayText, equals('Niagara Falls'));
    });

    test('flagDescription displayText is non-empty', () {
      const clue = const Clue(
        type: ClueType.flagDescription,
        targetCountryCode: 'US',
        displayData: {'flagDesc': 'Red, white, and blue stripes'},
      );

      expect(clue.displayText, isNotEmpty);
      expect(clue.displayText, equals('Red, white, and blue stripes'));
    });
  });

  group('Clue Factory Methods', () {
    test('Clue.flag creates flag clue with flag emoji', () {
      final clue = Clue.flag('US');

      expect(clue.type, equals(ClueType.flag));
      expect(clue.targetCountryCode, equals('US'));
      expect(clue.displayData.containsKey('flagEmoji'), isTrue);
      expect(clue.displayData['flagEmoji'], isNotEmpty);
    });

    test('Clue.flag generates flag emoji for country code', () {
      final usClue = Clue.flag('US');
      final ukClue = Clue.flag('GB');

      expect(usClue.displayData['flagEmoji'], isNotEmpty);
      expect(ukClue.displayData['flagEmoji'], isNotEmpty);
      expect(
        usClue.displayData['flagEmoji'],
        isNot(equals(ukClue.displayData['flagEmoji'])),
      );
    });
  });

  group('Clue displayData Storage', () {
    test('displayData preserves all provided key-value pairs', () {
      final data = {
        'key1': 'value1',
        'key2': 123,
        'key3': true,
        'key4': ['list', 'of', 'items'],
      };

      final clue = Clue(
        type: ClueType.stats,
        targetCountryCode: 'US',
        displayData: data,
      );

      expect(clue.displayData, equals(data));
      expect(clue.displayData['key1'], equals('value1'));
      expect(clue.displayData['key2'], equals(123));
      expect(clue.displayData['key3'], equals(true));
      expect(clue.displayData['key4'], equals(['list', 'of', 'items']));
    });

    test('displayData can be empty map', () {
      const clue = const Clue(
        type: ClueType.flag,
        targetCountryCode: 'FR',
        displayData: {},
      );

      expect(clue.displayData, isEmpty);
    });

    test('targetCountryCode is stored correctly', () {
      const countryCode = 'JP';
      const clue = const Clue(
        type: ClueType.capital,
        targetCountryCode: countryCode,
        displayData: {'capitalName': 'Tokyo'},
      );

      expect(clue.targetCountryCode, equals(countryCode));
    });
  });

  group('ClueType Enum Name Property', () {
    test('All ClueType values have valid name property', () {
      for (final clueType in ClueType.values) {
        expect(clueType.name, isNotNull);
        expect(clueType.name, isNotEmpty);
      }
    });

    test('ClueType names match expected values', () {
      expect(ClueType.flag.name, equals('flag'));
      expect(ClueType.outline.name, equals('outline'));
      expect(ClueType.borders.name, equals('borders'));
      expect(ClueType.capital.name, equals('capital'));
      expect(ClueType.stats.name, equals('stats'));
      expect(ClueType.sportsTeam.name, equals('sportsTeam'));
      expect(ClueType.leader.name, equals('leader'));
      expect(ClueType.nickname.name, equals('nickname'));
      expect(ClueType.landmark.name, equals('landmark'));
      expect(ClueType.flagDescription.name, equals('flagDescription'));
    });
  });
}
