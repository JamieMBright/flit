import 'package:flutter_test/flutter_test.dart';

import 'package:flit/data/models/avatar_config.dart';

void main() {
  group('Companion distinct stats', () {
    test('none grants no effect', () {
      expect(AvatarCompanion.none.stats.hasEffect, isFalse);
      expect(AvatarCompanion.none.stats.perkLabel, isNull);
    });

    test('every paid companion grants a distinct, labelled perk', () {
      final paid =
          AvatarCompanion.values.where((c) => c != AvatarCompanion.none);
      for (final c in paid) {
        expect(c.stats.hasEffect, isTrue, reason: '$c should have an effect');
        expect(c.stats.perkLabel, isNotNull, reason: '$c needs a perk label');
        // Each companion emphasises exactly ONE stat.
        final s = c.stats;
        final active = [
          s.coinBonus != 1.0,
          s.speed != 1.0,
          s.handling != 1.0,
          s.fuelEfficiency != 1.0,
          s.clueChanceBonus != 0,
        ].where((x) => x).length;
        expect(active, 1, reason: '$c should alter exactly one stat');
      }
    });

    test('companions emphasise different stats (not all the same)', () {
      // The old design had every companion do the same thing; the new one
      // spreads across coin / speed / handling / fuel / clue.
      expect(AvatarCompanion.pidgey.stats.fuelEfficiency, greaterThan(1.0));
      expect(AvatarCompanion.sparrow.stats.speed, greaterThan(1.0));
      expect(AvatarCompanion.eagle.stats.clueChanceBonus, greaterThan(0));
      expect(AvatarCompanion.parrot.stats.coinBonus, greaterThan(1.0));
      expect(AvatarCompanion.phoenix.stats.handling, greaterThan(1.0));
      expect(AvatarCompanion.dragon.stats.speed, greaterThan(1.0));
      expect(AvatarCompanion.charizard.stats.coinBonus, greaterThan(1.0));
    });

    test('effects scale with rarity — Charizard is the strongest', () {
      // Charizard (75k legendary) is the strongest coin earner.
      expect(
        AvatarCompanion.charizard.stats.coinBonus,
        greaterThan(AvatarCompanion.parrot.stats.coinBonus),
      );
      // Dragon (30k legendary) out-speeds the cheap Sparrow.
      expect(
        AvatarCompanion.dragon.stats.speed,
        greaterThan(AvatarCompanion.sparrow.stats.speed),
      );
    });

    test('perkLabel reads as an item stat, not the old fuel text', () {
      expect(AvatarCompanion.charizard.stats.perkLabel, '+15% coins');
      expect(AvatarCompanion.eagle.stats.perkLabel, '+6% clue chance');
      expect(AvatarCompanion.pidgey.stats.perkLabel, '+4% fuel economy');
    });

    test('companionFromCosmeticId resolves shop ids', () {
      expect(companionFromCosmeticId('companion_eagle'), AvatarCompanion.eagle);
      expect(companionFromCosmeticId('companion_none'), AvatarCompanion.none);
      expect(companionFromCosmeticId('garbage'), AvatarCompanion.none);
    });
  });
}
