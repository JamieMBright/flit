import 'package:flit/data/services/elo.dart';
import 'package:flit/data/services/matchmaking_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Elo.expectedScore', () {
    test('equal ratings give 0.5', () {
      expect(Elo.expectedScore(1000, 1000), closeTo(0.5, 1e-9));
      expect(Elo.expectedScore(1543, 1543), closeTo(0.5, 1e-9));
    });

    test('expected scores of both players sum to 1', () {
      expect(
        Elo.expectedScore(1200, 900) + Elo.expectedScore(900, 1200),
        closeTo(1.0, 1e-9),
      );
      expect(
        Elo.expectedScore(2000, 800) + Elo.expectedScore(800, 2000),
        closeTo(1.0, 1e-9),
      );
    });

    test('a 400-point favourite has ~10:1 odds', () {
      // The classic Elo property: +400 rating difference means an expected
      // score of 10/11 (~0.909).
      expect(Elo.expectedScore(1400, 1000), closeTo(10 / 11, 1e-9));
      expect(Elo.expectedScore(1000, 1400), closeTo(1 / 11, 1e-9));
    });

    test('higher rated player always has expectation above 0.5', () {
      expect(Elo.expectedScore(1001, 1000), greaterThan(0.5));
      expect(Elo.expectedScore(999, 1000), lessThan(0.5));
    });
  });

  group('Elo.update (K = 32)', () {
    test('win between equals moves rating up by K/2', () {
      expect(
        Elo.update(rating: 1000, opponentRating: 1000, score: Elo.win),
        1016,
      );
    });

    test('loss between equals moves rating down by K/2', () {
      expect(
        Elo.update(rating: 1000, opponentRating: 1000, score: Elo.loss),
        984,
      );
    });

    test('draw between equals leaves rating unchanged', () {
      expect(
        Elo.update(rating: 1000, opponentRating: 1000, score: Elo.draw),
        1000,
      );
    });

    test('underdog win gains more than favourite win', () {
      final underdogGain =
          Elo.update(rating: 1000, opponentRating: 1400, score: Elo.win) - 1000;
      final favouriteGain =
          Elo.update(rating: 1400, opponentRating: 1000, score: Elo.win) - 1400;
      expect(underdogGain, greaterThan(favouriteGain));
      // 400-point underdog win: 32 * (1 - 1/11) = ~29.
      expect(underdogGain, 29);
      // 400-point favourite win: 32 * (1 - 10/11) = ~3.
      expect(favouriteGain, 3);
    });

    test('draw moves ratings toward each other', () {
      final lowAfter =
          Elo.update(rating: 1000, opponentRating: 1400, score: Elo.draw);
      final highAfter =
          Elo.update(rating: 1400, opponentRating: 1000, score: Elo.draw);
      expect(lowAfter, greaterThan(1000));
      expect(highAfter, lessThan(1400));
      // Zero-sum: the gain matches the loss.
      expect(lowAfter - 1000, 1400 - highAfter);
    });

    test('rating change is symmetric (zero-sum) for decisive results', () {
      const ra = 1234;
      const rb = 1180;
      final aAfterWin = Elo.update(rating: ra, opponentRating: rb, score: 1);
      final bAfterLoss = Elo.update(rating: rb, opponentRating: ra, score: 0);
      expect(aAfterWin - ra, -(bAfterLoss - rb));
    });

    test('maximum single-game movement is bounded by K', () {
      // Massive favourite loses: loses at most K points.
      final after =
          Elo.update(rating: 2400, opponentRating: 800, score: Elo.loss);
      expect(2400 - after, lessThanOrEqualTo(Elo.kFactor));
      expect(2400 - after, Elo.kFactor); // expectation ~1.0 → full K.
    });
  });

  group('Elo.coldStartRating', () {
    test('matches estimateElo formula inside the clamp range', () {
      // level 5, best 2000: 1000 + 250 + 100 = 1350.
      expect(Elo.coldStartRating(level: 5, bestScore: 2000), 1350);
      expect(
        Elo.coldStartRating(level: 5, bestScore: 2000),
        MatchmakingService.estimateElo(level: 5, bestScore: 2000),
      );
    });

    test('brand-new player seeds above the minimum', () {
      // level 1, no best score: 1000 + 50 = 1050.
      expect(Elo.coldStartRating(level: 1), 1050);
    });

    test('caps at 2000 for very high level/score', () {
      expect(Elo.coldStartRating(level: 50, bestScore: 50000), 2000);
      expect(Elo.coldStartRating(level: 100, bestScore: 0), 2000);
    });

    test('floors at 800', () {
      // The formula can't go below 1000 with non-negative inputs, but the
      // clamp guards degenerate values.
      expect(Elo.coldStartRating(level: -10, bestScore: 0), 800);
    });

    test('bounds are inclusive', () {
      // Exactly at the cap: level 20 → 1000 + 1000 = 2000.
      expect(Elo.coldStartRating(level: 20), 2000);
    });
  });
}
