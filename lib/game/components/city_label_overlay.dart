import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../flit_game.dart';
import '../map/country_data.dart';

/// Renders city name labels at low altitude when the shader renderer is active.
///
/// When WorldMap (canvas renderer) is used, it handles city rendering itself.
/// This overlay fills the gap for the GPU shader path, which renders the globe
/// via fragment shader but cannot draw text labels.
class CityLabelOverlay extends Component with HasGameRef<FlitGame> {
  /// Maximum number of cities to render at once.
  /// On web (Safari iOS especially), cap aggressively to prevent crashes.
  static const int _maxVisibleCities = kIsWeb ? 6 : 15;

  /// Cached TextPainters to avoid recreating every frame (Safari crash cause).
  final Map<String, TextPainter> _textCache = {};

  /// Maximum number of capital cities to show at high altitude.
  static const int _maxHighAltCapitals = kIsWeb ? 4 : 8;

  /// Major world capitals to show at high altitude (largest by population).
  static const Set<String> _majorCapitals = {
    'Washington D.C.', 'Ottawa', 'Mexico City', 'Brasília', 'Buenos Aires',
    'London', 'Paris', 'Berlin', 'Madrid', 'Rome', 'Moscow',
    'Tokyo', 'Beijing', 'New Delhi', 'Seoul', 'Jakarta', 'Bangkok',
    'Cairo', 'Nairobi', 'Pretoria', 'Canberra',
  };

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    try {
      // Skip when using Canvas renderer — WorldMap renders cities directly.
      if (!gameRef.isShaderActive) return;

      // Get continuous altitude from plane (0.0 = low, 1.0 = high)
      final continuousAlt = gameRef.plane.continuousAltitude;

      // At high altitude, show only major capitals (small dots, no labels)
      if (continuousAlt >= 0.6) {
        _renderHighAltCapitals(canvas, continuousAlt);
        return;
      }

      // Calculate opacity based on altitude (0.6 = transparent, 0.0 = opaque)
      final opacity = (1.0 - continuousAlt / 0.6).clamp(0.0, 1.0);

      final cityDotPaint = Paint()..color = FlitColors.city.withOpacity(opacity);
      final capitalDotPaint = Paint()..color = FlitColors.cityCapital.withOpacity(opacity);

      // On web (especially Safari), avoid stroke paint which can be expensive.
      // Use solid dots only.
      final cityOutlinePaint = kIsWeb
          ? null
          : (Paint()
            ..color = FlitColors.shadow.withOpacity(opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5);

      // Calculate screen center for distance-based culling
      final centerX = gameRef.size.x / 2;
      final centerY = gameRef.size.y / 2;

      // Pre-compute city screen positions and distances
      final visibleCities = <({
        double distance,
        Offset screenPos,
        dynamic city,
      })>[];

      for (final city in CountryData.majorCities) {
        try {
          // Validate city location before projection
          if (!city.location.x.isFinite ||
              !city.location.y.isFinite) {
            continue;
          }

          final screenPos = gameRef.worldToScreen(city.location);

          // Skip if off-screen (with margin) or invalid coordinates.
          if (!screenPos.x.isFinite ||
              !screenPos.y.isFinite ||
              screenPos.x < -50 ||
              screenPos.x > gameRef.size.x + 50 ||
              screenPos.y < -50 ||
              screenPos.y > gameRef.size.y + 50) {
            continue;
          }

          // Calculate distance from screen center for prioritization
          final dx = screenPos.x - centerX;
          final dy = screenPos.y - centerY;
          final distanceSquared = dx * dx + dy * dy;
          
          // Check for valid distance before sqrt
          if (!distanceSquared.isFinite || distanceSquared < 0) {
            continue;
          }
          
          final distance = math.sqrt(distanceSquared);

          visibleCities.add((
            distance: distance,
            screenPos: Offset(screenPos.x, screenPos.y),
            city: city,
          ));
        } catch (e) {
          // Skip individual city if projection fails - don't break the loop.
          continue;
        }
      }

      // Sort by distance (nearest first) and limit to max visible cities.
      // This prevents Safari from choking on too many text labels.
      visibleCities.sort((a, b) => a.distance.compareTo(b.distance));
      final citiesToRender = visibleCities.take(_maxVisibleCities);

      // Render the nearest cities only
      for (final entry in citiesToRender) {
        try {
          final city = entry.city;
          final screenPos = entry.screenPos;

          final dotSize = city.isCapital ? 4.0 : 2.5;
          final paint = city.isCapital ? capitalDotPaint : cityDotPaint;

          // Draw city dot
          canvas.drawCircle(screenPos, dotSize, paint);

          // Draw outline (skip on web for performance)
          if (cityOutlinePaint != null) {
            canvas.drawCircle(screenPos, dotSize, cityOutlinePaint);
          }

          // Get or create cached TextPainter (avoids per-frame allocation).
          final cacheKey = '${city.name}_${city.isCapital}';
          var textPainter = _textCache[cacheKey];
          if (textPainter == null) {
            textPainter = TextPainter(
              text: TextSpan(
                text: city.name,
                style: TextStyle(
                  color: city.isCapital
                      ? FlitColors.textPrimary
                      : FlitColors.textSecondary,
                  fontSize: city.isCapital ? 10 : 8,
                  fontWeight: city.isCapital ? FontWeight.w600 : FontWeight.w400,
                  // Avoid shadows on web - they're expensive in Safari
                  shadows: kIsWeb ? null : const [
                    Shadow(
                      offset: Offset(1, 1),
                      blurRadius: 2,
                      color: Color(0x40000000),
                    ),
                  ],
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            _textCache[cacheKey] = textPainter;
          }

          textPainter.paint(
            canvas,
            Offset(
              screenPos.dx + dotSize + 3,
              screenPos.dy - textPainter.height / 2,
            ),
          );
        } catch (e) {
          // Skip individual city if rendering fails - don't crash the whole overlay.
          continue;
        }
      }
    } catch (e, st) {
      // If city overlay crashes entirely, send to error telemetry.
      // The error service will capture this and send to Vercel if configured.
      // Also log locally for debugging.
      try {
        gameRef.onError?.call(e, st);
      } catch (_) {
        // If even error reporting fails, there's nothing more we can do.
      }
    }
  }

  /// Render major world capitals at high altitude as small labeled dots.
  void _renderHighAltCapitals(Canvas canvas, double altitude) {
    try {
      // Fade in from altitude 0.95 down to 0.6 (fully visible at 0.6-0.85)
      final opacity = altitude > 0.95
          ? (1.0 - altitude) / 0.05
          : altitude < 0.6
              ? 1.0
              : 0.7;

      final dotPaint = Paint()
        ..color = FlitColors.cityCapital.withOpacity(opacity.clamp(0.0, 1.0));

      final centerX = gameRef.size.x / 2;
      final centerY = gameRef.size.y / 2;

      final visible = <({double distance, Offset screenPos, dynamic city})>[];

      for (final city in CountryData.majorCities) {
        if (!city.isCapital || !_majorCapitals.contains(city.name)) continue;

        try {
          // Validate city location
          if (!city.location.x.isFinite ||
              !city.location.y.isFinite) {
            continue;
          }

          final screenPos = gameRef.worldToScreen(city.location);
          if (!screenPos.x.isFinite ||
              !screenPos.y.isFinite ||
              screenPos.x < -20 ||
              screenPos.x > gameRef.size.x + 20 ||
              screenPos.y < -20 ||
              screenPos.y > gameRef.size.y + 20) {
            continue;
          }

          final dx = screenPos.x - centerX;
          final dy = screenPos.y - centerY;
          final distanceSquared = dx * dx + dy * dy;
          
          if (!distanceSquared.isFinite || distanceSquared < 0) {
            continue;
          }
          
          visible.add((
            distance: math.sqrt(distanceSquared),
            screenPos: Offset(screenPos.x, screenPos.y),
            city: city,
          ));
        } catch (_) {
          continue;
        }
      }

      visible.sort((a, b) => a.distance.compareTo(b.distance));

      for (final entry in visible.take(_maxHighAltCapitals)) {
        try {
          canvas.drawCircle(entry.screenPos, 3.0, dotPaint);

          // Small label for high altitude capitals
          final cacheKey = '${entry.city.name}_hialt';
          var tp = _textCache[cacheKey];
          if (tp == null) {
            tp = TextPainter(
              text: TextSpan(
                text: entry.city.name,
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 7,
                  fontWeight: FontWeight.w500,
                  shadows: kIsWeb
                      ? null
                      : [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 2,
                            color: Color(0x60000000),
                          ),
                        ],
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            _textCache[cacheKey] = tp;
          }
          tp.paint(canvas, Offset(entry.screenPos.dx + 5, entry.screenPos.dy - tp.height / 2));
        } catch (_) {
          continue;
        }
      }
    } catch (_) {
      // Silently fail — don't crash the game for high-alt labels.
    }
  }
}
