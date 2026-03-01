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
  static const List<int> _hintTierPenalties = [500, 1000, 1500, 2500];

  /// Raw score before difficulty multiplier (base − penalties).
  ///
  /// Formula:
  ///   base     = 10,000 per round
  ///   hints    = non-linear escalating penalty per tier (see [_hintTierPenalties])
  ///             (0 hints = 0, all 4 = −5,500)
  ///   fuel     = −up to 5,000 scaled linearly by fuel burned
  ///             (100% fuel remaining = 0 penalty, 0% = −5,000)
  ///
  /// Result is clamped to [0, 10000].
  int get rawScore {
    if (!_completed) return 0;
    const int base = 10000;
    int hintPenalty = 0;
    for (int i = 0; i < _hintsUsed && i < _hintTierPenalties.length; i++) {
      hintPenalty += _hintTierPenalties[i];
    }
    final int fuelPenalty = ((1.0 - _fuelFraction) * 5000).round();
    return max(0, base - hintPenalty - fuelPenalty);
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
  void complete({int hintsUsed = 0, double fuelFraction = 1.0}) {
    if (!_completed) {
      _completed = true;
      _hintsUsed = hintsUsed;
      _fuelFraction = fuelFraction.clamp(0.0, 1.0);
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
    if (targetArea != null) {
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
        polygons: [area.points],
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
  factory GameSession.seeded(
    int seed, {
    String? preferredClueType,
    Set<String>? allowedClueTypes,
  }) {
    final random = Random(seed);

    // Pick country based on seed (from playable pool, excluding obscure territories)
    final countryIndex = random.nextInt(CountryData.playableCountries.length);
    final country = CountryData.playableCountries[countryIndex];

    // Use Clue.random() with the same filters as random mode
    final clue = Clue.random(
      country.code,
      preferredClueType: preferredClueType,
      allowedTypes: allowedClueTypes,
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
