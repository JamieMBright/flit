/// Dithering utilities for preventing color banding in the globe shader.
///
/// Since we are limited to 4 texture samplers per shader pass, the dither
/// pattern is provided as uniform data (a flat list of floats) rather than
/// as a separate sampler texture. The shader can index into this data to
/// apply ordered dithering.
///
/// Usage in GLSL:
/// ```glsl
/// // uDitherMatrix is a uniform float array of 16 values.
/// float dither(vec2 fragCoord) {
///   int x = int(mod(fragCoord.x, 4.0));
///   int y = int(mod(fragCoord.y, 4.0));
///   int index = y * 4 + x;
///   return uDitherMatrix[index];  // value in [0, 1)
/// }
/// ```
abstract class DitherUtil {
  DitherUtil._();

  // ---------------------------------------------------------------------------
  // 4x4 Bayer dither matrix
  // ---------------------------------------------------------------------------

  /// Classic 4x4 Bayer ordered dither matrix, normalized to [0, 1).
  ///
  /// The matrix values are arranged row-major:
  /// ```
  ///  0/16   8/16   2/16  10/16
  /// 12/16   4/16  14/16   6/16
  ///  3/16  11/16   1/16   9/16
  /// 15/16   7/16  13/16   5/16
  /// ```
  ///
  /// To use: subtract 0.5 and scale to desired dither amplitude, then add
  /// to the color before quantization.
  static const List<double> bayerMatrix4x4 = <double>[
    0.0 / 16.0, 8.0 / 16.0, 2.0 / 16.0, 10.0 / 16.0, //
    12.0 / 16.0, 4.0 / 16.0, 14.0 / 16.0, 6.0 / 16.0, //
    3.0 / 16.0, 11.0 / 16.0, 1.0 / 16.0, 9.0 / 16.0, //
    15.0 / 16.0, 7.0 / 16.0, 13.0 / 16.0, 5.0 / 16.0, //
  ];

  // ---------------------------------------------------------------------------
  // 8x8 Bayer dither matrix
  // ---------------------------------------------------------------------------

  /// 8x8 Bayer ordered dither matrix, normalized to [0, 1).
  ///
  /// Provides finer dithering at the cost of 64 uniform floats.
  /// Use when the 4x4 pattern becomes visually obvious.
  static const List<double> bayerMatrix8x8 = <double>[
    0.0 / 64.0, 32.0 / 64.0, 8.0 / 64.0, 40.0 / 64.0,
    2.0 / 64.0, 34.0 / 64.0, 10.0 / 64.0, 42.0 / 64.0, //
    48.0 / 64.0, 16.0 / 64.0, 56.0 / 64.0, 24.0 / 64.0,
    50.0 / 64.0, 18.0 / 64.0, 58.0 / 64.0, 26.0 / 64.0, //
    12.0 / 64.0, 44.0 / 64.0, 4.0 / 64.0, 36.0 / 64.0,
    14.0 / 64.0, 46.0 / 64.0, 6.0 / 64.0, 38.0 / 64.0, //
    60.0 / 64.0, 28.0 / 64.0, 52.0 / 64.0, 20.0 / 64.0,
    62.0 / 64.0, 30.0 / 64.0, 54.0 / 64.0, 22.0 / 64.0, //
    3.0 / 64.0, 35.0 / 64.0, 11.0 / 64.0, 43.0 / 64.0,
    1.0 / 64.0, 33.0 / 64.0, 9.0 / 64.0, 41.0 / 64.0, //
    51.0 / 64.0, 19.0 / 64.0, 59.0 / 64.0, 27.0 / 64.0,
    49.0 / 64.0, 17.0 / 64.0, 57.0 / 64.0, 25.0 / 64.0, //
    15.0 / 64.0, 47.0 / 64.0, 7.0 / 64.0, 39.0 / 64.0,
    13.0 / 64.0, 45.0 / 64.0, 5.0 / 64.0, 37.0 / 64.0, //
    63.0 / 64.0, 31.0 / 64.0, 55.0 / 64.0, 23.0 / 64.0,
    61.0 / 64.0, 29.0 / 64.0, 53.0 / 64.0, 21.0 / 64.0, //
  ];

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns the dither threshold for a given screen-space pixel coordinate
  /// using the 4x4 Bayer matrix.
  ///
  /// Useful for Dart-side post-processing or CPU fallback.
  static double threshold4x4(int x, int y) {
    final ix = x % 4;
    final iy = y % 4;
    return bayerMatrix4x4[iy * 4 + ix];
  }

  /// Returns the dither threshold for a given screen-space pixel coordinate
  /// using the 8x8 Bayer matrix.
  static double threshold8x8(int x, int y) {
    final ix = x % 8;
    final iy = y % 8;
    return bayerMatrix8x8[iy * 8 + ix];
  }

  /// Returns the signed dither offset (range [-amplitude, +amplitude]) for
  /// the given pixel, using the 4x4 matrix.
  ///
  /// [amplitude] controls the strength; 1.0/255.0 is a good default for
  /// 8-bit color to break up banding by exactly one code value.
  static double signedOffset4x4(int x, int y, {double amplitude = 1.0 / 255.0}) {
    // Map [0, 1) to [-0.5, 0.5) then scale by amplitude.
    return (threshold4x4(x, y) - 0.5) * 2.0 * amplitude;
  }
}
