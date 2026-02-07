import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/theme/flit_colors.dart';
import '../../core/utils/game_log.dart';
import '../components/plane_component.dart';
import '../flit_game.dart';
import 'camera_state.dart';
import 'shader_manager.dart';

/// Re-export PlaneComponent so imports from plane_component.dart resolve
/// when callers import globe_renderer.dart.
export '../components/plane_component.dart' show PlaneComponent;

final _log = GameLog.instance;

/// Flame component that renders the globe using the GPU fragment shader.
///
/// Replaces the Canvas-based [WorldMap] with a single full-screen quad
/// drawn with a [FragmentShader] paint. The shader handles all visual
/// layers: satellite terrain, ocean, foam, atmosphere, clouds, city lights,
/// and day/night terminator.
///
/// Falls back to a solid dark color if the shader has not yet loaded.
///
/// Owns a [CameraState] instance that tracks the plane's position and
/// produces the camera uniforms each frame.
class GlobeRenderer extends Component with HasGameRef<FlitGame> {
  GlobeRenderer();

  /// Camera state for computing view uniforms.
  final CameraState _camera = CameraState();

  /// Elapsed time in seconds, fed to the shader for animations.
  double _time = 0.0;

  /// Current sun direction (normalized), rotated slowly for day/night cycle.
  double _sunDirX = 1.0;
  double _sunDirY = 0.3;
  double _sunDirZ = 0.0;

  /// Rate at which the sun rotates around the globe (radians per second).
  /// One full day/night cycle every ~120 seconds of game time.
  static const double _sunRotationRate = 2 * pi / 120.0;

  /// Cached screen size from the last render pass.
  Size _lastSize = Size.zero;

  /// Access to the camera state for external queries (e.g., hit testing).
  CameraState get camera => _camera;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Kick off shader loading if not already initialized.
    if (!ShaderManager.instance.isReady) {
      _log.info('globe_renderer', 'Initializing ShaderManager');
      try {
        await ShaderManager.instance.initialize();
      } catch (e, st) {
        _log.error('globe_renderer', 'ShaderManager initialization failed',
            error: e, stackTrace: st);
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    _time += dt;

    // -- Update camera from the game's plane position --
    final worldPos = gameRef.worldPosition;
    final plane = gameRef.plane;

    // speedFraction: ratio of current speed to max speed.
    final speedFraction =
        plane.currentSpeed / PlaneComponent.highAltitudeSpeed;

    _camera.update(
      dt,
      planeLatDeg: worldPos.y,
      planeLngDeg: worldPos.x,
      isHighAltitude: plane.isHighAltitude,
      speedFraction: speedFraction.clamp(0.0, 1.0),
    );

    // -- Rotate the sun direction for day/night cycle --
    final sunAngle = _time * _sunRotationRate;
    _sunDirX = cos(sunAngle);
    _sunDirY = 0.3; // slight tilt above the equatorial plane
    _sunDirZ = sin(sunAngle);

    // Normalize the sun direction vector.
    final sunLen = sqrt(_sunDirX * _sunDirX +
        _sunDirY * _sunDirY +
        _sunDirZ * _sunDirZ);
    if (sunLen > 0.0001) {
      _sunDirX /= sunLen;
      _sunDirY /= sunLen;
      _sunDirZ /= sunLen;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final screenSize = gameRef.size;
    _lastSize = Size(screenSize.x, screenSize.y);

    final shaderManager = ShaderManager.instance;

    if (!shaderManager.isReady) {
      // Fallback: draw a solid dark space background while shader loads.
      _renderFallback(canvas, _lastSize);
      return;
    }

    final shader = shaderManager.configureShader(
      size: _lastSize,
      camera: _camera,
      sunDirX: _sunDirX,
      sunDirY: _sunDirY,
      sunDirZ: _sunDirZ,
      time: _time,
    );

    if (shader == null) {
      _renderFallback(canvas, _lastSize);
      return;
    }

    // Draw full-screen rect with the shader paint.
    final paint = Paint()..shader = shader;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _lastSize.width, _lastSize.height),
      paint,
    );
  }

  /// Fallback rendering when the shader is unavailable.
  ///
  /// Draws a solid dark space color so the screen is never blank.
  void _renderFallback(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = FlitColors.space,
    );
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _lastSize = Size(size.x, size.y);
  }
}
