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

  /// Camera distance from globe center at high altitude (~2.8 radii).
  /// Close enough to show terrain context while still revealing curvature.
  static const double highAltitudeDistance = 2.8;

  /// Camera distance from globe center at low altitude (~1.3 radii).
  /// Close enough to see terrain detail and city-level geography.
  static const double lowAltitudeDistance = 1.3;

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

  // -- Heading-aligned up vector (prevents rolling at non-equatorial latitudes) --

  double _upX = 0.0;
  double _upY = 1.0;
  double _upZ = 0.0;

  /// Smoothed heading for interpolation (radians, navigation bearing).
  double _currentHeadingRad = 0.0;

  /// Camera X position in world space (for shader uniform).
  double get cameraX => _camX;

  /// Camera Y position in world space (for shader uniform).
  double get cameraY => _camY;

  /// Camera Z position in world space (for shader uniform).
  double get cameraZ => _camZ;

  /// Camera up vector X (heading-aligned tangent on globe surface).
  double get upX => _upX;

  /// Camera up vector Y.
  double get upY => _upY;

  /// Camera up vector Z.
  double get upZ => _upZ;

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
  /// [headingRad] - navigation bearing in radians (0 = north, clockwise).
  ///   Used to compute the heading-aligned up vector that prevents rolling.
  void update(
    double dt, {
    required double planeLatDeg,
    required double planeLngDeg,
    required bool isHighAltitude,
    double speedFraction = 0.0,
    double headingRad = 0.0,
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
      _currentHeadingRad = headingRad;
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

      // Smooth heading interpolation (shortest path).
      _currentHeadingRad = _lerpAngle(_currentHeadingRad, headingRad, altFactor);
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

    // Compute heading-aligned up vector at the camera position.
    // This prevents the view from rolling at non-equatorial latitudes.
    // The up vector is the heading tangent on the globe surface:
    //   heading = cos(bearing) * North + sin(bearing) * East
    // where North and East are the tangent basis vectors at (lat, lng).
    _computeUpVector();
  }

  /// Compute the heading-aligned up vector from current lat/lng/heading.
  ///
  /// At any point on the sphere, the local tangent basis is:
  ///   East  = (-sin(lng), 0, cos(lng))
  ///   North = (-sin(lat)*cos(lng), cos(lat), -sin(lat)*sin(lng))
  /// The heading tangent (navigation bearing) is:
  ///   H = cos(bearing) * North + sin(bearing) * East
  void _computeUpVector() {
    final lat = _currentLatRad;
    final lng = _currentLngRad;
    final bearing = _currentHeadingRad;

    final sinLat = sin(lat);
    final cosLat = cos(lat);
    final sinLng = sin(lng);
    final cosLng = cos(lng);
    final cosB = cos(bearing);
    final sinB = sin(bearing);

    // East tangent at (lat, lng)
    final eastX = -sinLng;
    const eastY = 0.0;
    final eastZ = cosLng;

    // North tangent at (lat, lng)
    final northX = -sinLat * cosLng;
    final northY = cosLat;
    final northZ = -sinLat * sinLng;

    // Heading tangent = cos(bearing) * North + sin(bearing) * East
    var ux = cosB * northX + sinB * eastX;
    var uy = cosB * northY + sinB * eastY;
    var uz = cosB * northZ + sinB * eastZ;

    // Normalize
    final len = sqrt(ux * ux + uy * uy + uz * uz);
    if (len > 1e-6) {
      ux /= len;
      uy /= len;
      uz /= len;
    } else {
      // Fallback (shouldn't happen except exactly at poles)
      ux = 0.0;
      uy = 1.0;
      uz = 0.0;
    }

    _upX = ux;
    _upY = uy;
    _upZ = uz;
  }

  /// Reset the camera to default state, forcing a snap on next update.
  void reset() {
    _firstUpdate = true;
    _currentDistance = highAltitudeDistance;
    _currentLatRad = 0.0;
    _currentLngRad = 0.0;
    _currentFov = fovNarrow;
    _currentHeadingRad = 0.0;
    _camX = 0.0;
    _camY = 0.0;
    _camZ = highAltitudeDistance;
    _upX = 0.0;
    _upY = 1.0;
    _upZ = 0.0;
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
