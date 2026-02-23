import 'package:flit/data/models/daily_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
