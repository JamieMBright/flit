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
