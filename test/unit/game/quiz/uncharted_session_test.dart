import 'package:flutter_test/flutter_test.dart';
import 'package:flit/game/quiz/uncharted_session.dart';
import 'package:flit/game/map/region.dart';

void main() {
  group('UnchartedSession — countries mode', () {
    late UnchartedSession session;

    setUp(() {
      // Use a small region for fast testing.
      session = UnchartedSession(
        region: GameRegion.canadianProvinces,
        mode: UnchartedMode.countries,
      );
    });

    test('initial state is not started and not complete', () {
      expect(session.isStarted, false);
      expect(session.isComplete, false);
      expect(session.revealedCount, 0);
      expect(session.totalCount, greaterThan(0));
    });

    test('start() sets the timer', () {
      session.start();
      expect(session.isStarted, true);
      expect(session.elapsedMs, greaterThanOrEqualTo(0));
    });

    test('correct guess reveals the area', () {
      session.start();
      // Canada has "Ontario" as a province name.
      final result = session.submitGuess('Ontario');
      expect(result.matched, true);
      expect(result.code, isNotNull);
      expect(result.areaName, 'Ontario');
      expect(session.revealedCount, 1);
    });

    test('wrong guess does not reveal anything', () {
      session.start();
      final result = session.submitGuess('Atlantis');
      expect(result.matched, false);
      expect(session.revealedCount, 0);
    });

    test('same area cannot be revealed twice', () {
      session.start();
      session.submitGuess('Ontario');
      final result2 = session.submitGuess('Ontario');
      // Should not match again since it's already revealed.
      expect(result2.matched, false);
      expect(session.revealedCount, 1);
    });

    test('progress reflects revealed / total', () {
      session.start();
      expect(session.progress, 0.0);
      session.submitGuess('Ontario');
      expect(session.progress, greaterThan(0.0));
      expect(session.progress, lessThanOrEqualTo(1.0));
    });

    test('giveUp marks session complete', () {
      session.start();
      session.submitGuess('Ontario');
      session.giveUp();
      expect(session.isComplete, true);
      expect(session.givenUp, true);
    });

    test('finalScore is non-negative', () {
      session.start();
      session.submitGuess('Ontario');
      session.submitGuess('Quebec');
      expect(session.finalScore, greaterThan(0));
    });

    test('elapsedFormatted returns minutes:seconds format', () {
      session.start();
      final formatted = session.elapsedFormatted;
      expect(formatted, matches(RegExp(r'^\d+:\d{2}$')));
    });
  });

  group('UnchartedSession — capitals mode', () {
    test('correct capital guess reveals the area', () {
      final session = UnchartedSession(
        region: GameRegion.europe,
        mode: UnchartedMode.capitals,
      );
      session.start();
      // Paris is the capital of France.
      final result = session.submitGuess('Paris');
      expect(result.matched, true);
      expect(result.code, isNotNull);
    });

    test('country name does not match in capitals mode', () {
      final session = UnchartedSession(
        region: GameRegion.europe,
        mode: UnchartedMode.capitals,
      );
      session.start();
      // "France" is not a capital.
      final result = session.submitGuess('France');
      // May or may not fuzzy-match to something, but should not match France.
      if (result.matched) {
        expect(result.code, isNot('FR'));
      }
    });
  });

  group('UnchartedMode extension', () {
    test('displayName returns correct values', () {
      expect(UnchartedMode.countries.displayName, 'Countries');
      expect(UnchartedMode.capitals.displayName, 'Capitals');
    });

    test('description returns correct values', () {
      expect(UnchartedMode.countries.description, contains('country'));
      expect(UnchartedMode.capitals.description, contains('capital'));
    });
  });
}
