import 'package:flutter_test/flutter_test.dart';
import 'package:flit/game/quiz/daily_briefing.dart';
import 'package:flit/game/quiz/quiz_category.dart';
import 'package:flit/game/quiz/quiz_difficulty.dart';
import 'package:flit/game/quiz/quiz_session.dart';

void main() {
  /// 60 consecutive dates starting 2026-01-01.
  List<DateTime> dates(int count) => List.generate(
        count,
        (i) => DateTime.utc(2026, 1, 1).add(Duration(days: i)),
      );

  /// Categories the daily is allowed to use.
  const accessible = {QuizCategory.stateName, QuizCategory.capital};
  const flavour = {QuizCategory.nickname, QuizCategory.landmark};

  group('DailyBriefing question set', () {
    test('is always exactly ${DailyBriefing.questionCount} questions', () {
      for (final date in dates(60)) {
        final briefing = DailyBriefing.forDate(date);
        expect(
          briefing.questions.length,
          DailyBriefing.questionCount,
          reason: 'wrong question count on ${briefing.dateKey}',
        );
      }
    });

    test('has no duplicate answer areas', () {
      for (final date in dates(60)) {
        final briefing = DailyBriefing.forDate(date);
        final codes = briefing.questions.map((q) => q.answerCode).toSet();
        expect(
          codes.length,
          briefing.questions.length,
          reason: 'duplicate answer area on ${briefing.dateKey}',
        );
      }
    });

    test('uses only name/capital plus at most one flavour question', () {
      for (final date in dates(60)) {
        final briefing = DailyBriefing.forDate(date);
        final flavourCount = briefing.questions
            .where((q) => flavour.contains(q.category))
            .length;
        expect(
          flavourCount,
          lessThanOrEqualTo(1),
          reason: 'more than one flavour question on ${briefing.dateKey}',
        );
        if (flavourCount > 0) {
          // Flavour clues only on well-known regions (tier <= 5).
          expect(
            briefing.level.requiredLevel,
            lessThanOrEqualTo(5),
            reason: 'flavour question on hard region ${briefing.level.id} '
                '(${briefing.dateKey})',
          );
        }
        for (final q in briefing.questions) {
          expect(
            accessible.contains(q.category) || flavour.contains(q.category),
            isTrue,
            reason: 'disallowed category ${q.category} on ${briefing.dateKey}',
          );
        }
      }
    });

    test('obscure categories never appear across 60 consecutive dates', () {
      const obscure = {
        QuizCategory.stateFlower,
        QuizCategory.stateBird,
        QuizCategory.motto,
        QuizCategory.sportsTeam,
        QuizCategory.celebrity,
        QuizCategory.filmSetting,
        QuizCategory.flagDescription,
        QuizCategory.mixed,
      };
      for (final date in dates(60)) {
        final briefing = DailyBriefing.forDate(date);
        for (final q in briefing.questions) {
          expect(
            obscure.contains(q.category),
            isFalse,
            reason: 'obscure category ${q.category} on ${briefing.dateKey}',
          );
        }
      }
    });

    test('every question has clue text, answer code, and answer name', () {
      for (final date in dates(60)) {
        final briefing = DailyBriefing.forDate(date);
        for (final q in briefing.questions) {
          expect(q.clueText, isNotEmpty);
          expect(q.answerCode, isNotEmpty);
          expect(q.answerName, isNotEmpty);
        }
      }
    });
  });

  group('DailyBriefing determinism', () {
    test('two forDate calls yield identical briefings', () {
      for (final date in dates(30)) {
        final a = DailyBriefing.forDate(date);
        final b = DailyBriefing.forDate(date);
        expect(a.dateKey, b.dateKey);
        expect(a.seed, b.seed);
        expect(a.level.id, b.level.id);
        expect(a.difficulty, b.difficulty);
        expect(a.mode, b.mode);
        expect(a.categories, b.categories);
        expect(a.questions.length, b.questions.length);
        for (var i = 0; i < a.questions.length; i++) {
          expect(a.questions[i].category, b.questions[i].category);
          expect(a.questions[i].clueText, b.questions[i].clueText);
          expect(a.questions[i].answerCode, b.questions[i].answerCode);
          expect(a.questions[i].labelFree, b.questions[i].labelFree);
        }
      }
    });

    test('time-of-day is ignored', () {
      final morning = DailyBriefing.forDate(DateTime.utc(2026, 3, 14, 6, 30));
      final night = DailyBriefing.forDate(DateTime.utc(2026, 3, 14, 23, 59));
      expect(morning.seed, night.seed);
      expect(morning.level.id, night.level.id);
      expect(
        morning.questions.map((q) => q.answerCode).toList(),
        night.questions.map((q) => q.answerCode).toList(),
      );
    });
  });

  group('DailyBriefing label policy', () {
    test('stateName questions are ALWAYS labelFree', () {
      // The whole game of a name question is finding the area — a visible
      // label would answer it outright.
      for (final date in dates(120)) {
        final briefing = DailyBriefing.forDate(date);
        for (final q in briefing.questions) {
          if (q.category == QuizCategory.stateName) {
            expect(
              q.labelFree,
              isTrue,
              reason: 'labeled stateName question ("${q.clueText}") on '
                  '${briefing.dateKey}',
            );
          }
        }
      }
    });

    test('capital and flavour questions are NEVER labelFree', () {
      // Labels don't reveal which area has a given capital / nickname /
      // landmark, so those questions keep labels on.
      for (final date in dates(120)) {
        final briefing = DailyBriefing.forDate(date);
        for (final q in briefing.questions) {
          if (q.category != QuizCategory.stateName) {
            expect(
              q.labelFree,
              isFalse,
              reason: 'label-free ${q.category} question on '
                  '${briefing.dateKey}',
            );
          }
        }
      }
    });

    test('blind counts match the region tier and sit at the end of the set',
        () {
      for (final date in dates(120)) {
        final briefing = DailyBriefing.forDate(date);
        final expected = DailyBriefing.labelFreeCountForTier(
          briefing.level.requiredLevel,
        );
        expect(
          briefing.labelFreeCount,
          expected,
          reason: 'wrong blind count for ${briefing.level.id} '
              '(${briefing.dateKey})',
        );
        // Only the trailing questions are label-free.
        final total = briefing.questions.length;
        for (var i = 0; i < total; i++) {
          expect(
            briefing.questions[i].labelFree,
            i >= total - expected,
            reason: 'labelFree misplaced at index $i on ${briefing.dateKey}',
          );
        }
      }
    });

    test('tier mix: easy 3 labeled + 3 blind, mid 4 + 2, hard 5 + 1', () {
      expect(DailyBriefing.labelFreeCountForTier(1), 3);
      expect(DailyBriefing.labelFreeCountForTier(5), 3);
      expect(DailyBriefing.labelFreeCountForTier(7), 3);
      expect(DailyBriefing.labelFreeCountForTier(9), 2);
      expect(DailyBriefing.labelFreeCountForTier(13), 2);
      expect(DailyBriefing.labelFreeCountForTier(15), 1);
      expect(DailyBriefing.labelFreeCountForTier(20), 1);
    });

    test('labeled questions are capital or flavour clues', () {
      for (final date in dates(120)) {
        final briefing = DailyBriefing.forDate(date);
        final labeled = briefing.questions.where((q) => !q.labelFree).toList();
        expect(
          labeled.length,
          DailyBriefing.questionCount -
              DailyBriefing.labelFreeCountForTier(
                briefing.level.requiredLevel,
              ),
          reason: 'wrong labeled count on ${briefing.dateKey}',
        );
        for (final q in labeled) {
          expect(
            q.category == QuizCategory.capital || flavour.contains(q.category),
            isTrue,
            reason: 'labeled ${q.category} question on ${briefing.dateKey}',
          );
        }
      }
    });
  });

  group('DailyBriefing conditions', () {
    test('difficulty always shows labels; mode is untimed with no fail-out',
        () {
      for (final date in dates(60)) {
        final briefing = DailyBriefing.forDate(date);
        expect(briefing.difficulty.showLabels, isTrue);
        expect(briefing.mode, QuizMode.allStates);
        expect(briefing.mode.timeLimit, isNull);
        expect(briefing.mode.maxWrong, isNull);
      }
    });

    test('niche regions stay rare, well-known regions rotate', () {
      const niche = {
        'uk_counties',
        'ireland',
        'canada',
        'oceania',
        'caribbean'
      };
      var nicheDays = 0;
      final seen = <String>{};
      for (final date in dates(365)) {
        final briefing = DailyBriefing.forDate(date);
        seen.add(briefing.level.id);
        if (niche.contains(briefing.level.id)) nicheDays++;
      }
      // Weighted at 5/33 (~15%); allow slack but stay near ~1 day in 7.
      expect(nicheDays / 365, lessThan(0.25));
      // The rotation genuinely varies regions.
      expect(seen.length, greaterThanOrEqualTo(4));
    });
  });

  group('QuizSession preset questions', () {
    test('session uses the curated daily set verbatim', () {
      final briefing = DailyBriefing.forDate(DateTime.utc(2026, 5, 1));
      final session = QuizSession(
        mode: briefing.mode,
        categories: briefing.categories,
        region: briefing.level.region,
        difficulty: briefing.difficulty,
        presetQuestions: briefing.questions,
        seed: briefing.seed,
      );
      session.start();
      expect(session.totalQuestions, DailyBriefing.questionCount);
      expect(
        session.currentQuestion?.answerCode,
        briefing.questions.first.answerCode,
      );
      // Answering the first question correctly advances to the second.
      final result = session.submitAnswer(briefing.questions.first.answerCode);
      expect(result?.correct, isTrue);
      expect(
        session.currentQuestion?.answerCode,
        briefing.questions[1].answerCode,
      );
    });

    test('practice-mode questions default to labelFree false', () {
      const question = QuizQuestion(
        category: QuizCategory.stateName,
        clueText: 'France',
        answerCode: 'FR',
        answerName: 'France',
      );
      expect(question.labelFree, isFalse);
    });
  });
}
