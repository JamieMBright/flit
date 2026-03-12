import 'dart:math';

import 'package:flame/components.dart';

import '../../core/services/game_settings.dart';
import '../clues/clue_types.dart';
import '../data/country_difficulty.dart';
import '../map/country_data.dart';
import '../map/region.dart';

/// Represents a single game session (one round of play).
class GameSession {
  GameSession({
    required this.targetCountry,
    required this.clue,
    required this.startPosition,
    this.region = GameRegion.world,
    this.targetArea,
  }) : startTime = DateTime.now();

  final CountryShape targetCountry;
  final Clue clue;
  final Vector2 startPosition;
  final DateTime startTime;
  final GameRegion region;
  final RegionalArea? targetArea;

  DateTime? endTime;
  bool _completed = false;
  List<Vector2> flightPath = [];

  /// Hints used when this round was completed (set by [complete]).
  int _hintsUsed = 0;

  /// Fuel fraction (0.0–1.0) when this round was completed (set by [complete]).
  double _fuelFraction = 1.0;

  /// Whether this session uses time-based scoring instead of fuel-based.
  /// When true, points decrease linearly from max at ≤10s to minimum at ≥60s.
  bool _useTimeScoring = false;

  /// Whether the session is complete
  bool get isCompleted => _completed;

  /// Time taken to complete (or current elapsed time)
  Duration get elapsed => (endTime ?? DateTime.now()).difference(startTime);

  /// Per-tier hint penalties (non-linear, escalating).
  ///
  /// Tier 1 (new clue)      →  −500
  /// Tier 2 (reveal country) →  −1,000
  /// Tier 3 (wayline)        →  −1,500
  /// Tier 4 (auto-navigate)  →  −2,500
  /// Exposed publicly so the HUD can display the penalty for each tier
  /// without duplicating the list.
  static const List<int> hintTierPenalties = [500, 1000, 1500, 2500];

  /// Time penalty for time-based scoring.
  ///
  /// ≤10 seconds → 0 penalty (full points)
  /// ≥60 seconds → 5,000 penalty (minimum points)
  /// Linear interpolation between 10s and 60s.
  int get timePenalty {
    if (!_completed || !_useTimeScoring) return 0;
    final seconds = elapsed.inMilliseconds / 1000.0;
    if (seconds <= 10) return 0;
    if (seconds >= 60) return 5000;
    // Linear from 0 at 10s to 5000 at 60s
    return ((seconds - 10) / 50.0 * 5000).round();
  }

  /// Fuel bonus awarded for remaining fuel (0–5,000 points).
  ///
  /// 100% fuel → +5,000 bonus (perfect fuel management)
  /// 0% fuel   → +0 bonus (ran out of fuel)
  int get fuelBonus => (_fuelFraction * 5000).round();

  /// Raw score before difficulty multiplier (base + fuel bonus − penalties).
  ///
  /// Formula:
  ///   base      = 5,000 per round
  ///   fuelBonus = +up to 5,000 (remaining fuel × 5,000)
  ///   hints     = non-linear escalating penalty per tier (see [hintTierPenalties])
  ///               (0 hints = 0, all 4 = −5,500)
  ///   time      = −up to 5,000 (only in time-scoring mode, e.g. daily challenge)
  ///
  /// Result is clamped to [0, 10000].
  int get rawScore {
    if (!_completed) return 0;
    const int base = 5000;
    int hintPenalty = 0;
    for (int i = 0; i < _hintsUsed && i < hintTierPenalties.length; i++) {
      hintPenalty += hintTierPenalties[i];
    }
    final int timeDeduction = _useTimeScoring ? timePenalty : 0;
    return max(0, base + fuelBonus - hintPenalty - timeDeduction);
  }

