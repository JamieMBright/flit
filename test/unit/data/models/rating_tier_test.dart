import 'package:flutter_test/flutter_test.dart';

import 'package:flit/data/models/rating_tier.dart';

void main() {
  group('RatingTier.fromRating', () {
    test('maps rating bands to aviation tiers', () {
      expect(RatingTier.fromRating(0), RatingTier.bronzeWings);
      expect(RatingTier.fromRating(800), RatingTier.bronzeWings);
      expect(RatingTier.fromRating(1099), RatingTier.bronzeWings);
      expect(RatingTier.fromRating(1100), RatingTier.silverWings);
      expect(RatingTier.fromRating(1299), RatingTier.silverWings);
      expect(RatingTier.fromRating(1300), RatingTier.goldWings);
      expect(RatingTier.fromRating(1499), RatingTier.goldWings);
      expect(RatingTier.fromRating(1500), RatingTier.platinumWings);
      expect(RatingTier.fromRating(1749), RatingTier.platinumWings);
      expect(RatingTier.fromRating(1750), RatingTier.ace);
      expect(RatingTier.fromRating(2400), RatingTier.ace);
    });

    test('new level-1 player (cold start ~1050) begins at Bronze Wings', () {
      // MatchmakingService.estimateElo(level: 1) == 1050.
      expect(RatingTier.fromRating(1050), RatingTier.bronzeWings);
    });

    test('tiers are strictly ordered by minRating', () {
      for (var i = 1; i < RatingTier.values.length; i++) {
        expect(
          RatingTier.values[i].minRating,
          greaterThan(RatingTier.values[i - 1].minRating),
        );
      }
    });
  });

  group('RatingTier progression', () {
    test('next walks up the ladder and ends at ace', () {
      expect(RatingTier.bronzeWings.next, RatingTier.silverWings);
      expect(RatingTier.platinumWings.next, RatingTier.ace);
      expect(RatingTier.ace.next, isNull);
    });

    test('pointsToNext counts the gap to the next floor', () {
      expect(RatingTier.bronzeWings.pointsToNext(1050), 50);
      expect(RatingTier.silverWings.pointsToNext(1100), 200);
      expect(RatingTier.ace.pointsToNext(1900), 0);
    });

    test('pointsToNext never returns negative', () {
      expect(RatingTier.bronzeWings.pointsToNext(1200), 0);
    });
  });

  group('display', () {
    test('every tier has a distinct display name', () {
      final names = RatingTier.values.map((t) => t.displayName).toSet();
      expect(names.length, RatingTier.values.length);
    });

    test('names read as aviation ranks', () {
      expect(RatingTier.bronzeWings.displayName, 'Bronze Wings');
      expect(RatingTier.ace.displayName, 'Ace');
    });
  });
}
