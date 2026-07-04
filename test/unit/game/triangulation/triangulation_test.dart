import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flit/core/services/game_settings.dart';
import 'package:flit/core/utils/math_utils.dart';
import 'package:flit/game/clues/clue_types.dart';
import 'package:flit/game/map/country_data.dart';
import 'package:flit/game/triangulation/daily_triangulation.dart';
import 'package:flit/game/triangulation/triangulation_scoring.dart';
import 'package:flit/game/triangulation/triangulation_session.dart';
import 'package:flit/game/triangulation/triangulation_share.dart';
import 'package:flit/game/triangulation/triangulation_target.dart';

void main() {
  group('bearing and distance helpers', () {
    test('due north bearing is 0', () {
      expect(
        initialBearingDeg(Vector2(0, 0), Vector2(0, 10)),
        closeTo(0, 0.01),
      );
    });

    test('due east bearing is 90', () {
      expect(
        initialBearingDeg(Vector2(0, 0), Vector2(10, 0)),
        closeTo(90, 0.01),
      );
    });

    test('due south bearing is 180, due west 270', () {
      expect(
        initialBearingDeg(Vector2(0, 10), Vector2(0, 0)),
        closeTo(180, 0.01),
      );
      expect(
        initialBearingDeg(Vector2(10, 0), Vector2(0, 0)),
        closeTo(270, 0.01),
      );
    });

    test('Islamabad→Bishkek points roughly north (screenshot geometry)', () {
      final islamabad = Vector2(73.04, 33.68);
      final bishkek = Vector2(74.59, 42.87);
      final bearing = initialBearingDeg(islamabad, bishkek);
      expect(bearing, greaterThan(0));
      expect(bearing, lessThan(20));
    });

    test('Islamabad→Tianjin points east-northeast', () {
      final islamabad = Vector2(73.04, 33.68);
      final tianjin = Vector2(117.20, 39.13);
      final bearing = initialBearingDeg(islamabad, tianjin);
      expect(bearing, greaterThan(50));
      expect(bearing, lessThan(80));
    });

    test('London→Paris distance is about 343 km', () {
      final london = Vector2(-0.1276, 51.5074);
      final paris = Vector2(2.3522, 48.8566);
      expect(greatCircleKm(london, paris), closeTo(343, 15));
    });

    test('rhumb bearing matches cardinal directions', () {
      expect(rhumbBearingDeg(Vector2(0, 0), Vector2(0, 10)), closeTo(0, 0.01));
      expect(rhumbBearingDeg(Vector2(0, 0), Vector2(10, 0)), closeTo(90, 0.01));
      expect(
        rhumbBearingDeg(Vector2(0, 10), Vector2(0, 0)),
        closeTo(180, 0.01),
      );
      expect(
        rhumbBearingDeg(Vector2(10, 0), Vector2(0, 0)),
        closeTo(270, 0.01),
      );
    });

    test('Colombo→Mexico City rhumb bearing reads west, not north', () {
      // Great-circle initial bearing here crosses near the pole (~N),
      // which broke map intuition in-game; the rhumb bearing is the
      // flat-map direction players expect.
      final colombo = Vector2(79.86, 6.93);
      final mexicoCity = Vector2(-99.13, 19.43);
      final rhumb = rhumbBearingDeg(colombo, mexicoCity);
      expect(rhumb, greaterThan(250));
      expect(rhumb, lessThan(300));
      // Sanity: the great-circle bearing really is the unintuitive one.
      final greatCircle = initialBearingDeg(colombo, mexicoCity);
      expect(greatCircle < 45 || greatCircle > 315, isTrue);
    });
  });

  group('daily determinism', () {
    test('same date yields identical seed, theme, target, difficulty', () {
      final a = DailyTriangulation.forDate(DateTime.utc(2026, 7, 4));
      final b = DailyTriangulation.forDate(DateTime.utc(2026, 7, 4));
      expect(a.seed, b.seed);
      expect(a.seed, 20260704);
      expect(a.theme.title, b.theme.title);
      expect(a.theme.targetType, b.theme.targetType);
      expect(a.difficulty, b.difficulty);
      expect(a.difficultyPercent, b.difficultyPercent);
      expect(a.difficultyPercent, inInclusiveRange(0, 100));
      expect(a.difficultyLabelText, isNotEmpty);
    });

    test('label-free (expert) themes report higher difficulty', () {
      final date = DateTime.utc(2026, 7, 4);
      final base = DailyTriangulation.forDate(date);
      const labelled = DailyTriangulationTheme(
        title: 'T',
        description: 'd',
        targetType: TriTargetType.capital,
        clueTypes: {ClueType.flag},
        labelTypes: {TriLabel.capital},
      );
      const expert = DailyTriangulationTheme(
        title: 'T',
        description: 'd',
        targetType: TriTargetType.capital,
        clueTypes: {ClueType.flag},
        labelTypes: {},
      );
      final withLabels = DailyTriangulation(
        date: date,
        seed: base.seed,
        theme: labelled,
        difficulty: GameDifficulty.normal,
      );
      final withoutLabels = DailyTriangulation(
        date: date,
        seed: base.seed,
        theme: expert,
        difficulty: GameDifficulty.normal,
      );
      expect(
        withoutLabels.difficultyPercent,
        greaterThan(withLabels.difficultyPercent),
      );
    });

    test('same seed yields identical targets, clues, and bearings', () {
      final daily = DailyTriangulation.forDate(DateTime.utc(2026, 7, 4));
      final s1 = TriangulationSession(daily.toConfig());
      final s2 = TriangulationSession(daily.toConfig());
      expect(s1.rounds.length, DailyTriangulation.roundCount);
      for (var i = 0; i < s1.rounds.length; i++) {
        final r1 = s1.rounds[i].round;
        final r2 = s2.rounds[i].round;
        expect(r1.targetCountryCode, r2.targetCountryCode);
        expect(
          r1.clues.map((c) => c.countryCode).toList(),
          r2.clues.map((c) => c.countryCode).toList(),
        );
        expect(
          r1.clues.map((c) => c.bearingFromTargetDeg).toList(),
          r2.clues.map((c) => c.bearingFromTargetDeg).toList(),
        );
      }
    });

    test('rounds have distinct targets', () {
      final daily = DailyTriangulation.forDate(DateTime.utc(2026, 7, 4));
      final session = TriangulationSession(daily.toConfig());
      final targets =
          session.rounds.map((r) => r.round.targetCountryCode).toSet();
      expect(targets.length, session.rounds.length);
    });

    test('day number counts from launch epoch', () {
      final launch = DailyTriangulation.forDate(DateTime.utc(2026, 7, 4));
      expect(launch.dayNumber, 1);
      final later = DailyTriangulation.forDate(DateTime.utc(2026, 7, 14));
      expect(later.dayNumber, 11);
    });
  });

  group('round generation', () {
    test('clue markers exclude the target and have valid bearings', () {
      final round = TriangulationRound.generate(
        seed: 42,
        difficulty: GameDifficulty.normal,
      );
      expect(round.clues.length, 5);
      for (final clue in round.clues) {
        expect(clue.countryCode, isNot(round.targetCountryCode));
        expect(clue.bearingFromTargetDeg, inInclusiveRange(0, 360));
        expect(clue.distanceFromTargetKm, greaterThan(0));
        // Arrows use flat-map (rhumb) bearings, not great-circle.
        expect(
          clue.bearingFromTargetDeg,
          closeTo(
            rhumbBearingDeg(round.targetCapitalLngLat, clue.capitalLngLat),
            1e-9,
          ),
        );
      }
      expect(
        round.clues.map((c) => c.countryCode).toSet().length,
        round.clues.length,
      );
    });

    test('leader/language labels only pick anchors with stats', () {
      final round = TriangulationRound.generate(
        seed: 7,
        difficulty: GameDifficulty.normal,
        requireStats: true,
      );
      for (final clue in round.clues) {
        expect(clue.labelText(TriLabel.leader), isNotNull);
        expect(clue.labelText(TriLabel.language), isNotNull);
      }
    });
  });

  group('scoring', () {
    test('perfect solve scores base times difficulty multiplier', () {
      final score = computeTriangulationScore(
        solved: true,
        solvedAsCountry: false,
        timeMs: 5000,
        wrongGuessPenalties: const [],
        targetCountryCode: 'FR',
      );
      expect(score, greaterThan(0));
      expect(score, lessThanOrEqualTo(triBaseScore));
    });

    test('time decay matches the daily scramble curve', () {
      expect(triTimePenalty(5000), 0);
      expect(triTimePenalty(10000), 0);
      expect(triTimePenalty(35000), 2500);
      expect(triTimePenalty(60000), 5000);
      expect(triTimePenalty(120000), 5000);
    });

    test('proximity penalty orders neighbour < mid < far', () {
      // Luxembourg target: France ~290 km (neighbour), Portugal ~1700 km,
      // Brazil ~9200 km.
      final france = triProximityPenalty(290, isNeighbor: true);
      final portugal = triProximityPenalty(1700);
      final brazil = triProximityPenalty(9200);
      expect(france, lessThan(portugal));
      expect(portugal, lessThan(brazil));
      expect(brazil, triWrongGuessFloor + triWrongGuessDistanceMax);
    });

    test('country-name solve scores 0.7x of capital solve', () {
      final viaCapital = computeTriangulationScore(
        solved: true,
        solvedAsCountry: false,
        timeMs: 5000,
        wrongGuessPenalties: const [],
        targetCountryCode: 'FR',
      );
      final viaCountry = computeTriangulationScore(
        solved: true,
        solvedAsCountry: true,
        timeMs: 5000,
        wrongGuessPenalties: const [],
        targetCountryCode: 'FR',
      );
      expect(viaCountry, (viaCapital * 0.7).round());
    });

    test('expired round scores 0', () {
      final score = computeTriangulationScore(
        solved: false,
        solvedAsCountry: false,
        timeMs: 5000,
        wrongGuessPenalties: const [500, 500, 500, 500, 500],
        targetCountryCode: 'FR',
      );
      expect(score, 0);
    });
  });

  group('session flow', () {
    TriangulationSession makeSession() => TriangulationSession(
          const TriangulationConfig(seed: 99, rounds: 1),
        );

    String wrongCode(TriangulationSession session, Set<String> used) {
      final target = session.currentRound.round.targetCountryCode;
      return CountryData.playableCountries
          .firstWhere(
            (c) =>
                c.code != target &&
                !used.contains(c.code) &&
                CountryData.getCapital(c.code) != null,
          )
          .code;
    }

    test('correct guess solves the round and scores', () {
      final session = makeSession();
      final guess = session.submitGuess(
        session.currentRound.round.targetCountryCode,
        viaCapital: true,
        elapsedMs: 4000,
      );
      expect(guess.isCorrect, isTrue);
      expect(session.currentRound.solved, isTrue);
      expect(session.currentRound.score, greaterThan(0));
      expect(session.isFinished, isTrue);
    });

    test('country-target days score full marks for the country name', () {
      // Same seed, same timing: solving a capital-target game via the
      // capital must equal solving a country-target game via the country
      // (no ×0.7 discount on country days).
      final capitalGame = TriangulationSession(
        const TriangulationConfig(seed: 99, rounds: 1),
      );
      final countryGame = TriangulationSession(
        const TriangulationConfig(
          seed: 99,
          rounds: 1,
          targetType: TriTargetType.country,
        ),
      );
      capitalGame.submitGuess(
        capitalGame.currentRound.round.targetCountryCode,
        viaCapital: true,
        elapsedMs: 4000,
      );
      countryGame.submitGuess(
        countryGame.currentRound.round.targetCountryCode,
        viaCapital: false,
        elapsedMs: 4000,
      );
      expect(countryGame.currentRound.score, capitalGame.currentRound.score);
      expect(countryGame.currentRound.score, greaterThan(0));
    });

    test('wrong guesses add compass markers and expire after 5', () {
      final session = makeSession();
      final used = <String>{};
      for (var i = 0; i < 5; i++) {
        final code = wrongCode(session, used);
        used.add(code);
        final guess = session.submitGuess(
          code,
          viaCapital: false,
          elapsedMs: 3000 * (i + 1),
        );
        expect(guess.isCorrect, isFalse);
        expect(guess.penalty, greaterThan(0));
        expect(guess.bearingFromTargetDeg, inInclusiveRange(0, 360));
      }
      expect(session.currentRound.expired, isTrue);
      expect(session.currentRound.wrongGuesses.length, 5);
      expect(session.currentRound.score, 0);
    });
  });

  group('share text', () {
    test('proximity emoji thresholds match scoring constants', () {
      expect(proximityEmoji(triHotKm - 1), '\u{1F7E9}');
      expect(proximityEmoji(triWarmKm - 1), '\u{1F7E8}');
      expect(proximityEmoji(triCoolKm - 1), '\u{1F7E7}');
      expect(proximityEmoji(triCoolKm + 1), '\u{1F7E5}');
    });

    test('share text is spoiler-free and shows outcome per round', () {
      final session = TriangulationSession(
        const TriangulationConfig(seed: 99, rounds: 1),
      );
      final round = session.currentRound.round;
      session.submitGuess(
        round.targetCountryCode,
        viaCapital: true,
        elapsedMs: 4000,
      );
      final text = buildTriangulationShareText(session, dayNumber: 12);
      expect(text, contains('Flit Triangulation #12'));
      expect(text, contains('1/1'));
      expect(text, contains('✅'));
      expect(text, isNot(contains(round.targetCapitalName)));
      expect(text, isNot(contains(round.targetCountryName)));
    });
  });
}
