import 'package:flutter/material.dart';

import '../../data/models/rating_tier.dart';
import '../theme/flit_colors.dart';

/// Compact tier chip for rated play (Standard Sortie / H2H).
///
/// Shows the aviation tier name ("Gold Wings", "Ace", ...) with the tier
/// colour, optionally with the numeric rating. Used on the menu, sortie
/// screen, profile, and leaderboard rows — pass [compact] for tight rows.
class RatingTierChip extends StatelessWidget {
  const RatingTierChip({
    super.key,
    required this.rating,
    this.provisional = false,
    this.showRating = true,
    this.compact = false,
  });

  /// The per-mode Elo rating to display.
  final int rating;

  /// Whether the rating is an estimate (no rated games yet).
  final bool provisional;

  /// Whether to append the numeric rating after the tier name.
  final bool showRating;

  /// Tighter paddings/fonts for leaderboard rows.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tier = RatingTier.fromRating(rating);
    final fontSize = compact ? 10.0 : 12.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: tier.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tier.color.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tier.emblem,
            style: TextStyle(color: tier.color, fontSize: fontSize),
          ),
          SizedBox(width: compact ? 3 : 5),
          Flexible(
            child: Text(
              showRating
                  ? '${tier.displayName} · ${provisional ? '~' : ''}$rating'
                  : tier.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: FlitColors.textPrimary,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
