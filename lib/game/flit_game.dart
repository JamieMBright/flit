import 'dart:math';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/services/audio_manager.dart';
import '../core/theme/flit_colors.dart';
import '../core/utils/game_log.dart';
import 'components/plane_component.dart';
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
/// fallback to the legacy Canvas 2D renderer if the shader fails to load.
class FlitGame extends FlameGame
    with HasKeyboardHandlerComponents, HorizontalDragDetector {
  FlitGame({
    this.onGameReady,
    this.onAltitudeChanged,
    this.fuelBoostMultiplier = 1.0,
    this.isChallenge = false,
    this.planeColorScheme,
    this.useShaderRenderer = true,
    this.equippedPlaneId = 'plane_default',
  });

  final VoidCallback? onGameReady;
  final void Function(bool isHigh)? onAltitudeChanged;

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

  /// Legacy Canvas renderer (fallback).
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

  bool get isPlaying => _isPlaying;
  bool get isHighAltitude => _plane.isHighAltitude;
  PlaneComponent get plane => _plane;
  String? get currentClue => _currentClue;
  bool get isShaderActive => _shaderReady;

  /// World position as (longitude, latitude) degrees.
  Vector2 get worldPosition => _worldPosition;
  double get heading => _heading;

  /// Where on screen the plane is rendered (proportional).
  static const double planeScreenY = 0.50;
  static const double planeScreenX = 0.50;

  /// Angular speed conversion: old speed value → radians/sec on the sphere.
  /// Old system: speed 200 on a 3600-unit map spanning 360°.
  /// So 1 unit = 0.1° → speed * π / 1800 rad/sec.
  static const double _speedToAngular = pi / 1800;

  @override
  Color backgroundColor() => FlitColors.space;

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

          _globeRenderer = GlobeRenderer();
          await add(_globeRenderer!);
          _shaderReady = true;
          _log.info('game', 'Shader renderer initialised');
        } catch (e, st) {
          _log.warning(
            'game',
            'Shader renderer failed, falling back to Canvas',
            error: e,
          );
          _shaderReady = false;
          _globeRenderer = null;
        }
      }

      // If shader failed or not requested, use the legacy Canvas renderer.
      if (!_shaderReady) {
        _worldMap = WorldMap();
        await add(_worldMap!);
        _log.info('game', 'Using legacy Canvas renderer');
      }

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

      // Start engine sound for equipped plane.
      AudioManager.instance.startEngine(equippedPlaneId);

      _log.info('game', 'FlitGame.onLoad complete');

      try {
        onGameReady?.call();
      } catch (e, st) {
        _log.error('game', 'onGameReady callback failed',
            error: e, stackTrace: st);
      }
    } catch (e, st) {
      _log.error('game', 'FlitGame.onLoad FAILED', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

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

    // Feed position to the active renderer.
    // GlobeRenderer reads position from gameRef in its own update(),
    // so we only drive the legacy Canvas renderer explicitly.
    if (!_shaderReady && _worldMap != null) {
      _worldMap!.setCameraCenter(_worldPosition);
      _worldMap!.setAltitude(high: _plane.isHighAltitude);
    }

    // Update plane visual
    _plane.visualHeading = _heading;
    _plane.position = Vector2(
      size.x * planeScreenX,
      size.y * planeScreenY,
    );

    // Modulate engine volume with turn intensity.
    AudioManager.instance.updateEngineVolume(_plane.turnDirection.abs());
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

  /// Drag sensitivity multiplier.
  static const double _dragSensitivity = 0.5;

  /// Minimum drag delta to register as a turn.
  static const double _dragDeadZone = 0.5;

  @override
  void onHorizontalDragUpdate(DragUpdateInfo info) {
    final dx = info.delta.global.x;
    if (dx.abs() < _dragDeadZone) {
      // In dead zone - don't change direction, let it coast
      return;
    }
    // Map the drag to -1..+1 with higher sensitivity
    _plane.setTurnDirection((dx * _dragSensitivity).clamp(-1, 1));
  }

  @override
  void onHorizontalDragEnd(DragEndInfo info) {
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

    _plane.setTurnDirection(direction);

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
