import 'package:flame/components.dart';
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
      final cityOutlinePaint = Paint()
        ..color = FlitColors.shadow.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;

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

          final dotSize = city.isCapital ? 4.0 : 2.5;
          final paint = city.isCapital ? capitalDotPaint : cityDotPaint;

          canvas.drawCircle(Offset(screenPos.x, screenPos.y), dotSize, paint);
          canvas.drawCircle(
              Offset(screenPos.x, screenPos.y), dotSize, cityOutlinePaint);

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
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          textPainter.paint(
            canvas,
            Offset(
              screenPos.x + dotSize + 3,
              screenPos.y - textPainter.height / 2,
            ),
          );
        } catch (e) {
          // Skip individual city if rendering fails - don't crash the whole overlay.
          // Log for debugging but don't break the rendering loop.
          gameRef.onError?.call(
            'City label render failed for ${city.name}',
            StackTrace.current,
          );
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
