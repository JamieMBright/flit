import 'package:flit/data/models/social_title.dart';
import 'package:flutter_test/flutter_test.dart';

/// Title-unlock gating tests.
///
// NOTE: `TitleService` (lib/data/services/title_service.dart) is a thin wrapper
// that builds a `PlayerClueProgress` from an `AccountState` and delegates the
// actual gating to `PlayerTitles.earnedTitles` / `SocialTitleCatalog.checkEarned`
// and `_isUnlocked`, which share IDENTICAL threshold logic. Constructing a full
// `AccountState` pulls in Supabase-backed providers, so these tests target the
// pure gating layer that TitleService delegates to — the real unlock rules
// (per-category thresholds, strict `<` for speed, bestTime>0, equipped-title
// re-validation) live here and are fully exercised without a network seam.
void main() {
  SocialTitle titleById(String id) => SocialTitleCatalog.getById(id)!;

  bool earned(String id, PlayerClueProgress p) =>
      SocialTitleCatalog.checkEarned(p).any((t) => t.id == id);

  group('count-based threshold boundaries (>=)', () {
    test('flag title unlocks exactly at its threshold', () {
      expect(titleById('flag_spotter').threshold, 10);
      expect(earned('flag_spotter', const PlayerClueProgress(flagsCorrect: 9)),
          isFalse);
      expect(earned('flag_spotter', const PlayerClueProgress(flagsCorrect: 10)),
          isTrue);
    });

    test('a higher-tier flag title stays locked until its own threshold', () {
      // 50 flags earns the tier-1 and tier-2 titles but not the tier-3 (100).
      const p = PlayerClueProgress(flagsCorrect: 50);
      expect(earned('flag_spotter', p), isTrue);
      expect(earned('flag_enthusiast', p), isTrue);
      expect(earned('flag_novice_vexillologist', p), isFalse);
    });

    test('categories are independent — flags do not earn capital titles', () {
      const p = PlayerClueProgress(flagsCorrect: 1000);
      expect(earned('capital_tourist', p), isFalse);
    });

    test('streak titles use >= at their threshold', () {
      expect(
          earned('streak_hot_streak', const PlayerClueProgress(bestStreak: 4)),
          isFalse);
      expect(
          earned('streak_hot_streak', const PlayerClueProgress(bestStreak: 5)),
          isTrue);
    });
  });

  group('speed titles use strict < and require bestTime > 0', () {
    test('best time equal to the threshold does NOT unlock', () {
      // Speed Demon threshold is 60s; must be strictly under 60.
      expect(titleById('speed_speed_demon').threshold, 60);
      expect(
        earned(
            'speed_speed_demon', const PlayerClueProgress(bestTimeSeconds: 60)),
        isFalse,
      );
    });

    test('best time one second under the threshold unlocks', () {
      expect(
        earned(
            'speed_speed_demon', const PlayerClueProgress(bestTimeSeconds: 59)),
        isTrue,
      );
    });

    test('a bestTime of 0 (no time recorded) earns no speed title', () {
      // 0 < 60 numerically, but 0 means "unrecorded" and must not unlock.
      const p = PlayerClueProgress(bestTimeSeconds: 0);
      expect(earned('speed_speed_demon', p), isFalse);
      expect(earned('speed_sonic_pilot', p), isFalse);
      expect(earned('speed_light_speed', p), isFalse);
    });

    test('a fast time unlocks all speed tiers at or above it', () {
      // 14s beats 60 / 30 / 15 thresholds (all strict).
      const p = PlayerClueProgress(bestTimeSeconds: 14);
      expect(earned('speed_speed_demon', p), isTrue);
      expect(earned('speed_sonic_pilot', p), isTrue);
      expect(earned('speed_light_speed', p), isTrue);
    });
  });

  group('equipped-title re-validation when stats drop', () {
    test('an equipped title is valid while its threshold is met', () {
      const p = PlayerClueProgress(flagsCorrect: 10);
      const equipped = PlayerTitles(activeTitleId: 'flag_spotter');
      expect(equipped.isActiveTitleValid(p), isTrue);
    });

    test('the equipped title becomes invalid once the stat falls below', () {
      const dropped = PlayerClueProgress(flagsCorrect: 5);
      const equipped = PlayerTitles(activeTitleId: 'flag_spotter');
      expect(equipped.isActiveTitleValid(dropped), isFalse);
    });

    test('no equipped title is always valid', () {
      const none = PlayerTitles();
      expect(none.isActiveTitleValid(const PlayerClueProgress()), isTrue);
    });

    test(
        'an equipped speed title invalidates when time regresses past threshold',
        () {
      const equipped = PlayerTitles(activeTitleId: 'speed_speed_demon');
      expect(
        equipped
            .isActiveTitleValid(const PlayerClueProgress(bestTimeSeconds: 45)),
        isTrue,
      );
      // Time slips to exactly the threshold -> strict `<` fails -> invalid.
      expect(
        equipped
            .isActiveTitleValid(const PlayerClueProgress(bestTimeSeconds: 60)),
        isFalse,
      );
    });
  });
}
