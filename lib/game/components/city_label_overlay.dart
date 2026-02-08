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

      // Only show cities at low altitude.
      if (gameRef.isHighAltitude) return;

      final cityDotPaint = Paint()..color = FlitColors.city;
      final capitalDotPaint = Paint()..color = FlitColors.cityCapital;
      final cityOutlinePaint = Paint()
        ..color = FlitColors.shadow
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
            Offset(
              screenPos.x + dotSize + 3,
              screenPos.y - textPainter.height / 2,
            ),
          );
        } catch (e) {
          // Skip individual city if rendering fails - don't crash the whole overlay.
          continue;
        }
      }
    } catch (e, st) {
      // If city overlay crashes entirely, log but don't crash the game.
      // The error service will capture this for telemetry.
      gameRef.onError?.call(e, st);
    }
  }
}
