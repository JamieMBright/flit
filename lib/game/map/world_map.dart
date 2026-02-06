import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../flit_game.dart';
import 'country_data.dart';

/// Renders the world map scrolling underneath the plane.
///
/// The camera is centered on the plane's world position.
/// At high altitude: zoomed out, simplified outlines, lat/lng grid.
/// At low altitude: zoomed in, detailed fills, city names, terrain tones.
class WorldMap extends Component with HasGameRef<FlitGame> {
  WorldMap({this.onCountryTapped});

  final void Function(String countryCode)? onCountryTapped;

  /// Current altitude mode
  bool _isHighAltitude = true;

  /// Camera center in world coordinates
  Vector2 _cameraCenter = Vector2.zero();

  /// Map dimensions (Mercator projection world space)
  static const double mapWidth = 3600;
  static const double mapHeight = 1800;

  /// Zoom levels
  static const double _highAltitudeZoom = 0.35;
  static const double _lowAltitudeZoom = 0.8;

  /// Current interpolated zoom
  double _currentZoom = _highAltitudeZoom;

  bool get isHighAltitude => _isHighAltitude;
  Vector2 get cameraCenter => _cameraCenter;

  void setAltitude({required bool high}) {
    _isHighAltitude = high;
  }

  void setCameraCenter(Vector2 center) {
    _cameraCenter = center;
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Smoothly interpolate zoom
    final targetZoom = _isHighAltitude ? _highAltitudeZoom : _lowAltitudeZoom;
    _currentZoom += (targetZoom - _currentZoom) * min(1.0, dt * 3);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final screenSize = gameRef.size;

    // Draw ocean background with subtle gradient
    _renderOcean(canvas, screenSize);

    // Draw lat/lng grid (subtle, atlas-style)
    _renderGrid(canvas, screenSize);

    // Draw countries
    _renderCountries(canvas, screenSize);

    // Draw coastline effects
    _renderCoastlines(canvas, screenSize);

    // Draw cities at low altitude
    if (!_isHighAltitude) {
      _renderCities(canvas, screenSize);
    }

    // Draw contrails from plane component
    _renderContrails(canvas, screenSize);

    // Atmospheric haze at edges (vignette)
    _renderAtmosphere(canvas, screenSize);
  }

