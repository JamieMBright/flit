import 'package:flutter_test/flutter_test.dart';
import 'package:flit/game/quiz/quiz_category.dart';
import 'package:flit/game/quiz/quiz_difficulty.dart';
import 'package:flit/game/quiz/quiz_session.dart';
import 'package:flit/game/map/region.dart';

void main() {
  group('QuizCategory', () {
    test('all categories have displayName', () {
      for (final category in QuizCategory.values) {
        expect(category.displayName, isNotEmpty);
      }
    });

    test('all categories have description', () {
      for (final category in QuizCategory.values) {
        expect(category.description, isNotEmpty);
      }
    });

    test('all categories have icon', () {
      for (final category in QuizCategory.values) {
        expect(category.icon, isNotEmpty);
      }
    });
  });

  group('QuizMode', () {
    test('allStates mode has no time limit and no max wrong', () {
      expect(QuizMode.allStates.timeLimit, isNull);
      expect(QuizMode.allStates.maxWrong, isNull);
    });

    test('timeTrial mode has 60 second time limit', () {
      expect(QuizMode.timeTrial.timeLimit, equals(60));
      expect(QuizMode.timeTrial.maxWrong, isNull);
    });

    test('rapidFire mode has 3 max wrong', () {
      expect(QuizMode.rapidFire.timeLimit, isNull);
      expect(QuizMode.rapidFire.maxWrong, equals(3));
    });

    test('all modes have displayName and description', () {
      for (final mode in QuizMode.values) {
        expect(mode.displayName, isNotEmpty);
        expect(mode.description, isNotEmpty);
      }
    });
  });

  group('QuizQuestionGenerator', () {
    test('generates questions for stateName category', () {
      final generator = QuizQuestionGenerator(
        region: GameRegion.usStates,
        seed: 42,
      );
      final questions = generator.generateQuestions(QuizCategory.stateName);

      expect(questions.length, equals(50));
      expect(
        questions.every((q) => q.category == QuizCategory.stateName),
        isTrue,
      );
      expect(questions.every((q) => q.answerCode.isNotEmpty), isTrue);
      expect(questions.every((q) => q.answerName.isNotEmpty), isTrue);
      expect(questions.every((q) => q.clueText.isNotEmpty), isTrue);
    });

    test('generates questions for capital category', () {
      final generator = QuizQuestionGenerator(
        region: GameRegion.usStates,
        seed: 42,
      );
      final questions = generator.generateQuestions(QuizCategory.capital);

      expect(questions.length, equals(50));
      for (final q in questions) {
        expect(q.clueText, startsWith('Capital: '));
      }
    });

    test('generates questions for nickname category', () {
      final generator = QuizQuestionGenerator(
        region: GameRegion.usStates,
        seed: 42,
      );
      final questions = generator.generateQuestions(QuizCategory.nickname);

      expect(questions.length, equals(50));
      for (final q in questions) {
        expect(q.clueText, startsWith('Nickname: '));
      }
    });

    test('generates questions for sportsTeam category', () {
      final generator = QuizQuestionGenerator(
        region: GameRegion.usStates,
        seed: 42,
      );
      final questions = generator.generateQuestions(QuizCategory.sportsTeam);

      expect(questions, isNotEmpty);
      for (final q in questions) {
        expect(q.clueText, startsWith('Team: '));
      }
    });

    test('generates questions for mixed category', () {
      final generator = QuizQuestionGenerator(
        region: GameRegion.usStates,
        seed: 42,
      );
      final questions = generator.generateQuestions(QuizCategory.mixed);

      expect(questions, isNotEmpty);
      // Mixed should have variety of categories
      final categories = questions.map((q) => q.category).toSet();
      expect(categories.length, greaterThan(1));
    });

    test('seeded generator produces deterministic results', () {
      final gen1 = QuizQuestionGenerator(region: GameRegion.usStates, seed: 42);
      final gen2 = QuizQuestionGenerator(region: GameRegion.usStates, seed: 42);
      final q1 = gen1.generateQuestions(QuizCategory.stateName);
      final q2 = gen2.generateQuestions(QuizCategory.stateName);

      expect(q1.length, equals(q2.length));
      for (var i = 0; i < q1.length; i++) {
        expect(q1[i].answerCode, equals(q2[i].answerCode));
      }
    });

    test('all answer codes refer to valid US states', () {
      final generator = QuizQuestionGenerator(
        region: GameRegion.usStates,
        seed: 42,
      );
      final questions = generator.generateQuestions(QuizCategory.stateName);
      final areas = RegionalData.getAreas(GameRegion.usStates);
      final validCodes = areas.map((a) => a.code).toSet();

      for (final q in questions) {
        expect(
          validCodes.contains(q.answerCode),
          isTrue,
          reason: '${q.answerCode} is not a valid US state code',
        );
      }
    });
  });

  group('QuizSession', () {
    test('session starts with correct initial state', () {
      final session = QuizSession(
        mode: QuizMode.allStates,
        category: QuizCategory.stateName,
        region: GameRegion.usStates,
        seed: 42,
      );
      session.start();

      expect(session.isStarted, isTrue);
      expect(session.isFinished, isFalse);
      expect(session.currentIndex, equals(0));
      expect(session.totalScore, equals(0));
      expect(session.streak, equals(0));
      expect(session.wrongCount, equals(0));
      expect(session.correctCount, equals(0));
      expect(session.answeredCodes, isEmpty);
      expect(session.currentQuestion, isNotNull);
      expect(session.totalQuestions, equals(50));
    });

    test('correct answer increases score and streak', () {
      final session = QuizSession(
        mode: QuizMode.allStates,
        category: QuizCategory.stateName,
        region: GameRegion.usStates,
        seed: 42,
      );
      session.start();

      final question = session.currentQuestion!;
      final result = session.submitAnswer(question.answerCode);

      expect(result, isNotNull);
      expect(result!.correct, isTrue);
      expect(result.points, greaterThan(0));
      expect(session.streak, equals(1));
      expect(session.totalScore, greaterThan(0));
      expect(session.correctCount, equals(1));
      expect(session.currentIndex, equals(1));
    });

    test('wrong answer resets streak and deducts points', () {
      final session = QuizSession(
        mode: QuizMode.allStates,
        category: QuizCategory.stateName,
        region: GameRegion.usStates,
        seed: 42,
      );
      session.start();

      // First, answer correctly to build a streak
      final q1 = session.currentQuestion!;
      session.submitAnswer(q1.answerCode);
      expect(session.streak, equals(1));

      // Now answer wrong
      final q2 = session.currentQuestion!;
      // Pick a wrong answer (any code that's not the right one)
      final wrongCode = q2.answerCode == 'CA' ? 'TX' : 'CA';
      final result = session.submitAnswer(wrongCode);

      expect(result, isNotNull);
      expect(result!.correct, isFalse);
      expect(result.points, equals(-200));
      expect(session.streak, equals(0));
      expect(session.wrongCount, equals(1));
    });

    test('already answered codes are rejected', () {
      final session = QuizSession(
        mode: QuizMode.allStates,
        category: QuizCategory.stateName,
        region: GameRegion.usStates,
        seed: 42,
      );
      session.start();

      final question = session.currentQuestion!;
      final code = question.answerCode;
      session.submitAnswer(code);

      // Try to tap the same state again
      final result = session.submitAnswer(code);
      expect(result, isNull);
    });

    test('rapid fire ends after max wrong answers', () {
      final session = QuizSession(
        mode: QuizMode.rapidFire,
        category: QuizCategory.stateName,
        region: GameRegion.usStates,
        seed: 42,
      );
      session.start();

      // Get 3 wrong answers
      for (var i = 0; i < 3; i++) {
        final q = session.currentQuestion!;
        final wrongCode = q.answerCode == 'CA' ? 'TX' : 'CA';
        session.submitAnswer(wrongCode);
      }

      expect(session.isFinished, isTrue);
      expect(session.wrongCount, equals(3));
    });

    test('allStates ends after all questions answered', () {
      final session = QuizSession(
        mode: QuizMode.allStates,
        category: QuizCategory.stateName,
        region: GameRegion.usStates,
        seed: 42,
      );
      session.start();

      // Answer all questions correctly
      while (!session.isFinished && session.currentQuestion != null) {
        final q = session.currentQuestion!;
        session.submitAnswer(q.answerCode);
      }

      expect(session.isFinished, isTrue);
      expect(session.correctCount, equals(50));
    });

    test('finish() manually ends the session', () {
      final session = QuizSession(
        mode: QuizMode.allStates,
        category: QuizCategory.stateName,
        region: GameRegion.usStates,
        seed: 42,
      );
      session.start();

      session.finish();
      expect(session.isFinished, isTrue);
    });

    test('cannot submit answers after session is finished', () {
      final session = QuizSession(
        mode: QuizMode.allStates,
        category: QuizCategory.stateName,
        region: GameRegion.usStates,
        seed: 42,
      );
      session.start();
      session.finish();

      final result = session.submitAnswer('CA');
      expect(result, isNull);
    });
  });

  group('QuizSummary', () {
    test('summary has correct accuracy', () {
      final session = QuizSession(
        mode: QuizMode.allStates,
        category: QuizCategory.stateName,
        region: GameRegion.usStates,
        seed: 42,
      );
      session.start();

      // Answer first question correctly
      final q1 = session.currentQuestion!;
      session.submitAnswer(q1.answerCode);

      // Answer second question wrong
      final q2 = session.currentQuestion!;
      final wrongCode = q2.answerCode == 'CA' ? 'TX' : 'CA';
      session.submitAnswer(wrongCode);

      session.finish();
      final summary = session.summary;

      expect(summary.correctCount, equals(1));
      expect(summary.wrongCount, equals(1));
      expect(summary.accuracy, equals(0.5));
    });

    test('summary grades based on accuracy', () {
      const summary90 = QuizSummary(
        mode: QuizMode.allStates,
        category: QuizCategory.stateName,
        difficulty: QuizDifficulty.medium,
        totalScore: 10000,
        correctCount: 45,
        wrongCount: 5,
        totalQuestions: 50,
        elapsedMs: 60000,
        bestStreak: 5,
        hintsUsed: 0,
        results: [],
      );
      expect(summary90.grade, equals('A'));

      const summary50 = QuizSummary(
        mode: QuizMode.allStates,
        category: QuizCategory.stateName,
        difficulty: QuizDifficulty.medium,
        totalScore: 5000,
        correctCount: 25,
        wrongCount: 25,
        totalQuestions: 50,
        elapsedMs: 120000,
        bestStreak: 3,
        hintsUsed: 0,
        results: [],
      );
      expect(summary50.grade, equals('D'));
    });

    test('elapsed time format is correct', () {
      const summary = QuizSummary(
        mode: QuizMode.allStates,
        category: QuizCategory.stateName,
        difficulty: QuizDifficulty.medium,
        totalScore: 10000,
        correctCount: 50,
        wrongCount: 0,
        totalQuestions: 50,
        elapsedMs: 125000,
        bestStreak: 50,
        hintsUsed: 0,
        results: [],
      );
      expect(summary.elapsedFormatted, equals('2:05'));
    });
  });

  group('QuizQuestion', () {
    test('QuizQuestion stores all fields', () {
      const question = QuizQuestion(
        category: QuizCategory.capital,
        clueText: 'Capital: Sacramento',
        answerCode: 'CA',
        answerName: 'California',
      );

      expect(question.category, equals(QuizCategory.capital));
      expect(question.clueText, equals('Capital: Sacramento'));
      expect(question.answerCode, equals('CA'));
      expect(question.answerName, equals('California'));
    });
  });
}
