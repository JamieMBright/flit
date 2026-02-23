import 'package:flit/data/models/daily_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DailyRoundResult emoji mapping', () {
    test('uses orange for 1-2 hints and yellow for 3+ hints', () {
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

      expect(oneHint.emoji, '\u{1F7E0}');
      expect(twoHints.emoji, '\u{1F7E0}');
      expect(threeHints.emoji, '\u{1F7E1}');
    });
  });
}
