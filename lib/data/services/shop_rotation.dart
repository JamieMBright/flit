import '../models/cosmetic.dart';
import '../models/rating_tier.dart';

/// One deal on the weekly deals board.
///
/// Every deal references an item that is ALSO available year-round in its
/// category tab at full price — the weekly board is a discount showcase, not
/// a gate. You never have to wait for the board to buy something; you come
/// back for the savings.
class ShopOffer {
  const ShopOffer({
    required this.cosmetic,
    this.discountPct = 0,
    this.requiredTier,
  });

  final Cosmetic cosmetic;

  /// Percentage discount (0-100) applied to the catalog price this week.
  final int discountPct;

  /// Rating tier required to buy (prestige gating), null = coins only.
  final RatingTier? requiredTier;

  /// Coin price after the weekly discount.
  int get price => (cosmetic.price * (100 - discountPct) / 100).round();

  /// Whether this is the week's headline deal (deepest discount).
  bool get isFeatured => discountPct >= ShopRotation.featuredDiscountPct;
}

/// Deterministic weekly DEALS board.
///
/// The board is seeded by the ISO-8601 week key (e.g. `2026-W27`) so every
/// player worldwide sees the same deals for the same week without a server
/// round-trip — the same trick daily modes use with date seeds
/// (see DailyChallenge.forDate). Uses a Park-Miller LCG rather than
/// `Random(seed)` so results are identical on VM and web.
///
/// Crucially, the board never gates AVAILABILITY: every item here is also
/// sold at full price in its category tab all week long. The board only
/// changes PRICE — a rotating mix of discounts (see [dealDiscounts]) with
/// one headline deal at the deepest [featuredDiscountPct]. This keeps the
/// "come back for deals" hook without turning the board into the only place
/// to buy (which would just make players wait for the item they want).
class ShopRotation {
  ShopRotation._();

  /// Deals on the board each week: 2 cheap, 2 mid, 2 prestige.
  static const int cheapSlots = 2;
  static const int midSlots = 2;
  static const int prestigeSlots = 2;

  /// Non-featured deals draw their discount from this mix (deterministic per
  /// slot). The headline deal uses the deeper [featuredDiscountPct].
  static const List<int> dealDiscounts = [15, 25];

  /// The week's single headline deal is discounted this deeply — the anchor
  /// that rewards the weekly visit. Deeper than any [dealDiscounts] tier.
  static const int featuredDiscountPct = 35;

  /// Price bands (coins).
  static const int cheapMax = 1000;
  static const int prestigeMin = 10000;

  /// Prestige cosmetics gated by BOTH rating tier and coins.
  ///
  /// Rated tiers come from the per-mode `player_ratings` (Standard Sortie
  /// rating). These items always require the tier, whether bought from the
  /// deals board or the prestige section — a deal only changes price, never
  /// the tier gate.
  static const Map<String, RatingTier> prestigeTierRequirements = {
    // The Ace-tier contrail: the game's flex item.
    'contrail_ace': RatingTier.ace,
    'contrail_aurora': RatingTier.platinumWings,
    'contrail_gold_dust': RatingTier.goldWings,
  };

  // ---------------------------------------------------------------------------
  // ISO week
  // ---------------------------------------------------------------------------

  /// ISO-8601 week key for [date] (UTC), e.g. `2026-W27`.
  ///
  /// ISO weeks start on Monday; week 1 is the week containing the year's
  /// first Thursday.
  static String isoWeekKey(DateTime date) {
    final utc =
        DateTime.utc(date.toUtc().year, date.toUtc().month, date.toUtc().day);
    // Thursday of this date's ISO week determines the ISO year.
    final thursday = utc.add(Duration(days: 4 - _isoWeekday(utc)));
    final isoYear = thursday.year;
    final firstThursday = _firstThursday(isoYear);
    final week = 1 + thursday.difference(firstThursday).inDays ~/ 7;
    return '$isoYear-W${week.toString().padLeft(2, '0')}';
  }

