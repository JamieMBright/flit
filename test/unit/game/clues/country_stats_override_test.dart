import 'package:flit/game/clues/clue_types.dart';
import 'package:flit/game/clues/country_stats_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the runtime override layer for volatile country stats.
///
/// The baked-in Dart `allStats` map is the offline baseline; the weekly
/// Wikidata refresh writes overrides for `headOfState` / `population` into
/// `assets/data/country_stats.json`, loaded by [CountryStats]. These tests
/// confirm:
///   (a) with no load, stats fall back to the Dart const (fail-safe);
///   (b) an injected override changes ONLY headOfState/population, leaving the
///       other six stat fields intact.
void main() {
  // Full baked-in baseline for the US (via the browser accessor that returns
  // every field rather than a random trio).
  final baseline = Clue.getAllCountryStats('US');

  tearDown(() {
    // Never leak override state between tests.
    CountryStats.instance.resetForTest();
  });

  group('CountryStats override', () {
    test('(a) no load → falls back to baked-in Dart const', () {
      CountryStats.instance.resetForTest();

      final stats = Clue.getAllCountryStats('US');
      expect(stats['headOfState'], baseline['headOfState']);
      expect(stats['population'], baseline['population']);
      expect(stats['headOfState'], isNotEmpty);
      expect(stats['population'], isNotEmpty);
    });

    test('(b) injected override changes only headOfState/population', () {
      CountryStats.instance.setOverridesForTest({
        'US': {
          'headOfState': 'Test President',
          'population': '999M',
        },
      });

      final stats = Clue.getAllCountryStats('US');

      // Overridden fields reflect the injected values.
      expect(stats['headOfState'], 'Test President');
      expect(stats['population'], '999M');

      // Every other field is untouched vs. the baseline. ('celebrity' is
      // intentionally randomised from a pool on each call, so it is not a
      // stable field to compare — assert it stays non-empty instead.)
      for (final key in baseline.keys) {
        if (key == 'headOfState' || key == 'population') continue;
        if (key == 'celebrity') {
          expect(stats[key], isNotEmpty, reason: 'celebrity still populated');
          continue;
        }
        expect(stats[key], baseline[key],
            reason: 'field "$key" must be intact');
      }
    });

    test('override for one country does not affect another', () {
      final caBaseline = Clue.getAllCountryStats('CA');

      CountryStats.instance.setOverridesForTest({
        'US': {'headOfState': 'Someone Else', 'population': '1M'},
      });

      final ca = Clue.getAllCountryStats('CA');
      expect(ca['headOfState'], caBaseline['headOfState']);
      expect(ca['population'], caBaseline['population']);
    });

    test('empty override values are ignored (baseline preserved)', () {
      CountryStats.instance.setOverridesForTest({
        'US': {'headOfState': '', 'population': ''},
      });

      final stats = Clue.getAllCountryStats('US');
      expect(stats['headOfState'], baseline['headOfState']);
      expect(stats['population'], baseline['population']);
    });
  });
}
