import 'package:flit/data/models/daily_challenge.dart';
import 'package:flit/game/clues/clue_types.dart';
import 'package:flit/game/map/country_data.dart';
import 'package:flit/game/session/game_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the capability predicate [Clue.canProduceClueType] and the
/// no-silent-fallback guarantee it enforces on themed dailies.
///
/// A themed daily must NEVER seed a target that can't honestly produce its
/// clue type (e.g. an island nation with no neighbours on Border Day, or the
/// Vatican — a 7-vertex speck — on Outline Day). The daily selector filters the
/// candidate pool with this predicate before the seeded pick, so every clue it
/// produces is in the day's theme, while staying fully deterministic.
void main() {
  final playable = CountryData.playableCountries;

  int countProducible(String clueType) =>
      playable.where((c) => Clue.canProduceClueType(c.code, clueType)).length;

  group('canProduceClueType — per single-clue theme coverage', () {
    test('flag / capital / stats are producible for every playable country',
        () {
      // Flag is always valid; capital and stats are contractually complete for
      // every playable country (see country_content_test).
      expect(countProducible('flag'), playable.length);
      expect(countProducible('capital'), playable.length);
      expect(countProducible('stats'), playable.length);
    });

    test('borders is producible for a large majority (>= 150)', () {
      expect(countProducible('borders'), greaterThanOrEqualTo(150));
    });

    test('outline is producible for most countries, blobs excluded', () {
      // The outline quality bar is 50+ total vertices: below that a
      // silhouette is a featureless blob (San Marino, Aruba, Malta …) that
      // can't be identified, so those countries serve their other clue types
      // instead. ~196 of the 218 playable countries clear the bar; keep a
      // little slack for data refreshes.
      expect(countProducible('outline'), greaterThanOrEqualTo(190));
      // And the bar actually bites: the blob tier must NOT be producible.
      expect(Clue.canProduceClueType('SM', 'outline'), isFalse); // 19 verts
      expect(Clue.canProduceClueType('AW', 'outline'), isFalse); // 25 verts
      expect(Clue.canProduceClueType('MT', 'outline'), isFalse); // 43 verts
      // While simple-but-recognisable large countries stay in.
      expect(Clue.canProduceClueType('SO', 'outline'), isTrue); // 71 verts
      expect(Clue.canProduceClueType('LY', 'outline'), isTrue); // 105 verts
    });

    test('an unrecognised clue type is never producible', () {
      expect(Clue.canProduceClueType('FR', 'not-a-real-type'), isFalse);
    });
  });

  group('canProduceClueType — specific known cases', () {
    test('island nations cannot produce a borders clue', () {
      // Japan and Fiji have no land neighbours.
      expect(Clue.canProduceClueType('JP', 'borders'), isFalse);
      expect(Clue.canProduceClueType('FJ', 'borders'), isFalse);
    });

    test('a mainland country can produce a borders clue', () {
      expect(Clue.canProduceClueType('FR', 'borders'), isTrue);
    });

    test('the Vatican cannot produce an outline clue (7-vertex polygon)', () {
      // VA is deliberately NOT bumped past the 10-vertex threshold — adding
      // collinear filler vertices would make it a "valid" outline target that
      // is still an unidentifiable speck. The capability filter honestly
      // excludes it from Outline Day instead.
      expect(Clue.canProduceClueType('VA', 'outline'), isFalse);
    });

    test('a large country can produce an outline clue', () {
      expect(Clue.canProduceClueType('FR', 'outline'), isTrue);
    });
  });

  group('stat sub-field fills', () {
    test('CM / KE / TD carry a non-empty celebrity', () {
      for (final code in ['CM', 'KE', 'TD']) {
        final stats = Clue.getAllCountryStats(code);
        expect(stats['celebrity'], isNotNull, reason: '$code celebrity');
        expect(stats['celebrity']!.isNotEmpty, isTrue,
            reason: '$code celebrity');
      }
    });

    test('WS carries a non-empty head of state', () {
      final stats = Clue.getAllCountryStats('WS');
      expect(stats['headOfState'], isNotNull);
      expect(stats['headOfState']!.isNotEmpty, isTrue);
    });
  });

  group('daily generator — determinism + no silent fallback', () {
    // Re-derive the exact per-round targets the daily challenge screen builds
    // (see play_screen._createSession): GameSession.seeded with the daily seed
    // offset per round, the theme's clue types, and the running set of used
    // country codes.
    List<GameSession> buildDailyRounds(DailyChallenge challenge) {
      final rounds = <GameSession>[];
      final used = <String>{};
      for (var i = 0; i < DailyChallenge.roundCount; i++) {
        final roundSeed = challenge.seed + i * 7919;
        final session = GameSession.seeded(
          roundSeed,
          allowedClueTypes: challenge.enabledClueTypes,
          excludedCountryCodes: Set.unmodifiable(used),
        );
        used.add(session.targetCountry.code);
        rounds.add(session);
      }
      return rounds;
    }

    test('every produced clue type is within the day theme (no fallback)', () {
      // Sweep 60 consecutive days, covering every theme in the rotation.
      var start = DateTime.utc(2026, 1, 1);
      for (var day = 0; day < 60; day++) {
        final date = start.add(Duration(days: day));
        final challenge = DailyChallenge.forDate(date);
        final theme = challenge.enabledClueTypes;
        for (final session in buildDailyRounds(challenge)) {
          expect(
            theme.contains(session.clue.type.name),
            isTrue,
            reason: 'Daily $date (${challenge.title}, theme $theme) produced '
                'an out-of-theme ${session.clue.type.name} clue for '
                '${session.targetCountry.code}',
          );
        }
      }
    });

    test('the same date yields identical targets and clue types', () {
      var start = DateTime.utc(2026, 1, 1);
      for (var day = 0; day < 60; day++) {
        final date = start.add(Duration(days: day));
        final a = buildDailyRounds(DailyChallenge.forDate(date));
        final b = buildDailyRounds(DailyChallenge.forDate(date));
        expect(a.length, b.length);
        for (var i = 0; i < a.length; i++) {
          expect(a[i].targetCountry.code, b[i].targetCountry.code,
              reason: 'target drift on $date round $i');
          expect(a[i].clue.type, b[i].clue.type,
              reason: 'clue-type drift on $date round $i');
        }
      }
    });
  });
}
