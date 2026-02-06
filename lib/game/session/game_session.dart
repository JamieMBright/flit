import 'dart:math';

import 'package:flame/components.dart';

import '../clues/clue_types.dart';
import '../map/country_data.dart';

/// Represents a single game session (one round of play).
class GameSession {
  GameSession({
    required this.targetCountry,
    required this.clue,
    required this.startPosition,
  }) : startTime = DateTime.now();

  final CountryShape targetCountry;
  final Clue clue;
  final Vector2 startPosition;
  final DateTime startTime;

  DateTime? endTime;
  bool _completed = false;
  List<Vector2> flightPath = [];

  /// Whether the session is complete
  bool get isCompleted => _completed;

  /// Time taken to complete (or current elapsed time)
  Duration get elapsed =>
      (endTime ?? DateTime.now()).difference(startTime);

  /// Score based on time (lower is better)
  int get score {
    if (!_completed) return 0;
    // Base score is 10000, minus 10 per second
    final seconds = elapsed.inSeconds;
    return max(0, 10000 - (seconds * 10));
  }

  /// Mark the session as completed
  void complete() {
    if (!_completed) {
      _completed = true;
      endTime = DateTime.now();
    }
  }

  /// Record a position in the flight path
  void recordPosition(Vector2 position) {
    flightPath.add(position.clone());
  }

  /// Get the target position (capital city or center of country)
  Vector2 get targetPosition {
    final capital = CountryData.getCapital(targetCountry.code);
    if (capital != null) {
      return capital.location;
    }
    // Fall back to center of country bounds
    var sumX = 0.0;
    var sumY = 0.0;
    for (final point in targetCountry.points) {
      sumX += point.x;
      sumY += point.y;
    }
    return Vector2(
      sumX / targetCountry.points.length,
      sumY / targetCountry.points.length,
    );
  }

  /// Create a new random game session
  factory GameSession.random() {
    final country = CountryData.getRandomCountry();
    final clue = Clue.random(country.code);

    // Generate random start position (not too close to target)
    final random = Random();
    final startLng = (random.nextDouble() * 360) - 180;
    final startLat = (random.nextDouble() * 140) - 70;

    return GameSession(
      targetCountry: country,
      clue: clue,
      startPosition: Vector2(startLng, startLat),
    );
  }

  /// Create a seeded game session (for challenges)
  factory GameSession.seeded(int seed) {
    final random = Random(seed);

    // Pick country based on seed
    final countryIndex = random.nextInt(CountryData.countries.length);
    final country = CountryData.countries[countryIndex];

    // Pick clue type based on seed
    final clueTypes = ClueType.values;
    final clueTypeIndex = random.nextInt(clueTypes.length);
    final clueType = clueTypes[clueTypeIndex];

    final clue = switch (clueType) {
      ClueType.flag => Clue.flag(country.code),
      ClueType.outline => Clue.outline(country.code),
      ClueType.borders => Clue.borders(country.code),
      ClueType.capital => Clue.capital(country.code),
      ClueType.stats => Clue.stats(country.code),
    };

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

/// Result of a completed game session
class GameResult {
  const GameResult({
    required this.targetCountry,
    required this.clueType,
    required this.elapsed,
    required this.score,
    required this.flightPath,
  });

  final String targetCountry;
  final ClueType clueType;
  final Duration elapsed;
  final int score;
  final List<Vector2> flightPath;

  factory GameResult.fromSession(GameSession session) {
    return GameResult(
      targetCountry: session.targetCountry.code,
      clueType: session.clue.type,
      elapsed: session.elapsed,
      score: session.score,
      flightPath: session.flightPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'targetCountry': targetCountry,
        'clueType': clueType.name,
        'elapsedMs': elapsed.inMilliseconds,
        'score': score,
      };
}
