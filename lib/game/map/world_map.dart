import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import 'country_data.dart';

/// Renders the world map with countries and cities.
/// Supports two detail levels: high altitude (outlines) and low altitude (detailed).
class WorldMap extends Component with HasGameRef {
  WorldMap({this.onCountryTapped});

  final void Function(String countryCode)? onCountryTapped;

  /// Current altitude mode
  bool _isHighAltitude = true;

  /// Camera offset for scrolling
  Vector2 _cameraOffset = Vector2.zero();

  /// Scale factor for the map
  final double _scale = 1.0;

  /// Map dimensions (Mercator projection)
  static const double mapWidth = 3600;
  static const double mapHeight = 1800;

  bool get isHighAltitude => _isHighAltitude;
  Vector2 get cameraOffset => _cameraOffset;

  void setAltitude({required bool high}) {
    _isHighAltitude = high;
  }

  void setCameraOffset(Vector2 offset) {
    _cameraOffset = offset;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final screenSize = gameRef.size;

    // Draw ocean background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, screenSize.x, screenSize.y),
      Paint()..color = FlitColors.ocean,
    );

    // Draw countries
    _renderCountries(canvas, screenSize);

    // Draw cities at low altitude
    if (!_isHighAltitude) {
      _renderCities(canvas, screenSize);
    }
  }

  void _renderCountries(Canvas canvas, Vector2 screenSize) {
    final landPaint = Paint()
      ..color = _isHighAltitude ? FlitColors.landMass : FlitColors.landMassHighlight
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = FlitColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = _isHighAltitude ? 1.0 : 2.0;

    // Render simplified country shapes
    for (final country in CountryData.countries) {
      final path = _createCountryPath(country, screenSize);
      canvas.drawPath(path, landPaint);
      canvas.drawPath(path, borderPaint);
    }
  }

  Path _createCountryPath(CountryShape country, Vector2 screenSize) {
    final path = Path();

    for (var i = 0; i < country.points.length; i++) {
      final point = _projectPoint(country.points[i], screenSize);

      if (i == 0) {
        path.moveTo(point.x, point.y);
      } else {
        path.lineTo(point.x, point.y);
      }
    }

    path.close();
    return path;
  }

  Vector2 _projectPoint(Vector2 latLng, Vector2 screenSize) {
    // Simple Mercator projection
    // latLng.x = longitude (-180 to 180)
    // latLng.y = latitude (-90 to 90)

    final x = (latLng.x + 180) / 360 * mapWidth;
    final y = (90 - latLng.y) / 180 * mapHeight;

    // Apply camera offset and scale
    final screenX = (x - _cameraOffset.x) * _scale + screenSize.x / 2;
    final screenY = (y - _cameraOffset.y) * _scale + screenSize.y / 2;

    // Wrap around horizontally
    final wrappedX = screenX % (mapWidth * _scale);

    return Vector2(wrappedX, screenY);
  }

  void _renderCities(Canvas canvas, Vector2 screenSize) {
    final cityPaint = Paint()..color = FlitColors.city;
    final textPaint = TextPaint(
      style: const TextStyle(
        color: FlitColors.textPrimary,
        fontSize: 10,
      ),
    );

    for (final city in CountryData.majorCities) {
      final point = _projectPoint(city.location, screenSize);

      // Draw city dot
      canvas.drawCircle(
        Offset(point.x, point.y),
        4,
        cityPaint,
      );

      // Draw city name
      textPaint.render(
        canvas,
        city.name,
        Vector2(point.x + 6, point.y - 5),
      );
    }
  }

  /// Convert screen position to lat/lng
  Vector2 screenToLatLng(Vector2 screenPos, Vector2 screenSize) {
    final mapX = (screenPos.x - screenSize.x / 2) / _scale + _cameraOffset.x;
    final mapY = (screenPos.y - screenSize.y / 2) / _scale + _cameraOffset.y;

    final lng = mapX / mapWidth * 360 - 180;
    final lat = 90 - mapY / mapHeight * 180;

    return Vector2(lng, lat);
  }

  /// Convert lat/lng to screen position
  Vector2 latLngToScreen(Vector2 latLng, Vector2 screenSize) {
    return _projectPoint(latLng, screenSize);
  }
}
