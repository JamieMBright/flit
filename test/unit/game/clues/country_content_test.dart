import 'package:flag/flag.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flit/core/widgets/country_flag.dart';
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

  test('every playable country has a real flag rendering path', () {
    // Either the flag package ships the SVG, or we bundle our own
    // (assets/images/flags/). The emoji fallback is a safety net, not an
    // acceptable steady state for a playable country.
    final unrenderable = [
      for (final c in playable)
        if (!Flag.flagsCode.contains(c.code.toLowerCase()) &&
            !CountryFlag.bundledCodes.contains(c.code.toUpperCase()))
          '${c.code} (${c.name})',
    ];
    expect(unrenderable, isEmpty,
        reason: 'Countries with no flag asset: $unrenderable');
  });

  test('every playable country outline has enough detail for its size', () {
    // Guards against crude placeholder polygons: a country spanning more
    // than 3 degrees must have a properly detailed outline, and nothing
    // playable may be missing polygons entirely.
    final crude = <String>[];
    for (final c in playable) {
      final info = CountryData.getCountry(c.code);
      final polys = info?.polygons ?? const [];
      final points = polys.fold<int>(0, (s, p) => s + p.length);
      if (points < 4) {
        crude.add('${c.code} (no outline)');
        continue;
      }
      // Judge detail against the largest single landmass, not the full
      // bbox — an atoll nation spans a huge box of tiny, honest specks.
      var mainSpan = 0.0;
      for (final poly in polys) {
        final lngs = poly.map((v) => v.x);
        final lats = poly.map((v) => v.y);
        final span = [
          lngs.reduce((a, b) => a > b ? a : b) -
              lngs.reduce((a, b) => a < b ? a : b),
          lats.reduce((a, b) => a > b ? a : b) -
              lats.reduce((a, b) => a < b ? a : b),
        ].reduce((a, b) => a > b ? a : b);
        if (span > mainSpan) mainSpan = span;
      }
      if (mainSpan > 3 && points < 60) {
        crude.add(
          '${c.code} ($points pts over ${mainSpan.toStringAsFixed(1)}°)',
        );
      }
    }
    expect(crude, isEmpty, reason: 'Crude/missing outlines: $crude');
  });

  test('spot-check known facts stay sane', () {
    expect(Clue.getAllCountryStats('FR')['language'], contains('French'));
    expect(Clue.getNeighbors('CH'), contains('Germany'));
    expect(Clue.getNeighbors('LU'), contains('France'));
    expect(CountryData.getCapital('LI')?.name, 'Vaduz');
    expect(CountryData.getCapital('XK')?.name, 'Pristina');
  });
}
