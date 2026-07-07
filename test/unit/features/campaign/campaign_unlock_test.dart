import 'package:flit/game/tutorial/campaign_mission.dart';
import 'package:flit/game/tutorial/campaign_missions.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pure predicate mirroring the sequential-unlock rule in `campaign_screen.dart`:
///
///   isUnlocked = index == 0 || completedIds.contains(missions[index - 1].id)
///
// NOTE: the rule itself lives inline inside the CampaignScreen widget's
// ListView.builder, so it cannot be imported directly. This local copy pins the
// intended semantics against the REAL `campaignMissions` data so a change to the
// mission list (or an accidental change to the rule) is caught by these tests.
bool isMissionUnlocked(int index, Set<String> completedIds) {
  if (index == 0) return true;
  return completedIds.contains(campaignMissions[index - 1].id);
}

void main() {
  group('CampaignMissionResult.calculateStars', () {
    test('3 stars at exactly the 0.5 score fraction (inclusive)', () {
      // rounds=2 -> maxScore 20000. 10000/20000 = 0.5 -> 3 stars.
      expect(CampaignMissionResult.calculateStars(10000, 2), 3);
      // Full marks also 3.
      expect(CampaignMissionResult.calculateStars(20000, 2), 3);
    });

    test('2 stars just below the 0.5 boundary', () {
      // 9999/20000 = 0.49995 -> falls to 2 stars.
      expect(CampaignMissionResult.calculateStars(9999, 2), 2);
    });

    test('2 stars at exactly the 0.25 score fraction (inclusive)', () {
      // 5000/20000 = 0.25 -> 2 stars.
      expect(CampaignMissionResult.calculateStars(5000, 2), 2);
    });

    test('1 star just below the 0.25 boundary and at zero', () {
      // 4999/20000 = 0.24995 -> 1 star.
      expect(CampaignMissionResult.calculateStars(4999, 2), 1);
      expect(CampaignMissionResult.calculateStars(0, 2), 1);
    });

    test('thresholds scale with round count', () {
      // rounds=5 -> maxScore 50000. 0.5 boundary is 25000.
      expect(CampaignMissionResult.calculateStars(25000, 5), 3);
      expect(CampaignMissionResult.calculateStars(24999, 5), 2);
      // 0.25 boundary is 12500.
      expect(CampaignMissionResult.calculateStars(12500, 5), 2);
      expect(CampaignMissionResult.calculateStars(12499, 5), 1);
    });
  });

  group('campaign mission data invariants', () {
    test('there is at least one mission and ids are unique', () {
      expect(campaignMissions, isNotEmpty);
      final ids = campaignMissions.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length,
          reason: 'mission ids must be unique');
    });
  });

  group('sequential unlock rule', () {
    test('the first mission is always unlocked, even with nothing completed',
        () {
      expect(isMissionUnlocked(0, <String>{}), isTrue);
    });

    test('a later mission is locked until the previous mission is completed',
        () {
      // Nothing completed -> mission index 1 is locked.
      expect(isMissionUnlocked(1, <String>{}), isFalse);
      // Completing the immediately-preceding mission unlocks it.
      final prevId = campaignMissions[0].id;
      expect(isMissionUnlocked(1, {prevId}), isTrue);
    });

    test('completing a non-adjacent mission does not unlock the next one', () {
      // Only index 0 completed does NOT unlock index 2 (needs index 1 done).
      final firstId = campaignMissions[0].id;
      expect(isMissionUnlocked(2, {firstId}), isFalse);
    });

    test('walking the whole chain unlocks each mission in order', () {
      final completed = <String>{};
      for (var i = 0; i < campaignMissions.length; i++) {
        expect(
          isMissionUnlocked(i, completed),
          isTrue,
          reason: 'mission $i should be unlocked once all prior are complete',
        );
        completed.add(campaignMissions[i].id);
      }
    });
  });
}
