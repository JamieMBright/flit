import 'package:flutter_test/flutter_test.dart';
import 'package:flit/game/quiz/fuzzy_match.dart';

void main() {
  group('FuzzyMatcher', () {
    late FuzzyMatcher matcher;

    setUp(() {
      matcher = FuzzyMatcher({
        'FR': 'France',
        'DE': 'Germany',
        'JP': 'Japan',
        'PH': 'Philippines',
        'KZ': 'Kazakhstan',
        'CI': "Cote d'Ivoire",
        'MM': 'Myanmar',
        'CZ': 'Czechia',
        'BA': 'Bosnia and Herzegovina',
        'GB': 'United Kingdom',
        'US': 'United States',
        'MX': 'Mexico',
        'BR': 'Brazil',
      });
    });

    test('exact match returns distance 0', () {
      final result = matcher.bestMatch('France');
      expect(result, isNotNull);
      expect(result!.code, 'FR');
      expect(result.distance, 0);
      expect(result.isExact, true);
    });

    test('case insensitive match', () {
      final result = matcher.bestMatch('france');
      expect(result, isNotNull);
      expect(result!.code, 'FR');
      expect(result.isExact, true);
    });

    test('match with extra whitespace', () {
      final result = matcher.bestMatch('  France  ');
      expect(result, isNotNull);
      expect(result!.code, 'FR');
    });

    test('common misspelling: Phillipines → Philippines', () {
      final result = matcher.bestMatch('Phillipines');
      expect(result, isNotNull);
      expect(result!.code, 'PH');
    });

    test('common misspelling: Kazakstan → Kazakhstan', () {
      final result = matcher.bestMatch('Kazakstan');
      expect(result, isNotNull);
      expect(result!.code, 'KZ');
    });

    test('alias match: Ivory Coast → Cote d\'Ivoire', () {
      final result = matcher.bestMatch('Ivory Coast');
      expect(result, isNotNull);
      expect(result!.code, 'CI');
    });

    test('alias match: Burma → Myanmar', () {
      final result = matcher.bestMatch('Burma');
      expect(result, isNotNull);
      expect(result!.code, 'MM');
    });

    test('alias match: Czech Republic → Czechia', () {
      final result = matcher.bestMatch('Czech Republic');
      expect(result, isNotNull);
      expect(result!.code, 'CZ');
    });

    test('short form: Bosnia → Bosnia and Herzegovina', () {
      final result = matcher.bestMatch('Bosnia');
      expect(result, isNotNull);
      expect(result!.code, 'BA');
    });

    test('alias: Britain → United Kingdom', () {
      final result = matcher.bestMatch('Britain');
      expect(result, isNotNull);
      expect(result!.code, 'GB');
    });

    test('abbreviation: USA → United States', () {
      final result = matcher.bestMatch('USA');
      expect(result, isNotNull);
      expect(result!.code, 'US');
    });

    test('too far off returns null', () {
      final result = matcher.bestMatch('xyzzyplugh');
      expect(result, isNull);
    });

    test('empty input returns null', () {
      final result = matcher.bestMatch('');
      expect(result, isNull);
    });

    test('excludeCodes prevents matching already-revealed areas', () {
      final result = matcher.bestMatch('France', excludeCodes: {'FR'});
      // Should not match France since it's excluded.
      expect(result == null || result.code != 'FR', true);
    });

    test('close Levenshtein match: Brasil → Brazil', () {
      final result = matcher.bestMatch('Brasil');
      expect(result, isNotNull);
      expect(result!.code, 'BR');
    });

    test('Levenshtein distance within threshold: Mexiko → Mexico', () {
      final result = matcher.bestMatch('Mexiko');
      expect(result, isNotNull);
      expect(result!.code, 'MX');
    });
  });

  group('Levenshtein distance', () {
    // Access via static method testing indirectly through matches.
    test('identical strings have distance 0', () {
      final matcher = FuzzyMatcher({'XX': 'test'});
      final result = matcher.bestMatch('test');
      expect(result, isNotNull);
      expect(result!.distance, 0);
    });

    test('single character difference detected', () {
      final matcher = FuzzyMatcher({'XX': 'cat'});
      final result = matcher.bestMatch('car');
      expect(result, isNotNull);
      // distance should be 1
      expect(result!.distance, lessThanOrEqualTo(1));
    });
  });
}
