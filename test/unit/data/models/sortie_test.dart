import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:flit/data/models/challenge.dart';
import 'package:flit/data/models/sortie.dart';
import 'package:flit/game/economy/rated_loadout.dart';

void main() {
  group('SortieRun', () {
    test('uses the same 5-round format as H2H challenges', () {
      expect(SortieRun.totalRounds, Challenge.totalRounds);
      expect(SortieRun.totalRounds, 5);
    });

    test('generates one seed per round in the challenge seed range', () {
      final run = SortieRun.generate(rng: Random(7));
      expect(run.seeds.length, SortieRun.totalRounds);
      for (final seed in run.seeds) {
        expect(seed, greaterThanOrEqualTo(0));
        expect(seed, lessThan(1 << 31));
      }
    });

    test('seeded generation is reproducible', () {
      final a = SortieRun.generate(rng: Random(99));
      final b = SortieRun.generate(rng: Random(99));
      expect(a.seeds, b.seeds);
    });

    test('max run score covers 5 perfect rounds', () {
      expect(SortieRun.maxRunScore, 50000);
    });
  });

  group('rated normalization', () {
    test('standard loadout is exactly baseline physics', () {
      const loadout = RatedLoadout.standard;
      expect(loadout.planeHandling, 1.0);
      expect(loadout.planeSpeed, 1.0);
      expect(loadout.planeFuelEfficiency, 1.0);
      expect(loadout.fuelBoostMultiplier, 1.0);
    });
  });

  group('SortieOutcome', () {
    test('parses a ghost-duel win payload', () {
      final outcome = SortieOutcome.fromJson({
        'applied': true,
        'delta': 16,
        'new_rating': 1066,
        'ghost_name': 'Maverick',
        'ghost_score': 21000,
        'player_score': 32000,
      });
      expect(outcome.applied, isTrue);
      expect(outcome.ratingDelta, 16);
      expect(outcome.newRating, 1066);
      expect(outcome.won, isTrue);
      expect(outcome.lost, isFalse);
    });

    test('parses a house-ghost loss payload (null ghost name)', () {
      final outcome = SortieOutcome.fromJson({
        'applied': true,
        'delta': -14,
        'new_rating': 1036,
        'ghost_name': null,
        'ghost_score': 20000,
        'player_score': 11000,
      });
      expect(outcome.applied, isTrue);
      expect(outcome.ghostName, isNull);
      expect(outcome.lost, isTrue);
    });

    test('draw when scores tie', () {
      final outcome = SortieOutcome.fromJson({
        'applied': true,
        'delta': 0,
        'new_rating': 1050,
        'ghost_score': 20000,
        'player_score': 20000,
      });
      expect(outcome.draw, isTrue);
      expect(outcome.won, isFalse);
      expect(outcome.lost, isFalse);
    });

    test('unavailable outcome applies nothing', () {
      const outcome = SortieOutcome.unavailable;
      expect(outcome.applied, isFalse);
      expect(outcome.ratingDelta, 0);
      expect(outcome.newRating, isNull);
    });
  });
}
