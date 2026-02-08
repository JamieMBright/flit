import 'dart:math';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/services/audio_manager.dart';
import '../core/services/error_service.dart';
import '../core/theme/flit_colors.dart';
import '../core/utils/game_log.dart';
import '../core/utils/web_error_bridge.dart';
import '../data/models/avatar_config.dart';
import 'components/city_label_overlay.dart';
import 'components/country_border_overlay.dart';
import 'components/companion_renderer.dart';
import 'components/contrail_renderer.dart';
import 'components/wayline_renderer.dart';
import 'map/country_data.dart';
import 'map/world_map.dart';
import 'rendering/camera_state.dart';
import 'rendering/globe_hit_test.dart';
import 'rendering/globe_renderer.dart';
import 'rendering/shader_manager.dart';

final _log = GameLog.instance;

/// Degrees-to-radians constant.
const double _deg2rad = pi / 180;

/// Radians-to-degrees constant.
const double _rad2deg = 180 / pi;

/// Main game class for Flit.
///
/// The plane flies on the surface of a sphere. Position is stored as
/// (longitude, latitude) in degrees. Movement uses great-circle math.
/// The world is rendered via a GPU fragment shader (globe.frag) with
/// fallback to the Canvas 2D renderer (default world: blue ocean, green
/// land, country outlines) if the shader fails to load.
/// Speed levels for flight control.
enum FlightSpeed { slow, medium, fast }

