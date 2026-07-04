import 'dart:math';

import 'package:flame/components.dart';

import '../../core/services/game_settings.dart';
import '../../core/utils/math_utils.dart';
import '../clues/clue_types.dart';
import '../data/country_difficulty.dart';
import '../map/country_data.dart';

/// Label types that can accompany a clue marker on the compass.
enum TriLabel { country, capital, leader, language }

/// Display metadata for a [TriLabel].
extension TriLabelMeta on TriLabel {
  String get displayName {
    switch (this) {
      case TriLabel.country:
        return 'Country';
      case TriLabel.capital:
        return 'Capital';
      case TriLabel.leader:
        return 'Leader';
      case TriLabel.language:
        return 'Language';
    }
  }
}

/// A known location shown on the compass, with the true bearing from the
/// hidden target's capital to this location's capital.
class TriangulationClue {
  const TriangulationClue({
    required this.countryCode,
    required this.countryName,
    required this.capitalName,
    required this.capitalLngLat,
    required this.bearingFromTargetDeg,
    required this.distanceFromTargetKm,
  });

  final String countryCode;
  final String countryName;
  final String capitalName;

  /// Capital coordinates as (lng, lat) degrees.
  final Vector2 capitalLngLat;

  /// Compass bearing (0 = N, clockwise) from the hidden target's capital
  /// to this clue's capital.
  final double bearingFromTargetDeg;

  /// Great-circle distance from the hidden target's capital, in km.
  final double distanceFromTargetKm;

  /// Label text for a given label type; null when data is unavailable.
  String? labelText(TriLabel label) {
    switch (label) {
      case TriLabel.country:
        return countryName;
      case TriLabel.capital:
        return capitalName;
      case TriLabel.leader:
        final v = Clue.getAllCountryStats(countryCode)['headOfState'];
        return (v == null || v.isEmpty) ? null : v;
      case TriLabel.language:
        final v = Clue.getAllCountryStats(countryCode)['language'];
        return (v == null || v.isEmpty) ? null : v;
    }
  }
}

/// One hidden target plus its starting clue markers, generated
/// deterministically from a seed.
class TriangulationRound {
  TriangulationRound({
    required this.targetCountryCode,
    required this.targetCountryName,
    required this.targetCapitalName,
    required this.targetCapitalLngLat,
    required this.clues,
  });

  final String targetCountryCode;
  final String targetCountryName;
  final String targetCapitalName;

  /// Target capital coordinates as (lng, lat) degrees.
  final Vector2 targetCapitalLngLat;

  /// Starting clue markers (same for every player on a daily seed).
  final List<TriangulationClue> clues;

  /// Countries eligible as targets or clue anchors: playable, with a
  /// capital that has coordinates.
  static List<CountryShape> _eligibleCountries() =>
      CountryData.playableCountries
          .where((c) => CountryData.getCapital(c.code) != null)
          .toList();

  /// Target pool for a difficulty, mirroring the free-flight thresholds
  /// in game_session.dart.
  static List<CountryShape> _targetPool(GameDifficulty difficulty) {
    final all = _eligibleCountries();
    switch (difficulty) {
      case GameDifficulty.easy:
        return all
            .where((c) => countryDifficultyRating(c.code) <= easyThreshold)
            .toList();
      case GameDifficulty.normal:
        return all
            .where((c) => countryDifficultyRating(c.code) <= normalThreshold)
            .toList();
      case GameDifficulty.hard:
        return all
            .where((c) => countryDifficultyRating(c.code) >= hardMinimum)
            .toList();
    }
  }

  /// Generates a round from [seed]. Same seed → same target and clues.
  ///
  /// [requireStats] filters clue anchors to countries with leader/language
  /// stats so enabled labels always have text. [excludedTargetCodes] prevents
  /// target repeats across a multi-round game.
  factory TriangulationRound.generate({
    required int seed,
    required GameDifficulty difficulty,
    int markerCount = 5,
    bool requireStats = false,
    Set<String> excludedTargetCodes = const {},
  }) {
    final rng = Random(seed);

    var targetPool = _targetPool(difficulty)
        .where((c) => !excludedTargetCodes.contains(c.code))
        .toList();
    if (targetPool.isEmpty) targetPool = _eligibleCountries();
    final target = targetPool[rng.nextInt(targetPool.length)];
    final targetCapital = CountryData.getCapital(target.code)!;

    // Clue anchors: recognisable countries (rating within the normal pool)
    // so the reference points don't add a second identification puzzle.
    var anchors = _eligibleCountries()
        .where((c) =>
            c.code != target.code &&
            countryDifficultyRating(c.code) <= normalThreshold)
        .toList();
    if (requireStats) {
      anchors = anchors
          .where((c) =>
              (Clue.getAllCountryStats(c.code)['headOfState'] ?? '')
                  .isNotEmpty &&
              (Clue.getAllCountryStats(c.code)['language'] ?? '').isNotEmpty)
          .toList();
    }
    anchors.shuffle(rng);

    // Greedily spread markers around the compass: prefer anchors whose
    // bearing lands in an unused octant so arrows don't cluster.
    final clues = <TriangulationClue>[];
    final usedOctants = <int>{};
    final deferred = <TriangulationClue>[];
    for (final c in anchors) {
      if (clues.length >= markerCount) break;
      final capital = CountryData.getCapital(c.code)!;
      final bearing =
          initialBearingDeg(targetCapital.location, capital.location);
      final clue = TriangulationClue(
        countryCode: c.code,
        countryName: c.name,
        capitalName: capital.name,
        capitalLngLat: capital.location,
        bearingFromTargetDeg: bearing,
        distanceFromTargetKm:
            greatCircleKm(targetCapital.location, capital.location),
      );
      final octant = (bearing / 45.0).floor() % 8;
      if (usedOctants.contains(octant)) {
        deferred.add(clue);
      } else {
        usedOctants.add(octant);
        clues.add(clue);
      }
    }
    // Fill any remaining slots from the deferred (clustered) candidates.
    for (final clue in deferred) {
      if (clues.length >= markerCount) break;
      clues.add(clue);
    }

    return TriangulationRound(
      targetCountryCode: target.code,
      targetCountryName: target.name,
      targetCapitalName: targetCapital.name,
      targetCapitalLngLat: targetCapital.location,
      clues: clues,
    );
  }
}
