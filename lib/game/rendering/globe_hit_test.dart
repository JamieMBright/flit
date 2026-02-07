import 'dart:math';

import 'package:flutter/painting.dart';

import 'camera_state.dart';

/// Utility class for converting screen coordinates to globe (lat/lng)
/// coordinates and performing geographic hit-testing.
///
/// Implements the inverse of the perspective projection used by the globe
/// fragment shader so that screen taps can be mapped to geographic
/// positions on the sphere.
class GlobeHitTest {
  const GlobeHitTest();

  /// Convert a screen point to latitude/longitude on the globe.
  ///
  /// Returns an [Offset] where dx = longitude (degrees) and dy = latitude
  /// (degrees), or null if the ray from the camera through the screen
  /// point misses the globe entirely.
  ///
  /// The projection math mirrors what the fragment shader does:
  /// 1. Screen point -> Normalized Device Coordinates (NDC)
  /// 2. NDC -> ray direction in world space (inverse perspective)
  /// 3. Ray-sphere intersection test
  /// 4. Hit point -> latitude/longitude
  ///
  /// [screenPoint] - tap position in screen pixels (origin top-left).
  /// [screenSize]  - viewport dimensions in pixels.
  /// [camera]      - current camera state (position, target, FOV).
  Offset? screenToLatLng(
    Offset screenPoint,
    Size screenSize,
    CameraState camera,
  ) {
    if (screenSize.isEmpty) return null;

    // -- Step 1: Screen -> NDC --
    // Map pixel coordinates to [-1, 1] range.
    // x: left=-1, right=+1; y: top=+1, bottom=-1 (flip y).
    final aspect = screenSize.width / screenSize.height;
    final ndcX = (2.0 * screenPoint.dx / screenSize.width - 1.0) * aspect;
    final ndcY = 1.0 - 2.0 * screenPoint.dy / screenSize.height;

    // -- Step 2: NDC -> ray direction --
    // Use the camera's FOV to determine the view-plane distance.
    final fovScale = tan(camera.fov / 2.0);
    final rayDirLocalX = ndcX * fovScale;
    final rayDirLocalY = ndcY * fovScale;
    const rayDirLocalZ = -1.0; // looking into the screen

    // Build camera basis vectors (right, up, forward) from camera position
    // and heading-aligned up vector. The camera always looks at the origin.
    final camX = camera.cameraX;
    final camY = camera.cameraY;
    final camZ = camera.cameraZ;

    // Forward = normalize(target - cameraPos) = normalize(-cameraPos)
    final fwdX = -camX;
    final fwdY = -camY;
    final fwdZ = -camZ;
    final fwdLen = sqrt(fwdX * fwdX + fwdY * fwdY + fwdZ * fwdZ);
    if (fwdLen < 1e-8) return null;
    final fX = fwdX / fwdLen;
    final fY = fwdY / fwdLen;
    final fZ = fwdZ / fwdLen;

    // Use the heading-aligned up vector from CameraState (matches shader).
    final cupX = camera.upX;
    final cupY = camera.upY;
    final cupZ = camera.upZ;

    // Right = normalize(cross(forward, camUp))
    var rX = fY * cupZ - fZ * cupY;
    var rY = fZ * cupX - fX * cupZ;
    var rZ = fX * cupY - fY * cupX;

    final rLen = sqrt(rX * rX + rY * rY + rZ * rZ);
    if (rLen < 1e-8) {
      // Degenerate: forward and up are parallel. Fall back to world up.
      rX = fY * 0.0 - fZ * 1.0;
      rY = fZ * 0.0 - fX * 0.0;
      rZ = fX * 1.0 - fY * 0.0;
      final rLen2 = sqrt(rX * rX + rY * rY + rZ * rZ);
      if (rLen2 < 1e-8) return null;
      rX /= rLen2;
      rY /= rLen2;
      rZ /= rLen2;
    } else {
      rX /= rLen;
      rY /= rLen;
      rZ /= rLen;
    }

    // Up = cross(right, forward)
    final uX = rY * fZ - rZ * fY;
    final uY = rZ * fX - rX * fZ;
    final uZ = rX * fY - rY * fX;

    // Transform local ray direction to world space.
    // rayWorld = right * localX + up * localY + forward * (-localZ)
    // (localZ is -1, so forward * 1)
    final rwX = rX * rayDirLocalX + uX * rayDirLocalY + fX * (-rayDirLocalZ);
    final rwY = rY * rayDirLocalX + uY * rayDirLocalY + fY * (-rayDirLocalZ);
    final rwZ = rZ * rayDirLocalX + uZ * rayDirLocalY + fZ * (-rayDirLocalZ);

    // Normalize the world-space ray direction.
    final rwLen = sqrt(rwX * rwX + rwY * rwY + rwZ * rwZ);
    if (rwLen < 1e-8) return null;
    final dX = rwX / rwLen;
    final dY = rwY / rwLen;
    final dZ = rwZ / rwLen;

    // -- Step 3: Ray-sphere intersection --
    // Sphere: center = origin, radius = globeRadius (1.0).
    // Ray: P(t) = cam + t * d
    // |P(t)|^2 = r^2
    // t^2 * (d.d) + 2t * (cam.d) + (cam.cam - r^2) = 0
    const r = CameraState.globeRadius;
    final a = dX * dX + dY * dY + dZ * dZ; // always ~1 if normalized
    final b = 2.0 * (camX * dX + camY * dY + camZ * dZ);
    final c = camX * camX + camY * camY + camZ * camZ - r * r;

    final discriminant = b * b - 4.0 * a * c;
    if (discriminant < 0.0) {
      // Ray misses the globe.
      return null;
    }

    // Take the nearest positive intersection.
    final sqrtDisc = sqrt(discriminant);
    final t1 = (-b - sqrtDisc) / (2.0 * a);
    final t2 = (-b + sqrtDisc) / (2.0 * a);
    final t = (t1 > 0.0) ? t1 : t2;
    if (t < 0.0) return null; // globe is behind camera

    // -- Step 4: Hit point -> lat/lng --
    final hitX = camX + t * dX;
    final hitY = camY + t * dY;
    final hitZ = camZ + t * dZ;

    // Convert cartesian to spherical (matching CameraState convention):
    // y = sin(lat), x = cos(lat)*cos(lng), z = cos(lat)*sin(lng)
    final lat = asin(hitY.clamp(-1.0, 1.0));
    final lng = atan2(hitZ, hitX);

    // Return as degrees: dx = longitude, dy = latitude.
    return Offset(lng * 180.0 / pi, lat * 180.0 / pi);
  }