  /// UTC instant the current rotation ends (start of next ISO week, Monday
  /// 00:00 UTC).
  static DateTime rotationEnd(DateTime now) {
    final utc =
        DateTime.utc(now.toUtc().year, now.toUtc().month, now.toUtc().day);
    final daysToMonday = 8 - _isoWeekday(utc);
    return utc.add(Duration(days: daysToMonday == 8 ? 1 : daysToMonday));
  }

  static int _isoWeekday(DateTime d) => d.weekday; // Mon=1..Sun=7 already.

  static DateTime _firstThursday(int isoYear) {
    var d = DateTime.utc(isoYear, 1, 1);
    while (d.weekday != DateTime.thursday) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  // ---------------------------------------------------------------------------
  // Deals board
  // ---------------------------------------------------------------------------

  /// The deterministic weekly deals for the week containing [date].
  static List<ShopOffer> weeklyOffers(DateTime date) =>
      offersForWeek(isoWeekKey(date));

  /// Deals for an explicit week key (testable without clock control).
  ///
  /// Picks a stable weekly selection from the FULL catalog and puts every
  /// pick on a discount: one headline deal at [featuredDiscountPct] and the
  /// rest at a deterministic mix of [dealDiscounts]. Availability is never
  /// affected — the same items are always sold at full price in their
  /// category tabs.
  static List<ShopOffer> offersForWeek(String weekKey) {
    final pool = CosmeticCatalog.all
        .where((c) => c.price > 0) // Exclude free defaults.
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id)); // Stable base order.

    final cheap = pool.where((c) => c.price <= cheapMax).toList();
    final mid =
        pool.where((c) => c.price > cheapMax && c.price < prestigeMin).toList();
    final prestige = pool.where((c) => c.price >= prestigeMin).toList();

    final rng = _Lcg(_fnv1a(weekKey));
    final picks = <Cosmetic>[
      ..._pick(cheap, cheapSlots, rng),
      ..._pick(mid, midSlots, rng),
      ..._pick(prestige, prestigeSlots, rng),
    ];

    // Every deal is discounted; one headline slot gets the deepest cut.
    final featuredIndex = picks.isEmpty ? -1 : rng.nextInt(picks.length);

    return [
      for (var i = 0; i < picks.length; i++)
        ShopOffer(
          cosmetic: picks[i],
          discountPct: i == featuredIndex
              ? featuredDiscountPct
              : dealDiscounts[rng.nextInt(dealDiscounts.length)],
          requiredTier: prestigeTierRequirements[picks[i].id],
        ),
    ];
  }

  /// Draw [n] distinct items from [pool] using [rng] (partial
  /// Fisher-Yates). Returns fewer when the pool is smaller than [n].
  static List<Cosmetic> _pick(List<Cosmetic> pool, int n, _Lcg rng) {
    final copy = List<Cosmetic>.of(pool);
    final count = n < copy.length ? n : copy.length;
    for (var i = 0; i < count; i++) {
      final j = i + rng.nextInt(copy.length - i);
      final tmp = copy[i];
      copy[i] = copy[j];
      copy[j] = tmp;
    }
    return copy.sublist(0, count);
  }

  /// Stable FNV-1a hash — same value on VM and web (mirrors
  /// MatchmakingService._stableHash).
  static int _fnv1a(String input) {
    var hash = 0x811c9dc5;
    for (var i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash == 0 ? 1 : hash;
  }
}

/// Park-Miller minimal-standard LCG. All intermediate values stay well
/// below 2^53, so behaviour is identical on the Dart VM and dart2js.
class _Lcg {
  _Lcg(int seed) : _state = seed % 0x7FFFFFFF {
    if (_state <= 0) _state += 0x7FFFFFFE;
  }

  int _state;

  int _next() => _state = (_state * 48271) % 0x7FFFFFFF;

  /// Uniform int in [0, max).
  int nextInt(int max) => max <= 1 ? 0 : _next() % max;
}
