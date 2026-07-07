import 'package:flit/data/models/h2h_challenge.dart';
import 'package:flit/game/quiz/quiz_category.dart';
import 'package:flit/game/quiz/quiz_difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

H2HRound _round({
  int? challengerScore,
  int? challengedScore,
  int seed = 1,
}) {
  return H2HRound(
    levelId: 'europe',
    levelName: 'Europe',
    category: QuizCategory.mixed,
    difficulty: QuizDifficulty.medium,
    seed: seed,
    challengerScore: challengerScore,
    challengedScore: challengedScore,
  );
}

H2HChallenge _challenge(List<H2HRound> rounds) => H2HChallenge(
      id: 'h1',
      challengerId: 'u1',
      challengerName: 'Alice',
      challengedId: 'u2',
      challengedName: 'Bob',
      rounds: rounds,
      status: H2HStatus.inProgress,
      createdAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  group('H2HRound.winner (score comparison)', () {
    test('higher score wins', () {
      expect(_round(challengerScore: 900, challengedScore: 500).winner,
          'challenger');
      expect(_round(challengerScore: 400, challengedScore: 700).winner,
          'challenged');
    });

    test('equal scores draw', () {
      expect(_round(challengerScore: 600, challengedScore: 600).winner, 'draw');
    });

    test('incomplete round has no winner', () {
      expect(_round(challengerScore: 600).winner, isNull);
      expect(_round(challengerScore: 600).isComplete, isFalse);
    });
  });

  group('H2HChallenge.isClinched at 2 wins (best-of-3)', () {
    H2HRound challengerWin(int seed) =>
        _round(challengerScore: 900, challengedScore: 100, seed: seed);
    H2HRound challengedWin(int seed) =>
        _round(challengerScore: 100, challengedScore: 900, seed: seed);

    test('not clinched after a single round win', () {
      // Full best-of-3 card with only round 1 played.
      final c = _challenge([
        challengerWin(1),
        _round(seed: 2), // unplayed
        _round(seed: 3), // unplayed
      ]);
      expect(c.challengerWins, 1);
      expect(c.isClinched, isFalse);
      expect(c.isComplete, isFalse);
    });

    test('clinched once a side reaches 2 wins (before round 3 is played)', () {
      final c = _challenge([
        challengerWin(1),
        challengerWin(2),
        _round(seed: 3), // round 3 not yet played
      ]);
      expect(c.challengerWins, H2HChallenge.winsRequired);
      expect(c.isClinched, isTrue);
      expect(c.isComplete, isTrue);
      expect(c.scoreText, '2 - 0');
    });

    test('a 1-1 split with an unplayed decider is not yet complete', () {
      final c = _challenge([
        challengerWin(1),
        challengedWin(2),
        _round(seed: 3),
      ]);
      expect(c.challengerWins, 1);
      expect(c.challengedWins, 1);
      expect(c.isClinched, isFalse);
      expect(c.isComplete, isFalse);
      expect(c.nextUnplayedRoundIndex, 2);
    });

    test(
        'all three rounds played completes the challenge even without a clinch',
        () {
      // Draws never clinch, but every round complete -> isComplete true.
      final c = _challenge([
        _round(challengerScore: 5, challengedScore: 5, seed: 1),
        _round(challengerScore: 5, challengedScore: 5, seed: 2),
        _round(challengerScore: 5, challengedScore: 5, seed: 3),
      ]);
      expect(c.isClinched, isFalse);
      expect(c.isComplete, isTrue);
      expect(c.nextUnplayedRoundIndex, -1);
    });
  });

  group('H2HStatus.fromDb safe fallback', () {
    test('known values map correctly', () {
      expect(H2HStatus.fromDb('completed'), H2HStatus.completed);
      expect(H2HStatus.fromDb('declined'), H2HStatus.declined);
    });

    test('garbage falls back to pending', () {
      expect(H2HStatus.fromDb('bogus'), H2HStatus.pending);
      expect(H2HStatus.fromDb(''), H2HStatus.pending);
    });
  });

  group('JSON round-trip', () {
    test('H2HRound survives toJson -> fromJson', () {
      const original = H2HRound(
        levelId: 'us_states',
        levelName: 'United States',
        category: QuizCategory.mixed,
        difficulty: QuizDifficulty.medium,
        seed: 777,
        challengerScore: 820,
        challengedScore: 640,
        challengerTimeMs: 12000,
        challengedTimeMs: 15000,
        challengerCorrect: 9,
        challengedCorrect: 7,
        challengerWrong: 1,
        challengedWrong: 3,
      );
      final restored = H2HRound.fromJson(original.toJson());

      expect(restored.levelId, original.levelId);
      expect(restored.levelName, original.levelName);
      expect(restored.category, original.category);
      expect(restored.difficulty, original.difficulty);
      expect(restored.seed, original.seed);
      expect(restored.challengerScore, original.challengerScore);
      expect(restored.challengedScore, original.challengedScore);
      expect(restored.challengerTimeMs, original.challengerTimeMs);
      expect(restored.challengerCorrect, original.challengerCorrect);
      expect(restored.challengedWrong, original.challengedWrong);
      expect(restored.winner, original.winner);
    });

    test('H2HChallenge survives toJson -> fromJson', () {
      final original = _challenge([
        _round(challengerScore: 900, challengedScore: 100, seed: 1),
        _round(challengerScore: 900, challengedScore: 100, seed: 2),
        _round(seed: 3),
      ]);
      final restored = H2HChallenge.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.challengerName, original.challengerName);
      expect(restored.status, original.status);
      expect(restored.rounds.length, 3);
      expect(restored.challengerWins, original.challengerWins);
      expect(restored.isClinched, original.isClinched);
      expect(restored.createdAt, original.createdAt);
    });
  });
}
