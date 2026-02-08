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
  /// Maximum number of cities to render at once (Safari performance).
  static const int _maxVisibleCities = 20;

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    try {
      // Skip when using Canvas renderer — WorldMap renders cities directly.
      if (!gameRef.isShaderActive) return;

      // Get continuous altitude from plane (0.0 = low, 1.0 = high)
      final continuousAlt = gameRef.plane.continuousAltitude;

      // Only show cities at lower altitudes (< 0.6)
      // Fade in as altitude decreases below 0.6
      if (continuousAlt >= 0.6) return;

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
          final distance = math.sqrt(dx * dx + dy * dy);

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

          // Render city label with simplified style for web
          final textPainter = TextPainter(
            text: TextSpan(
              text: city.name,
              style: TextStyle(
                color: (city.isCapital
                        ? FlitColors.textPrimary
                        : FlitColors.textSecondary)
                    .withOpacity(opacity),
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
}