  void _renderOcean(Canvas canvas, Vector2 screenSize) {
    // Gradient ocean - deeper at top, shallower near center
    final oceanGradient = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          FlitColors.oceanDeep,
          FlitColors.ocean,
          FlitColors.oceanDeep,
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, screenSize.x, screenSize.y));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, screenSize.x, screenSize.y),
      oceanGradient,
    );
  }

  void _renderGrid(Canvas canvas, Vector2 screenSize) {
    final gridPaint = Paint()
      ..color = FlitColors.gridLine
      ..strokeWidth = 0.5;

    // Draw latitude/longitude grid lines every 30 degrees
    const gridSpacing = 30.0;

    // Longitude lines (vertical)
    for (var lng = -180.0; lng <= 180.0; lng += gridSpacing) {
      final worldX = (lng + 180) / 360 * mapWidth;
      final screenX = _worldToScreenX(worldX, screenSize);
      if (screenX >= -50 && screenX <= screenSize.x + 50) {
        canvas.drawLine(
          Offset(screenX, 0),
          Offset(screenX, screenSize.y),
          gridPaint,
        );
      }
    }

    // Latitude lines (horizontal)
    for (var lat = -90.0; lat <= 90.0; lat += gridSpacing) {
      final worldY = (90 - lat) / 180 * mapHeight;
      final screenY = _worldToScreenY(worldY, screenSize);
      if (screenY >= -50 && screenY <= screenSize.y + 50) {
        canvas.drawLine(
          Offset(0, screenY),
          Offset(screenSize.x, screenY),
          gridPaint,
        );
      }
    }

    // Equator and prime meridian slightly stronger
    final majorGridPaint = Paint()
      ..color = FlitColors.gridLine.withOpacity(0.15)
      ..strokeWidth = 1.0;

    // Equator
    final eqY = _worldToScreenY(mapHeight / 2, screenSize);
    if (eqY >= 0 && eqY <= screenSize.y) {
      canvas.drawLine(
        Offset(0, eqY),
        Offset(screenSize.x, eqY),
        majorGridPaint,
      );
    }

    // Prime meridian
    final pmX = _worldToScreenX(mapWidth / 2, screenSize);
    if (pmX >= 0 && pmX <= screenSize.x) {
      canvas.drawLine(
        Offset(pmX, 0),
        Offset(pmX, screenSize.y),
        majorGridPaint,
      );
    }
  }

  void _renderCountries(Canvas canvas, Vector2 screenSize) {
    for (final country in CountryData.countries) {
      _renderCountry(canvas, screenSize, country);
    }
  }

  void _renderCountry(Canvas canvas, Vector2 screenSize, CountryShape country) {
    final path = _createCountryPath(country, screenSize);
    if (path == null) return;

    // Land fill - vary by latitude for visual interest
    final centerLat = _getCountryCenterLat(country);
    final landColor = _getLandColorByLatitude(centerLat);

    final landPaint = Paint()
      ..color = landColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, landPaint);

    // Inner highlight (subtle lighter edge)
    if (!_isHighAltitude) {
      final highlightPaint = Paint()
        ..color = FlitColors.landMassHighlight.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawPath(path, highlightPaint);
    }

    // Border
    final borderPaint = Paint()
      ..color = _isHighAltitude
          ? FlitColors.border.withOpacity(0.6)
          : FlitColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = _isHighAltitude ? 0.8 : 1.5;

    canvas.drawPath(path, borderPaint);
  }

  Color _getLandColorByLatitude(double lat) {
    // Vary land color by latitude for natural look
    final absLat = lat.abs();
    if (absLat > 65) {
      // Polar/tundra - snowy
      return FlitColors.landSnow;
    } else if (absLat > 50) {
      // Temperate - green
      return FlitColors.landMass;
    } else if (absLat > 30) {
      // Subtropical - lighter green
      return FlitColors.landMassHighlight;
    } else if (absLat > 15) {
      // Arid/tropical transition
      return FlitColors.landArid;
    } else {
      // Tropical - warm green
      return FlitColors.landMass;
    }
  }

  double _getCountryCenterLat(CountryShape country) {
    var sumLat = 0.0;
    for (final p in country.points) {
      sumLat += p.y;
    }
    return sumLat / country.points.length;
  }

  void _renderCoastlines(Canvas canvas, Vector2 screenSize) {
    // Draw a subtle glow around coastlines for that atlas feel
    final coastPaint = Paint()
      ..color = FlitColors.oceanShallow.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _isHighAltitude ? 2.0 : 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    for (final country in CountryData.countries) {
      final path = _createCountryPath(country, screenSize);
      if (path != null) {
        canvas.drawPath(path, coastPaint);
      }
    }
  }

  Path? _createCountryPath(CountryShape country, Vector2 screenSize) {
    final path = Path();
    var anyOnScreen = false;

    for (var i = 0; i < country.points.length; i++) {
      final screenPos = _latLngToScreen(country.points[i], screenSize);

      // Check if any point is roughly on screen (with margin)
      if (screenPos.x >= -200 &&
          screenPos.x <= screenSize.x + 200 &&
          screenPos.y >= -200 &&
          screenPos.y <= screenSize.y + 200) {
        anyOnScreen = true;
      }

      if (i == 0) {
        path.moveTo(screenPos.x, screenPos.y);
      } else {
        path.lineTo(screenPos.x, screenPos.y);
      }
    }

    path.close();
    return anyOnScreen ? path : null;
  }

  Vector2 _latLngToScreen(Vector2 latLng, Vector2 screenSize) {
    // Convert lat/lng to world coordinates
    final worldX = (latLng.x + 180) / 360 * mapWidth;
    final worldY = (90 - latLng.y) / 180 * mapHeight;

    return Vector2(
      _worldToScreenX(worldX, screenSize),
      _worldToScreenY(worldY, screenSize),
    );
  }

  double _worldToScreenX(double worldX, Vector2 screenSize) {
    // Plane is at planeScreenX on screen, camera is at _cameraCenter in world
    final planeScreenPosX = screenSize.x * FlitGame.planeScreenX;
    var dx = worldX - _cameraCenter.x;

    // Handle wrapping
    if (dx > mapWidth / 2) dx -= mapWidth;
    if (dx < -mapWidth / 2) dx += mapWidth;

    return planeScreenPosX + dx * _currentZoom;
  }

  double _worldToScreenY(double worldY, Vector2 screenSize) {
    final planeScreenPosY = screenSize.y * FlitGame.planeScreenY;
    final dy = worldY - _cameraCenter.y;
    return planeScreenPosY + dy * _currentZoom;
  }

  void _renderCities(Canvas canvas, Vector2 screenSize) {
    final cityDotPaint = Paint()..color = FlitColors.city;
    final capitalDotPaint = Paint()..color = FlitColors.cityCapital;
    final cityOutlinePaint = Paint()
      ..color = FlitColors.shadow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (final city in CountryData.majorCities) {
      final screenPos = _latLngToScreen(city.location, screenSize);

      // Only render if on screen
      if (screenPos.x < -20 ||
          screenPos.x > screenSize.x + 20 ||
          screenPos.y < -20 ||
          screenPos.y > screenSize.y + 20) {
        continue;
      }

      final dotSize = city.isCapital ? 4.0 : 2.5;
      final paint = city.isCapital ? capitalDotPaint : cityDotPaint;

      // City dot with outline
      canvas.drawCircle(
        Offset(screenPos.x, screenPos.y),
        dotSize,
        paint,
      );
      canvas.drawCircle(
        Offset(screenPos.x, screenPos.y),
        dotSize,
        cityOutlinePaint,
      );

      // City name
      final textPainter = TextPainter(
        text: TextSpan(
          text: city.name,
          style: TextStyle(
            color: city.isCapital
                ? FlitColors.textPrimary
                : FlitColors.textSecondary,
            fontSize: city.isCapital ? 10 : 8,
            fontWeight: city.isCapital ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(screenPos.x + dotSize + 3, screenPos.y - textPainter.height / 2),
      );
    }
  }

  void _renderContrails(Canvas canvas, Vector2 screenSize) {
    final plane = gameRef.plane;
    final planeScreenPos = Vector2(
      screenSize.x * FlitGame.planeScreenX,
      screenSize.y * FlitGame.planeScreenY,
    );

    for (final particle in plane.contrails) {
      final opacity = (particle.life / particle.maxLife).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = FlitColors.contrail.withOpacity(opacity * 0.5);

      final pos = planeScreenPos + particle.screenOffset;
      canvas.drawCircle(
        Offset(pos.x, pos.y),
        particle.size * (0.3 + opacity * 0.7),
        paint,
      );
    }
  }

  void _renderAtmosphere(Canvas canvas, Vector2 screenSize) {
    // Subtle vignette effect - darker at edges
    final vignetteRect = Rect.fromLTWH(0, 0, screenSize.x, screenSize.y);

    // Top fade
    final topGradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [
          FlitColors.oceanDeep.withOpacity(0.5),
          FlitColors.oceanDeep.withOpacity(0.0),
        ],
      ).createShader(vignetteRect);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, screenSize.x, screenSize.y * 0.3),
      topGradient,
    );

    // Bottom fade (below the plane)
    final bottomGradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.center,
        end: Alignment.bottomCenter,
        colors: [
          FlitColors.oceanDeep.withOpacity(0.0),
          FlitColors.oceanDeep.withOpacity(0.4),
        ],
      ).createShader(vignetteRect);
    canvas.drawRect(
      Rect.fromLTWH(0, screenSize.y * 0.8, screenSize.x, screenSize.y * 0.2),
      bottomGradient,
    );
  }

  /// Convert screen position to lat/lng
  Vector2 screenToLatLng(Vector2 screenPos, Vector2 screenSize) {
    final planeScreenPosX = screenSize.x * FlitGame.planeScreenX;
    final planeScreenPosY = screenSize.y * FlitGame.planeScreenY;

    final worldX = _cameraCenter.x + (screenPos.x - planeScreenPosX) / _currentZoom;
    final worldY = _cameraCenter.y + (screenPos.y - planeScreenPosY) / _currentZoom;

    final lng = worldX / mapWidth * 360 - 180;
    final lat = 90 - worldY / mapHeight * 180;

    return Vector2(lng, lat);
  }

  /// Convert lat/lng to screen position
  Vector2 latLngToScreen(Vector2 latLng, Vector2 screenSize) {
    return _latLngToScreen(latLng, screenSize);
  }
}