  /// Test whether a geographic point lies inside a polygon using the
  /// ray casting (crossing number) algorithm.
  ///
  /// [lat] and [lng] are in degrees.
  /// [polygon] is a list of [Offset] where dx = longitude, dy = latitude,
  /// matching the format used by [CountryData.countries].
  ///
  /// Returns true if the point is inside the polygon.
  bool isPointInPolygon(double lat, double lng, List<Offset> polygon) {
    if (polygon.length < 3) return false;

    var inside = false;
    final n = polygon.length;

    // Ray casting: cast a horizontal ray from (lng, lat) to the right
    // and count how many polygon edges it crosses.
    for (var i = 0, j = n - 1; i < n; j = i++) {
      final yi = polygon[i].dy; // latitude of vertex i
      final xi = polygon[i].dx; // longitude of vertex i
      final yj = polygon[j].dy;
      final xj = polygon[j].dx;

      // Check if the ray crosses this edge.
      final crossesEdge = ((yi > lat) != (yj > lat)) &&
          (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi);

      if (crossesEdge) {
        inside = !inside;
      }
    }

    return inside;
  }

  /// Great-circle angular distance between two points in degrees.
  ///
  /// Uses the Haversine formula for numerical stability.
  /// [lat1], [lng1], [lat2], [lng2] are all in degrees.
  double greatCircleDistDeg(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const deg2rad = pi / 180.0;
    const rad2deg = 180.0 / pi;

    final lat1r = lat1 * deg2rad;
    final lat2r = lat2 * deg2rad;
    final dLat = (lat2 - lat1) * deg2rad;
    final dLng = (lng2 - lng1) * deg2rad;

    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1r) * cos(lat2r) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(h), sqrt(1 - h));
    return c * rad2deg;
  }
}
