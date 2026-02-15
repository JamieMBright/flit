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
  });

  /// Map center in degrees (offset ahead of player so the player
  /// appears at ~80% screen height, matching the plane sprite).
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

  /// Convert camera bearing (radians, 0=north, π/2=east) to map rotation
  /// (degrees). The map rotates so the flight direction faces screen-up.
  double get _rotation {
    return -widget.heading * 180.0 / math.pi;
  }

  @override
  void didUpdateWidget(DescentMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_mapReady) {
      _mapController.move(
        LatLng(widget.centerLat, widget.centerLng),
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
          initialCenter: LatLng(widget.centerLat, widget.centerLng),
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
  }
}
