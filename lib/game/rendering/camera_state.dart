import 'dart:math';

/// Manages the 3D camera state for the globe fragment shader.
///
/// The camera orbits a unit-radius globe centered at the origin.
/// Position is derived from the plane's latitude/longitude on the sphere
/// surface, offset outward along the surface normal by an altitude distance.
///
/// Provides smooth transitions between high and low altitude, and a
/// speed-dependent FOV shift for a sense of acceleration.
class CameraState {
  /// Globe radius in world units (normalized to 1.0).
  static const double globeRadius = 1.0;

  /// Camera distance from globe center at high altitude (~3.5 radii).
  static const double highAltitudeDistance = 3.5;

  /// Camera distance from globe center at low altitude (~1.8 radii).
  static const double lowAltitudeDistance = 1.8;

  /// Narrow FOV at rest (radians). Approximately 45 degrees.
  static const double fovNarrow = 0.785;

  /// Wide FOV at max speed (radians). Approximately 70 degrees.
  static const double fovWide = 1.22;

  /// Rate of easing for altitude transitions (higher = faster).
  static const double _altitudeEaseRate = 3.0;

  /// Rate of easing for FOV transitions (higher = faster).
  static const double _fovEaseRate = 4.0;

  // -- Internal state --

  /// Current interpolated camera distance from globe center.
  double _currentDistance = highAltitudeDistance;

  /// Current interpolated camera latitude (radians).
  double _currentLatRad = 0.0;

  /// Current interpolated camera longitude (radians).
  double _currentLngRad = 0.0;

  /// Current interpolated field of view (radians).
  double _currentFov = fovNarrow;

  /// Whether this is the first update (skip lerp, snap to position).
  bool _firstUpdate = true;

  // -- Computed camera position in cartesian coordinates --

  double _camX = 0.0;
  double _camY = 0.0;
  double _camZ = highAltitudeDistance;

  /// Camera X position in world space (for shader uniform).
  double get cameraX => _camX;

  /// Camera Y position in world space (for shader uniform).
  double get cameraY => _camY;

  /// Camera Z position in world space (for shader uniform).
  double get cameraZ => _camZ;

  /// Camera look-at target X (always globe center).
  double get targetX => 0.0;

  /// Camera look-at target Y (always globe center).
  double get targetY => 0.0;

  /// Camera look-at target Z (always globe center).
  double get targetZ => 0.0;

  /// Current field of view in radians.
  double get fov => _currentFov;

  /// Current interpolated distance from globe center.
  double get currentDistance => _currentDistance;

  /// Update the camera state based on the plane's position and flight mode.
  ///
  /// [dt] - delta time in seconds since last frame.
  /// [planeLatDeg] - plane latitude in degrees.
  /// [planeLngDeg] - plane longitude in degrees.
  /// [isHighAltitude] - true for high altitude (zoomed out), false for low.
  /// [speedFraction] - normalized speed 0.0 (stopped) to 1.0 (max speed),
  ///   used to shift the FOV for a sense of acceleration.
  void update(
    double dt, {
    required double planeLatDeg,
    required double planeLngDeg,
    required bool isHighAltitude,
    double speedFraction = 0.0,
  }) {
    final targetLatRad = planeLatDeg * pi / 180.0;
    final targetLngRad = planeLngDeg * pi / 180.0;
    final targetDistance =
        isHighAltitude ? highAltitudeDistance : lowAltitudeDistance;
    final targetFov = _lerpDouble(fovNarrow, fovWide, speedFraction.clamp(0, 1));

    if (_firstUpdate) {
      // Snap to target on first frame - no interpolation.
      _currentLatRad = targetLatRad;
      _currentLngRad = targetLngRad;
      _currentDistance = targetDistance;
      _currentFov = targetFov;
      _firstUpdate = false;
    } else {
      // Smooth ease-out interpolation using dt-based lerp factor.
      // factor = 1 - e^(-rate * dt) gives frame-rate-independent easing.
      final altFactor = 1.0 - exp(-_altitudeEaseRate * dt);
      final fovFactor = 1.0 - exp(-_fovEaseRate * dt);

      _currentDistance =
          _lerpDouble(_currentDistance, targetDistance, altFactor);
      _currentFov = _lerpDouble(_currentFov, targetFov, fovFactor);

      // For lat/lng, use the same ease-out interpolation.
      // Handle longitude wrapping: find shortest angular path.
      _currentLatRad = _lerpDouble(_currentLatRad, targetLatRad, altFactor);
      _currentLngRad = _lerpAngle(_currentLngRad, targetLngRad, altFactor);
    }

    // Convert spherical coordinates to cartesian.
    // Convention: y = up (sin(lat)), x/z = horizontal plane.
    // x = cos(lat) * cos(lng)
    // y = sin(lat)
    // z = cos(lat) * sin(lng)
    // Then scale by distance from globe center.
    _camX = cos(_currentLatRad) * cos(_currentLngRad) * _currentDistance;
    _camY = sin(_currentLatRad) * _currentDistance;
    _camZ = cos(_currentLatRad) * sin(_currentLngRad) * _currentDistance;
  }

  /// Reset the camera to default state, forcing a snap on next update.
  void reset() {
    _firstUpdate = true;
    _currentDistance = highAltitudeDistance;
    _currentLatRad = 0.0;
    _currentLngRad = 0.0;
    _currentFov = fovNarrow;
    _camX = 0.0;
    _camY = 0.0;
    _camZ = highAltitudeDistance;
  }

  /// Linear interpolation between two doubles.
  static double _lerpDouble(double a, double b, double t) {
    return a + (b - a) * t;
  }

  /// Interpolate between two angles (radians) along the shortest path.
  /// Handles the -pi/+pi wraparound correctly.
  static double _lerpAngle(double a, double b, double t) {
    var diff = b - a;
    // Normalize difference to [-pi, pi]
    while (diff > pi) {
      diff -= 2 * pi;
    }
    while (diff < -pi) {
      diff += 2 * pi;
    }
    return a + diff * t;
  }
}
