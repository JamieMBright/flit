import '../map/region.dart';

/// A camera preset defining position, zoom, and bounds for a game region.
///
/// Used by the globe renderer to frame regional maps appropriately.
/// Altitude distance is measured in globe radii (1.0 = surface).
class CameraPreset {
  const CameraPreset({
    required this.centerLat,
    required this.centerLng,
    required this.altitudeDistance,
    required this.maxBoundsLat,
    required this.maxBoundsLng,
    this.fovOverride,
  });

  /// Center latitude of the region in degrees.
  final double centerLat;

  /// Center longitude of the region in degrees.
  final double centerLng;

  /// Camera altitude in globe radii (higher = more zoomed out).
  /// World view ~3.0, regional views ~1.2-2.0.
  final double altitudeDistance;

  /// Maximum latitude deviation the camera can stray from center (degrees).
  final double maxBoundsLat;

  /// Maximum longitude deviation the camera can stray from center (degrees).
  final double maxBoundsLng;

  /// Optional FOV override in degrees. Narrower for close-up regions to
  /// reduce distortion. Null means use the default FOV.
  final double? fovOverride;

  @override
  String toString() => 'CameraPreset(lat: $centerLat, lng: $centerLng, '
      'alt: $altitudeDistance, bounds: +/-$maxBoundsLat/$maxBoundsLng'
      '${fovOverride != null ? ', fov: $fovOverride' : ''})';
}

/// Static camera presets for each [GameRegion].
///
/// Each preset defines where the camera should start and how far it can
/// roam when the player is in that region's game mode.
abstract class RegionCameraPresets {
  RegionCameraPresets._();

  // ---------------------------------------------------------------------------
  // Preset definitions
  // ---------------------------------------------------------------------------

  /// World view: high altitude, full freedom.
  static const CameraPreset _worldPreset = CameraPreset(
    centerLat: 20.0,
    centerLng: 0.0,
    altitudeDistance: 3.0,
    maxBoundsLat: 90.0,
    maxBoundsLng: 180.0,
  );

  /// United States: centered on geographic center (near Lebanon, Kansas).
  static const CameraPreset _usStatesPreset = CameraPreset(
    centerLat: 39.8,
    centerLng: -98.5,
    altitudeDistance: 2.0,
    maxBoundsLat: 20.0,
    maxBoundsLng: 35.0,
    fovOverride: 50.0,
  );

  /// United Kingdom: centered on the geographic middle of Great Britain.
  static const CameraPreset _ukCountiesPreset = CameraPreset(
    centerLat: 54.0,
    centerLng: -2.0,
    altitudeDistance: 1.4,
    maxBoundsLat: 8.0,
    maxBoundsLng: 10.0,
    fovOverride: 45.0,
  );

  /// Caribbean: centered on Hispaniola region.
  static const CameraPreset _caribbeanPreset = CameraPreset(
    centerLat: 18.0,
    centerLng: -72.0,
    altitudeDistance: 1.5,
    maxBoundsLat: 12.0,
    maxBoundsLng: 16.0,
    fovOverride: 48.0,
  );

  /// Ireland: centered on the geographic middle of the island.
  static const CameraPreset _irelandPreset = CameraPreset(
    centerLat: 53.5,
    centerLng: -7.5,
    altitudeDistance: 1.3,
    maxBoundsLat: 5.0,
    maxBoundsLng: 6.0,
    fovOverride: 42.0,
  );

  /// Canada: centered on the southern populated belt.
  static const CameraPreset _canadianProvincesPreset = CameraPreset(
    centerLat: 55.0,
    centerLng: -96.0,
    altitudeDistance: 2.2,
    maxBoundsLat: 25.0,
    maxBoundsLng: 50.0,
    fovOverride: 50.0,
  );

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns the [CameraPreset] for the given [region].
  static CameraPreset getPreset(GameRegion region) {
    switch (region) {
      case GameRegion.world:
        return _worldPreset;
      case GameRegion.usStates:
        return _usStatesPreset;
      case GameRegion.ukCounties:
        return _ukCountiesPreset;
      case GameRegion.caribbean:
        return _caribbeanPreset;
      case GameRegion.ireland:
        return _irelandPreset;
      case GameRegion.canadianProvinces:
        return _canadianProvincesPreset;
    }
  }

  /// Returns `true` if the given lat/lng position is within the camera bounds
  /// for the specified [region].
  ///
  /// Camera bounds are defined as a rectangular region centered on the
  /// preset's center point, extended by [CameraPreset.maxBoundsLat] and
  /// [CameraPreset.maxBoundsLng] in each direction.
  static bool isWithinBounds(double lat, double lng, GameRegion region) {
    final preset = getPreset(region);

    final latDelta = (lat - preset.centerLat).abs();
    final lngDelta = _lngDelta(lng, preset.centerLng);

    return latDelta <= preset.maxBoundsLat && lngDelta <= preset.maxBoundsLng;
  }

  /// Clamps a lat/lng position to be within the camera bounds for [region].
  ///
  /// Returns a list of [lat, lng] clamped to the region's bounds.
  static List<double> clampToBounds(double lat, double lng, GameRegion region) {
    final preset = getPreset(region);

    final clampedLat = lat.clamp(
      preset.centerLat - preset.maxBoundsLat,
      preset.centerLat + preset.maxBoundsLat,
    );

    // Handle longitude wrapping
    final minLng = preset.centerLng - preset.maxBoundsLng;
    final maxLng = preset.centerLng + preset.maxBoundsLng;
    final clampedLng = lng.clamp(minLng, maxLng);

    return [clampedLat, clampedLng];
  }

  /// Computes the shortest longitude delta, accounting for date-line wrapping.
  static double _lngDelta(double lng1, double lng2) {
    var delta = (lng1 - lng2).abs();
    if (delta > 180.0) {
      delta = 360.0 - delta;
    }
    return delta;
  }
}
