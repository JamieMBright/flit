import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/flit_colors.dart';
import 'components/plane_component.dart';

/// Main game class for Flit.
class FlitGame extends FlameGame
    with HasKeyboardHandlerComponents, HorizontalDragDetector, TapDetector {
  FlitGame({this.onGameReady, this.onAltitudeChanged});

  final VoidCallback? onGameReady;
  final void Function(bool isHigh)? onAltitudeChanged;

  late PlaneComponent _plane;

  /// Current game state
  bool _isPlaying = false;

  /// Target location for current challenge
  Vector2? _targetLocation;

  /// Current clue data
  String? _currentClue;

  bool get isPlaying => _isPlaying;
  bool get isHighAltitude => _plane.isHighAltitude;
  PlaneComponent get plane => _plane;

  @override
  Color backgroundColor() => FlitColors.ocean;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Create plane
    _plane = PlaneComponent(
      onAltitudeChanged: (isHigh) {
        onAltitudeChanged?.call(isHigh);
      },
    );
    await add(_plane);

    // Add placeholder world text
    add(
      TextComponent(
        text: 'Flit',
        textRenderer: TextPaint(
          style: const TextStyle(
            color: FlitColors.textPrimary,
            fontSize: 48,
            fontWeight: FontWeight.bold,
          ),
        ),
        anchor: Anchor.center,
        position: size / 2 + Vector2(0, -100),
      ),
    );

    add(
      TextComponent(
        text: 'Use arrow keys or swipe to steer\nTap or space to change altitude',
        textRenderer: TextPaint(
          style: const TextStyle(
            color: FlitColors.textSecondary,
            fontSize: 14,
          ),
        ),
        anchor: Anchor.center,
        position: size / 2 + Vector2(0, 150),
      ),
    );

    onGameReady?.call();
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

    return KeyEventResult.handled;
  }

  /// Start a new game/challenge
  void startGame({
    required Vector2 startPosition,
    required Vector2 targetPosition,
    required String clue,
  }) {
    _plane.position = startPosition;
    _plane.angle = Random().nextDouble() * 2 * pi;
    _targetLocation = targetPosition;
    _currentClue = clue;
    _isPlaying = true;
  }

  /// Check if plane is near target (for landing detection)
  bool isNearTarget({double threshold = 50}) {
    if (_targetLocation == null) return false;
    return _plane.position.distanceTo(_targetLocation!) < threshold;
  }
}
