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
import '../data/models/avatar_config.dart';
import 'components/city_label_overlay.dart';
import 'components/country_border_overlay.dart';
import 'components/companion_renderer.dart';
import 'components/contrail_renderer.dart';
import 'components/plane_component.dart';
import 'components/wayline_renderer.dart';
import 'map/country_data.dart';
import 'map/region.dart';
import 'map/world_map.dart';
import 'rendering/camera_state.dart';
import 'rendering/flat_map_renderer.dart';
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

/// Phases of the game launch animation.
///
/// [positioning] — Globe snaps to start position, black overlay covers screen.
/// [flyIn] — Plane animates from bottom of screen to final position.
/// [playing] — Normal gameplay.
enum LaunchPhase { none, positioning, flyIn, playing }

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
    this.motionEnabled = true,
    this.region = GameRegion.world,
  });

  /// The game region being played. Determines renderer (globe vs flat map).
  final GameRegion region;

  /// Whether this game uses a flat map projection (regional modes).
  bool get isFlatMapMode => region.isFlatMap;

  /// The flat map renderer (only set in flat map mode).
  FlatMapRenderer? _flatMapRenderer;

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

  /// Whether plane motion is enabled. When false, the plane stays stationary
  /// and no movement/steering/input is processed. Used for Step 1 rebuild
  /// to verify static camera + projection before adding motion.
  final bool motionEnabled;

  late PlaneComponent _plane;

  /// Whether _plane has been initialized (late field, set in onLoad).
  bool _planeReady = false;

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
  /// Camera heading ease rate. Higher = tighter tracking of plane heading.
  /// 12.0 converges within ~15 frames (~0.25s) so the plane always faces
  /// forward on screen with no visible drift during straight flight.
  static const double _cameraHeadingEaseRate = 12.0;

  // -- Waymarker navigation state --

  /// Waypoint the player has tapped — the plane auto-steers toward it.
  /// Set by tapping anywhere on the globe (works with both renderers).
  /// null when no waypoint is set (plane flies straight).
  /// Automatically cleared when the plane reaches the waypoint (within 1.0°)
  /// or when keyboard controls are used.
  Vector2? _waymarker;

  /// Time since the current waymarker was set (seconds).
  /// Used to ramp up turn strength smoothly over 0.6s after a tap, giving
  /// the plane a natural-feeling response rather than an instant snap.
  double _waymarkerAge = 0.0;

  /// Hint target — displays wayline but does NOT steer the plane.
  /// Set by showHintWayline, auto-clears after a few seconds.
  Vector2? _hintTarget;

  /// Current flight speed setting.
  FlightSpeed _flightSpeed = FlightSpeed.medium;

  /// Globe hit-test utility (screen-tap → lat/lng).
  final GlobeHitTest _hitTest = const GlobeHitTest();

  // -- Progressive turn input state --

  /// Keyboard turn direction: -1 (left), 0 (none), +1 (right).
  int _keyTurnDir = 0;

  /// How long the current keyboard turn has been held (seconds).
  double _keyTurnHoldTime = 0.0;

  /// On-screen button turn direction: -1 (left), 0 (none), +1 (right).
  int _buttonTurnDir = 0;

  /// How long the current button turn has been held (seconds).
  double _buttonTurnHoldTime = 0.0;

  /// Wayline overlay renderer (draws translucent line to waymarker).
  WaylineRenderer? _waylineRenderer;

  /// Per-frame correction vector that aligns worldToScreen(_worldPosition)
  /// with the fixed plane sprite position. Accounts for CameraState easing
  /// lag, one-frame delay, and FOV transitions.
  Vector2 _screenCorrection = Vector2.zero();

  /// Whether this is the first update (skip lerp, snap camera heading).
  bool _cameraFirstUpdate = true;

  /// Cached country name for current position.
  String? _cachedCountryName;

  /// Previous country name for detecting changes.
  String? _previousCountryName;

  /// Time since last country check (to avoid checking every frame).
  double _countryCheckTimer = 0.0;

  /// How often to check country (seconds).
  /// Must be short enough that at max speed the plane doesn't skip over
  /// small countries between checks. At high altitude + fast speed the
  /// plane covers ~5.8°/s, so 0.1 s → 0.58° per check — safe for most
  /// countries.
  static const double _countryCheckInterval = 0.1;

  /// Flash animation timer when entering a new country (seconds remaining).
  double _countryFlashTimer = 0.0;

  /// Duration of the country entry flash animation.
  static const double _countryFlashDuration = 1.5;

  // -- Launch animation state --

  /// Current phase of the launch intro animation.
  LaunchPhase _launchPhase = LaunchPhase.none;

  /// Timer within the current launch phase (seconds).
  double _launchTimer = 0.0;

  /// Duration of the positioning phase (globe snaps to start position).
  static const double _positioningDuration = 1.0;

  /// Duration of the plane fly-in animation.
  static const double _flyInDuration = 0.8;

  // -- Fuel system --

  /// Whether fuel mechanics are active for this session.
  /// Off for free flight; on for training, daily, dogfight.
  bool fuelEnabled = false;

  /// Current fuel level (0.0 = empty, [maxFuel] = full tank).
  late double _fuel;

  /// Maximum fuel level. License boost gives a larger tank:
  /// e.g. 10% boost → maxFuel = 1.1 → displayed as "110%".
  double get maxFuel => fuelBoostMultiplier;

  /// Base fuel burn rate per second at normal speed.
  /// At 1/90 per second, a full base tank lasts 90 seconds.
  static const double _baseFuelBurnRate = 1.0 / 90.0;

  /// Fuel cost for using a hint (each tier costs 5% of base tank).
  static const double _hintFuelCost = 0.05;

  /// Callback when fuel runs out.
  void Function()? onFuelEmpty;

  /// Current fuel level (0.0–[maxFuel]).
  double get fuel => _fuel;

  /// Refuel the tank (called when a clue is answered correctly).
  /// Restores +75% of base tank, capped at [maxFuel].
  void refuel() {
    if (!fuelEnabled) return;
    _fuel = (_fuel + 0.75).clamp(0.0, maxFuel);
  }

  /// Deduct fuel for using a hint. Returns false if tank is empty.
  bool useHintFuel() {
    if (!fuelEnabled) return true;
    _fuel = (_fuel - _hintFuelCost).clamp(0.0, maxFuel);
    if (_fuel <= 0) {
      onFuelEmpty?.call();
      return false;
    }
    return true;
  }

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

  /// Current launch animation phase.
  LaunchPhase get launchPhase => _launchPhase;

  /// Whether the game is in the launch intro (positioning or fly-in).
  bool get isInLaunchIntro =>
      _launchPhase == LaunchPhase.positioning ||
      _launchPhase == LaunchPhase.flyIn;

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
  /// Different scales for ascend (globe cruising) vs descend (map exploration).
  /// Ascend base speed is 36 units/s, descend base is 3.6 units/s (10% of high).
  double get _speedMultiplier {
    if (_planeReady && !_plane.isHighAltitude) {
      // Descend mode: really slow for cruising / exploring the OSM map.
      // Effective speeds: slow ≈ 1.1, medium ≈ 2.2, fast ≈ 3.6 units/s.
      switch (_flightSpeed) {
        case FlightSpeed.slow:
          return 0.3;
        case FlightSpeed.medium:
          return 0.6;
        case FlightSpeed.fast:
          return 1.0;
      }
    }
    // Ascend mode: fast globe traversal.
    // Effective speeds: slow = 18, medium = 36, fast = 90 units/s.
    switch (_flightSpeed) {
      case FlightSpeed.slow:
        return 0.5;
      case FlightSpeed.medium:
        return 1.0;
      case FlightSpeed.fast:
        return 2.5;
    }
  }

  /// World position as (longitude, latitude) degrees.
  Vector2 get worldPosition => _worldPosition;
  double get heading => _heading;

  /// Camera-offset position for the Canvas renderer (ahead of plane).
  Vector2 get cameraPosition => _cameraOffsetPosition;
  Vector2 _cameraOffsetPosition = Vector2.zero();

  /// Camera-offset position for the shader renderer (behind the plane).
  /// In the shader's chase-camera view, the camera is BEHIND the plane so
  /// the plane appears in the lower portion of the screen (looking over its
  /// shoulder). The tiltDown in the shader provides the forward-looking view.
  Vector2 get shaderCameraPosition => _shaderCameraPosition;
  Vector2 _shaderCameraPosition = Vector2.zero();

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
  /// Works with Canvas (WorldMap), shader (GlobeRenderer), and flat map
  /// (FlatMapRenderer) renderers.
  ///
  /// When the shader is active, applies a per-frame screen correction so that
  /// worldToScreen(_worldPosition) == plane sprite position. This guarantees
  /// contrails, waypoints, and overlays align with the plane regardless of
  /// CameraState easing lag or one-frame delays.
  Vector2 worldToScreen(Vector2 lngLat) {
    if (_flatMapRenderer != null) {
      return _flatMapRenderer!.worldToScreen(lngLat, size.x, size.y);
    }
    if (_worldMap != null) {
      return _worldMap!.latLngToScreen(lngLat, size);
    }
    if (_globeRenderer != null) {
      final projected = _shaderWorldToScreen(lngLat);
      // Don't correct off-screen / occluded points.
      if (projected.x < -500) return projected;
      return projected + _screenCorrection;
    }
    return Vector2(-1000, -1000);
  }

  /// Project world coordinates to screen WITHOUT the plane-tracking correction.
  /// Use this for globe-surface overlays (borders, geographic features) that must
  /// stay glued to the satellite texture rather than tracking the plane sprite.
  /// In flat map mode, this is the same as worldToScreen (no correction needed).
  Vector2 worldToScreenGlobe(Vector2 lngLat) {
    if (_flatMapRenderer != null) {
      return _flatMapRenderer!.worldToScreen(lngLat, size.x, size.y);
    }
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

    // Globe occlusion check: hide points on the far side of the globe.
    // For a unit sphere, a surface point P is visible from camera C
    // iff dot(P, C) > 1.0 (geometric horizon test).
    // Use 1.05 threshold to exclude points near the limb that would
    // overlap with the atmosphere rim glow rendered by the shader.
    final dotPC = px * cam.cameraX + py * cam.cameraY + pz * cam.cameraZ;
    if (dotPC <= 1.05) {
      return Vector2(-1000, -1000);
    }

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

    // Right = normalize(cross(camUp, forward)) — east on screen-right
    var rx = cam.upY * fz - cam.upZ * fy;
    var ry = cam.upZ * fx - cam.upX * fz;
    var rz = cam.upX * fy - cam.upY * fx;
    final rLen = sqrt(rx * rx + ry * ry + rz * rz);
    if (rLen < 1e-8) {
      return Vector2(size.x * 0.5, size.y * 0.5);
    }
    rx /= rLen;
    ry /= rLen;
    rz /= rLen;

    // Up = cross(forward, right) — heading direction on screen-up
    final ux = fy * rz - fz * ry;
    final uy = fz * rx - fx * rz;
    final uz = fx * ry - fy * rx;

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
    //   uv.y = -uv.y           (Y-flip: Flutter y-down → screen y-up)
    //   uv.y += tiltDown        (chase-camera tilt)
    // Solving for fragCoord:
    //   fragCoord.x = uvX * res.y + 0.5 * res.x
    //   fragCoord.y = (tiltDown - uvY) * res.y + 0.5 * res.y
    const tiltDown = 0.35; // Must match globe.frag cameraRayDir tiltDown
    final screenX = uvX * size.y + size.x * 0.5;
    final screenY = (tiltDown - uvY) * size.y + size.y * 0.5;

    return Vector2(screenX, screenY);
  }

  /// Recompute the per-frame screen correction vector.
  ///
  /// Called at the end of each update after both the camera and plane position
  /// have been updated. Measures the gap between where the shader projects
  /// the plane's world position and where the plane sprite actually sits,
  /// then caches the difference so worldToScreen can apply it.
  void _computeScreenCorrection() {
    if (_globeRenderer == null || size.x < 1 || size.y < 1) {
      _screenCorrection = Vector2.zero();
      return;
    }
    final projected = _shaderWorldToScreen(_worldPosition);
    if (projected.x < -500) {
      // Plane is occluded (shouldn't happen) — skip correction.
      _screenCorrection = Vector2.zero();
      return;
    }
    final target = Vector2(size.x * planeScreenX, size.y * planeScreenY);
    _screenCorrection = target - projected;
  }

  /// Where on screen the plane sprite is rendered (proportional).
  /// Centered horizontally, 20% from the bottom of the screen (80% from top).
  /// This position is FIXED — the world scrolls underneath, the plane stays put.
  static const double planeScreenY = 0.80;
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
  Color backgroundColor() {
    if (_planeReady) {
      final alt = _plane.continuousAltitude;
      if (alt < 0.6) {
        // Fade background to transparent as altitude drops below 0.6,
        // allowing the DescentMapView behind to show through smoothly.
        final alpha = (alt / 0.6).clamp(0.0, 1.0);
        return FlitColors.oceanDeep.withOpacity(alpha);
      }
    }
    return FlitColors.oceanDeep;
  }

  @override
  Future<void> onLoad() async {
    _log.info('game', 'FlitGame.onLoad started');
    _fuel = maxFuel; // Initialize fuel to full tank (licence-boosted).
    try {
      await super.onLoad();

      if (isFlatMapMode) {
        // Regional flat map mode — static satellite view with boundaries.
        // The satellite tiles come from an OSM tile layer behind the game canvas.
        _flatMapRenderer = FlatMapRenderer(region: region);
        await add(_flatMapRenderer!);
        _shaderReady = false;
        _log.info('game', 'Using flat map renderer for ${region.displayName}');
      } else {
        // Globe mode — try to initialise the GPU shader renderer (V1+).
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
      _planeReady = true;

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

  /// Cached bounding boxes for each country (minLng, minLat, maxLng, maxLat).
  /// Computed once on first use to avoid per-frame allocations.
  static List<Rect>? _countryBounds;

  /// Detect which country the plane is currently over.
  /// Uses bounding-box pre-filtering and point-in-polygon testing.
  void _updateCountryDetection(double dt) {
    _countryCheckTimer += dt;
    if (_countryCheckTimer < _countryCheckInterval) return;

    _countryCheckTimer = 0.0;

    final countries = CountryData.countries;

    // Lazy-init bounding boxes (once, first frame that needs them).
    _countryBounds ??= List<Rect>.generate(countries.length, (i) {
      var minLng = double.infinity;
      var minLat = double.infinity;
      var maxLng = double.negativeInfinity;
      var maxLat = double.negativeInfinity;
      for (final polygon in countries[i].polygons) {
        for (final v in polygon) {
          if (v.x < minLng) minLng = v.x;
          if (v.x > maxLng) maxLng = v.x;
          if (v.y < minLat) minLat = v.y;
          if (v.y > maxLat) maxLat = v.y;
        }
      }
      return Rect.fromLTRB(minLng, minLat, maxLng, maxLat);
    });

    final lng = _worldPosition.x;
    final lat = _worldPosition.y;

    for (var ci = 0; ci < countries.length; ci++) {
      // Fast bounding-box reject (skips ~95% of countries).
      final b = _countryBounds![ci];
      if (lng < b.left || lng > b.right || lat < b.top || lat > b.bottom) {
        continue;
      }

      final country = countries[ci];
      for (final polygon in country.polygons) {
        // Use Vector2 overload directly — no Offset allocation.
        if (_hitTest.isPointInPolygonVec2(lat, lng, polygon)) {
          if (_cachedCountryName != country.name) {
            _previousCountryName = _cachedCountryName;
            _cachedCountryName = country.name;
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

    // --- Launch intro sequence ---
    if (_launchPhase == LaunchPhase.positioning) {
      _launchTimer += dt;
      _updateChaseCamera(dt);
      // Keep plane off-screen below the viewport during globe snap.
      _plane.position = Vector2(size.x * planeScreenX, size.y * 1.5);
      _plane.worldPos = _worldPosition.clone();
      _plane.worldHeading = _heading;
      _computeScreenCorrection();
      if (_launchTimer >= _positioningDuration) {
        _launchPhase = LaunchPhase.flyIn;
        _launchTimer = 0.0;
        _plane.setVisible(); // Make plane visible for fly-in
      }
      return;
    }

    if (_launchPhase == LaunchPhase.flyIn) {
      _launchTimer += dt;
      final t = (_launchTimer / _flyInDuration).clamp(0.0, 1.0);
      // Ease-out cubic for smooth deceleration into final position.
      final eased = 1.0 - pow(1.0 - t, 3);
      final startY = size.y * 1.3; // Below screen
      final endY = size.y * planeScreenY; // Final position (80%)
      _plane.position = Vector2(
        size.x * planeScreenX,
        startY + (endY - startY) * eased,
      );
      _updateChaseCamera(dt);
      _plane.worldPos = _worldPosition.clone();
      _plane.worldHeading = _heading;
      _computeScreenCorrection();
      if (t >= 1.0) {
        _launchPhase = LaunchPhase.playing;
      }
      return;
    }

    // --- Normal gameplay below ---

    // --- Country detection ---
    _updateCountryDetection(dt);

    // --- Decrement country flash timer ---
    if (_countryFlashTimer > 0) {
      _countryFlashTimer = (_countryFlashTimer - dt).clamp(0.0, _countryFlashDuration);
    }

    // --- Fuel consumption ---
    if (fuelEnabled && _fuel > 0) {
      // Burn rate scales with speed setting AND altitude:
      //   - Faster speeds burn more fuel (2.5× at fast vs 0.5× at slow)
      //   - Descent mode burns much less (25% of ascend rate) to encourage
      //     exploration without fuel anxiety
      final isLow = _planeReady && !_plane.isHighAltitude;
      final altitudeFactor = isLow ? 0.25 : 1.0;
      final burnRate = _baseFuelBurnRate * _speedMultiplier * altitudeFactor;
      _fuel = (_fuel - burnRate * dt).clamp(0.0, maxFuel);
      if (_fuel <= 0) {
        onFuelEmpty?.call();
      }
    }

    // --- Motion-gated: input, steering, movement ---
    if (motionEnabled) {
      _updateMotion(dt);
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

    // Update plane visual heading.
    if (isFlatMapMode) {
      // Flat map: north-up static map. The plane must visually face its
      // heading direction. Convert from math convention (0 = east) to
      // canvas convention (0 = up/north) by adding π/2.
      _plane.visualHeading = _heading + pi / 2;
    } else {
      // Globe mode: world rotates under the plane, so the visual heading
      // is the difference between the plane heading and the camera heading.
      // Use shortest-path difference to avoid ±π wrapping jumps.
      var visualDiff = _heading - _cameraHeading;
      while (visualDiff > pi) { visualDiff -= 2 * pi; }
      while (visualDiff < -pi) { visualDiff += 2 * pi; }
      _plane.visualHeading = visualDiff;
    }

    // In flat map mode, the plane moves across the screen.
    // In globe mode, the plane stays fixed and the world scrolls underneath.
    if (isFlatMapMode && _flatMapRenderer != null) {
      final screenPos = _flatMapRenderer!.worldToScreen(
        _worldPosition,
        size.x,
        size.y,
      );
      _plane.position = screenPos;
    } else {
      _plane.position = Vector2(size.x * planeScreenX, size.y * planeScreenY);
    }

    // Feed world state to plane for world-space contrail spawning.
    _plane.worldPos = _worldPosition.clone();
    _plane.worldHeading = _heading;

    // Modulate engine volume with turn intensity.
    AudioManager.instance.updateEngineVolume(_plane.turnDirection.abs());

    // Compute per-frame screen correction so worldToScreen aligns with
    // the plane sprite. Must run AFTER chase camera and motion updates
    // but uses the camera state from super.update(dt) (this frame's
    // camera position after CameraState easing).
    _computeScreenCorrection();
  }

  /// Flight using 3D great-circle movement with turn input.
  ///
  /// Uses cartesian (x,y,z) math on the unit sphere to avoid the lat/lng
  /// singularity at poles. The plane follows a great circle — the true
  /// "straight line" on a sphere — with heading updated correctly at each
  /// step. No clamping, no auto-circle, no polar drift.
  ///
  /// Turn input (keyboard/button or waymarker auto-steer) modifies the
  /// heading before each movement step, curving the flight path.
  void _updateMotion(double dt) {
    // --- Process turn input (keyboard/button progressive, waymarker auto-steer) ---
    _updateTurnInput(dt);
    _updateWaymarkerSteering(dt);

    // --- Apply turn to heading ---
    final turnDir = _plane.turnDirection;
    if (turnDir.abs() > 0.001) {
      final turnRate = _plane.currentTurnRate;
      _heading += turnDir * turnRate * dt;
      while (_heading > pi) { _heading -= 2 * pi; }
      while (_heading < -pi) { _heading += 2 * pi; }
    }

    final speed = _plane.currentSpeedContinuous * _speedMultiplier;
    final angularDist = speed * _speedToAngular * dt; // radians on unit sphere

    if (angularDist < 1e-12) return; // Avoid division by zero when stationary

    // --- Convert current state to 3D ---
    final latRad = _worldPosition.y * _deg2rad;
    final lngRad = _worldPosition.x * _deg2rad;
    final cosLat = cos(latRad);
    final sinLat = sin(latRad);
    final cosLng = cos(lngRad);
    final sinLng = sin(lngRad);

    // Position on unit sphere
    final px = cosLat * cosLng;
    final py = sinLat;
    final pz = cosLat * sinLng;

    // Local tangent basis at current position
    // East  = (-sin(lng), 0, cos(lng))
    // North = (-sin(lat)*cos(lng), cos(lat), -sin(lat)*sin(lng))
    final ex = -sinLng;
    const ey = 0.0;
    final ez = cosLng;
    final nx = -sinLat * cosLng;
    final ny = cosLat;
    final nz = -sinLat * sinLng;

    // Heading tangent vector (bearing = heading + π/2 converts to nav bearing)
    final bearing = _heading + pi / 2;
    final cosB = cos(bearing);
    final sinB = sin(bearing);
    final hx = cosB * nx + sinB * ex;
    final hy = cosB * ny + sinB * ey;
    final hz = cosB * nz + sinB * ez;

    // --- Move along great circle arc: P' = P·cos(d) + H·sin(d) ---
    final cosD = cos(angularDist);
    final sinD = sin(angularDist);
    final newPx = px * cosD + hx * sinD;
    final newPy = py * cosD + hy * sinD;
    final newPz = pz * cosD + hz * sinD;

    // Convert back to lat/lng
    final newLatRad = asin(newPy.clamp(-1.0, 1.0));
    final newLngRad = atan2(newPz, newPx);

    _worldPosition = Vector2(
      _normalizeLng(newLngRad * _rad2deg),
      newLatRad * _rad2deg, // No clamp — asin naturally limits to [-90°, 90°]
    );

    // --- Update heading: project velocity onto new local tangent basis ---
    // Velocity direction on the great circle: V = -P·sin(d) + H·cos(d)
    final vx = -px * sinD + hx * cosD;
    final vy = -py * sinD + hy * cosD;
    final vz = -pz * sinD + hz * cosD;

    // New local tangent basis at destination
    final newCosLat = cos(newLatRad);
    final newSinLat = sin(newLatRad);
    final newCosLng = cos(newLngRad);
    final newSinLng = sin(newLngRad);
    final newNx = -newSinLat * newCosLng;
    final newNy = newCosLat;
    final newNz = -newSinLat * newSinLng;
    final newEx = -newSinLng;
    const newEy = 0.0;
    final newEz = newCosLng;

    // Project velocity onto new North/East to get the bearing at destination
    final northComp = vx * newNx + vy * newNy + vz * newNz;
    final eastComp = vx * newEx + vy * newEy + vz * newEz;
    final newBearing = atan2(eastComp, northComp);

    // Convert nav bearing back to heading (heading = bearing - π/2)
    _heading = newBearing - pi / 2;

    // Normalize heading to [-π, π]
    while (_heading > pi) { _heading -= 2 * pi; }
    while (_heading < -pi) { _heading += 2 * pi; }
  }

  /// Update the chase camera heading and compute the offset camera position.
  ///
  /// The camera heading smoothly interpolates toward the plane heading.
  /// The camera is positioned BEHIND the plane by a distance that places
  /// the plane's world position at exactly (planeScreenX, planeScreenY) on
  /// screen. This offset is computed dynamically from the current camera
  /// distance and FOV so contrails and overlays align with the plane sprite.
  void _updateChaseCamera(double dt) {
    if (_cameraFirstUpdate) {
      _cameraHeading = _heading;
      _cameraFirstUpdate = false;
    } else {
      // Smooth ease-out: camera heading chases plane heading.
      // During turns, reduce the tracking speed so the camera lags behind,
      // creating a gradual "catch-up" effect.
      //
      // In descent mode the plane moves slowly so we need much tighter
      // camera tracking — otherwise the camera drifts far behind during
      // turns, making controls feel broken and unresponsive.
      final turnMag = _plane.turnDirection.abs();
      final isLow = _planeReady && !_plane.isHighAltitude;
      // High altitude: lag up to 80% during turns (cinematic).
      // Low altitude: lag only up to 30% during turns (responsive).
      final lagFactor = isLow ? 0.3 : 0.8;
      final easeRate = _cameraHeadingEaseRate * (1.0 - turnMag * lagFactor);
      final factor = 1.0 - exp(-easeRate * dt);
      _cameraHeading = _lerpAngle(_cameraHeading, _heading, factor);
    }

    // --- Dynamic camera offset ---
    // Compute the angular offset behind the plane that makes
    // worldToScreen(_worldPosition) land at planeScreenY (80%).
    //
    // From the projection math:
    //   screenY/resY = tiltDown - uvY + 0.5
    //   uvY = sin(δ) / ((d - cos(δ)) * tan(fov/2))
    //
    // For planeScreenY = 0.80:
    //   uvY = tiltDown - 0.30 = 0.05
    //
    // Small-angle approximation (δ < 3°):
    //   δ ≈ uvY * (d - R) * tan(fov/2)
    // where d = camera distance from center, R = globe radius.
    const desiredUvY = 0.05; // tiltDown(0.35) - (planeScreenY(0.80) - 0.50)
    final d = cameraDistance;
    final fov = _globeRenderer?.camera.fov ?? CameraState.fovNarrow;
    final halfFovTan = tan(fov / 2);
    final offsetRad = desiredUvY * (d - CameraState.globeRadius) * halfFovTan;

    // Convert camera heading to navigation bearing (0 = north).
    final camBearing = _cameraHeading + pi / 2;

    // Great-circle destination: move offsetRad ahead of the plane (for Canvas).
    final planeLat = _worldPosition.y * _deg2rad;
    final planeLng = _worldPosition.x * _deg2rad;

    final sinPLat = sin(planeLat);
    final cosPLat = cos(planeLat);
    final sinDist = sin(offsetRad);
    final cosDist = cos(offsetRad);

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

    // Compute a point BEHIND the plane for the shader chase camera.
    // The shader camera is behind the plane so the plane appears at
    // planeScreenY on screen, creating a natural over-the-shoulder view.
    final behindBearing = camBearing + pi;
    final behindLat = asin(
      (sinPLat * cosDist + cosPLat * sinDist * cos(behindBearing))
          .clamp(-1.0, 1.0),
    );
    final behindLng = planeLng +
        atan2(
          sin(behindBearing) * sinDist * cosPLat,
          cosDist - sinPLat * sin(behindLat),
        );

    _shaderCameraPosition = Vector2(
      _normalizeLng(behindLng * _rad2deg),
      behindLat * _rad2deg,
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

  // -- Progressive turn input --

  /// Applies progressive turning from keyboard and on-screen buttons.
  ///
  /// Turn strength ramps up the longer the key/button is held:
  ///   - Instant tap: ~0.08 strength (a few degrees of turn)
  ///   - 0.3s hold: ~0.5 strength (moderate turn)
  ///   - 0.6s+ hold: 1.0 strength (full turn)
  /// This makes short taps produce gentle corrections and holds produce
  /// sweeping arcs.
  ///
  /// On web, key-up events can be unreliable (browser steals focus, etc.).
  /// We poll HardwareKeyboard each frame to detect stale key state.
  void _updateTurnInput(double dt) {
    // Poll actual keyboard state every frame (more reliable than events on web).
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    int polledDir = 0;
    if (keys.contains(LogicalKeyboardKey.arrowLeft) ||
        keys.contains(LogicalKeyboardKey.keyA)) {
      polledDir -= 1;
    }
    if (keys.contains(LogicalKeyboardKey.arrowRight) ||
        keys.contains(LogicalKeyboardKey.keyD)) {
      polledDir += 1;
    }

    // If the polled state disagrees with our cached state, force update.
    // This catches missed key-up events on web.
    if (polledDir != _keyTurnDir) {
      _keyTurnHoldTime = polledDir != 0 ? _keyTurnHoldTime : 0.0;
      _keyTurnDir = polledDir;
    }

    // Combine keyboard and button input (button overrides keyboard).
    final dir = _buttonTurnDir != 0 ? _buttonTurnDir : _keyTurnDir;

    if (dir != 0) {
      // Ramp up hold time and compute progressive strength.
      // In descent mode, scale ramp rate faster (2×) so the plane
      // responds immediately despite the lower movement speed.
      final isLow = _planeReady && !_plane.isHighAltitude;
      final rampDt = isLow ? dt * 2.0 : dt;
      if (_buttonTurnDir != 0) {
        _buttonTurnHoldTime += rampDt;
      }
      if (_keyTurnDir != 0) {
        _keyTurnHoldTime += rampDt;
      }
      final holdTime = _buttonTurnDir != 0
          ? _buttonTurnHoldTime
          : _keyTurnHoldTime;

      // Progressive curve: starts at 0.08, reaches 1.0 after ~0.6s.
      // Scale ramp speed with turn sensitivity setting (default 0.5 → 1.0x).
      // In descent mode the faster ramp-up + higher base turn rate gives
      // immediate, snappy steering that matches the slower movement.
      final sensitivityScale = GameSettings.instance.turnSensitivity / 0.5;
      final strength = (0.08 + holdTime * holdTime * 4.5 * sensitivityScale).clamp(0.0, 1.0);
      // When invertControls is false, pass direction through (right = right).
      // When invertControls is true, negate (right input = left turn).
      final invert = GameSettings.instance.invertControls ? -1.0 : 1.0;
      _plane.setTurnDirection(dir * strength * invert);
      _waymarker = null; // keyboard/button overrides waymarker
    } else if (_waymarker == null) {
      // No input and no waymarker — stop turning immediately.
      // releaseTurn() is idempotent so calling every frame is safe.
      _keyTurnHoldTime = 0.0;
      _buttonTurnHoldTime = 0.0;
      _plane.releaseTurn();
    }
  }

  // -- Waymarker auto-steering --

  /// Computes the initial bearing from the plane to the waymarker and
  /// smoothly steers the plane toward it.
  void _updateWaymarkerSteering(double dt) {
    if (_waymarker == null) return;

    // Advance waymarker age for smooth ramp-up.
    _waymarkerAge += dt;

    // Check if plane has reached the waymarker (within ~1 degree / ~111 km).
    final arrivalDist = _greatCircleDistDeg(_worldPosition, _waymarker!);
    if (arrivalDist < 1.0) {
      _waymarker = null;
      _plane.releaseTurn();
      _log.info('game', 'Waymarker reached — cleared');
      return;
    }

    // Compute initial bearing from plane to waymarker (great-circle).
    final lat1 = _worldPosition.y * _deg2rad;
    final lng1 = _worldPosition.x * _deg2rad;
    final lat2 = _waymarker!.y * _deg2rad;
    final lng2 = _waymarker!.x * _deg2rad;
    final dLng = lng2 - lng1;

    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
    final targetBearing = atan2(y, x);

    final currentBearing = _heading + pi / 2;

    var diff = targetBearing - currentBearing;
    while (diff > pi) { diff -= 2 * pi; }
    while (diff < -pi) { diff += 2 * pi; }

    // Sharp turn strength: narrow proportional zone so the plane commits to
    // the turn quickly and doesn't spiral around the waypoint.
    // At 45° error → full turn. Distance factor only slightly dampens when
    // very close (within 10°) to prevent overshoot on final approach.
    final distToWaymarker = _greatCircleDistDeg(_worldPosition, _waymarker!);
    final distanceFactor = (distToWaymarker / 10.0).clamp(0.6, 1.0);
    final baseTurnStrength = (diff / (pi * 0.25)).clamp(-1.0, 1.0);

    // Smooth ramp-up: ease into the turn so the plane doesn't snap instantly.
    // In descent mode, ramp up faster (0.25s vs 0.6s) since the plane is slow
    // and delayed response feels broken.
    final isLow = _planeReady && !_plane.isHighAltitude;
    final rampDuration = isLow ? 0.25 : 0.6;
    final rampUp = (_waymarkerAge / rampDuration).clamp(0.0, 1.0);
    final turnStrength = baseTurnStrength * distanceFactor * rampUp;
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
  /// - Shader renderer: ray-cast initial guess + Newton refinement
  /// - Canvas renderer: uses azimuthal projection inverse
  @override
  void onTapUp(TapUpInfo info) {
    if (!_isPlaying) return;

    // Convert screen tap to globe lat/lng.
    Vector2? latLng;

    if (_globeRenderer != null) {
      // Shader renderer: ray-cast for an initial guess, then refine
      // iteratively so the waymarker dot appears exactly at the tap point.
      final screenPoint = Offset(
        info.eventPosition.widget.x,
        info.eventPosition.widget.y,
      );
      latLng = _screenToLatLngRefined(screenPoint);
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
      _waymarkerAge = 0.0; // Reset ramp-up timer for smooth turn onset
      _log.info('game', 'Waymarker set', data: {
        'lng': latLng.x.toStringAsFixed(1),
        'lat': latLng.y.toStringAsFixed(1),
      });
    } else {
      _log.info('game', 'Tap missed globe - no waymarker set', data: {
        'screenX': info.eventPosition.widget.x.toStringAsFixed(0),
        'screenY': info.eventPosition.widget.y.toStringAsFixed(0),
      });
    }
  }

  /// Convert a screen tap to globe lat/lng using iterative refinement.
  ///
  /// 1. Ray-sphere intersection gives an initial geographic guess.
  /// 2. Newton-Raphson refines the guess until [worldToScreen] projects
  ///    the lat/lng back to within 1 px of the original tap point.
  ///
  /// This guarantees visual consistency: the waymarker dot (rendered via
  /// [worldToScreen]) always appears exactly where the user tapped,
  /// regardless of floating-point drift in the inverse projection.
  Vector2? _screenToLatLngRefined(Offset tap) {
    final cam = _globeRenderer!.camera;

    // Step 1: ray-sphere intersection for initial guess.
    final initial = _hitTest.screenToLatLng(tap, Size(size.x, size.y), cam);
    if (initial == null) return null;

    var lng = initial.dx;
    var lat = initial.dy;

    // Step 2: iterative Newton-Raphson refinement.
    for (var iter = 0; iter < 8; iter++) {
      final proj = _shaderWorldToScreen(Vector2(lng, lat));

      // Off-screen sentinel — the point is behind the camera.
      if (proj.x < -500) break;

      final errX = proj.x - tap.dx;
      final errY = proj.y - tap.dy;

      // Converged to sub-pixel accuracy.
      if (errX.abs() < 0.5 && errY.abs() < 0.5) break;

      // Numerical Jacobian via finite differences.
      const h = 0.005; // degrees (~500 m)
      final pLng = _shaderWorldToScreen(Vector2(lng + h, lat));
      final pLat = _shaderWorldToScreen(Vector2(lng, lat + h));

      // dScreen / d(lng, lat)
      final j00 = (pLng.x - proj.x) / h; // dSx/dLng
      final j01 = (pLat.x - proj.x) / h; // dSx/dLat
      final j10 = (pLng.y - proj.y) / h; // dSy/dLng
      final j11 = (pLat.y - proj.y) / h; // dSy/dLat

      final det = j00 * j11 - j01 * j10;
      if (det.abs() < 1e-10) break; // singular near limb

      // Newton step: delta = J^-1 * (-error)
      final dLng = (-errX * j11 + errY * j01) / det;
      final dLat = (errX * j10 - errY * j00) / det;

      lng += dLng;
      lat = (lat + dLat).clamp(-85.0, 85.0);
    }

    return Vector2(lng, lat);
  }

  @override
  KeyEventResult onKeyEvent(
    RawKeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final superResult = super.onKeyEvent(event, keysPressed);

    // Track keyboard turn direction (progressive turn applied in _updateTurnInput).
    int dir = 0;
    if (keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
        keysPressed.contains(LogicalKeyboardKey.keyA)) {
      dir -= 1;
    }
    if (keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
        keysPressed.contains(LogicalKeyboardKey.keyD)) {
      dir += 1;
    }

    // Reset hold time when direction changes.
    if (dir != _keyTurnDir) {
      _keyTurnHoldTime = 0.0;
      _keyTurnDir = dir;
    }

    // Altitude toggle on key-down only (not hold).
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _plane.toggleAltitude();
        AudioManager.instance.playSfx(SfxType.altitudeChange);
      }

      // Speed controls: 1/2/3 keys (with or without ctrl)
      if (event.logicalKey == LogicalKeyboardKey.digit1 ||
          event.logicalKey == LogicalKeyboardKey.numpad1) {
        setFlightSpeed(FlightSpeed.slow);
      } else if (event.logicalKey == LogicalKeyboardKey.digit2 ||
          event.logicalKey == LogicalKeyboardKey.numpad2) {
        setFlightSpeed(FlightSpeed.medium);
      } else if (event.logicalKey == LogicalKeyboardKey.digit3 ||
          event.logicalKey == LogicalKeyboardKey.numpad3) {
        setFlightSpeed(FlightSpeed.fast);
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
    _waymarkerAge = 0.0;
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

    // Compute initial heading toward the target (great-circle initial bearing).
    final lat1 = startPosition.y * _deg2rad;
    final lat2 = targetPosition.y * _deg2rad;
    final dLng = (targetPosition.x - startPosition.x) * _deg2rad;
    final bearing = atan2(
      sin(dLng) * cos(lat2),
      cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng),
    );
    // Convert nav bearing (0=north) to code heading (heading = bearing - π/2).
    _heading = bearing - pi / 2;
    _cameraHeading = _heading; // snap camera to heading on game start
    _cameraFirstUpdate = true;
    _plane.fadeIn(); // Start invisible during positioning phase
    _plane.contrails.clear(); // Clear leftover contrails from previous games
    _targetLocation = targetPosition;
    _currentClue = clue;
    _waymarker = null; // clear any previous waymarker
    _hintTarget = null; // clear any previous hint
    _flightSpeed = FlightSpeed.medium; // reset speed
    _fuel = maxFuel; // full tank (includes licence bonus)
    // Start launch animation sequence.
    _launchPhase = LaunchPhase.positioning;
    _launchTimer = 0.0;
    _isPlaying = true;
  }

  /// Continue the game with a new target without moving the plane.
  ///
  /// Used for multi-round play: when the player finds the correct country,
  /// the plane keeps flying in its current position/direction and only the
  /// target and clue change. This avoids the jarring teleport effect.
  void continueWithNewTarget({
    required Vector2 targetPosition,
    required String clue,
  }) {
    _log.info('game', 'continueWithNewTarget', data: {
      'target':
          '${targetPosition.x.toStringAsFixed(1)},${targetPosition.y.toStringAsFixed(1)}',
    });

    _targetLocation = targetPosition;
    _currentClue = clue;
    _waymarker = null;
    _hintTarget = null;
    // Refuel on new target (clue answered correctly).
    refuel();
    // Keep position, heading, speed, and camera — seamless transition.
  }

  /// Set on-screen button turn direction. Called by mobile L/R buttons.
  void setButtonTurn(int direction) {
    _buttonTurnDir = direction.clamp(-1, 1);
    if (direction == 0) _buttonTurnHoldTime = 0.0;
  }

  /// Release on-screen button turn.
  void releaseButtonTurn() {
    _buttonTurnDir = 0;
    _buttonTurnHoldTime = 0.0;
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