class FlitGame extends FlameGame
    with HasKeyboardHandlerComponents, TapDetector {
  FlitGame({
    this.onGameReady,
    this.onAltitudeChanged,
    this.onError,
    this.fuelBoostMultiplier = 1.0,
    this.isChallenge = false,
    this.planeColorScheme,
    this.planeWingSpan,
    this.useShaderRenderer = true,
    this.equippedPlaneId = 'plane_default',
    this.companionType = AvatarCompanion.none,
  });

  final VoidCallback? onGameReady;
  final void Function(bool isHigh)? onAltitudeChanged;

  /// Called when the game loop hits an unrecoverable error.
  final void Function(Object error, StackTrace? stack)? onError;

  /// Fuel boost from pilot license (1.0 = no boost). Only applies in solo play.
  final double fuelBoostMultiplier;

  /// Whether this is a H2H challenge (disables license bonuses for fair play).
  final bool isChallenge;

  /// Color scheme for the equipped plane cosmetic.
  final Map<String, int>? planeColorScheme;

  /// Wing span for the equipped plane cosmetic.
  final double? planeWingSpan;

  /// Whether to use the new GPU shader renderer (V1+) or legacy Canvas.
  final bool useShaderRenderer;

  /// Equipped plane ID for engine sound selection.
  final String equippedPlaneId;

  /// Companion creature type (flies behind the plane as a sidekick).
  final AvatarCompanion companionType;

  late PlaneComponent _plane;

  /// Canvas renderer — default world (blue ocean, green land, outlines).
  WorldMap? _worldMap;

  /// GPU shader renderer (V1+).
  GlobeRenderer? _globeRenderer;

  /// Whether the shader renderer is active and ready.
  bool _shaderReady = false;

  /// Plane's position on the globe: x = longitude, y = latitude (degrees).
  Vector2 _worldPosition = Vector2.zero();

  /// Plane's heading in radians.
  /// Math convention: 0 = east, -π/2 = north, π/2 = south, π = west.
  double _heading = 0;

  /// Current game state
  bool _isPlaying = false;

  /// Target location in lat/lng degrees.
  Vector2? _targetLocation;

  /// Current clue data
  String? _currentClue;

  // -- Chase camera state --

  /// Smoothed camera heading — lags behind the plane heading for chase feel.
  double _cameraHeading = 0;

  /// Rate at which camera heading catches up to plane heading.
  /// Lower = more lag. 1.5 gives a satisfying delayed swing on turns.
  static const double _cameraHeadingEaseRate = 1.5;

  // -- Waymarker navigation state --

  /// Waypoint the player has tapped — the plane auto-steers toward it.
  /// Set by tapping anywhere on the globe (works with both renderers).
  /// null when no waypoint is set (plane flies straight).
  /// Automatically cleared when the plane reaches the waypoint (within 1.0°)
  /// or when keyboard controls are used.
  Vector2? _waymarker;

  /// Hint target — displays wayline but does NOT steer the plane.
  /// Set by showHintWayline, auto-clears after a few seconds.
  Vector2? _hintTarget;

  /// Current flight speed setting.
  FlightSpeed _flightSpeed = FlightSpeed.medium;

  /// Globe hit-test utility (screen-tap → lat/lng).
  final GlobeHitTest _hitTest = const GlobeHitTest();

  /// Wayline overlay renderer (draws translucent line to waymarker).
  WaylineRenderer? _waylineRenderer;

  /// How far ahead (in degrees) the camera looks along heading.
  /// The shader Y-flip + these offsets naturally project the plane
  /// to approximately its fixed screen position (y ≈ 72%).
  static const double _cameraOffsetHigh = 11.0;
  static const double _cameraOffsetLow = 3.2;

  /// Whether this is the first update (skip lerp, snap camera heading).
  bool _cameraFirstUpdate = true;

  /// Cached country name for current position.
  String? _cachedCountryName;

  /// Previous country name for detecting changes.
  String? _previousCountryName;

  /// Time since last country check (to avoid checking every frame).
  double _countryCheckTimer = 0.0;

  /// How often to check country (seconds).
  static const double _countryCheckInterval = 0.5;

  /// Flash animation timer when entering a new country (seconds remaining).
  double _countryFlashTimer = 0.0;

  /// Duration of the country entry flash animation.
  static const double _countryFlashDuration = 1.5;

  bool get isPlaying => _isPlaying;
  bool get isHighAltitude => _plane.isHighAltitude;
  PlaneComponent get plane => _plane;
  String? get currentClue => _currentClue;
  bool get isShaderActive => _shaderReady;

  /// Current country name the plane is flying over, or null if over ocean/unknown.
  String? get currentCountryName => _cachedCountryName;

  /// Flash animation progress when entering a new country (1.0 = full flash, 0.0 = no flash).
  double get countryFlashProgress =>
      (_countryFlashTimer / _countryFlashDuration).clamp(0.0, 1.0);

  /// Current waymarker position (lng, lat) or null if none set.
  Vector2? get waymarker => _waymarker;

  /// Hint target position (lng, lat) or null if no hint active.
  /// Used by WaylineRenderer to display a temporary wayline without steering.
  Vector2? get hintTarget => _hintTarget;

  /// Current flight speed setting.
  FlightSpeed get flightSpeed => _flightSpeed;

  /// Set flight speed from HUD controls.
  void setFlightSpeed(FlightSpeed speed) {
    _flightSpeed = speed;
    _log.info('game', 'Speed changed', data: {'speed': speed.name});
  }

  /// Speed multiplier based on current flight speed setting.
  double get _speedMultiplier {
    switch (_flightSpeed) {
      case FlightSpeed.slow:
        return 0.5;
      case FlightSpeed.medium:
        return 1.0;
      case FlightSpeed.fast:
        return 1.6;
    }
  }

  /// World position as (longitude, latitude) degrees.
  Vector2 get worldPosition => _worldPosition;
  double get heading => _heading;

  /// Camera-offset position for the renderer (ahead of plane).
  Vector2 get cameraPosition => _cameraOffsetPosition;
  Vector2 _cameraOffsetPosition = Vector2.zero();

  /// Navigation bearing for the camera position offset (radians).
  /// Includes chase camera lag.
  double get cameraBearing => _cameraHeading + pi / 2;

  /// Navigation bearing for the camera heading (radians).
  double get cameraHeadingBearing => _cameraHeading + pi / 2;

  /// Get current camera distance from globe center (in globe radii).
  /// Returns the distance based on current altitude for zoom-aware calculations.
  /// Used for contrail positioning that adjusts with camera zoom.
  double get cameraDistance {
    if (_globeRenderer != null) {
      return _globeRenderer!.camera.currentDistance;
    }
    // Fallback for Canvas renderer - use high altitude distance
    return CameraState.highAltitudeDistance;
  }

  /// Project a world position (lng, lat) to screen coordinates.
  /// Works with both Canvas (WorldMap) and shader (GlobeRenderer) renderers.
  Vector2 worldToScreen(Vector2 lngLat) {
    if (_worldMap != null) {
      return _worldMap!.latLngToScreen(lngLat, size);
    }
    if (_globeRenderer != null) {
      return _shaderWorldToScreen(lngLat);
    }
    return Vector2(size.x * projectionCenterX, size.y * projectionCenterY);
  }

  /// Project a world (lng, lat) point to screen using the shader camera.
  /// Mirrors the perspective projection in globe.frag's cameraRayDir.
  Vector2 _shaderWorldToScreen(Vector2 lngLat) {
    final cam = _globeRenderer!.camera;
    final latRad = lngLat.y * _deg2rad;
    final lngRad = lngLat.x * _deg2rad;

    // World point on unit sphere
    final px = cos(latRad) * cos(lngRad);
    final py = sin(latRad);
    final pz = cos(latRad) * sin(lngRad);

    // Vector from camera to point
    final vx = px - cam.cameraX;
    final vy = py - cam.cameraY;
    final vz = pz - cam.cameraZ;

    // Camera forward = normalize(-camPos)
    final fwdLen = sqrt(
      cam.cameraX * cam.cameraX +
      cam.cameraY * cam.cameraY +
      cam.cameraZ * cam.cameraZ,
    );
    if (fwdLen < 1e-8) {
      return Vector2(size.x * 0.5, size.y * 0.5);
    }
    final fx = -cam.cameraX / fwdLen;
    final fy = -cam.cameraY / fwdLen;
    final fz = -cam.cameraZ / fwdLen;

    // Right = normalize(cross(forward, camUp))
    var rx = fy * cam.upZ - fz * cam.upY;
    var ry = fz * cam.upX - fx * cam.upZ;
    var rz = fx * cam.upY - fy * cam.upX;
    final rLen = sqrt(rx * rx + ry * ry + rz * rz);
    if (rLen < 1e-8) {
      return Vector2(size.x * 0.5, size.y * 0.5);
    }
    rx /= rLen;
    ry /= rLen;
    rz /= rLen;

    // Up = cross(right, forward)
    final ux = ry * fz - rz * fy;
    final uy = rz * fx - rx * fz;
    final uz = rx * fy - ry * fx;

    // Project onto camera basis
    final localZ = vx * fx + vy * fy + vz * fz;
    if (localZ <= 0) {
      // Behind camera — off screen
      return Vector2(-1000, -1000);
    }
    final localX = vx * rx + vy * ry + vz * rz;
    final localY = vx * ux + vy * uy + vz * uz;

    // Perspective divide (matches shader: uv = localXY / localZ / halfFov)
    final halfFov = tan(cam.fov / 2);
    final uvX = localX / (localZ * halfFov);
    final uvY = localY / (localZ * halfFov);

    // Convert to screen coords. Must match the shader's cameraRayDir:
    //   uv = (fragCoord - 0.5 * resolution) / resolution.y
    //   uv.y = -uv.y   (Flutter y-down flip)
    // Inverse: fragCoord = (uvX * res.y + 0.5 * res.x, -uvY * res.y + 0.5 * res.y)
    final screenX = uvX * size.y + size.x * 0.5;
    final screenY = -uvY * size.y + size.y * 0.5;

    return Vector2(screenX, screenY);
  }

  /// Where on screen the plane sprite is rendered (proportional).
  /// Pushed well toward the bottom to create a "behind the plane" view.
  static const double planeScreenY = 0.72;
  static const double planeScreenX = 0.50;

  /// Where the Canvas (WorldMap) renderer centers its projection on screen.
  /// The shader renderer uses screen center (0.5, 0.5) with a Y-flip instead.
  static const double projectionCenterY = 0.45;
  static const double projectionCenterX = 0.50;

  /// Angular speed conversion: old speed value → radians/sec on the sphere.
  /// Old system: speed 200 on a 3600-unit map spanning 360°.
  /// So 1 unit = 0.1° → speed * π / 1800 rad/sec.
  static const double _speedToAngular = pi / 1800;

  @override
  Color backgroundColor() => FlitColors.oceanDeep;

  @override
  Future<void> onLoad() async {
    _log.info('game', 'FlitGame.onLoad started');
    try {
      await super.onLoad();

      // Try to initialise the GPU shader renderer (V1+).
      if (useShaderRenderer) {
        try {
          final shaderManager = ShaderManager.instance;
          await shaderManager.initialize();

          // ShaderManager.initialize() swallows errors internally.
          // Verify it actually succeeded before creating the renderer.
          if (shaderManager.isReady) {
            _globeRenderer = GlobeRenderer();
            await add(_globeRenderer!);
            _shaderReady = true;
            _log.info('game', 'Shader renderer initialised');
          } else {
            _log.warning(
              'game',
              'ShaderManager not ready after initialize, falling back to Canvas',
            );
            _shaderReady = false;
          }
        } catch (e) {
          _log.warning(
            'game',
            'Shader renderer failed, falling back to Canvas',
            error: e,
          );
          _shaderReady = false;
          _globeRenderer = null;
        }
      }

      // If shader failed or not requested, use the Canvas world renderer.
      // This is the default world: simple blue ocean, green land, outlines.
      if (!_shaderReady) {
        _worldMap = WorldMap();
        await add(_worldMap!);
        _log.info('game', 'Using Canvas world renderer');
      }

      // Contrail overlay — renders on top of globe, before the plane.
      await add(ContrailRenderer());

      // Wayline overlay — draws translucent line from plane to waymarker.
      _waylineRenderer = WaylineRenderer();
      await add(_waylineRenderer!);

      // Companion creature — flies behind the plane as a sidekick.
      if (companionType != AvatarCompanion.none) {
        await add(CompanionRenderer(companionType: companionType));
      }

      // Country border overlay — renders border outlines when shader is active.
      await add(CountryBorderOverlay());

      // City label overlay — renders city names at low altitude.
      // Works with both shader and canvas renderers (WorldMap renders its own
      // cities at low altitude, so the overlay skips when WorldMap is active).
      await add(CityLabelOverlay());

      _plane = PlaneComponent(
        onAltitudeChanged: (isHigh) {
          _log.info('game', 'Altitude changed', data: {'isHigh': isHigh});
          try {
            onAltitudeChanged?.call(isHigh);
          } catch (e, st) {
            _log.error('game', 'onAltitudeChanged callback failed',
                error: e, stackTrace: st);
          }
        },
        colorScheme: planeColorScheme,
        wingSpan: planeWingSpan ?? 26.0,
        equippedPlaneId: equippedPlaneId,
      );
      await add(_plane);

      if (!isChallenge) {
        _plane.fuelBoostMultiplier = fuelBoostMultiplier;
      }

      // Start at 0°, 0° facing north
      _worldPosition = Vector2(0, 0);
      _heading = -pi / 2; // north

      // Start engine sound for equipped plane (fire-and-forget, safe if missing).
      try {
        AudioManager.instance.startEngine(equippedPlaneId);
      } catch (e) {
        _log.warning('game', 'Engine sound start failed', error: e);
      }

      _log.info('game', 'FlitGame.onLoad complete');

      try {
        onGameReady?.call();
      } catch (e, st) {
        _log.error('game', 'onGameReady callback failed',
            error: e, stackTrace: st);
        ErrorService.instance.reportCritical(
          e,
          st,
          context: {'source': 'FlitGame', 'action': 'onGameReady'},
        );
      }
    } catch (e, st) {
      _log.error('game', 'FlitGame.onLoad FAILED', error: e, stackTrace: st);
      ErrorService.instance.reportCritical(
        e,
        st,
        context: {'source': 'FlitGame', 'action': 'onLoad'},
      );
      rethrow;
    }
  }

  /// Whether the game loop has been killed due to an error.
  bool _dead = false;

  @override
  void update(double dt) {
    super.update(dt);
    if (_dead) return;
    try {
      _updateInner(dt);
    } catch (e, st) {
      _dead = true;
      _log.error('game', 'GAME LOOP CRASHED', error: e, stackTrace: st);
      ErrorService.instance.reportCritical(e, st, context: {
        'source': 'FlitGame',
        'action': 'update',
      });
      // Push to JS overlay for iOS PWA
      WebErrorBridge.show('Game loop crash:\n$e\n\n$st');
      onError?.call(e, st);
    }
  }

  /// Detect which country the plane is currently over.
  /// Uses point-in-polygon testing with caching to avoid checking every frame.
  void _updateCountryDetection(double dt) {
    _countryCheckTimer += dt;
    if (_countryCheckTimer < _countryCheckInterval) return;

    _countryCheckTimer = 0.0;

    // Check if current position is in any country's polygons
    final lng = _worldPosition.x;
    final lat = _worldPosition.y;

    // Linear search through countries (fast enough for ~200 countries)
    for (final country in CountryData.countries) {
      // Check each polygon in the country (many countries have multiple polygons)
      for (final polygon in country.polygons) {
        // Convert Vector2 list to Offset list for hit test
        final polygonOffsets = polygon.map((v) => Offset(v.x, v.y)).toList();
        if (_hitTest.isPointInPolygon(lat, lng, polygonOffsets)) {
          // Detect country change and trigger flash animation
          if (_cachedCountryName != country.name) {
            _previousCountryName = _cachedCountryName;
            _cachedCountryName = country.name;
            // Trigger flash when entering any country (including from ocean)
            _countryFlashTimer = _countryFlashDuration;
            _log.info('game', 'Entered country', data: {
              'from': _previousCountryName ?? 'ocean',
              'to': country.name,
            });
          }
          return;
        }
      }
    }

    // Not in any country — over ocean
    if (_cachedCountryName != null) {
      _previousCountryName = _cachedCountryName;
    }
    _cachedCountryName = null;
  }

  void _updateInner(double dt) {
    // Don't run game logic until a session is active and the game has a size.
    if (!_isPlaying || size.x < 1 || size.y < 1) return;

    // --- Country detection ---
    _updateCountryDetection(dt);

    // --- Decrement country flash timer ---
    if (_countryFlashTimer > 0) {
      _countryFlashTimer = (_countryFlashTimer - dt).clamp(0.0, _countryFlashDuration);
    }

    // --- Waymarker auto-steering ---
    _updateWaymarkerSteering(dt);

    // --- Great-circle movement ---
    // Use continuous altitude speed for smooth transitions, scaled by speed setting
    final speed = _plane.currentSpeedContinuous * _speedMultiplier;
    final angularDist = speed * _speedToAngular * dt; // radians

    // Convert heading to navigation bearing (0 = north, clockwise)
    final bearing = _heading + pi / 2;

    final lat0 = _worldPosition.y * _deg2rad;
    final lng0 = _worldPosition.x * _deg2rad;

    final sinLat0 = sin(lat0);
    final cosLat0 = cos(lat0);
    final sinD = sin(angularDist);
    final cosD = cos(angularDist);

    final newLat = asin(
      (sinLat0 * cosD + cosLat0 * sinD * cos(bearing)).clamp(-1.0, 1.0),
    );

    final newLng = lng0 +
        atan2(
          sin(bearing) * sinD * cosLat0,
          cosD - sinLat0 * sin(newLat),
        );

    _worldPosition = Vector2(
      _normalizeLng(newLng * _rad2deg),
      (newLat * _rad2deg).clamp(-85.0, 85.0),
    );

    // Update heading based on turn input (left/right only).
    // Negated so right input turns clockwise on the globe.
    _heading -= _plane.turnDirection * PlaneComponent.turnRate * dt;

    // Normalize heading to [-π, π] to prevent accumulation
    while (_heading > pi) { _heading -= 2 * pi; }
    while (_heading < -pi) { _heading += 2 * pi; }

    // Auto-circle near poles: when within 2° of the 85° limit,
    // add a gentle eastward turn to circle the pole instead of hitting the wall.
    final absLat = _worldPosition.y.abs();
    if (absLat > 83.0) {
      final poleTurnStrength = ((absLat - 83.0) / 2.0).clamp(0.0, 1.0);
      _heading += poleTurnStrength * 0.8 * dt;
    }

    // Clear waymarker when plane arrives within ~1° of it
    if (_waymarker != null) {
      final distToWaymarker = _greatCircleDistDeg(_worldPosition, _waymarker!);
      if (distToWaymarker < 1.0) {
        _waymarker = null;
        _plane.releaseTurn();
      }
    }

    // --- Chase camera: smooth heading with lag ---
    _updateChaseCamera(dt);

    // Feed camera position to the active renderer.
    // GlobeRenderer reads position from gameRef in its own update(),
    // so we only drive the Canvas renderer explicitly.
    if (!_shaderReady && _worldMap != null) {
      _worldMap!.setCameraCenter(_cameraOffsetPosition);
      _worldMap!.setCameraHeading(cameraHeadingBearing);
      _worldMap!.setAltitude(high: _plane.isHighAltitude);
    }

    // Update plane visual — heading is relative to camera heading only.
    // Drag offset is excluded: when the player drags to look around,
    // the globe rotates but the plane keeps facing forward on screen.
    _plane.visualHeading = _heading - _cameraHeading;

    // Place the plane at its projected world position so it aligns with
    // contrails and map features. Works for both Canvas and shader renderers.
    final projectedPlane = worldToScreen(_worldPosition);
    if (projectedPlane.x > -500) {
      _plane.position = projectedPlane;
    } else {
      // Off-screen fallback (shouldn't happen with camera offset system)
      _plane.position = Vector2(size.x * planeScreenX, size.y * planeScreenY);
    }

    // Feed world state to plane for world-space contrail spawning.
    _plane.worldPos = _worldPosition.clone();
    _plane.worldHeading = _heading;

    // Modulate engine volume with turn intensity.
    AudioManager.instance.updateEngineVolume(_plane.turnDirection.abs());
  }

  /// Update the chase camera heading and compute the offset camera position.
  ///
  /// The camera heading smoothly interpolates toward the plane heading,
  /// creating a satisfying lag when the plane turns. The camera center
  /// is offset ahead of the plane along the camera heading direction.
  void _updateChaseCamera(double dt) {
    if (_cameraFirstUpdate) {
      _cameraHeading = _heading;
      _cameraFirstUpdate = false;
    } else {
      // Smooth ease-out: camera heading chases plane heading.
      final factor = 1.0 - exp(-_cameraHeadingEaseRate * dt);
      _cameraHeading = _lerpAngle(_cameraHeading, _heading, factor);
    }

    // Compute a point ahead of the plane along the camera heading direction.
    final offsetDeg = _plane.isHighAltitude ? _cameraOffsetHigh : _cameraOffsetLow;

    // Reduce camera offset near poles to prevent oscillation
    final latAbs = _worldPosition.y.abs();
    final polarDamping = latAbs > 80.0 ? (90.0 - latAbs) / 10.0 : 1.0;
    final effectiveOffset = offsetDeg * polarDamping;

    // Convert camera heading to navigation bearing (0 = north).
    final camBearing = _cameraHeading + pi / 2;

    // Great-circle destination: move offsetDeg ahead of the plane.
    final d = effectiveOffset * _deg2rad;
    final planeLat = _worldPosition.y * _deg2rad;
    final planeLng = _worldPosition.x * _deg2rad;

    final sinPLat = sin(planeLat);
    final cosPLat = cos(planeLat);
    final sinDist = sin(d);
    final cosDist = cos(d);

    final aheadLat = asin(
      (sinPLat * cosDist + cosPLat * sinDist * cos(camBearing)).clamp(-1.0, 1.0),
    );
    final aheadLng = planeLng +
        atan2(
          sin(camBearing) * sinDist * cosPLat,
          cosDist - sinPLat * sin(aheadLat),
        );

    _cameraOffsetPosition = Vector2(
      _normalizeLng(aheadLng * _rad2deg),
      aheadLat * _rad2deg,
    );
  }

  /// Interpolate between two angles along the shortest path.
  static double _lerpAngle(double a, double b, double t) {
    var diff = b - a;
    while (diff > pi) {
      diff -= 2 * pi;
    }
    while (diff < -pi) {
      diff += 2 * pi;
    }
    return a + diff * t;
  }

  /// Normalize longitude to [-180, 180].
  double _normalizeLng(double lng) {
    while (lng > 180) {
      lng -= 360;
    }
    while (lng < -180) {
      lng += 360;
    }
    return lng;
  }

  // -- Waymarker auto-steering --

  /// Computes the initial bearing from the plane to the waymarker and
  /// smoothly steers the plane toward it.
  void _updateWaymarkerSteering(double dt) {
    if (_waymarker == null) return;

    // Compute initial bearing from plane to waymarker (great-circle).
    final lat1 = _worldPosition.y * _deg2rad;
    final lng1 = _worldPosition.x * _deg2rad;
    final lat2 = _waymarker!.y * _deg2rad;
    final lng2 = _waymarker!.x * _deg2rad;
    final dLng = lng2 - lng1;

    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
    // targetBearing: 0 = north, π/2 = east (standard navigation bearing)
    final targetBearing = atan2(y, x);

    // Convert our internal heading to navigation bearing for comparison
    final currentBearing = _heading + pi / 2;

    // Angle difference (shortest path)
    var diff = targetBearing - currentBearing;
    while (diff > pi) { diff -= 2 * pi; }
    while (diff < -pi) { diff += 2 * pi; }

    // Steer proportionally to the angular difference.
    // Uses smooth interpolation so the plane banks gradually into turns.
    final turnStrength = (diff / (pi * 0.3)).clamp(-1.0, 1.0);
    if (turnStrength.abs() < 0.02) {
      _plane.steerToward(0, dt);
    } else {
      _plane.steerToward(turnStrength, dt);
    }
  }

  // -- Tap-to-waymarker touch handler --

  /// Handle tap events to set waypoints for navigation.
  /// 
  /// When the player taps on the globe, we convert the screen coordinates
  /// to a geographic position (lat/lng) and set it as a waymarker. The plane
  /// will then auto-steer toward that position using great-circle navigation.
  /// 
  /// Works with both renderers:
  /// - Shader renderer: uses ray-casting with camera perspective
  /// - Canvas renderer: uses azimuthal projection inverse
  @override
  void onTapUp(TapUpInfo info) {
    if (!_isPlaying) return;

    // Convert screen tap to globe lat/lng.
    Vector2? latLng;
    
    if (_globeRenderer != null) {
      // Shader renderer: use camera-based ray-casting hit test.
      final cam = _globeRenderer!.camera;
      final screenPoint = Offset(
        info.eventPosition.widget.x,
        info.eventPosition.widget.y,
      );
      final result = _hitTest.screenToLatLng(
        screenPoint,
        Size(size.x, size.y),
        cam,
      );
      if (result != null) {
        latLng = Vector2(result.dx, result.dy);
      }
    } else if (_worldMap != null) {
      // Canvas renderer: use azimuthal projection inverse.
      final screenPoint = Vector2(
        info.eventPosition.widget.x,
        info.eventPosition.widget.y,
      );
      latLng = _worldMap!.screenToLatLng(screenPoint, size);
    }

    if (latLng != null) {
      _waymarker = latLng;
      _log.info('game', 'Waymarker set', data: {
        'lng': latLng.x.toStringAsFixed(1),
        'lat': latLng.y.toStringAsFixed(1),
      });
    }
  }

  @override
  KeyEventResult onKeyEvent(
    RawKeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final superResult = super.onKeyEvent(event, keysPressed);

    // Keyboard navigation still supported for desktop/web.
    double direction = 0;

    if (keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
        keysPressed.contains(LogicalKeyboardKey.keyA)) {
      direction -= 1;
    }
    if (keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
        keysPressed.contains(LogicalKeyboardKey.keyD)) {
      direction += 1;
    }

    if (direction != 0) {
      // Keyboard overrides waymarker steering
      _waymarker = null;
      _plane.setTurnDirection(direction);
    } else if (_waymarker == null) {
      _plane.releaseTurn();
    }

    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _plane.toggleAltitude();
        AudioManager.instance.playSfx(SfxType.altitudeChange);
      }
    }

    return superResult == KeyEventResult.handled
        ? superResult
        : KeyEventResult.handled;
  }

  /// Temporarily show a wayline hint toward the given position.
  /// The wayline is visual only — it does NOT steer the plane.
  void showHintWayline(Vector2 target) {
    _hintTarget = target.clone();
    // Auto-clear after 6 seconds so it's a brief visual hint.
    Future<void>.delayed(const Duration(seconds: 6), () {
      // Only clear if hint target is still pointing at this target.
      if (_hintTarget != null &&
          (_hintTarget!.x - target.x).abs() < 0.01 &&
          (_hintTarget!.y - target.y).abs() < 0.01) {
        _hintTarget = null;
      }
    });
  }

  /// Set a navigation waypoint programmatically (e.g. from hint tier 4).
  /// The plane will auto-steer toward this position.
  void setWaymarker(Vector2 position) {
    _waymarker = position.clone();
  }

  /// Start a new game/challenge.
  void startGame({
    required Vector2 startPosition,
    required Vector2 targetPosition,
    required String clue,
  }) {
    _log.info('game', 'startGame', data: {
      'start':
          '${startPosition.x.toStringAsFixed(1)},${startPosition.y.toStringAsFixed(1)}',
      'target':
          '${targetPosition.x.toStringAsFixed(1)},${targetPosition.y.toStringAsFixed(1)}',
    });

    // startPosition is already (lng, lat) degrees — use directly
    _worldPosition = startPosition.clone();
    _heading = Random().nextDouble() * 2 * pi;
    _cameraHeading = _heading; // snap camera to heading on game start
    _cameraFirstUpdate = true;
    _targetLocation = targetPosition;
    _currentClue = clue;
    _waymarker = null; // clear any previous waymarker
    _hintTarget = null; // clear any previous hint
    _flightSpeed = FlightSpeed.medium; // reset speed
    _isPlaying = true;
  }

  /// Check if plane is near target using great-circle distance.
  bool isNearTarget({double threshold = 80}) {
    if (_targetLocation == null) return false;
    final dist = _greatCircleDistDeg(_worldPosition, _targetLocation!);
    // threshold is in the old "world units" (1 unit ≈ 0.1°).
    // Convert: 80 units = 8 degrees.
    return dist < threshold * 0.1;
  }

  /// Great-circle angular distance between two (lng, lat) points, in degrees.
  double _greatCircleDistDeg(Vector2 a, Vector2 b) {
    final lat1 = a.y * _deg2rad;
    final lat2 = b.y * _deg2rad;
    final dLat = (b.y - a.y) * _deg2rad;
    final dLng = (b.x - a.x) * _deg2rad;

    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(h), sqrt(1 - h));
    return c * _rad2deg;
  }
}
