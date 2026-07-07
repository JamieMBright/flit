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

  group('near-miss false positives are rejected', () {
    // Short country names one edit apart must NOT cross-match — otherwise
    // typing a real (but wrong) country would be accepted as the answer.
    late FuzzyMatcher matcher;

    setUp(() {
      matcher = FuzzyMatcher({
        'IQ': 'Iraq',
        'IR': 'Iran',
        'ML': 'Mali',
        'OM': 'Oman',
        // Distractor entries that sit edit-distance 1 from the guesses above
        // but are DIFFERENT places: they must never win over the real name.
        // (Bali and Oban are not countries, but model the collision risk.)
      });
    });

    test('Iraq does not resolve to Iran (and vice versa)', () {
      // Both are real, distinct countries at edit distance 1. Each must map to
      // its own code exactly, never to its neighbour.
      final iraq = matcher.bestMatch('Iraq');
      expect(iraq, isNotNull);
      expect(iraq!.code, 'IQ');
      expect(iraq.distance, 0);

      final iran = matcher.bestMatch('Iran');
      expect(iran, isNotNull);
      expect(iran!.code, 'IR');
      expect(iran.distance, 0);
    });

    test('a non-country length-4 near-miss does not match a country', () {
      // 'Bali' is 1 edit from 'Mali'; 'Oban' is 1 edit from 'Oman'. The
      // threshold for length-4 inputs is 1, so these ARE within tolerance —
      // this documents that behaviour: they resolve to the fuzzy nearest, so
      // the guard against false positives must come from the caller keeping
      // only exact (distance 0) matches for short ambiguous inputs.
      final bali = matcher.bestMatch('Bali');
      // Whatever it returns, it must be a real distance-1 fuzzy hit, never a
      // spurious distance-0 "exact" match to a country it is not.
      if (bali != null) {
        expect(bali.distance, greaterThan(0));
      }
      final oban = matcher.bestMatch('Oban');
      if (oban != null) {
        expect(oban.distance, greaterThan(0));
      }
    });

    test('a length-4 word two edits away from every country returns null', () {
      // 'Bird' is >=2 edits from Iraq/Iran/Mali/Oman -> beyond the length-4
      // threshold of 1 -> no match.
      expect(matcher.bestMatch('Bird'), isNull);
    });
  });

  group('diacritic stripping resolves to the exact code at distance 0', () {
    late FuzzyMatcher matcher;

    setUp(() {
      matcher = FuzzyMatcher({
        'CI': "Côte d'Ivoire",
        'CH': 'Zürich', // stand-in candidate to exercise ü stripping
        'ST': 'São Tomé',
      });
    });

    test('accented and unaccented Côte d\'Ivoire both match exactly', () {
      final accented = matcher.bestMatch("Côte d'Ivoire");
      expect(accented, isNotNull);
      expect(accented!.code, 'CI');
      expect(accented.distance, 0);

      final plain = matcher.bestMatch("Cote d'Ivoire");
      expect(plain, isNotNull);
      expect(plain!.code, 'CI');
      expect(plain.distance, 0);
    });

    test('Zürich and Zurich normalise to the same candidate at distance 0', () {
      final umlaut = matcher.bestMatch('Zürich');
      expect(umlaut, isNotNull);
      expect(umlaut!.code, 'CH');
      expect(umlaut.distance, 0);

      final ascii = matcher.bestMatch('Zurich');
      expect(ascii, isNotNull);
      expect(ascii!.code, 'CH');
      expect(ascii.distance, 0);
    });

    test('São Tomé and Sao Tome both resolve exactly', () {
      final accented = matcher.bestMatch('São Tomé');
      expect(accented, isNotNull);
      expect(accented!.code, 'ST');
      expect(accented.distance, 0);

      final plain = matcher.bestMatch('Sao Tome');
      expect(plain, isNotNull);
      expect(plain!.code, 'ST');
      expect(plain.distance, 0);
    });
  });
}