  /// Final score for this round, with difficulty multiplier applied.
  ///
  /// Harder countries yield higher scores: `rawScore × difficultyMultiplier`.
  /// The multiplier is `0.5 + 0.5 × countryDifficulty` — easy countries
  /// (e.g. Brazil 0.06) halve the score while obscure ones (e.g. Jersey 0.83)
  /// preserve nearly all of it.
  int get score {
    final raw = rawScore;
    if (raw == 0) return 0;
    final multiplier = difficultyMultiplier(targetCountry.code);
    return (raw * multiplier).round().clamp(0, 10000);
  }

  /// Mark the session as completed.
  ///
  /// [hintsUsed] — number of hint tiers used this round (0–4).
  /// [fuelFraction] — fuel remaining as a fraction of max (0.0–1.0).
  /// [useTimeScoring] — when true, uses elapsed time instead of fuel for
  ///   the resource penalty (≤10s = 0, ≥60s = −5,000).
  void complete({
    int hintsUsed = 0,
    double fuelFraction = 1.0,
    bool useTimeScoring = false,
  }) {
    if (!_completed) {
      _completed = true;
      _hintsUsed = hintsUsed;
      _fuelFraction = fuelFraction.clamp(0.0, 1.0);
      _useTimeScoring = useTimeScoring;
      endTime = DateTime.now();
    }
  }

  /// Record a position in the flight path
  void recordPosition(Vector2 position) {
    flightPath.add(position.clone());
  }

  /// Get the target position (capital city or center of area)
  Vector2 get targetPosition {
    // If we have a regional area, use its center
    if (targetArea != null && targetArea!.points.isNotEmpty) {
      var sumX = 0.0;
      var sumY = 0.0;
      for (final point in targetArea!.points) {
        sumX += point.x;
        sumY += point.y;
      }
      return Vector2(
        sumX / targetArea!.points.length,
        sumY / targetArea!.points.length,
      );
    }

    // For world region, use capital city if available
    final capital = CountryData.getCapital(targetCountry.code);
    if (capital != null) {
      return capital.location;
    }
    // Fall back to center of country bounds
    final pts = targetCountry.allPoints;
    if (pts.isEmpty) return Vector2.zero();
    var sumX = 0.0;
    var sumY = 0.0;
    for (final point in pts) {
      sumX += point.x;
      sumY += point.y;
    }
    return Vector2(sumX / pts.length, sumY / pts.length);
  }

  /// Get the target name for display
  String get targetName => targetArea?.name ?? targetCountry.name;

  /// Combined difficulty of this round (0.0–1.0).
  ///
  /// Combines the clue type weight with the country recognisability rating.
  double get roundDifficultyScore =>
      roundDifficulty(clue.type, targetCountry.code);

  /// Countries filtered by difficulty tier for free-flight mode.
  ///
  /// [GameDifficulty.easy]   → countries with rating ≤ [easyThreshold]
  /// [GameDifficulty.normal] → all playable countries
  /// [GameDifficulty.hard]   → countries with rating ≥ [hardMinimum]
  static List<CountryShape> _countriesForDifficulty(GameDifficulty diff) {
    switch (diff) {
      case GameDifficulty.easy:
        return CountryData.playableCountries
            .where((c) => countryDifficultyRating(c.code) <= easyThreshold)
            .toList();
      case GameDifficulty.normal:
        return CountryData.playableCountries;
      case GameDifficulty.hard:
        return CountryData.playableCountries
            .where((c) => countryDifficultyRating(c.code) >= hardMinimum)
            .toList();
    }
  }

