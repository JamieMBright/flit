import 'consumables.dart';

/// Rare post-game supply drops.
///
/// Design (owner-approved):
/// - After a COMPLETED game in any mode, a strong performance has a small
///   chance (~[dropChanceBps] bps = 3%) to drop a random consumable.
/// - "Strong" = score >= [strongScoreFraction] of the mode's max score, or
///   a new personal best (each result screen knows its own max).
/// - The roll is DETERMINISTIC per (user, mode, date, score): replaying the
///   result screen or reopening the app can never re-roll the dice. Same
///   FNV-1a + Park-Miller-free approach as ShopRotation so VM and web agree.
abstract final class SupplyDrop {
  /// Drop chance in basis points (300 = 3%).
  static const int dropChanceBps = 300;

  /// Fraction of a mode's max score that counts as a strong performance.
  static const double strongScoreFraction = 0.6;

  /// Whether [score] out of [maxScore] qualifies as strong.
  static bool isStrong({required int score, required int maxScore}) {
    if (maxScore <= 0) return false;
    return score >= (maxScore * strongScoreFraction).round();
  }

  /// Roll for a drop. Returns the dropped consumable, or null.
  ///
  /// [strongPerformance] should be `isStrong(...) || newPersonalBest` —
  /// callers gate on their own mode's notion of max score / PB.
  /// [dateKey] is the UTC day (YYYY-MM-DD) so one (user, mode, date,
  /// score) tuple always yields the same outcome.
  static ConsumableType? roll({
    required String userId,
    required String mode,
    required String dateKey,
    required int score,
    required bool strongPerformance,
  }) {
    if (!strongPerformance) return null;
    if (userId.isEmpty) return null;
    final h = _fnv1a('$userId|$mode|$dateKey|$score');
    if (h % 10000 >= dropChanceBps) return null;
    // Independent bits pick the item so the item choice isn't correlated
    // with squeaking past the drop threshold.
    return ConsumableType.values[(h ~/ 10000) % ConsumableType.values.length];
  }

  /// Stable FNV-1a hash — identical on VM and dart2js (mirrors
  /// ShopRotation._fnv1a).
  static int _fnv1a(String input) {
    var hash = 0x811c9dc5;
    for (var i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }
}
