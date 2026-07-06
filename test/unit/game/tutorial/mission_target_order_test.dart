import 'package:flutter_test/flutter_test.dart';

import 'package:flit/game/session/game_session.dart';
import 'package:flit/game/tutorial/campaign_mission.dart';
import 'package:flit/game/tutorial/campaign_missions.dart';
import 'package:flit/game/tutorial/training_missions.dart';

/// Regression tests for the "coach narrates Paris while the clue says Madrid"
/// bug: campaign missions with an ordered `targetCountryCodes` list must
/// present those countries strictly in order, one per round, so the on-screen
/// clue always matches the coach's scripted narration.
void main() {
  group('CampaignMission.targetCodeForRound', () {
    test('returns codes in array order, one per round', () {
      expect(trainingFlightMission.targetCodeForRound(1), 'FR');
      expect(trainingFlightMission.targetCodeForRound(2), 'ES');
    });

    test('wraps when there are more rounds than codes', () {
      // Two codes, so round 3 wraps back to codes[0].
      expect(trainingFlightMission.targetCodeForRound(3), 'FR');
      expect(trainingFlightMission.targetCodeForRound(4), 'ES');
    });

    test('handles single-target missions', () {
      expect(advancedHintSchoolMission.targetCodeForRound(1), 'MA');
      // A single code means every round targets it.
      expect(advancedHintSchoolMission.targetCodeForRound(2), 'MA');
    });

    test('returns null when the mission has no ordered targets', () {
      const mission = CampaignMission(
        id: 'no_targets',
        order: 99,
        title: 'x',
        subtitle: 'x',
        description: 'x',
        coach: trainingCoachTata,
        allowedClues: {},
      );
      expect(mission.targetCodeForRound(1), isNull);
    });
  });

  group('Ordered targets drive a deterministic session per round', () {
    // Mirrors PlayScreen._createSession: campaign rounds pass a single-element
    // targetCountryCodes list derived from targetCodeForRound, so the seeded
    // session's pool is exactly that one country.
    GameSession sessionForRound(CampaignMission mission, int round) {
      final baseSeed = mission.id.hashCode;
      final roundSeed = baseSeed + (round - 1) * 7919;
      final roundCode = mission.targetCodeForRound(round);
      return GameSession.seeded(
        roundSeed,
        allowedClueTypes: mission.allowedClues.isEmpty
            ? null
            : mission.allowedClues.map((c) => c.name).toSet(),
        maxDifficulty: mission.maxDifficulty,
        targetCountryCodes: roundCode != null ? [roundCode] : null,
      );
    }

    test('Training Flight targets France on round 1, Spain on round 2', () {
      expect(
          sessionForRound(trainingFlightMission, 1).targetCountry.code, 'FR');
      expect(
          sessionForRound(trainingFlightMission, 2).targetCountry.code, 'ES');
    });

    test('Fuel Run targets Iceland on round 1, Ireland on round 2', () {
      expect(
          sessionForRound(advancedFuelRunMission, 1).targetCountry.code, 'IS');
      expect(
          sessionForRound(advancedFuelRunMission, 2).targetCountry.code, 'IE');
    });

    test('Hint School targets Morocco on its single round', () {
      expect(sessionForRound(advancedHintSchoolMission, 1).targetCountry.code,
          'MA');
    });

    test('multi-round campaign missions target codes in array order', () {
      for (final mission in campaignMissions) {
        final codes = mission.targetCountryCodes;
        if (codes == null || codes.length < 2) continue;
        for (var round = 1; round <= mission.rounds; round++) {
          final expected = codes[(round - 1) % codes.length];
          expect(
            sessionForRound(mission, round).targetCountry.code,
            expected,
            reason: '${mission.id} round $round should target $expected',
          );
        }
      }
    });
  });
}
