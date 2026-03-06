import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'city_lights_extracted.dart';

/// Width of the data texture (power-of-2, fits extracted points with headroom).
const int cityLightsDataTexWidth = 2048;

/// Generates a data texture encoding city light positions for the shader.
///
/// Each pixel in the 2048×1 RGBA8888 texture encodes one light source:
///   R = nx * 0.5 + 0.5  (unit sphere normal X)
///   G = ny * 0.5 + 0.5  (unit sphere normal Y)
///   B = nz * 0.5 + 0.5  (unit sphere normal Z)
///   A = intensity        (0 = none, 255 = brightest)
///
/// The shader loops through pixels, decodes the normal, and computes
/// glow falloff per-fragment for resolution-independent city lights.
class CityLightsGenerator {
  CityLightsGenerator._();

  /// Generate the city-lights data texture and return a [ui.Image].
  ///
  /// Uses [extractedCityLights] (auto-extracted from NASA Earth at Night)
  /// as the source of light positions and intensities.
  static Future<ui.Image> generateDataTexture() async {
    final pixels = Uint8List(cityLightsDataTexWidth * 1 * 4); // 2048x1 RGBA

    final count = extractedCityLights.length;
    for (int i = 0; i < count && i < cityLightsDataTexWidth; i++) {
      final entry = extractedCityLights[i];
      final lat = entry[0];
      final lon = entry[1];
      final intensity = entry[2];

      // Convert lat/lon (degrees) to unit sphere normal.
      final latRad = lat * pi / 180.0;
      final lonRad = lon * pi / 180.0;
      final cosLat = cos(latRad);
      final nx = cosLat * cos(lonRad);
      final ny = sin(latRad);
      final nz = cosLat * sin(lonRad);

      // Encode normal components from [-1, 1] to [0, 255].
      final idx = i * 4;
      pixels[idx] = ((nx * 0.5 + 0.5) * 255.0).round().clamp(0, 255);
      pixels[idx + 1] = ((ny * 0.5 + 0.5) * 255.0).round().clamp(0, 255);
      pixels[idx + 2] = ((nz * 0.5 + 0.5) * 255.0).round().clamp(0, 255);
      pixels[idx + 3] = (intensity * 255.0).round().clamp(0, 255);
    }

    // Remaining pixels (count..2048) stay zero — shader skips them (A=0).

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      cityLightsDataTexWidth,
      1,
      ui.PixelFormat.rgba8888,
      (ui.Image image) {
        completer.complete(image);
      },
    );

    return completer.future;
  }
}
