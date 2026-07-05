import 'dart:math';

import 'package:flame/components.dart';

/// Degrees-to-radians conversion constant.
const double deg2rad = pi / 180.0;

/// Radians-to-degrees conversion constant.
const double rad2deg = 180.0 / pi;

/// Kilometres per degree of great-circle arc (mean Earth radius).
const double kmPerDegree = 111.195;

/// Great-circle angular distance between two (lng, lat) points, in degrees.
double greatCircleDistDeg(Vector2 a, Vector2 b) {
  final lat1 = a.y * deg2rad;
  final lat2 = b.y * deg2rad;
  final dLat = (b.y - a.y) * deg2rad;
  final dLng = (b.x - a.x) * deg2rad;

  final h = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
  final c = 2 * atan2(sqrt(h), sqrt(1 - h));
  return c * rad2deg;
}

/// Great-circle distance between two (lng, lat) points, in kilometres.
double greatCircleKm(Vector2 a, Vector2 b) =>
    greatCircleDistDeg(a, b) * kmPerDegree;

/// Initial great-circle bearing from [from] to [to], in radians.
///
/// Points are (lng, lat) in degrees. Result is a navigation bearing:
/// 0 = north, positive clockwise, in the range (-pi, pi].
double initialBearingRad(Vector2 from, Vector2 to) {
  final lat1 = from.y * deg2rad;
  final lng1 = from.x * deg2rad;
  final lat2 = to.y * deg2rad;
  final lng2 = to.x * deg2rad;
  final dLng = lng2 - lng1;

  final y = sin(dLng) * cos(lat2);
  final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
  return atan2(y, x);
}

/// Initial great-circle bearing from [from] to [to], in compass degrees.
///
/// Points are (lng, lat) in degrees. Result is normalised to [0, 360):
/// 0 = north, 90 = east, 180 = south, 270 = west.
double initialBearingDeg(Vector2 from, Vector2 to) {
  final deg = initialBearingRad(from, to) * rad2deg;
  return (deg % 360 + 360) % 360;
}

/// Flat-map bearing from [from] to [to], in compass degrees normalised
/// to [0, 360).
///
/// This is the direction as drawn on a standard Greenwich-centred world
/// map (Mercator vertical scale), with NO antimeridian shortcut: Russia
/// reads east of the USA and Japan east of California even when crossing
/// the ±180° line would be shorter. Players reason on the flat map, so
/// game bearings must match it — a great-circle initial bearing can cross
/// near a pole (Colombo→Mexico City reads "north"), and a true rhumb line
/// takes the short way around the antimeridian; both violate map sense.
double flatMapBearingDeg(Vector2 from, Vector2 to) {
  final lat1 = from.y * deg2rad;
  final lat2 = to.y * deg2rad;
  // Raw longitude difference — the on-map horizontal direction.
  final dLng = (to.x - from.x) * deg2rad;

  final dPsi = log(tan(pi / 4 + lat2 / 2) / tan(pi / 4 + lat1 / 2));
  final deg = atan2(dLng, dPsi) * rad2deg;
  return (deg % 360 + 360) % 360;
}

/// Points along the great-circle (shortest) route from [from] to [to],
/// as (lng, lat) degrees — spherical linear interpolation on the unit
/// sphere. Used to draw the "optimal route" overlay on reveal maps; the
/// polyline may cross the antimeridian (renderers split it there).
List<Vector2> greatCirclePoints(Vector2 from, Vector2 to, {int samples = 48}) {
  Vector3 toXyz(Vector2 lngLat) {
    final lng = lngLat.x * deg2rad;
    final lat = lngLat.y * deg2rad;
    return Vector3(cos(lat) * cos(lng), cos(lat) * sin(lng), sin(lat));
  }

  final a = toXyz(from);
  final b = toXyz(to);
  final angle = acos(a.dot(b).clamp(-1.0, 1.0));
  if (angle < 1e-6) return [from.clone(), to.clone()];

  final sinAngle = sin(angle);
  return [
    for (var i = 0; i <= samples; i++)
      () {
        final t = i / samples;
        final w1 = sin((1 - t) * angle) / sinAngle;
        final w2 = sin(t * angle) / sinAngle;
        final p = a * w1 + b * w2;
        return Vector2(
            atan2(p.y, p.x) * rad2deg, asin(p.z.clamp(-1.0, 1.0)) * rad2deg);
      }(),
  ];
}
