import 'package:flutter_test/flutter_test.dart';

import 'package:flit/game/clues/clue_types.dart';
import 'package:flit/game/map/country_data.dart';

/// Coverage contract: every playable country must carry the full content
/// set used across game modes (Triangulation anchors/targets, flying-game
/// clues). This is what keeps clue pools large enough to avoid the
/// repeated-clue problem — new countries can't ship half-filled.
void main() {
  final playable = CountryData.playableCountries;

  test('every playable country has a capital with coordinates', () {
    final missing = [
      for (final c in playable)
        if (CountryData.getCapital(c.code) == null) '${c.code} (${c.name})',
    ];
    expect(missing, isEmpty,
        reason: 'Playable countries without an isCapital city: $missing');
  });

  test('every playable country has leader and language stats', () {
    final missing = <String>[];
    for (final c in playable) {
      final stats = Clue.getAllCountryStats(c.code);
      if ((stats['headOfState'] ?? '').isEmpty ||
          (stats['language'] ?? '').isEmpty) {
        missing.add('${c.code} (${c.name})');
      }
    }
    expect(missing, isEmpty,
        reason: 'Playable countries without leader/language stats: $missing');
  });

  test('every playable country has complete stat fields', () {
    const requiredFields = [
      'population',
      'continent',
      'currency',
      'religion',
      'headOfState',
      'sport',
      'language',
      'celebrity',
    ];
    final incomplete = <String>[];
    for (final c in playable) {
      final stats = Clue.getAllCountryStats(c.code);
      for (final field in requiredFields) {
        if ((stats[field] ?? '').isEmpty) {
          incomplete.add('${c.code}.$field');
        }
      }
    }
    expect(incomplete, isEmpty, reason: 'Empty stat fields: $incomplete');
  });

  test('spot-check known facts stay sane', () {
    expect(Clue.getAllCountryStats('FR')['language'], contains('French'));
    expect(Clue.getNeighbors('CH'), contains('Germany'));
    expect(Clue.getNeighbors('LU'), contains('France'));
    expect(CountryData.getCapital('LI')?.name, 'Vaduz');
    expect(CountryData.getCapital('XK')?.name, 'Pristina');
  });
}
