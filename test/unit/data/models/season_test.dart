import 'package:flutter_test/flutter_test.dart';

import 'package:flit/data/models/season.dart';

void main() {
  group('Season.idFor', () {
    test('quarterly ids', () {
      expect(Season.idFor(DateTime.utc(2026, 1, 1)), '2026-Q1');
      expect(Season.idFor(DateTime.utc(2026, 3, 31)), '2026-Q1');
      expect(Season.idFor(DateTime.utc(2026, 4, 1)), '2026-Q2');
      expect(Season.idFor(DateTime.utc(2026, 7, 5)), '2026-Q3');
      expect(Season.idFor(DateTime.utc(2026, 12, 31)), '2026-Q4');
    });

    test('season boundaries', () {
      expect(
          Season.startOf(DateTime.utc(2026, 8, 15)), DateTime.utc(2026, 7, 1));
      expect(
          Season.endOf(DateTime.utc(2026, 8, 15)), DateTime.utc(2026, 10, 1));
      // Q4 rolls into the next year.
      expect(Season.endOf(DateTime.utc(2026, 11, 2)), DateTime.utc(2027, 1, 1));
    });
  });

  group('TrophyCase', () {
    const trophy = Trophy(
      seasonId: '2026-Q3',
      gameMode: 'sortie',
      tierName: 'Gold Wings',
      rating: 1350,
      bestScore: 41200,
    );

    test('records and queries trophies', () {
      final tc = const TrophyCase().record(trophy);
      expect(tc.has('2026-Q3', 'sortie'), isTrue);
      expect(tc.has('2026-Q3', 'flight'), isFalse);
      expect(tc.forSeason('2026-Q3').single.tierName, 'Gold Wings');
    });

    test('recording twice for the same season+mode replaces (idempotent)', () {
      final tc = const TrophyCase().record(trophy).record(const Trophy(
            seasonId: '2026-Q3',
            gameMode: 'sortie',
            tierName: 'Platinum Wings',
            rating: 1520,
          ));
      expect(tc.trophies.length, 1);
      expect(tc.trophies.single.tierName, 'Platinum Wings');
    });

    test('round-trips through JSON', () {
      final tc = const TrophyCase().record(trophy);
      final restored = TrophyCase.fromJson(tc.toJson());
      expect(restored.trophies.single.seasonId, '2026-Q3');
      expect(restored.trophies.single.rating, 1350);
      expect(restored.trophies.single.bestScore, 41200);
    });

    test('null JSON yields an empty case', () {
      expect(TrophyCase.fromJson(null).trophies, isEmpty);
    });
  });

  group('Trophy.fromJson - numeric jsonb robustness (item B5)', () {
    test('rating arriving as a jsonb double parses to int, not a crash', () {
      final trophy = Trophy.fromJson({
        'season_id': '2026-Q3',
        'game_mode': 'sortie',
        'tier': 'Gold Wings',
        'rating': 1500.0,
        'best_score': 41200.0,
      });

      expect(trophy.rating, equals(1500));
      expect(trophy.rating, isA<int>());
      expect(trophy.bestScore, equals(41200));
      expect(trophy.bestScore, isA<int>());
    });

    test('missing numeric fields default to 0 instead of throwing', () {
      final trophy = Trophy.fromJson({
        'season_id': '2026-Q3',
        'game_mode': 'sortie',
        'tier': 'Bronze Wings',
      });

      expect(trophy.rating, equals(0));
      expect(trophy.bestScore, equals(0));
    });

    test(
      'a jsonb-double rating survives round-tripping through TrophyCase',
      () {
        final tc = TrophyCase.fromJson([
          {
            'season_id': '2026-Q3',
            'game_mode': 'flight',
            'tier': 'Silver Wings',
            'rating': 1150.0,
            'best_score': 8000.0,
          },
        ]);

        expect(tc.trophies.single.rating, equals(1150));
      },
    );
  });
}
