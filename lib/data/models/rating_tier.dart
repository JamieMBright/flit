import 'package:flutter/material.dart';

/// Aviation-themed rating tiers for rated play (Standard Sortie, H2H).
///
/// Tiers map a per-mode Elo rating (see `player_ratings` +
/// supabase/migrations/20260705_player_ratings.sql) onto display bands.
/// Cold-start ratings land around 1050 (level 1), so brand-new players
/// begin at Bronze Wings and climb from there.
enum RatingTier {
  bronzeWings('Bronze Wings', 0),
  silverWings('Silver Wings', 1100),
  goldWings('Gold Wings', 1300),
  platinumWings('Platinum Wings', 1500),
  ace('Ace', 1750);

  const RatingTier(this.displayName, this.minRating);

  /// Human-readable tier name shown on profiles/leaderboards.
  final String displayName;

  /// Minimum rating (inclusive) for this tier.
  final int minRating;

  /// The tier for a given rating. Ratings below Silver's floor are Bronze.
  static RatingTier fromRating(int rating) {
    for (var i = RatingTier.values.length - 1; i >= 0; i--) {
      if (rating >= RatingTier.values[i].minRating) {
        return RatingTier.values[i];
      }
    }
    return RatingTier.bronzeWings;
  }

  /// The next tier up, or null when already at [ace].
  RatingTier? get next {
    final i = index + 1;
    return i < RatingTier.values.length ? RatingTier.values[i] : null;
  }

  /// Rating points needed to reach the next tier (0 at [ace]).
  int pointsToNext(int rating) {
    final n = next;
    if (n == null) return 0;
    final gap = n.minRating - rating;
    return gap > 0 ? gap : 0;
  }

  /// Primary chip/badge colour for this tier.
  Color get color {
    switch (this) {
      case RatingTier.bronzeWings:
        return const Color(0xFFB08D57);
      case RatingTier.silverWings:
        return const Color(0xFFA8B2BD);
      case RatingTier.goldWings:
        return const Color(0xFFD4A93C);
      case RatingTier.platinumWings:
        return const Color(0xFF7FD1CE);
      case RatingTier.ace:
        return const Color(0xFFE0524D);
    }
  }

  /// Short emblem shown inside compact chips.
  String get emblem {
    switch (this) {
      case RatingTier.bronzeWings:
        return '✈'; // airplane
      case RatingTier.silverWings:
        return '✈';
      case RatingTier.goldWings:
        return '✈';
      case RatingTier.platinumWings:
        return '✈';
      case RatingTier.ace:
        return '★'; // star
    }
  }
}
