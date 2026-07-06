import 'package:flutter_test/flutter_test.dart';

import 'package:flit/data/providers/account_provider.dart';
import 'package:flit/game/quiz/flight_school_level.dart';
import 'package:flit/game/tutorial/mode_requirements.dart';
import 'package:flit/game/tutorial/training_missions.dart';

void main() {
  group('Basic Training mission catalogue', () {
    test('exactly three basic missions matching the gate constants', () {
      expect(basicTrainingMissions, hasLength(3));
      expect(
        basicTrainingMissions.map((m) => m.id).toSet(),
        equals(basicTrainingMissionIds),
      );
      expect(basicTrainingMissions.every((m) => m.isBasic), isTrue);
      expect(advancedTrainingMissions.every((m) => !m.isBasic), isTrue);
    });

    test('mission IDs and orders are unique across the whole trail', () {
      final ids = allTrainingMissions.map((m) => m.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      final orders = allTrainingMissions.map((m) => m.order).toList();
      expect(orders.toSet(), hasLength(orders.length));
    });

    test('basic XP rewards alone cross the level-2 threshold (100 XP)', () {
      final totalXp =
          basicTrainingMissions.fold<int>(0, (sum, m) => sum + m.xpReward);
      expect(totalXp, greaterThanOrEqualTo(100));
    });

    test('flight-kind missions carry a matching gameplay payload', () {
      for (final mission in allTrainingMissions) {
        if (mission.kind == TrainingMissionKind.flight) {
          expect(mission.flightMission, isNotNull, reason: mission.id);
          expect(mission.flightMission!.id, equals(mission.id));
          expect(mission.flightMission!.xpReward, equals(mission.xpReward));
          expect(
            mission.flightMission!.coinReward,
            equals(mission.coinReward),
          );
        } else {
          expect(mission.flightMission, isNull, reason: mission.id);
        }
      }
    });

    test('every training coach has portrait art', () {
      for (final mission in allTrainingMissions) {
        expect(mission.coach.imageAsset, isNotNull, reason: mission.id);
      }
    });

    test('getTrainingMission resolves every mission and rejects unknowns', () {
      for (final mission in allTrainingMissions) {
        expect(getTrainingMission(mission.id), same(mission));
      }
      expect(getTrainingMission('nope'), isNull);
    });
  });

  group('Per-daily unlock mapping', () {
    ModeRequirement req(String modeId) => getModeRequirement(modeId)!;

    test('Training Flight unlocks Daily Scramble immediately at level 1', () {
      expect(req('daily_challenge').isUnlocked(1, {}), isFalse);
      expect(
        req('daily_challenge').isUnlocked(1, {trainingFlightMissionId}),
        isTrue,
      );
    });

    test('Training Recon unlocks Daily Recon immediately at level 1', () {
      expect(req('daily_triangulation').isUnlocked(1, {}), isFalse);
      expect(
        req('daily_triangulation').isUnlocked(1, {trainingReconMissionId}),
        isTrue,
      );
    });

    test('Training Briefing unlocks Daily Briefing immediately at level 1', () {
      expect(req('daily_briefing').isUnlocked(1, {}), isFalse);
      expect(
        req('daily_briefing').isUnlocked(1, {trainingBriefingMissionId}),
        isTrue,
      );
    });

    test('each daily unlock is independent of the other two', () {
      const flightOnly = {trainingFlightMissionId};
      expect(req('daily_challenge').isUnlocked(1, flightOnly), isTrue);
      expect(req('daily_triangulation').isUnlocked(1, flightOnly), isFalse);
      expect(req('daily_briefing').isUnlocked(1, flightOnly), isFalse);

      const reconOnly = {trainingReconMissionId};
      expect(req('daily_challenge').isUnlocked(1, reconOnly), isFalse);
      expect(req('daily_triangulation').isUnlocked(1, reconOnly), isTrue);
      expect(req('daily_briefing').isUnlocked(1, reconOnly), isFalse);
    });
  });

  group('Base mode gating (level 1 = Basic Training only)', () {
    const baseModes = [
      'campaign',
      'free_flight',
      'standard_sortie',
      'training_sortie',
      'uncharted',
      'triangulation',
      'dogfight',
      'matchmaking',
    ];

    test('all base modes are locked for a fresh level-1 pilot', () {
      for (final mode in baseModes) {
        expect(
          getModeRequirement(mode)!.isUnlocked(1, {}),
          isFalse,
          reason: mode,
        );
      }
    });

    test('flight school (the Basic Training surface) is never locked', () {
      expect(getModeRequirement('flight_school')!.isUnlocked(1, {}), isTrue);
    });

    test('completing all three basics unlocks every base mode', () {
      for (final mode in baseModes) {
        expect(
          getModeRequirement(mode)!.isUnlocked(1, basicTrainingMissionIds),
          isTrue,
          reason: mode,
        );
      }
    });

    test('a partial basic set does not unlock base modes', () {
      const partial = {trainingFlightMissionId, trainingReconMissionId};
      for (final mode in baseModes) {
        expect(
          getModeRequirement(mode)!.isUnlocked(1, partial),
          isFalse,
          reason: mode,
        );
      }
    });

    test('lock reasons are the exact approved copy', () {
      expect(
        getModeRequirement('daily_challenge')!.unlockHint(1),
        equals('Complete Basic Training: Training Flight'),
      );
      expect(
        getModeRequirement('daily_triangulation')!.unlockHint(1),
        equals('Complete Basic Training: Training Recon'),
      );
      expect(
        getModeRequirement('daily_briefing')!.unlockHint(1),
        equals('Complete Basic Training: Training Briefing'),
      );
      for (final mode in baseModes) {
        expect(
          getModeRequirement(mode)!.unlockHint(1),
          equals('Reach Level 2 — finish Basic Training'),
          reason: mode,
        );
      }
    });
  });

  group('Level-2 promotion through the account provider', () {
    test('completing the three basics promotes to level 2', () {
      final notifier = AccountNotifier();
      expect(notifier.state.currentPlayer.level, equals(1));

      notifier.completeTrainingMission(trainingFlightMissionId, score: 5000);
      expect(notifier.state.currentPlayer.level, equals(1));
      expect(notifier.state.isGameModeUnlocked('daily_challenge'), isTrue);
      expect(notifier.state.isGameModeUnlocked('daily_triangulation'), isFalse);
      expect(notifier.state.isGameModeUnlocked('standard_sortie'), isFalse);

      notifier.completeTrainingMission(trainingReconMissionId, score: 3000);
      expect(notifier.state.currentPlayer.level, equals(1));
      expect(notifier.state.isGameModeUnlocked('daily_triangulation'), isTrue);
      expect(notifier.state.isGameModeUnlocked('daily_briefing'), isFalse);

      notifier.completeTrainingMission(trainingBriefingMissionId, score: 900);
      expect(notifier.state.basicTrainingComplete, isTrue);
      expect(notifier.state.currentPlayer.level, greaterThanOrEqualTo(2));
      expect(notifier.state.isGameModeUnlocked('daily_briefing'), isTrue);
      expect(notifier.state.isGameModeUnlocked('standard_sortie'), isTrue);
      expect(notifier.state.isGameModeUnlocked('campaign'), isTrue);
      expect(notifier.state.isGameModeUnlocked('dogfight'), isTrue);
      expect(notifier.state.isGameModeUnlocked('matchmaking'), isTrue);
      expect(notifier.state.isGameModeUnlocked('free_flight'), isTrue);
      expect(notifier.state.isGameModeUnlocked('uncharted'), isTrue);
      expect(notifier.state.isGameModeUnlocked('triangulation'), isTrue);
      expect(notifier.state.isGameModeUnlocked('training_sortie'), isTrue);

      notifier.dispose();
    });

    test('promotion holds regardless of completion order', () {
      final notifier = AccountNotifier();
      notifier.completeTrainingMission(trainingBriefingMissionId);
      notifier.completeTrainingMission(trainingFlightMissionId);
      expect(notifier.state.currentPlayer.level, equals(1));
      notifier.completeTrainingMission(trainingReconMissionId);
      expect(notifier.state.currentPlayer.level, greaterThanOrEqualTo(2));
      notifier.dispose();
    });

    test('re-completing a mission never double-awards or re-promotes', () {
      final notifier = AccountNotifier();
      notifier.completeTrainingMission(trainingFlightMissionId, score: 1000);
      final coinsAfterFirst = notifier.state.currentPlayer.coins;
      notifier.completeTrainingMission(trainingFlightMissionId, score: 2000);
      expect(notifier.state.currentPlayer.coins, equals(coinsAfterFirst));
      notifier.dispose();
    });

    test('completeTrainingObjective is inert before wings are earned', () {
      final notifier = AccountNotifier();
      notifier.completeTrainingObjective('adv_shop');
      expect(notifier.state.campaignProgress.containsKey('adv_shop'), isFalse);

      for (final id in basicTrainingMissionIds) {
        notifier.completeTrainingMission(id);
      }
      notifier.completeTrainingObjective('adv_shop');
      expect(notifier.state.campaignProgress.containsKey('adv_shop'), isTrue);

      // Idempotent: a second call keeps rewards unchanged.
      final coins = notifier.state.currentPlayer.coins;
      notifier.completeTrainingObjective('adv_shop');
      expect(notifier.state.currentPlayer.coins, equals(coins));
      notifier.dispose();
    });

    test('basicTrainingCompletedCount tracks the 0/3 → 3/3 indicator', () {
      final notifier = AccountNotifier();
      expect(notifier.state.basicTrainingCompletedCount, equals(0));
      notifier.completeTrainingMission(trainingReconMissionId);
      expect(notifier.state.basicTrainingCompletedCount, equals(1));
      notifier.completeTrainingMission(trainingFlightMissionId);
      notifier.completeTrainingMission(trainingBriefingMissionId);
      expect(notifier.state.basicTrainingCompletedCount, equals(3));
      notifier.dispose();
    });
  });

  group('Regional Flight School ladder is untouched', () {
    test('regional levels keep their existing level requirements', () {
      const expected = {
        'europe': 1,
        'australia': 3,
        'france': 4,
        'mexico': 5,
        'netherlands': 6,
        'us_states': 5,
        'africa': 7,
        'germany': 6,
        'spain': 8,
        'italy': 8,
        'asia': 9,
        'south_korea': 9,
        'poland': 10,
        'switzerland': 11,
        'austria': 12,
        'latin_america': 11,
        'japan': 12,
        'portugal': 13,
        'greece': 14,
        'brazil': 14,
        'uk_counties': 13,
        'ireland': 15,
        'canada': 17,
        'india': 16,
        'sweden': 15,
        'argentina': 16,
        'south_africa': 17,
        'new_zealand': 18,
        'indonesia': 19,
        'oceania': 19,
        'caribbean': 20,
      };
      final actual = {
        for (final level in flightSchoolLevels) level.id: level.requiredLevel,
      };
      expect(actual, equals(expected));
    });
  });
}
