import 'dart:math';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/flit_colors.dart';
import '../core/utils/game_log.dart';
import 'components/plane_component.dart';
import 'map/world_map.dart';

final _log = GameLog.instance;

/// Main game class for Flit.
///
/// Uses a 3rd-person perspective where the plane stays fixed in the
/// lower portion of the screen and the world scrolls underneath.
class FlitGame extends FlameGame
    with HasKeyboardHandlerComponents, HorizontalDragDetector, TapDetector {
  FlitGame({
    this.onGameReady,
    this.onAltitudeChanged,
    this.fuelBoostMultiplier = 1.0,
    this.isChallenge = false,
  });

  final VoidCallback? onGameReady;
  final void Function(bool isHigh)? onAltitudeChanged;

  /// Fuel boost from pilot license (1.0 = no boost). Only applies in solo play.
  final double fuelBoostMultiplier;

  /// Whether this is a H2H challenge (disables license bonuses for fair play).
  final bool isChallenge;

  late PlaneComponent _plane;
  late WorldMap _worldMap;

  /// Plane's position in world coordinates (longitude, latitude mapped to map space)
  Vector2 _worldPosition = Vector2.zero();

  /// Plane's heading in radians (0 = north, clockwise)
  double _heading = 0;

  /// Current game state
  bool _isPlaying = false;

  /// Target location for current challenge
  Vector2? _targetLocation;

  /// Current clue data
  String? _currentClue;

  bool get isPlaying => _isPlaying;
  bool get isHighAltitude => _plane.isHighAltitude;
  PlaneComponent get plane => _plane;
  String? get currentClue => _currentClue;
  Vector2 get worldPosition => _worldPosition;
  double get heading => _heading;

  /// Where on screen the plane is rendered (proportional)
  /// 0.7 = 70% down the screen
  static const double planeScreenY = 0.72;
  static const double planeScreenX = 0.5;

  @override
  Color backgroundColor() => FlitColors.oceanDeep;

  @override
  Future<void> onLoad() async {
    _log.info('game', 'FlitGame.onLoad started');
    try {
      await super.onLoad();

      // Create world map (renders behind plane)
      _worldMap = WorldMap();
      await add(_worldMap);

      // Create plane (renders on top, fixed screen position)
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
      );
      await add(_plane);

      // Apply fuel boost only in solo play (not challenges - level playing field)
      if (!isChallenge) {
        _plane.fuelBoostMultiplier = fuelBoostMultiplier;
      }

      // Start at a random position
      _worldPosition = Vector2(0, 0); // Center of map
      _heading = -pi / 2; // Facing north

      _log.info('game', 'FlitGame.onLoad complete');

      // Notify the host widget that the engine is ready.  Wrapped in try/catch
      // so a failure in the callback doesn't break the Flame loading future
      // (which would leave the GameWidget in an unrecoverable error state and
      // produce the white-flash-then-crash behaviour).
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

    // Move in world space based on heading and speed
    final speed = _plane.currentSpeed;
    final dx = cos(_heading) * speed * dt;
    final dy = sin(_heading) * speed * dt;
    _worldPosition += Vector2(dx, dy);

    // Wrap world position horizontally
    if (_worldPosition.x < 0) {
      _worldPosition.x += WorldMap.mapWidth;
    } else if (_worldPosition.x > WorldMap.mapWidth) {
      _worldPosition.x -= WorldMap.mapWidth;
    }

    // Clamp vertical position (don't fly off the poles)
    _worldPosition.y = _worldPosition.y.clamp(0, WorldMap.mapHeight);

    // Update heading based on turn direction
    _heading += _plane.turnDirection * PlaneComponent.turnRate * dt;

    // Tell the world map where the camera should be centered
    _worldMap.setCameraCenter(_worldPosition);
    _worldMap.setAltitude(high: _plane.isHighAltitude);

    // Update plane's visual heading
    _plane.visualHeading = _heading;

    // Tell plane its fixed screen position
    _plane.position = Vector2(
      size.x * planeScreenX,
      size.y * planeScreenY,
    );
  }

  /// Drag sensitivity multiplier.
  /// Higher = plane reacts more to smaller finger movements.
  static const double _dragSensitivity = 0.2;

  @override
  void onHorizontalDragUpdate(DragUpdateInfo info) {
    _plane.setTurnDirection(
        (info.delta.global.x * _dragSensitivity).clamp(-1, 1));
  }

  @override
  void onHorizontalDragEnd(DragEndInfo info) {
    // Don't snap to zero — let PlaneComponent decay the turn smoothly.
    // Only nudge toward zero so the plane straightens out over time.
    _plane.releaseTurn();
  }

  @override
  void onTap() {
    _log.debug('input', 'Screen tap → altitude toggle');
    _plane.toggleAltitude();
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
      }
    }

    return superResult == KeyEventResult.handled
        ? superResult
        : KeyEventResult.handled;
  }

  /// Start a new game/challenge
  void startGame({
    required Vector2 startPosition,
    required Vector2 targetPosition,
    required String clue,
  }) {
    _log.info('game', 'startGame', data: {
      'start': '${startPosition.x.toStringAsFixed(1)},${startPosition.y.toStringAsFixed(1)}',
      'target': '${targetPosition.x.toStringAsFixed(1)},${targetPosition.y.toStringAsFixed(1)}',
    });

    // Convert lat/lng start position to map coordinates
    _worldPosition = _latLngToWorld(startPosition);
    _heading = Random().nextDouble() * 2 * pi;
    _targetLocation = targetPosition;
    _currentClue = clue;
    _isPlaying = true;
  }

  /// Check if plane is near target (for landing detection)
  bool isNearTarget({double threshold = 50}) {
    if (_targetLocation == null) return false;
    final targetWorld = _latLngToWorld(_targetLocation!);
    return _worldPosition.distanceTo(targetWorld) < threshold;
  }

  /// Convert lat/lng to world map coordinates
  Vector2 _latLngToWorld(Vector2 latLng) {
    final x = (latLng.x + 180) / 360 * WorldMap.mapWidth;
    final y = (90 - latLng.y) / 180 * WorldMap.mapHeight;
    return Vector2(x, y);
  }

  /// Convert world map coordinates to lat/lng
  Vector2 worldToLatLng(Vector2 world) {
    final lng = world.x / WorldMap.mapWidth * 360 - 180;
    final lat = 90 - world.y / WorldMap.mapHeight * 180;
    return Vector2(lng, lat);
  }
}
