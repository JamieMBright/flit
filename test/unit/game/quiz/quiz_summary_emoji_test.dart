import 'package:flit/game/map/region.dart';
import 'package:flit/game/quiz/quiz_category.dart';
import 'package:flit/game/quiz/quiz_difficulty.dart';
import 'package:flit/game/quiz/quiz_session.dart';
import 'package:flutter_test/flutter_test.dart';

QuizAnswerResult result({
  required bool correct,
  required int questionIndex,
  int hintCount = 0,
}) =>
    QuizAnswerResult(
      correct: correct,
      points: correct ? 1000 : -100,
      streak: correct ? 1 : 0,
      questionIndex: questionIndex,
      answerCode: correct ? 'FR' : 'DE',
      correctCode: 'FR',
      elapsedMs: 1000,
      hintUsed: hintCount > 0,
      hintCount: hintCount,
    );

QuizSummary summary(List<QuizAnswerResult> results, {int totalQuestions = 6}) {
  final correct = results.where((r) => r.correct).length;
  final wrong = results.where((r) => !r.correct).length;
  return QuizSummary(
    mode: QuizMode.allStates,
    categories: const {QuizCategory.stateName},
    difficulty: QuizDifficulty.easy,
    totalScore: 5000,
    correctCount: correct,
    wrongCount: wrong,
    totalQuestions: totalQuestions,
    elapsedMs: 60000,
    bestStreak: 1,
    hintsUsed: 0,
    results: results,
  );
}

void main() {
  group('QuizSummary per-question emoji', () {
    test('green for correct with no hints', () {
      final s = summary([result(correct: true, questionIndex: 0)]);
      expect(s.questionEmoji(0), '\u{1F7E2}');
    });

    test('yellow for correct with 1-2 hints', () {
      final s = summary([
        result(correct: true, questionIndex: 0, hintCount: 1),
        result(correct: true, questionIndex: 1, hintCount: 2),
      ]);
      expect(s.questionEmoji(0), '\u{1F7E1}');
      expect(s.questionEmoji(1), '\u{1F7E1}');
    });

    test('orange for correct with more than 2 hints', () {
      final s = summary([
        result(correct: true, questionIndex: 0, hintCount: 3),
        result(correct: true, questionIndex: 1, hintCount: 6),
      ]);
      expect(s.questionEmoji(0), '\u{1F7E0}');
      expect(s.questionEmoji(1), '\u{1F7E0}');
    });

    test('red for wrong or never answered', () {
      final s = summary([result(correct: false, questionIndex: 0)]);
      expect(s.questionEmoji(0), '\u{1F534}'); // wrong
      expect(s.questionEmoji(3), '\u{1F534}'); // never answered
    });

    test('a correct answer after wrong taps on the same question wins', () {
      final s = summary([
        result(correct: false, questionIndex: 0),
        result(correct: true, questionIndex: 0),
      ]);
      expect(s.questionEmoji(0), '\u{1F7E2}');
    });

    test('emojiRow covers every question slot in order', () {
      final s = summary([
        result(correct: true, questionIndex: 0),
        result(correct: true, questionIndex: 1, hintCount: 2),
        result(correct: true, questionIndex: 2, hintCount: 4),
        result(correct: false, questionIndex: 3),
      ]);
      expect(
        s.emojiRow,
        '\u{1F7E2}\u{1F7E1}\u{1F7E0}\u{1F534}\u{1F534}\u{1F534}',
      );
    });
  });

  group('QuizSession hint counts feed results', () {
    test('hintCount is recorded per answer and resets between questions', () {
      final session = QuizSession(
        mode: QuizMode.allStates,
        categories: const {QuizCategory.stateName},
        region: GameRegion.europe,
        difficulty: QuizDifficulty.easy,
        presetQuestions: const [
          QuizQuestion(
            category: QuizCategory.stateName,
            clueText: 'France',
            answerCode: 'FR',
            answerName: 'France',
          ),
          QuizQuestion(
            category: QuizCategory.stateName,
            clueText: 'Germany',
            answerCode: 'DE',
            answerName: 'Germany',
          ),
        ],
        seed: 42,
      );
      session.start();

      // Two hints, then a correct answer.
      session.useHint();
      session.useHint();
      final first = session.submitAnswer('FR');
      expect(first?.correct, isTrue);
      expect(first?.hintCount, 2);

      // Hint level resets for the next question.
      final second = session.submitAnswer('DE');
      expect(second?.correct, isTrue);
      expect(second?.hintCount, 0);

      final s = session.summary;
      expect(s.emojiRow, '\u{1F7E1}\u{1F7E2}');
    });
  });
}
