import 'dart:math';

/// A single recorded point along the flight path.
class FlightPoint {
  const FlightPoint({
    required this.lat,
    required this.lng,
    required this.heading,
    required this.isHigh,
    required this.timestamp,
  });

  /// Latitude in degrees.
  final double lat;

  /// Longitude in degrees.
  final double lng;

  /// Heading in radians.
  final double heading;

  /// Whether the plane was at high altitude.
  final bool isHigh;

  /// Time since the recording started.
  final Duration timestamp;

  @override
  String toString() =>
      'FlightPoint(lat: ${lat.toStringAsFixed(2)}, '
      'lng: ${lng.toStringAsFixed(2)}, '
      'heading: ${heading.toStringAsFixed(2)}, '
      'isHigh: $isHigh, '
      't: ${timestamp.inMilliseconds}ms)';
}

/// Records the plane's flight path during a game session.
///
/// Captures position, heading, and altitude at regular intervals using a
/// ring buffer to cap memory usage. Provides total distance and elapsed
/// time calculations for scoring and replay.
class FlightRecorder {
  FlightRecorder({
    this.recordInterval = 0.5,
    this.maxPoints = 1000,
  });

  /// Minimum time between recorded points (seconds).
  final double recordInterval;

  /// Maximum number of points stored (ring buffer capacity).
  final int maxPoints;

  /// Internal storage for flight points (ring buffer).
  final List<FlightPoint> _points = [];

  /// Time accumulator for interval-based recording.
  double _timeSinceLastRecord = 0.0;

  /// Total elapsed time since recording started (seconds).
  double _totalElapsed = 0.0;

  /// Whether recording has started.
  bool _isRecording = false;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// The recorded flight path.
  List<FlightPoint> get path => List<FlightPoint>.unmodifiable(_points);

  /// Number of recorded points.
  int get pointCount => _points.length;

  /// Whether the recorder is currently active.
  bool get isRecording => _isRecording;

  /// Total elapsed time since recording began.
  Duration get elapsed =>
      Duration(milliseconds: (_totalElapsed * 1000).round());

  /// Total great-circle distance traveled in degrees.
  ///
  /// Uses the Haversine formula between consecutive recorded points.
  double get totalDistanceDeg {
    if (_points.length < 2) return 0.0;

    double total = 0.0;
    for (int i = 1; i < _points.length; i++) {
      total += _haversineDistDeg(
        _points[i - 1].lat,
        _points[i - 1].lng,
        _points[i].lat,
        _points[i].lng,
      );
    }
    return total;
  }

  /// Starts or resumes recording.
  void start() {
    _isRecording = true;
  }

  /// Pauses recording (preserves existing data).
  void pause() {
    _isRecording = false;
  }

  /// Records a position if the interval has elapsed.
  ///
  /// Call this every frame with the current delta time [dt].
  /// The point is only stored once per [recordInterval] seconds.
  void update(
    double dt, {
    required double lat,
    required double lng,
    required double heading,
    required bool isHigh,
  }) {
    if (!_isRecording) return;

    _totalElapsed += dt;
    _timeSinceLastRecord += dt;

    if (_timeSinceLastRecord >= recordInterval) {
      _timeSinceLastRecord = 0.0;
      record(lat, lng, heading, isHigh);
    }
  }

  /// Directly records a point (bypassing the interval timer).
  ///
  /// Enforces the ring buffer [maxPoints] limit by removing the oldest
  /// point when full.
  void record(double lat, double lng, double heading, bool isHigh) {
    if (_points.length >= maxPoints) {
      _points.removeAt(0);
    }

    _points.add(FlightPoint(
      lat: lat,
      lng: lng,
      heading: heading,
      isHigh: isHigh,
      timestamp: elapsed,
    ));
  }

  /// Clears all recorded data and resets the timer.
  void reset() {
    _points.clear();
    _timeSinceLastRecord = 0.0;
    _totalElapsed = 0.0;
    _isRecording = false;
  }

  // ---------------------------------------------------------------------------
  // Internal: Haversine distance
  // ---------------------------------------------------------------------------

  static const double _deg2rad = pi / 180.0;
  static const double _rad2deg = 180.0 / pi;

  /// Computes the great-circle angular distance between two lat/lng points
  /// in degrees, using the Haversine formula.
  static double _haversineDistDeg(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dLat = (lat2 - lat1) * _deg2rad;
    final dLng = (lng2 - lng1) * _deg2rad;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * _deg2rad) *
            cos(lat2 * _deg2rad) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2.0 * atan2(sqrt(a), sqrt(1.0 - a));

    return c * _rad2deg;
  }
}
