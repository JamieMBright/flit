import 'package:flit/data/models/daily_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DailyResult proficiencyPercent', () {
    test('returns 100 for perfect score with no country code', () {
      const round = DailyRoundResult(
        hintsUsed: 0,
        completed: true,
        timeMs: 5000, // ≤10s → no time penalty
        score: 10000,
      );
      final result = DailyResult(
        date: '2026-01-01',
        rounds: [round],
        totalScore: 10000,
        totalTimeMs: 5000,
        totalRounds: 1,
        theme: 'Test',
      );
      expect(result.proficiencyPercent, 100);
    });

    test('returns 0 for empty rounds', () {
      final result = DailyResult(
        date: '2026-01-01',
        rounds: [],
        totalScore: 0,
        totalTimeMs: 0,
        totalRounds: 0,
        theme: 'Test',
      );
      expect(result.proficiencyPercent, 0);
    });

    test('penalises unplayed rounds', () {
      const round = DailyRoundResult(
        hintsUsed: 0,
        completed: true,
        timeMs: 5000,
        score: 10000,
      );
      // 1 round played (max 10000), 1 unplayed (max 10000) → max total 20000
      final result = DailyResult(
        date: '2026-01-01',
        rounds: [round],
        totalScore: 10000,
        totalTimeMs: 5000,
        totalRounds: 2,
        theme: 'Test',
      );
      expect(result.proficiencyPercent, 50);
    });

    test('toShareText includes Proficiency line', () {
      const round = DailyRoundResult(
        hintsUsed: 0,
        completed: true,
        timeMs: 5000,
        score: 10000,
      );
      final result = DailyResult(
        date: '2026-01-01',
        rounds: [round],
        totalScore: 10000,
        totalTimeMs: 5000,
        totalRounds: 1,
        theme: 'Test',
      );
      final text = result.toShareText();
      expect(text, contains('Proficiency: 100%'));
      expect(text, contains('Score: 10,000 pts'));
      expect(text, contains('Time: 5s'));
      // Proficiency line appears between score and time
      final scoreIdx = text.indexOf('Score:');
      final profIdx = text.indexOf('Proficiency:');
      final timeIdx = text.indexOf('Time:');
      expect(profIdx, greaterThan(scoreIdx));
      expect(timeIdx, greaterThan(profIdx));
    });
  });

  group('DailyRoundResult emoji mapping', () {
    test('uses 0=green, 1-2=yellow, 3-4=orange, 5+=red', () {
      const zeroHints = DailyRoundResult(
        hintsUsed: 0,
        completed: true,
        timeMs: 1000,
        score: 100,
      );
      const oneHint = DailyRoundResult(
        hintsUsed: 1,
        completed: true,
        timeMs: 1000,
        score: 100,
      );
      const twoHints = DailyRoundResult(
        hintsUsed: 2,
        completed: true,
        timeMs: 1000,
        score: 100,
      );
      const threeHints = DailyRoundResult(
        hintsUsed: 3,
        completed: true,
        timeMs: 1000,
        score: 100,
      );
      const fourHints = DailyRoundResult(
        hintsUsed: 4,
        completed: true,
        timeMs: 1000,
        score: 100,
      );
      const fiveHints = DailyRoundResult(
        hintsUsed: 5,
        completed: true,
        timeMs: 1000,
        score: 100,
      );

      expect(zeroHints.emoji, '\u{1F7E2}');
      expect(oneHint.emoji, '\u{1F7E1}');
      expect(twoHints.emoji, '\u{1F7E1}');
      expect(threeHints.emoji, '\u{1F7E0}');
      expect(fourHints.emoji, '\u{1F7E0}');
      expect(fiveHints.emoji, '\u{1F534}');
    });
  });
}