  /// Create a new random game session.
  ///
  /// When [allowedClueTypes] is provided (e.g. from a daily challenge
  /// theme), only those clue types will be generated.
  ///
  /// When [preferredClueType] is provided, the generated clue will favour
  /// the preferred type within the allowed set.
  ///
  /// When [difficulty] is provided, the country pool is filtered to match
  /// the selected tier. Defaults to the current [GameSettings] difficulty.
  factory GameSession.random({
    GameRegion region = GameRegion.world,
    String? preferredClueType,
    Set<String>? allowedClueTypes,
    GameDifficulty? difficulty,
  }) {
    final random = Random();

    if (region == GameRegion.world) {
      // Filter country pool by difficulty tier
      final diff = difficulty ?? GameSettings.instance.difficulty;
      final pool = _countriesForDifficulty(diff);
      final country = pool[random.nextInt(pool.length)];

      final clue = Clue.random(
        country.code,
        preferredClueType: preferredClueType,
        allowedTypes: allowedClueTypes,
      );

      // Generate random start position (not too close to target)
      final startLng = (random.nextDouble() * 360) - 180;
      final startLat = (random.nextDouble() * 140) - 70;

      return GameSession(
        targetCountry: country,
        clue: clue,
        startPosition: Vector2(startLng, startLat),
        region: region,
      );
    } else {
      // Regional mode: pick a random area from the region
      final areas = RegionalData.getAreas(region);
      final area = areas[random.nextInt(areas.length)];

      // Create a clue for the regional area (with region for rich data)
      final clue = Clue.regionalArea(area, region: region);

      // Generate start position within region bounds
      final bounds = region.bounds;
      final startLng =
          bounds[0] + random.nextDouble() * (bounds[2] - bounds[0]);
      final startLat =
          bounds[1] + random.nextDouble() * (bounds[3] - bounds[1]);

      // Create a placeholder country shape from the regional area
      final country = CountryShape(
        code: area.code,
        name: area.name,
        polygons: area.polygons ?? [area.points],
        capital: area.capital,
      );

      return GameSession(
        targetCountry: country,
        clue: clue,
        startPosition: Vector2(startLng, startLat),
        region: region,
        targetArea: area,
      );
    }
  }

  /// Create a seeded game session (for challenges and daily challenges).
  ///
  /// Uses a deterministic [Random] so all players with the same seed get the
  /// same country and start position. Supports the same clue-type filtering
  /// as [GameSession.random].
  ///
  /// When [maxDifficulty] is provided (e.g. from a campaign mission), the
  /// country pool is filtered to only include countries at or below that
  /// difficulty rating. When [targetCountryCodes] is provided, the pool is
  /// restricted to those specific country codes.
  factory GameSession.seeded(
    int seed, {
    String? preferredClueType,
    Set<String>? allowedClueTypes,
    double? maxDifficulty,
    List<String>? targetCountryCodes,
  }) {
    final random = Random(seed);

    // Build country pool, optionally filtered by difficulty or target codes.
    List<CountryShape> pool;
    if (targetCountryCodes != null && targetCountryCodes.isNotEmpty) {
      final codeSet = targetCountryCodes.toSet();
      pool = CountryData.playableCountries
          .where((c) => codeSet.contains(c.code))
          .toList();
    } else if (maxDifficulty != null) {
      pool = CountryData.playableCountries
          .where((c) => countryDifficultyRating(c.code) <= maxDifficulty)
          .toList();
    } else {
      pool = CountryData.playableCountries;
    }

    // Fallback to full pool if filtering yields nothing (shouldn't happen
    // with valid data, but avoids a crash).
    if (pool.isEmpty) {
      pool = CountryData.playableCountries;
    }

    // Pick country based on seed
    final countryIndex = random.nextInt(pool.length);
    final country = pool[countryIndex];

    // Use Clue.random() with the seeded Random so clue type selection is
    // deterministic — both challenge players get the same clue type.
    final clue = Clue.random(
      country.code,
      preferredClueType: preferredClueType,
      allowedTypes: allowedClueTypes,
      random: random,
    );

    // Generate start position based on seed
    final startLng = (random.nextDouble() * 360) - 180;
    final startLat = (random.nextDouble() * 140) - 70;

    return GameSession(
      targetCountry: country,
      clue: clue,
      startPosition: Vector2(startLng, startLat),
    );
  }
}
