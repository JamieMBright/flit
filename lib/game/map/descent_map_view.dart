import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// OSM tile map shown during descent mode.
///
/// Renders OpenStreetMap tiles with the player's current position and heading.
/// Uses flutter_map's built-in tile caching (1 GB soft limit on non-web;
/// browser cache on web). No additional caching package needed.
///
/// The map is non-interactive — position and zoom are driven entirely by
/// the game state (player lng/lat and altitude transition). Wrapped in
/// [IgnorePointer] so touch events pass through to game controls underneath.
class DescentMapView extends StatefulWidget {
  const DescentMapView({
    super.key,
    required this.playerLng,
    required this.playerLat,
    required this.heading,
    required this.altitudeTransition,
  });

  /// Player position in degrees.
  final double playerLng;
  final double playerLat;

  /// Player heading in radians (code convention: 0 = east, π/2 = north).
  final double heading;

  /// Altitude transition value (0.0 = ground, 1.0 = high altitude).
  /// Used to compute zoom level.
  final double altitudeTransition;

  @override
  State<DescentMapView> createState() => _DescentMapViewState();
}

class _DescentMapViewState extends State<DescentMapView> {
  final MapController _mapController = MapController();
  bool _mapReady = false;

  /// Convert altitude transition (0.0–1.0) to flutter_map zoom level.
  /// Low altitude (0.0) → zoom 10 (city-level detail)
  /// High altitude (1.0) → zoom 4 (continent-level)
  double get _zoom {
    return 4.0 + (1.0 - widget.altitudeTransition) * 6.0;
  }

  /// Convert game heading (radians, 0=east, π/2=north) to map rotation
  /// (degrees). The map rotates so the plane's direction faces screen-up.
  double get _rotation {
    final headingDeg = widget.heading * 180.0 / math.pi;
    return -(90.0 - headingDeg);
  }

  @override
  void didUpdateWidget(DescentMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_mapReady) {
      _mapController.move(
        LatLng(widget.playerLat, widget.playerLng),
        _zoom,
      );
      _mapController.rotate(_rotation);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: LatLng(widget.playerLat, widget.playerLng),
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
          // OSM raster tiles
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.jamiembright.flit',
            maxZoom: 18,
            // Built-in caching is enabled by default on non-web platforms.
            // On web, the browser cache handles tile storage.
          ),

          // Player position marker (plane icon)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(widget.playerLat, widget.playerLng),
                width: 40,
                height: 40,
                child: Transform.rotate(
                  // Rotate plane icon to match heading.
                  // Icon points up (north) by default. Map is rotated so
                  // the player's heading faces screen-up, so the plane
                  // icon should point up = forward.
                  angle: 0, // already aligned via map rotation
                  child: const Icon(
                    Icons.airplanemode_active,
                    color: Colors.white,
                    size: 32,
                    shadows: [
                      Shadow(
                        blurRadius: 4,
                        color: Colors.black54,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

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
  }
}
