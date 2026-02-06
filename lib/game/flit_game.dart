import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/flit_colors.dart';
import 'components/plane_component.dart';
import 'map/world_map.dart';

/// Main game class for Flit.
///
/// Uses a 3rd-person perspective where the plane stays fixed in the
/// lower portion of the screen and the world scrolls underneath.
class FlitGame extends FlameGame
    with HasKeyboardHandlerComponents, HorizontalDragDetector, TapDetector {
  FlitGame({this.onGameReady, this.onAltitudeChanged});

  final VoidCallback? onGameReady;
  final void Function(bool isHigh)? onAltitudeChanged;

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
    await super.onLoad();

    // Create world map (renders behind plane)
    _worldMap = WorldMap();
    await add(_worldMap);

    // Create plane (renders on top, fixed screen position)
    _plane = PlaneComponent(
      onAltitudeChanged: (isHigh) {
        onAltitudeChanged?.call(isHigh);
      },
    );
    await add(_plane);

    // Start at a random position
    _worldPosition = Vector2(0, 0); // Center of map
    _heading = -pi / 2; // Facing north

    onGameReady?.call();
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

  @override
  void onHorizontalDragUpdate(DragUpdateInfo info) {
    _plane.setTurnDirection((info.delta.global.x * 0.05).clamp(-1, 1));
  }

  @override
  void onHorizontalDragEnd(DragEndInfo info) {
    _plane.setTurnDirection(0);
  }

  @override
  void onTap() {
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
