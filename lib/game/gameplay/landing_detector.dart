import 'dart:math';

import 'package:flame/game.dart';

/// How close the plane is to the landing target.
enum LandingProximity {
  /// More than 30 degrees away.
  far,

  /// Between 15 and 30 degrees away.
  approaching,

  /// Between 8 and 15 degrees away.
  near,

  /// Within 8 degrees AND at low altitude - ready to land.
  landing,
}

/// Detects when the player has successfully landed on a target location.
///
/// Works with the globe renderer coordinate system where positions are
/// specified as (longitude, latitude) in degrees. Distance is computed
/// using the Haversine great-circle formula.
///
/// Landing requires:
/// 1. The plane must be within [landingThresholdDeg] of the target.
/// 2. The plane must be at low altitude.
class LandingDetector {
  const LandingDetector({
    this.landingThresholdDeg = 8.0,
    this.nearThresholdDeg = 15.0,
    this.approachingThresholdDeg = 30.0,
  });

  /// Maximum great-circle distance (degrees) to qualify as a landing.
  /// Default 8.0 degrees matches the old system (80 world-units * 0.1).
  final double landingThresholdDeg;

  /// Distance threshold for "near" proximity (degrees).
  final double nearThresholdDeg;

  /// Distance threshold for "approaching" proximity (degrees).
  final double approachingThresholdDeg;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Checks whether the plane has successfully landed on the target.
  ///
  /// [planePosition] and [targetPosition] are (longitude, latitude) in degrees.
  /// The plane must be at low altitude ([isLowAltitude] = true) to land.
  bool checkLanding(
    Vector2 planePosition,
    Vector2 targetPosition, {
    required bool isLowAltitude,
  }) {
    if (!isLowAltitude) return false;

    final distance = greatCircleDistanceDeg(planePosition, targetPosition);
    return distance <= landingThresholdDeg;
  }

  /// Returns the current proximity level between the plane and the target.
  ///
  /// [planePosition] and [targetPosition] are (longitude, latitude) in degrees.
  /// [isLowAltitude] is required because [LandingProximity.landing] is only
  /// returned when the plane is both close enough AND at low altitude.
  LandingProximity getProximity(
    Vector2 planePosition,
    Vector2 targetPosition, {
    bool isLowAltitude = false,
  }) {
    final distance = greatCircleDistanceDeg(planePosition, targetPosition);

    if (distance <= landingThresholdDeg && isLowAltitude) {
      return LandingProximity.landing;
    }
    if (distance <= nearThresholdDeg) {
      return LandingProximity.near;
    }
    if (distance <= approachingThresholdDeg) {
      return LandingProximity.approaching;
    }
    return LandingProximity.far;
  }

  /// Computes the great-circle angular distance between two points
  /// in degrees using the Haversine formula.
  ///
  /// [a] and [b] are Vector2 with x = longitude, y = latitude (degrees).
  ///
  /// The Haversine formula is numerically stable for small distances
  /// (unlike the spherical law of cosines) and avoids the complexity
  /// of Vincenty's formula.
  static double greatCircleDistanceDeg(Vector2 a, Vector2 b) {
    const deg2rad = pi / 180.0;
    const rad2deg = 180.0 / pi;

    final lat1 = a.y * deg2rad;
    final lat2 = b.y * deg2rad;
    final dLat = (b.y - a.y) * deg2rad;
    final dLng = (b.x - a.x) * deg2rad;

    // Haversine formula
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2.0 * atan2(sqrt(h), sqrt(1.0 - h));

    return c * rad2deg;
  }
}
