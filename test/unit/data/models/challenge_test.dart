import 'package:flame/components.dart';
import 'package:flit/data/models/challenge.dart';
import 'package:flit/game/clues/clue_types.dart';
import 'package:flutter_test/flutter_test.dart';

ChallengeRound _round({
  int number = 1,
  Duration? challengerTime,
  Duration? challengedTime,
  int? challengerScore,
  int? challengedScore,
}) {
  return ChallengeRound(
    roundNumber: number,
    seed: 100 + number,
    clueType: ClueType.flag,
    startLocation: Vector2(10, 20),
    targetCountryCode: 'FR',
    challengerTime: challengerTime,
    challengedTime: challengedTime,
    challengerScore: challengerScore,
    challengedScore: challengedScore,
  );
}

Challenge _challenge(List<ChallengeRound> rounds) => Challenge(
      id: 'c1',
      challengerId: 'u1',
      challengerName: 'Alice',
      challengedId: 'u2',
      challengedName: 'Bob',
      status: ChallengeStatus.inProgress,
      rounds: rounds,
    );

void main() {
  group('ChallengeRound.winner', () {
    test('score wins when both scores are present', () {
      final higher = _round(
        challengerTime: const Duration(seconds: 30),
        challengedTime: const Duration(seconds: 10),
        challengerScore: 9000,
        challengedScore: 5000,
      );
      // Challenger has the higher score even though the slower time — score wins.
      expect(higher.winner, 'challenger');

      final lower = _round(
        challengerTime: const Duration(seconds: 5),
        challengedTime: const Duration(seconds: 30),
        challengerScore: 4000,
        challengedScore: 8000,
      );
      expect(lower.winner, 'challenged');
    });

    test('equal scores are a draw', () {
      final tie = _round(
        challengerTime: const Duration(seconds: 5),
        challengedTime: const Duration(seconds: 9),
        challengerScore: 7000,
        challengedScore: 7000,
      );
      expect(tie.winner, 'draw');
    });

    test('falls back to time when scores are absent (lower time wins)', () {
      final faster = _round(
        challengerTime: const Duration(seconds: 8),
        challengedTime: const Duration(seconds: 20),
      );
      expect(faster.winner, 'challenger');

      final slower = _round(
        challengerTime: const Duration(seconds: 25),
        challengedTime: const Duration(seconds: 12),
      );
      expect(slower.winner, 'challenged');
    });

    test('equal times with no scores is a draw', () {
      final tie = _round(
        challengerTime: const Duration(seconds: 15),
        challengedTime: const Duration(seconds: 15),
      );
      expect(tie.winner, 'draw');
    });

    test('incomplete round (a missing time) has no winner', () {
      final incomplete = _round(challengerTime: const Duration(seconds: 5));
      expect(incomplete.isComplete, isFalse);
      expect(incomplete.winner, isNull);
    });
  });

  group('Challenge.isComplete at winsRequired', () {
    ChallengeRound challengerWin(int n) => _round(
          number: n,
          challengerTime: const Duration(seconds: 5),
          challengedTime: const Duration(seconds: 9),
          challengerScore: 9000,
          challengedScore: 3000,
        );

    test('not complete before either side reaches 3 wins', () {
      final c = _challenge([challengerWin(1), challengerWin(2)]);
      expect(c.challengerWins, 2);
      expect(c.isComplete, isFalse);
    });

    test('complete once a side reaches winsRequired (3)', () {
      final c = _challenge([
        challengerWin(1),
        challengerWin(2),
        challengerWin(3),
      ]);
      expect(c.challengerWins, Challenge.winsRequired);
      expect(c.isComplete, isTrue);
      expect(c.scoreText, '3 - 0');
    });
  });

  group('enum fromDb safe fallback', () {
    test('ChallengeStatus.fromDb round-trips known values', () {
      expect(ChallengeStatus.fromDb('in_progress'), ChallengeStatus.inProgress);
      expect(ChallengeStatus.fromDb('completed'), ChallengeStatus.completed);
    });

    test('ChallengeStatus.fromDb falls back to pending on garbage', () {
      expect(ChallengeStatus.fromDb('not_a_status'), ChallengeStatus.pending);
      expect(ChallengeStatus.fromDb(''), ChallengeStatus.pending);
    });

    test('ChallengeGameMode.fromDb falls back to flight on garbage', () {
      expect(ChallengeGameMode.fromDb('quiz'), ChallengeGameMode.quiz);
      expect(ChallengeGameMode.fromDb('recon'), ChallengeGameMode.flight);
    });
  });

  group('JSON round-trip', () {
    test('ChallengeRound survives toJson -> fromJson', () {
      final original = ChallengeRound(
        roundNumber: 2,
        seed: 424242,
        clueType: ClueType.flag,
        startLocation: Vector2(12.5, -8.25),
        targetCountryCode: 'BR',
        countryName: 'Brazil',
        challengerTime: const Duration(milliseconds: 4200),
        challengedTime: const Duration(milliseconds: 9100),
        challengerScore: 8800,
        challengedScore: 6100,
        challengerHintsUsed: 1,
        challengedHintsUsed: 3,
      );
      final restored = ChallengeRound.fromJson(original.toJson());

      expect(restored.roundNumber, original.roundNumber);
      expect(restored.seed, original.seed);
      expect(restored.clueType, original.clueType);
      expect(restored.startLocation.x, original.startLocation.x);
      expect(restored.startLocation.y, original.startLocation.y);
      expect(restored.targetCountryCode, original.targetCountryCode);
      expect(restored.countryName, original.countryName);
      expect(restored.challengerTime, original.challengerTime);
      expect(restored.challengedTime, original.challengedTime);
      expect(restored.challengerScore, original.challengerScore);
      expect(restored.challengedScore, original.challengedScore);
      expect(restored.challengerHintsUsed, original.challengerHintsUsed);
      expect(restored.challengedHintsUsed, original.challengedHintsUsed);
      expect(restored.winner, original.winner);
    });

    test('Challenge survives toJson -> fromJson', () {
      final original = _challenge([
        _round(
          number: 1,
          challengerTime: const Duration(seconds: 5),
          challengedTime: const Duration(seconds: 9),
          challengerScore: 9000,
          challengedScore: 3000,
        ),
      ]);
      final restored = Challenge.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.challengerId, original.challengerId);
      expect(restored.challengedName, original.challengedName);
      expect(restored.status, original.status);
      expect(restored.gameMode, original.gameMode);
      expect(restored.rounds.length, original.rounds.length);
      expect(restored.rounds.first.winner, 'challenger');
      expect(restored.scoreText, original.scoreText);
    });

    test('an unknown DB game_mode round-trips losslessly via rawGameMode', () {
      final json = <String, dynamic>{
        'id': 'c9',
        'challenger_id': 'u1',
        'challenger_name': 'A',
        'challenged_id': 'u2',
        'challenged_name': 'B',
        'status': 'pending',
        'game_mode': 'scramble',
        'rounds': <Map<String, dynamic>>[],
      };
      final c = Challenge.fromJson(json);
      // The enum degrades safely to flight, but the raw string is preserved.
      expect(c.gameMode, ChallengeGameMode.flight);
      expect(c.rawGameMode, 'scramble');
      expect(c.toJson()['game_mode'], 'scramble');
    });
  });
}
