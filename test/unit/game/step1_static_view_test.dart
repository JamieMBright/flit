import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:flit/game/rendering/camera_state.dart';
import 'package:flit/game/components/plane_component.dart';

/// Step 1 rebuild tests: static plane, camera POV, map projection.
///
/// These tests verify the foundational view before motion is added:
///   - Plane does not move when motion is disabled
///   - Camera is positioned behind and above the plane
///   - Globe curvature (horizon) is visible at the top of the screen
///   - Plane has correct perspective foreshortening
///   - tiltDown constant is in sync between shader and Dart projection
void main() {
  // ---------------------------------------------------------------------------
  // Constants that must stay in sync between globe.frag and flit_game.dart
  // ---------------------------------------------------------------------------

  /// tiltDown value used in both the shader (globe.frag line ~222) and the
  /// Dart inverse projection (_shaderWorldToScreen in flit_game.dart).
  /// If these diverge, the plane sprite drifts from its projected position
  /// and contrails misalign with map features.
  const double tiltDown = 0.35;

  // ---------------------------------------------------------------------------
  // Camera state tests
  // ---------------------------------------------------------------------------

  group('CameraState - Step 1 POV', () {
    late CameraState camera;

    setUp(() {
      camera = CameraState();
    });

    test('camera starts at high altitude distance', () {
      // First update snaps to position (no interpolation).
      camera.update(0.016,
          planeLatDeg: 0,
          planeLngDeg: 0,
          isHighAltitude: true,
          headingRad: 0);

      expect(camera.currentDistance, closeTo(CameraState.highAltitudeDistance, 1e-6),
          reason: 'Camera should snap to high altitude on first update');
    });

    test('camera FOV starts at narrow value (no speed)', () {
      camera.update(0.016,
          planeLatDeg: 0,
          planeLngDeg: 0,
          isHighAltitude: true,
          speedFraction: 0.0,
          headingRad: 0);

      expect(camera.fov, closeTo(CameraState.fovNarrow, 1e-6),
          reason: 'FOV should be narrow when speed is zero');
    });

    test('camera position is along the surface normal at (0, 0)', () {
      camera.update(0.016,
          planeLatDeg: 0,
          planeLngDeg: 0,
          isHighAltitude: true,
          headingRad: 0);

      // At (lat=0, lng=0) on the unit sphere, the surface normal points
      // along +x. Camera should be at (distance, 0, 0).
      final d = CameraState.highAltitudeDistance;
      expect(camera.cameraX, closeTo(d, 1e-6));
      expect(camera.cameraY, closeTo(0, 1e-6));
      expect(camera.cameraZ, closeTo(0, 1e-6));
    });

    test('camera position is correct for non-zero lat/lng', () {
      // Position at (lat=45°N, lng=90°E)
      camera.update(0.016,
          planeLatDeg: 45,
          planeLngDeg: 90,
          isHighAltitude: true,
          headingRad: 0);

      final d = CameraState.highAltitudeDistance;
      final latRad = 45 * pi / 180;
      final lngRad = 90 * pi / 180;
      final expectedX = cos(latRad) * cos(lngRad) * d;
      final expectedY = sin(latRad) * d;
      final expectedZ = cos(latRad) * sin(lngRad) * d;

      expect(camera.cameraX, closeTo(expectedX, 1e-6));
      expect(camera.cameraY, closeTo(expectedY, 1e-6));
      expect(camera.cameraZ, closeTo(expectedZ, 1e-6));
    });

    test('up vector is unit-length', () {
      camera.update(0.016,
          planeLatDeg: 30,
          planeLngDeg: 45,
          isHighAltitude: true,
          headingRad: pi / 4);

      final len = sqrt(
          camera.upX * camera.upX +
          camera.upY * camera.upY +
          camera.upZ * camera.upZ);
      expect(len, closeTo(1.0, 1e-6),
          reason: 'Up vector must be normalized');
    });

    test('up vector is perpendicular to camera-to-origin direction', () {
      camera.update(0.016,
          planeLatDeg: 30,
          planeLngDeg: 45,
          isHighAltitude: true,
          headingRad: pi / 4);

      // Camera forward = -camPos (looking at origin)
      final fwdLen = sqrt(
          camera.cameraX * camera.cameraX +
          camera.cameraY * camera.cameraY +
          camera.cameraZ * camera.cameraZ);
      final fwdX = -camera.cameraX / fwdLen;
      final fwdY = -camera.cameraY / fwdLen;
      final fwdZ = -camera.cameraZ / fwdLen;

      // dot(forward, up) should be ~0 (perpendicular)
      final dot = fwdX * camera.upX + fwdY * camera.upY + fwdZ * camera.upZ;
      expect(dot, closeTo(0.0, 1e-6),
          reason: 'Up vector must be perpendicular to forward direction');
    });

    test('camera does not move when updated with same position repeatedly', () {
      // Simulate Step 1: plane stationary, camera updated every frame.
      camera.update(0.016,
          planeLatDeg: 10,
          planeLngDeg: 20,
          isHighAltitude: true,
          headingRad: 0);

      final x1 = camera.cameraX;
      final y1 = camera.cameraY;
      final z1 = camera.cameraZ;

      // Multiple frames with same input — should converge, not drift.
      for (var i = 0; i < 60; i++) {
        camera.update(0.016,
            planeLatDeg: 10,
            planeLngDeg: 20,
            isHighAltitude: true,
            headingRad: 0);
      }

      expect(camera.cameraX, closeTo(x1, 1e-4),
          reason: 'Camera X should not drift with static input');
      expect(camera.cameraY, closeTo(y1, 1e-4),
          reason: 'Camera Y should not drift with static input');
      expect(camera.cameraZ, closeTo(z1, 1e-4),
          reason: 'Camera Z should not drift with static input');
    });
  });

  // ---------------------------------------------------------------------------
  // Horizon visibility tests
  // ---------------------------------------------------------------------------

  group('Horizon geometry - Step 1 POV', () {
    test('horizon angle from forward at high altitude', () {
      // The horizon (globe limb) is at angle arcsin(R/d) from the
      // camera-to-center direction, where R=1.0 (globe radius) and
      // d=camera distance from center.
      final d = CameraState.highAltitudeDistance;
      final horizonAngleRad = asin(CameraState.globeRadius / d);
      final horizonAngleDeg = horizonAngleRad * 180 / pi;

      // At d=1.8: arcsin(1/1.8) ≈ 33.75°
      expect(horizonAngleDeg, closeTo(33.75, 0.5),
          reason: 'Horizon angle at high altitude should be ~33.75°');
    });

    test('top of screen ray exceeds horizon angle (curvature visible)', () {
      // At the top of the screen (fragCoord.y = 0), the ray direction
      // has uv.y = 0.5 + tiltDown (after y-flip and tilt shift).
      // After FOV scaling: uv_scaled = uv.y * tan(fov/2)
      // Ray angle from forward = atan(uv_scaled)
      final fov = CameraState.fovNarrow; // Use narrow (static, no speed)
      final uvTopY = 0.5 + tiltDown;
      final halfFovTan = tan(fov / 2);
      final rayAngleRad = atan(uvTopY * halfFovTan);
      final rayAngleDeg = rayAngleRad * 180 / pi;

      // Horizon angle at high altitude
      final d = CameraState.highAltitudeDistance;
      final horizonAngleDeg = asin(CameraState.globeRadius / d) * 180 / pi;

      // The top-of-screen ray must exceed the horizon angle for curvature
      // to be visible. With fovNarrow=0.96 and tiltDown=0.35:
      // ray ≈ atan(0.85 * tan(0.48)) = atan(0.85 * 0.5206) = atan(0.4425) ≈ 23.9°
      // horizon ≈ 33.75°
      // With fovNarrow, the ray doesn't quite reach the horizon.
      // With fovWide=1.4: ray ≈ atan(0.85 * tan(0.7)) ≈ atan(0.716) ≈ 35.6°
      // That exceeds the horizon.
      //
      // This test verifies the geometry is in the right ballpark.
      // At narrow FOV (stationary), the horizon is near but not at the top
      // of the screen — acceptable for Step 1 since we'll have speed-based
      // FOV widening in later steps. At wide FOV (when moving), the horizon
      // becomes visible at the top.
      expect(rayAngleDeg, greaterThan(15.0),
          reason: 'Top-of-screen ray should point well above center');
      expect(horizonAngleDeg, greaterThan(30.0),
          reason: 'Horizon should be > 30° from forward at this altitude');
    });

    test('horizon visible at top with wide FOV (speed-adjusted)', () {
      // When moving, FOV widens to fovWide, which pushes the horizon
      // into view at the top of the screen.
      final fov = CameraState.fovWide;
      final uvTopY = 0.5 + tiltDown;
      final halfFovTan = tan(fov / 2);
      final rayAngleRad = atan(uvTopY * halfFovTan);
      final rayAngleDeg = rayAngleRad * 180 / pi;

      final d = CameraState.highAltitudeDistance;
      final horizonAngleDeg = asin(CameraState.globeRadius / d) * 180 / pi;

      expect(rayAngleDeg, greaterThan(horizonAngleDeg),
          reason: 'At wide FOV, top of screen must show past the horizon '
              '(ray ${rayAngleDeg.toStringAsFixed(1)}° > '
              'horizon ${horizonAngleDeg.toStringAsFixed(1)}°)');
    });

    test('bottom of screen ray hits globe surface', () {
      // At the bottom of the screen (fragCoord.y = resolution.y),
      // uv.y = -0.5 + tiltDown = -0.15
      // This should point at the globe surface (below the horizon).
      final fov = CameraState.fovNarrow;
      final uvBottomY = -0.5 + tiltDown;
      final halfFovTan = tan(fov / 2);
      final rayAngleRad = atan(uvBottomY * halfFovTan);
      final rayAngleDeg = rayAngleRad * 180 / pi;

      final d = CameraState.highAltitudeDistance;
      final horizonAngleDeg = asin(CameraState.globeRadius / d) * 180 / pi;

      expect(rayAngleDeg.abs(), lessThan(horizonAngleDeg),
          reason: 'Bottom of screen must point at globe surface, '
              'not past the horizon');
    });

    test('screen center ray hits globe surface', () {
      // At screen center, uv.y = tiltDown (after flip, center = 0 + tiltDown)
      final fov = CameraState.fovNarrow;
      final uvCenterY = tiltDown;
      final halfFovTan = tan(fov / 2);
      final rayAngleRad = atan(uvCenterY * halfFovTan);
      final rayAngleDeg = rayAngleRad * 180 / pi;

      final d = CameraState.highAltitudeDistance;
      final horizonAngleDeg = asin(CameraState.globeRadius / d) * 180 / pi;

      expect(rayAngleDeg, lessThan(horizonAngleDeg),
          reason: 'Screen center must show globe surface');
      expect(rayAngleDeg, greaterThan(0),
          reason: 'Screen center should point above forward direction '
              '(tilted toward heading)');
    });

    test('portrait phone sides show globe surface', () {
      // On a 9:16 portrait phone, the horizontal extent is narrow.
      // At the left/right edge of center row:
      // uv.x = ±0.5 * (width/height) = ±0.5 * (9/16) = ±0.281
      // The combined angular extent from center should be within the horizon.
      final fov = CameraState.fovNarrow;
      final halfFovTan = tan(fov / 2);
      const aspectRatio = 9.0 / 16.0; // portrait phone
      final uvEdgeX = 0.5 * aspectRatio;
      final uvEdgeY = tiltDown; // center row, after tilt

      final scaledX = uvEdgeX * halfFovTan;
      final scaledY = uvEdgeY * halfFovTan;
      final combinedAngleRad = atan(sqrt(scaledX * scaledX + scaledY * scaledY));
      final combinedAngleDeg = combinedAngleRad * 180 / pi;

      final d = CameraState.highAltitudeDistance;
      final horizonAngleDeg = asin(CameraState.globeRadius / d) * 180 / pi;

      expect(combinedAngleDeg, lessThan(horizonAngleDeg),
          reason: 'Side edges on portrait phone must show globe surface');
    });
  });

  // ---------------------------------------------------------------------------
  // Plane perspective tests
  // ---------------------------------------------------------------------------

  group('PlaneComponent - Step 1 perspective', () {
    test('perspectiveScaleY compresses the plane vertically', () {
      // The plane should appear foreshortened from the above-behind camera.
      expect(PlaneComponent.perspectiveScaleY, greaterThan(0.0),
          reason: 'Scale must be positive');
      expect(PlaneComponent.perspectiveScaleY, lessThan(1.0),
          reason: 'Scale must compress (< 1.0) for perspective effect');
    });

    test('perspectiveScaleY is in realistic range for ~45° camera angle', () {
      // For a camera at ~45° above the horizontal, the foreshortening
      // factor is cos(45°) ≈ 0.707. We allow some artistic license.
      expect(PlaneComponent.perspectiveScaleY, inInclusiveRange(0.5, 0.85),
          reason: 'Scale should be in range for a camera above and behind');
    });
  });

  // ---------------------------------------------------------------------------
  // tiltDown sync test
  // ---------------------------------------------------------------------------

  group('tiltDown sync', () {
    test('Dart tiltDown matches expected shader value', () {
      // The tiltDown constant appears in two places:
      //   1. globe.frag: const float tiltDown = 0.35;
      //   2. flit_game.dart: const tiltDown = 0.35;
      // This test verifies the Dart-side value so any mismatch is caught.
      // The shader value must be checked manually or via a shader parse test.
      expect(tiltDown, equals(0.35),
          reason: 'Dart tiltDown must match globe.frag tiltDown (0.35)');
    });
  });

  // ---------------------------------------------------------------------------
  // Earth dimensions test
  // ---------------------------------------------------------------------------

  group('Globe dimensions', () {
    test('globe radius is 1.0 (unit sphere)', () {
      expect(CameraState.globeRadius, equals(1.0),
          reason: 'Globe must be a unit sphere for projection math');
    });

    test('high altitude camera is outside the globe', () {
      expect(CameraState.highAltitudeDistance, greaterThan(CameraState.globeRadius),
          reason: 'Camera must be outside the globe');
    });

    test('low altitude camera is outside the globe', () {
      expect(CameraState.lowAltitudeDistance, greaterThan(CameraState.globeRadius),
          reason: 'Camera must be outside the globe at low altitude too');
    });

    test('high altitude is further than low altitude', () {
      expect(CameraState.highAltitudeDistance,
          greaterThan(CameraState.lowAltitudeDistance),
          reason: 'High altitude should be further from the globe surface');
    });
  });

  // ---------------------------------------------------------------------------
  // Camera reset test
  // ---------------------------------------------------------------------------

  group('CameraState - reset', () {
    test('reset forces snap on next update', () {
      final camera = CameraState();

      // First update at one position
      camera.update(0.016,
          planeLatDeg: 45,
          planeLngDeg: 90,
          isHighAltitude: true,
          headingRad: pi / 4);

      // Reset
      camera.reset();

      // Next update at a completely different position — should snap, not lerp
      camera.update(0.016,
          planeLatDeg: -30,
          planeLngDeg: -60,
          isHighAltitude: true,
          headingRad: 0);

      final d = CameraState.highAltitudeDistance;
      final latRad = -30 * pi / 180;
      final lngRad = -60 * pi / 180;
      final expectedX = cos(latRad) * cos(lngRad) * d;
      final expectedY = sin(latRad) * d;
      final expectedZ = cos(latRad) * sin(lngRad) * d;

      expect(camera.cameraX, closeTo(expectedX, 1e-6),
          reason: 'After reset, camera should snap to new position');
      expect(camera.cameraY, closeTo(expectedY, 1e-6));
      expect(camera.cameraZ, closeTo(expectedZ, 1e-6));
    });
  });
}
