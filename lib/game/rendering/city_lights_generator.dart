import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'city_lights_data.dart';

/// Generates a procedural city-lights texture from [cityLightClusters].
///
/// Instead of loading the NASA Earth-at-Night PNG, this builds a small
/// equirectangular image at runtime where each city is rendered as a warm
/// glow dot with radial falloff. The result can be bound to the shader's
/// `uCityLights` sampler.
class CityLightsGenerator {
  CityLightsGenerator._();

  /// Texture dimensions — small is fine since glow dots are low-frequency.
  static const int _width = 1024;
  static const int _height = 512;

  /// Glow radius in pixels (at the texture resolution).
  static const double _baseGlowRadius = 8.0;

  /// Generate the city-lights texture and return a [ui.Image].
  static Future<ui.Image> generate() async {
    final pixels = Uint8List(_width * _height * 4); // RGBA

    // For each city, stamp a glow dot into the pixel buffer.
    for (final city in cityLightClusters) {
      final lat = city[0];
      final lng = city[1];
      final intensity = city[2];

      // Lat/lon → equirectangular pixel coordinates.
      // u = (lng + 180) / 360, v = (90 - lat) / 180
      final cx = ((lng + 180.0) / 360.0 * _width).round();
      final cy = ((90.0 - lat) / 180.0 * _height).round();

      // Scale glow radius by intensity so bigger cities glow wider.
      final radius = _baseGlowRadius * (0.6 + 0.4 * intensity);
      final radiusSq = radius * radius;
      final ri = radius.ceil();

      // Warm city-light tint: amber-orange bias.
      final r0 = (255 * intensity).round().clamp(0, 255);
      final g0 = (200 * intensity).round().clamp(0, 255);
      final b0 = (120 * intensity).round().clamp(0, 255);

      for (int dy = -ri; dy <= ri; dy++) {
        final py = cy + dy;
        if (py < 0 || py >= _height) continue;

        for (int dx = -ri; dx <= ri; dx++) {
          // Wrap horizontally for seamless equirectangular.
          var px = (cx + dx) % _width;
          if (px < 0) px += _width;

          final distSq = (dx * dx + dy * dy).toDouble();
          if (distSq > radiusSq) continue;

          // Smooth radial falloff (quadratic, looks like a soft glow).
          final t = 1.0 - distSq / radiusSq;
          final glow = t * t; // quadratic falloff

          final idx = (py * _width + px) * 4;

          // Additive blend — accumulates where cities overlap.
          final nr = (pixels[idx] + (r0 * glow).round()).clamp(0, 255);
          final ng = (pixels[idx + 1] + (g0 * glow).round()).clamp(0, 255);
          final nb = (pixels[idx + 2] + (b0 * glow).round()).clamp(0, 255);
          final na = (pixels[idx + 3] + (255 * glow).round()).clamp(0, 255);

          pixels[idx] = nr;
          pixels[idx + 1] = ng;
          pixels[idx + 2] = nb;
          pixels[idx + 3] = na;
        }
      }
    }

    // Apply a second pass: slight blur to soften hard edges.
    // Skip for performance — the quadratic falloff already looks smooth.

    // Decode pixels into a ui.Image.
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(pixels, _width, _height, ui.PixelFormat.rgba8888, (
      ui.Image image,
    ) {
      completer.complete(image);
    });

    return completer.future;
  }
}
