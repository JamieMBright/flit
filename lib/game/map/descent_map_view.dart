import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// OSM tile map shown during descent mode.
///
/// Renders OpenStreetMap tiles with the player's current position and heading.
/// Uses flutter_map v6 (compatible with Dart 3.2 / Flutter 3.16).
/// On web, the browser cache handles tile storage.
///
/// The map is non-interactive — position and zoom are driven entirely by
/// the game state (player lng/lat and altitude transition). Wrapped in
/// [IgnorePointer] so touch events pass through to game controls underneath.
class DescentMapView extends StatefulWidget {
  const DescentMapView({
    super.key,
    required this.centerLng,
    required this.centerLat,
    required this.heading,
    required this.altitudeTransition,
    required this.tileUrl,
    this.trackPlane = false,
  });

  /// Map center in degrees.
  ///
  /// When [trackPlane] is false (default), this is the map center directly.
  /// When [trackPlane] is true, this is the plane's world position; the map
  /// center is offset ahead along [heading] so the plane appears at ~80%
  /// screen height, and rotation pivots around the plane.
  final double centerLng;
  final double centerLat;

  /// Camera heading as navigation bearing in radians (0 = north, π/2 = east).
  /// Uses the lagged camera heading for smooth rotation matching the globe view.
  final double heading;

  /// Altitude transition value (0.0 = ground, 1.0 = high altitude).
  /// Used to compute zoom level.
  final double altitudeTransition;

  /// Tile URL template (e.g. OSM, CARTO Dark, Voyager, OpenTopoMap).
  final String tileUrl;

  /// When true, offset the map center ahead of [centerLng]/[centerLat] along
  /// [heading] so the plane position appears at ~80% screen height and
  /// rotation pivots around the plane. Used for descent mode.
  final bool trackPlane;

  @override
  State<DescentMapView> createState() => _DescentMapViewState();
}

class _DescentMapViewState extends State<DescentMapView> {
  final MapController _mapController = MapController();
  bool _mapReady = false;
  double _widgetHeight = 800.0;

  /// Convert altitude transition (0.0–1.0) to flutter_map zoom level.
  /// Low altitude (0.0) → zoom 7 (regional overview)
  /// High altitude (1.0) → zoom 4 (continent-level)
  double get _zoom {
    return 4.0 + (1.0 - widget.altitudeTransition) * 3.0;
  }

  /// Convert camera bearing (radians, 0=north, π/2=east) to map rotation
  /// (degrees). The map rotates so the flight direction faces screen-up.
  double get _rotation {
    return -widget.heading * 180.0 / math.pi;
  }

  /// Compute the effective map center.
  ///
  /// When [trackPlane] is true, offsets ahead of the plane position along
  /// [heading] so the plane appears at ~80% of the widget height (30% below
  /// the map center). The offset is computed for the 2D Web Mercator
  /// projection at the current zoom level and latitude.
  ///
  /// When the map rotates by -heading, the heading direction becomes
  /// screen-up, placing the plane (which is behind the center in the heading
  /// direction) at ~80% screen height. Rotation pivots around the map center,
  /// keeping the plane visually fixed.
  LatLng _effectiveCenter() {
    if (!widget.trackPlane) {
      return LatLng(widget.centerLat, widget.centerLng);
    }

    final latRad = widget.centerLat * math.pi / 180.0;
    final cosLat = math.cos(latRad).abs().clamp(0.01, 1.0);

    // Degrees of latitude per pixel in Web Mercator at current zoom & latitude.
    final degPerPx = 360.0 * cosLat / (256.0 * math.pow(2, _zoom));

    // Offset ahead by 30% of widget height (center at 50% → plane at 80%).
    final offsetDeg = 0.30 * _widgetHeight * degPerPx;

    // Move ahead along the heading direction.
    final dLat = offsetDeg * math.cos(widget.heading);
    final dLng = offsetDeg * math.sin(widget.heading) / cosLat;

    return LatLng(widget.centerLat + dLat, widget.centerLng + dLng);
  }

  @override
  void didUpdateWidget(DescentMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_mapReady) {
      _mapController.move(_effectiveCenter(), _zoom);
      _mapController.rotate(_rotation);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _widgetHeight = constraints.maxHeight;
        final center = _effectiveCenter();
        return IgnorePointer(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: _zoom,
              initialRotation: _rotation,
              // Disable all user interaction — game controls the camera
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
              onMapReady: () {
                _mapReady = true;
              },
            ),
            children: [
              // Map tiles (style selected in settings)
              TileLayer(
                urlTemplate: widget.tileUrl,
                userAgentPackageName: 'com.jamiembright.flit',
                maxZoom: 18,
                subdomains: const ['a', 'b', 'c'],
                // On web, the browser cache handles tile storage.
              ),

              // No plane marker — the game's existing plane sprite stays visible
              // on the Canvas overlay at its fixed screen position (50%, 80%).

              // OSM attribution (required by tile usage policy)
              const RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
