import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/services.dart';

import 'plane_component.dart';

/// Handles input for controlling the plane.
/// Supports both touch (swipe) and keyboard (arrow keys) input.
class InputHandler extends Component
    with KeyboardHandler, HasGameRef {
  InputHandler({
    required this.plane,
  });

  final PlaneComponent plane;

  /// Horizontal drag tracking
  double _dragDelta = 0;

  /// Sensitivity for swipe controls
  static const double _swipeSensitivity = 0.01;

  /// Current pressed keys
  final Set<LogicalKeyboardKey> _pressedKeys = {};

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _pressedKeys.clear();
    _pressedKeys.addAll(keysPressed);

    // Update plane direction based on keys
    double direction = 0;

    if (_pressedKeys.contains(LogicalKeyboardKey.arrowLeft) ||
        _pressedKeys.contains(LogicalKeyboardKey.keyA)) {
      direction -= 1;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.arrowRight) ||
        _pressedKeys.contains(LogicalKeyboardKey.keyD)) {
      direction += 1;
    }

    plane.setTurnDirection(direction);

    // Toggle altitude with space or up/down arrows
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.arrowDown) {
        plane.toggleAltitude();
      }
    }

    return true;
  }

  /// Handle horizontal drag for touch/mouse input
  void onHorizontalDragUpdate(double delta) {
    _dragDelta = delta * _swipeSensitivity;
    plane.setTurnDirection(_dragDelta.clamp(-1, 1));
  }

  /// Reset turn when drag ends
  void onHorizontalDragEnd() {
    _dragDelta = 0;
    // Only reset if no keyboard keys are pressed
    if (_pressedKeys.isEmpty) {
      plane.setTurnDirection(0);
    }
  }

  /// Handle tap for altitude toggle
  void onTap() {
    plane.toggleAltitude();
  }
}
