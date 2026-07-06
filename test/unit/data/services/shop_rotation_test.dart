import 'package:flutter_test/flutter_test.dart';

import 'package:flit/data/models/cosmetic.dart';
import 'package:flit/data/models/rating_tier.dart';
import 'package:flit/data/services/shop_rotation.dart';

void main() {
  group('isoWeekKey', () {
    test('known ISO week fixtures', () {
      // 2026-07-05 is a Sunday in ISO week 27 of 2026.
      expect(ShopRotation.isoWeekKey(DateTime.utc(2026, 7, 5)), '2026-W27');
      // Monday 2026-07-06 starts week 28.
      expect(ShopRotation.isoWeekKey(DateTime.utc(2026, 7, 6)), '2026-W28');
      // Jan 1 2027 is a Friday — still week 53 of 2026.
      expect(ShopRotation.isoWeekKey(DateTime.utc(2027, 1, 1)), '2026-W53');
      // Jan 4 is always in week 1.
      expect(ShopRotation.isoWeekKey(DateTime.utc(2027, 1, 4)), '2027-W01');
      // 2026-01-01 (Thursday) is week 1 of 2026.
      expect(ShopRotation.isoWeekKey(DateTime.utc(2026, 1, 1)), '2026-W01');
    });

    test('every day of one ISO week shares the key', () {
      // Week of Monday 2026-06-29 .. Sunday 2026-07-05.
      for (var d = 29; d <= 30; d++) {
        expect(ShopRotation.isoWeekKey(DateTime.utc(2026, 6, d)), '2026-W27');
      }
      for (var d = 1; d <= 5; d++) {
        expect(ShopRotation.isoWeekKey(DateTime.utc(2026, 7, d)), '2026-W27');
      }
    });

    test('rotationEnd is the next Monday 00:00 UTC', () {
      expect(
        ShopRotation.rotationEnd(DateTime.utc(2026, 7, 5, 18)),
        DateTime.utc(2026, 7, 6),
      );
      expect(
        ShopRotation.rotationEnd(DateTime.utc(2026, 7, 6, 0, 1)),
        DateTime.utc(2026, 7, 13),
      );
    });
  });

  group('weekly rotation determinism', () {
    test('same week key always yields the same offers', () {
      final a = ShopRotation.offersForWeek('2026-W27');
      final b = ShopRotation.offersForWeek('2026-W27');
      expect(
        a.map((o) => o.cosmetic.id).toList(),
        b.map((o) => o.cosmetic.id).toList(),
      );
      expect(
        a.map((o) => o.discountPct).toList(),
        b.map((o) => o.discountPct).toList(),
      );
    });

    test('any two days of the same week agree', () {
      final sunday = ShopRotation.weeklyOffers(DateTime.utc(2026, 7, 5));
      final monday = ShopRotation.weeklyOffers(DateTime.utc(2026, 6, 29));
      expect(
        sunday.map((o) => o.cosmetic.id).toList(),
        monday.map((o) => o.cosmetic.id).toList(),
      );
    });

    test('different weeks differ (rotation actually rotates)', () {
      final keys = List.generate(8, (i) => '2026-W${20 + i}');
      final lineups = keys
          .map((k) =>
              ShopRotation.offersForWeek(k).map((o) => o.cosmetic.id).join(','))
          .toSet();
      expect(lineups.length, greaterThan(1));
    });
  });

  group('rotation composition', () {
    final offers = ShopRotation.offersForWeek('2026-W27');

    test('mixes cheap and prestige slots', () {
      final cheap =
          offers.where((o) => o.cosmetic.price <= ShopRotation.cheapMax).length;
      final prestige = offers
          .where((o) => o.cosmetic.price >= ShopRotation.prestigeMin)
          .length;
      expect(cheap, ShopRotation.cheapSlots);
      expect(prestige, ShopRotation.prestigeSlots);
      expect(
        offers.length,
        ShopRotation.cheapSlots +
            ShopRotation.midSlots +
            ShopRotation.prestigeSlots,
      );
    });

    test('never offers free default items', () {
      expect(offers.any((o) => o.cosmetic.price == 0), isFalse);
    });

    test('no duplicate items in one week', () {
      final ids = offers.map((o) => o.cosmetic.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every deal is discounted below full price', () {
      // The board is deals-only: no full-price slots (that would just make it
      // a shop). Every item is cheaper than its catalog price.
      for (final o in offers) {
        expect(o.discountPct, greaterThan(0));
        expect(o.price, lessThan(o.cosmetic.price));
      }
    });

    test('exactly one headline deal at the deepest discount', () {
      final featured = offers.where((o) => o.isFeatured).toList();
      expect(featured.length, 1);
      expect(featured.single.discountPct, ShopRotation.featuredDiscountPct);
      // No non-featured deal ever cuts as deep as the headline.
      for (final o in offers.where((o) => !o.isFeatured)) {
        expect(o.discountPct, lessThan(ShopRotation.featuredDiscountPct));
        expect(ShopRotation.dealDiscounts, contains(o.discountPct));
      }
    });

    test('discounted price = round(catalog * (100 - pct) / 100)', () {
      for (final o in offers) {
        final expected =
            (o.cosmetic.price * (100 - o.discountPct) / 100).round();
        expect(o.price, expected);
      }
    });
  });

  group('deals never gate availability', () {
    test('every deal item also exists in the permanent catalog', () {
      // No rotation-exclusive items: a deal only ever references a cosmetic
      // that is sold year-round at full price in its category tab. Scan a
      // full year of weeks.
      for (var w = 1; w <= 53; w++) {
        final offers =
            ShopRotation.offersForWeek('2026-W${w.toString().padLeft(2, '0')}');
        for (final o in offers) {
          final permanent = CosmeticCatalog.getById(o.cosmetic.id);
          expect(
            permanent,
            isNotNull,
            reason: '${o.cosmetic.id} must be buyable outside the deals board',
          );
          // The permanent listing is the FULL price the deal discounts from.
          expect(permanent!.price, o.cosmetic.price);
          expect(o.price, lessThanOrEqualTo(permanent.price));
        }
      }
    });

    test('the full purchasable catalog is never rotation-locked', () {
      // The category tabs render CosmeticCatalog.planes/contrails/companions
      // directly, so every non-free cosmetic is always available regardless
      // of which few items happen to be discounted this week.
      final purchasable =
          CosmeticCatalog.all.where((c) => c.price > 0).toList();
      expect(purchasable, isNotEmpty);
      final thisWeek = ShopRotation.offersForWeek('2026-W27')
          .map((o) => o.cosmetic.id)
          .toSet();
      // Most of the catalog is NOT on this week's board, yet all of it is
      // still purchasable from its category tab.
      final offBoard =
          purchasable.where((c) => !thisWeek.contains(c.id)).toList();
      expect(offBoard.length, greaterThan(thisWeek.length));
      for (final c in offBoard) {
        expect(CosmeticCatalog.getById(c.id), isNotNull);
      }
    });
  });

  group('prestige tier gating', () {
    test('the Ace contrail exists and is Ace-gated', () {
      final ace = CosmeticCatalog.getById('contrail_ace');
      expect(ace, isNotNull);
      expect(
        ShopRotation.prestigeTierRequirements['contrail_ace'],
        RatingTier.ace,
      );
      // Gated by BOTH tier and coins.
      expect(ace!.price, greaterThan(0));
    });

    test('rotation offers carry the tier requirement', () {
      // Find a week where a tier-gated item rotates in (deterministic scan).
      for (var w = 1; w <= 53; w++) {
        final offers =
            ShopRotation.offersForWeek('2026-W${w.toString().padLeft(2, '0')}');
        for (final o in offers) {
          final required = ShopRotation.prestigeTierRequirements[o.cosmetic.id];
          expect(o.requiredTier, required);
        }
      }
    });
  });
}
