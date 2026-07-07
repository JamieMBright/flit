import 'package:flit/data/models/daily_challenge.dart';
import 'package:flutter_test/flutter_test.dart';

/// Determinism + reward-multiplier tests for [DailyChallenge].
///
/// The daily is seeded purely from the calendar date, so the same date must
/// always yield an identical configuration for every player.
void main() {
  group('DailyChallenge.forDate determinism', () {
    test('the same date produces an identical challenge', () {
      final date = DateTime.utc(2026, 3, 14);
      final a = DailyChallenge.forDate(date);
      final b = DailyChallenge.forDate(date);

      expect(a.seed, b.seed);
      expect(a.title, b.title);
      expect(a.enabledClueTypes, b.enabledClueTypes);
      expect(a.mapRegion, b.mapRegion);
      expect(a.difficultyPercent, b.difficultyPercent);
      expect(a.coinReward, b.coinReward);
      expect(a.bonusCoinReward, b.bonusCoinReward);
    });

    test('time-of-day is ignored — only Y/M/D drive the seed', () {
      final morning =
          DailyChallenge.forDate(DateTime.utc(2026, 3, 14, 1, 2, 3));
      final night = DailyChallenge.forDate(DateTime.utc(2026, 3, 14, 23, 59));
      expect(morning.seed, night.seed);
      expect(morning.title, night.title);
      expect(morning.enabledClueTypes, night.enabledClueTypes);
    });

    test('seed is the packed YYYYMMDD integer', () {
      final d = DailyChallenge.forDate(DateTime.utc(2026, 3, 14));
      expect(d.seed, 2026 * 10000 + 3 * 100 + 14);
    });

    test('bonus reward is always 3x the coin reward', () {
      for (var day = 1; day <= 28; day++) {
        final d = DailyChallenge.forDate(DateTime.utc(2026, 2, day));
        expect(d.bonusCoinReward, d.coinReward * 3);
      }
    });
  });

  group('Duo / Triple themes resolve distinct clue types', () {
    test('every generated daily has a non-empty, valid region', () {
      const regions = {
        'World',
        'Europe',
        'Asia',
        'Africa',
        'Americas',
        'Oceania'
      };
      for (var day = 1; day <= 28; day++) {
        final d = DailyChallenge.forDate(DateTime.utc(2026, 4, day));
        expect(d.enabledClueTypes, isNotEmpty);
        expect(regions.contains(d.mapRegion), isTrue);
      }
    });

    test('Duo Mix always yields 2 distinct clue types; Triple yields 3', () {
      var sawDuo = false;
      var sawTriple = false;
      // Sweep a year of dates to hit both randomised themes.
      for (var month = 1; month <= 12; month++) {
        for (var day = 1; day <= 28; day++) {
          final d = DailyChallenge.forDate(DateTime.utc(2026, month, day));
          if (d.title == 'Duo Mix') {
            sawDuo = true;
            expect(d.enabledClueTypes.length, 2);
          } else if (d.title == 'Triple Threat') {
            sawTriple = true;
            expect(d.enabledClueTypes.length, 3);
          }
        }
      }
      expect(sawDuo, isTrue, reason: 'expected to encounter a Duo Mix daily');
      expect(sawTriple, isTrue, reason: 'expected to encounter a Triple daily');
    });
  });

  group('reward multipliers with baseRewardOverride', () {
    test('multiplier is driven by the number of clue types', () {
      const base = 300;
      for (var month = 1; month <= 6; month++) {
        for (var day = 1; day <= 28; day++) {
          final d = DailyChallenge.forDate(
            DateTime.utc(2026, month, day),
            baseRewardOverride: base,
          );
          final double mult;
          switch (d.enabledClueTypes.length) {
            case 1:
              mult = 1.33; // single-clue themes are hardest
              break;
            case 2:
              mult = 1.17; // duo
              break;
            case 3:
              mult = 1.07; // triple
              break;
            default:
              mult = 1.0; // all clues
          }
          expect(
            d.coinReward,
            (base * mult).round(),
            reason: '${d.title} (${d.enabledClueTypes.length} clues)',
          );
        }
      }
    });

    test('single-clue override beats an all-clues override for the same base',
        () {
      // Find a single-clue day and an all-clues day, confirm the multiplier
      // ordering (harder theme -> bigger reward).
      DailyChallenge? single;
      DailyChallenge? all;
      for (var day = 1; day <= 31 && (single == null || all == null); day++) {
        final d = DailyChallenge.forDate(
          DateTime.utc(2026, 1, day),
          baseRewardOverride: 300,
        );
        if (d.enabledClueTypes.length == 1) single ??= d;
        if (d.enabledClueTypes.length == 5) all ??= d;
      }
      if (single != null && all != null) {
        expect(single.coinReward, greaterThan(all.coinReward));
        expect(all.coinReward, 300); // 1.0x
        expect(single.coinReward, (300 * 1.33).round());
      }
    });
  });
}
