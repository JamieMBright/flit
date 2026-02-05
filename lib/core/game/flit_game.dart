import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../theme/flit_colors.dart';

/// Main game class for Flit.
/// Handles the game loop, rendering, and input.
class FlitGame extends FlameGame with HasKeyboardHandlerComponents {
  FlitGame({
    required this.onGameReady,
  });

  final VoidCallback onGameReady;

  @override
  Color backgroundColor() => FlitColors.backgroundDark;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Add placeholder text until we build the plane
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
        position: size / 2,
      ),
    );

    add(
      TextComponent(
        text: 'Sprint 0 - Infrastructure Ready',
        textRenderer: TextPaint(
          style: const TextStyle(
            color: FlitColors.textSecondary,
            fontSize: 16,
          ),
        ),
        anchor: Anchor.center,
        position: Vector2(size.x / 2, size.y / 2 + 60),
      ),
    );

    onGameReady();
  }
}
