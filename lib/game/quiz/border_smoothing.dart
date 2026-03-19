import 'dart:ui';

/// Chaikin's corner-cutting algorithm for polygon smoothing.
///
/// Each iteration replaces sharp corners with smoother curves by inserting
/// 25% and 75% interpolation points between consecutive vertices.
/// Two iterations is sufficient for visually smooth borders without
/// excessive vertex count.
///
/// This is used by all map renderers (Uncharted, Flight School US,
/// Flight School regions) to ensure consistent border quality.
List<Offset> chaikinSmooth(List<Offset> points, [int iterations = 2]) {
  if (points.length < 3) return points;
  // Strip duplicate closure point (many polygons repeat the first vertex at
  // the end to explicitly close the ring). The algorithm already handles
  // closure via modular indexing, so keeping the duplicate creates a
  // zero-length edge that produces a visible "bump" at the seam.
  var current = points;
  if (current.length > 3 &&
      (current.first.dx - current.last.dx).abs() < 1e-6 &&
      (current.first.dy - current.last.dy).abs() < 1e-6) {
    current = current.sublist(0, current.length - 1);
  }
  for (var iter = 0; iter < iterations; iter++) {
    final next = <Offset>[];
    for (var i = 0; i < current.length; i++) {
      final p0 = current[i];
      final p1 = current[(i + 1) % current.length];
      // 25% and 75% interpolation points.
      next.add(Offset(
        p0.dx * 0.75 + p1.dx * 0.25,
        p0.dy * 0.75 + p1.dy * 0.25,
      ));
      next.add(Offset(
        p0.dx * 0.25 + p1.dx * 0.75,
        p0.dy * 0.25 + p1.dy * 0.75,
      ));
    }
    current = next;
  }
  return current;
}

/// ISO codes for true micro-states and scattered tiny archipelagos that are
/// always treated as "tiny" on map views regardless of zoom level.
///
/// ONLY includes countries that are genuinely invisible at world/region zoom:
/// city-states (< 1,000 km²) and scattered atolls with no single landmass
/// large enough to render as a polygon.
///
/// Everything else — even small countries like Gambia, Mauritius, Dominica,
/// Barbados, etc. — should render as full polygons when zoomed in. The
/// dynamic `_isTinyArea()` check in each map widget handles them at low zoom
/// by falling back to a bounding-box marker only when the polygon is
/// literally too small to see on screen.
///
/// Shared across all map renderers so that tiny-area handling is consistent.
const Set<String> alwaysTinyCodes = {
  // European micro-states (city-states / < 500 km²)
  'GI', // Gibraltar (6.8 km²)
  'MC', // Monaco (2.0 km²)
  'SM', // San Marino (61 km²)
  'VA', // Vatican City (0.44 km²)

  // City-states
  'SG', // Singapore (733 km²)

  // Scattered atolls — no single island large enough to render
  'MV', // Maldives (scattered atolls, largest < 6 km²)
  'SC', // Seychelles (scattered, largest 157 km²)
  'MH', // Marshall Islands (scattered atolls)
  'TV', // Tuvalu (26 km² total, scattered)
  'NR', // Nauru (21 km²)
  'PW', // Palau (459 km², scattered)
  'KI', // Kiribati (scattered atolls across 3.5M km² of ocean)
  'FM', // Micronesia (scattered across 2.6M km² of ocean)

  // Tiny Caribbean islands (< 350 km², single small islands)
  'AG', // Antigua and Barbuda (440 km² but two tiny islands)
  'KN', // Saint Kitts and Nevis (261 km², two tiny islands)
  'GD', // Grenada (344 km²)
  'VC', // Saint Vincent and the Grenadines (389 km², scattered)

  // Tiny African islands
  'ST', // São Tomé and Príncipe (1,001 km² but two small islands)
};
