import 'dart:math';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/services/audio_manager.dart';
import '../core/services/error_service.dart';
import '../core/services/game_settings.dart';
import '../core/theme/flit_colors.dart';
import '../core/utils/game_log.dart';
import '../core/utils/web_error_bridge.dart';
import 'components/city_label_overlay.dart';
import 'components/contrail_renderer.dart';
import 'map/world_map.dart';
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
class FlitGame extends FlameGame
    with HasKeyboardHandlerComponents, HorizontalDragDetector {
  FlitGame({
    this.onGameReady,
    this.onAltitudeChanged,
    this.onError,
    this.fuelBoostMultiplier = 1.0,
    this.isChallenge = false,
    this.planeColorScheme,
    this.useShaderRenderer = true,
    this.equippedPlaneId = 'plane_default',
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

  /// Whether to use the new GPU shader renderer (V1+) or legacy Canvas.
  final bool useShaderRenderer;

  /// Equipped plane ID for engine sound selection.
  final String equippedPlaneId;

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

  // -- Camera drag (look-around) state --

  /// Accumulated camera rotation offset from user drag (radians).
  /// Positive = looking right of heading, negative = looking left.
  double _cameraDragOffset = 0;

  /// Whether the user is currently dragging to look around.
  bool _isDraggingCamera = false;

  /// Rate at which camera drag offset eases back to 0 on release.
  static const double _cameraDragReturnRate = 3.0;

  /// Sensitivity: how many radians of camera rotation per pixel of drag.
  static const double _cameraDragSensitivity = 0.004;

  /// How far ahead (in degrees) the projection center looks along heading.
  /// Must be ~56% of angular radius (in degrees) so the plane's world
  /// position projects to its fixed screen position (y=72%, center=45%).
  /// High: 0.18 rad = 10.3° → 10.3 × 0.56 = 5.8°
  /// Low:  0.06 rad = 3.44° → 3.44 × 0.56 = 1.9°
  static const double _cameraOffsetHigh = 5.8;
  static const double _cameraOffsetLow = 1.9;

  /// Whether this is the first update (skip lerp, snap camera heading).
  bool _cameraFirstUpdate = true;

  bool get isPlaying => _isPlaying;
  bool get isHighAltitude => _plane.isHighAltitude;
  PlaneComponent get plane => _plane;
  String? get currentClue => _currentClue;
  bool get isShaderActive => _shaderReady;

  /// World position as (longitude, latitude) degrees.
  Vector2 get worldPosition => _worldPosition;
  double get heading => _heading;

  /// Camera-offset position for the renderer (ahead of plane).
  Vector2 get cameraPosition => _cameraOffsetPosition;
  Vector2 _cameraOffsetPosition = Vector2.zero();

  /// Navigation bearing for the camera position offset (radians).
  /// Includes chase camera lag and drag look-around offset.
  double get cameraBearing => _cameraHeading + _cameraDragOffset + pi / 2;

  /// Navigation bearing for the camera up vector (radians).
  /// Excludes drag offset so the view actually rotates when dragging
  /// (instead of the plane appearing to turn while the globe stays fixed).
  double get cameraHeadingBearing => _cameraHeading + pi / 2;

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

    // Convert to screen coords (matches shader's fragCoord mapping)
    final screenX = uvX * size.y + size.x * 0.5;
    final screenY = uvY * size.y + size.y * 0.5;

    return Vector2(screenX, screenY);
  }

  /// Where on screen the plane sprite is rendered (proportional).
  /// Pushed well toward the bottom to create a "behind the plane" view.
  static const double planeScreenY = 0.72;
  static const double planeScreenX = 0.50;

  /// Where the map projection is centered on screen.
  /// This is higher up than the plane, so the map shows more world ahead.
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

  void _updateInner(double dt) {

    // --- Great-circle movement ---
    final speed = _plane.currentSpeed;
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

    // Update heading based on turn input (left/right only)
    _heading += _plane.turnDirection * PlaneComponent.turnRate * dt;

    // --- Chase camera: smooth heading with lag ---
    _updateChaseCamera(dt);

    // Feed camera position to the active renderer.
    // GlobeRenderer reads position from gameRef in its own update(),
    // so we only drive the Canvas renderer explicitly.
    if (!_shaderReady && _worldMap != null) {
      _worldMap!.setCameraCenter(_cameraOffsetPosition);
      _worldMap!.setAltitude(high: _plane.isHighAltitude);
    }

    // Update plane visual — heading is relative to camera heading only.
    // Drag offset is excluded: when the player drags to look around,
    // the globe rotates but the plane keeps facing forward on screen.
    _plane.visualHeading = _heading - _cameraHeading;
    _plane.position = Vector2(
      size.x * planeScreenX,
      size.y * planeScreenY,
    );

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
      _cameraDragOffset = 0;
      _cameraFirstUpdate = false;
    } else {
      // Smooth ease-out: camera heading chases plane heading.
      final factor = 1.0 - exp(-_cameraHeadingEaseRate * dt);
      _cameraHeading = _lerpAngle(_cameraHeading, _heading, factor);
    }

    // Ease camera drag offset back to 0 when not actively dragging.
    if (!_isDraggingCamera && _cameraDragOffset.abs() > 0.001) {
      final returnFactor = 1.0 - exp(-_cameraDragReturnRate * dt);
      _cameraDragOffset *= (1.0 - returnFactor);
    }

    // Compute a point ahead of the plane along the camera heading direction,
    // including any look-around drag offset.
    final offsetDeg = _plane.isHighAltitude ? _cameraOffsetHigh : _cameraOffsetLow;

    // Convert camera heading to navigation bearing (0 = north),
    // adding the user's look-around drag offset.
    final camBearing = _cameraHeading + _cameraDragOffset + pi / 2;

    // Great-circle destination: move offsetDeg ahead of the plane.
    final d = offsetDeg * _deg2rad;
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
      (aheadLat * _rad2deg).clamp(-85.0, 85.0),
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

  /// Minimum drag delta to register as camera rotation.
  static const double _dragDeadZone = 0.5;

  @override
  void onHorizontalDragUpdate(DragUpdateInfo info) {
    final dx = info.delta.global.x;
    if (dx.abs() < _dragDeadZone) return;

    _isDraggingCamera = true;
    final settings = GameSettings.instance;
    final sign = settings.invertControls ? -1.0 : 1.0;
    // Drag rotates the camera view, not the plane.
    _cameraDragOffset += sign * dx * _cameraDragSensitivity *
        settings.turnSensitivity;
    // Clamp to ±90° so you can't look fully behind.
    _cameraDragOffset = _cameraDragOffset.clamp(-pi / 2, pi / 2);
  }

  @override
  void onHorizontalDragEnd(DragEndInfo info) {
    _isDraggingCamera = false;
    // Camera drag offset will ease back to 0 in _updateChaseCamera().
  }

  // -- HUD turn controls --

  /// Set plane turn direction from HUD buttons.
  /// -1 = left, 0 = straight, 1 = right.
  void setHudTurn(double direction) {
    _plane.setTurnDirection(direction.clamp(-1, 1));
  }

  /// Release HUD turn (finger lifted from button).
  void releaseHudTurn() {
    _plane.releaseTurn();
  }

  @override
  KeyEventResult onKeyEvent(
    RawKeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final superResult = super.onKeyEvent(event, keysPressed);

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
      _plane.setTurnDirection(direction);
    } else {
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
