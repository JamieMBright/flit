import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/services/error_service.dart';
import '../../core/theme/flit_colors.dart';
import '../../core/utils/game_log.dart';
import '../../core/utils/web_error_bridge.dart';
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
/// layers: satellite terrain, ocean, atmosphere, clouds, city lights,
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

  /// Sun direction (normalized, static — computed once at initialization).
  /// Sun at ~30 degrees above the equatorial plane, slightly to the right.
  /// Already normalized: sqrt(0.866^2 + 0.5^2 + 0.0^2) = sqrt(0.75+0.25) = 1.0
  double _sunDirX = 0.866;
  double _sunDirY = 0.5;
  double _sunDirZ = 0.0;

  /// Cached shader Paint — reused every frame to avoid per-frame allocation.
  final Paint _shaderPaint = Paint();

  /// Cached fallback Paint — reused every frame to avoid per-frame allocation.
  static final Paint _fallbackPaint = Paint()..color = FlitColors.space;

  /// Cached screen size from the last render pass.
  Size _lastSize = Size.zero;

  /// Whether a render error has been reported (to avoid spam).
  bool _renderErrorReported = false;

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
        _log.error(
          'globe_renderer',
          'ShaderManager initialization failed',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    _time += dt;

    // -- Update camera from the behind-plane chase camera position --
    final camPos = gameRef.shaderCameraPosition;
    final plane = gameRef.plane;

    // speedFraction: ratio of current speed to max speed.
    // Use continuous speed for smooth FOV transitions
    final speedFraction =
        plane.currentSpeedContinuous / PlaneComponent.highAltitudeSpeed;

    _camera.update(
      dt,
      planeLatDeg: camPos.y,
      planeLngDeg: camPos.x,
      isHighAltitude: plane.isHighAltitude,
      speedFraction: speedFraction.clamp(0.0, 1.0),
      headingRad: gameRef.cameraHeadingBearing,
      altitudeFraction: plane.continuousAltitude,
    );
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Below altitude 0.3 the OSM tile map provides all visuals — skip shader
    // entirely. Between 0.3 and 0.6 we fade the shader out so the transition
    // from globe to flat map is smooth (no abrupt pop).
    final alt = gameRef.plane.continuousAltitude;
    if (alt < 0.3) return;

    try {
      final screenSize = gameRef.size;
      if (screenSize.x != _lastSize.width || screenSize.y != _lastSize.height) {
        _lastSize = Size(screenSize.x, screenSize.y);
      }

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
        cameraDist: _camera.currentDistance,
      );

      if (shader == null) {
        _renderFallback(canvas, _lastSize);
        return;
      }

      // Draw full-screen rect with the shader paint.
      // Fade out as altitude drops below 0.6 for smooth globe→map transition.
      final shaderOpacity = alt >= 0.6
          ? 1.0
          : ((alt - 0.3) / 0.3).clamp(0.0, 1.0);
      _shaderPaint.shader = shader;
      if (shaderOpacity < 1.0) {
        canvas.saveLayer(
          Rect.fromLTWH(0, 0, _lastSize.width, _lastSize.height),
          Paint()..color = Color.fromRGBO(0, 0, 0, shaderOpacity),
        );
      }
      canvas.drawRect(
        Rect.fromLTWH(0, 0, _lastSize.width, _lastSize.height),
        _shaderPaint,
      );
      if (shaderOpacity < 1.0) {
        canvas.restore();
      }
    } catch (e, st) {
      // Catch any shader rendering errors — critical for iOS Safari where
      // shader compilation or uniform setting can fail and crash the app.
      _log.error('globe_renderer', 'Render error', error: e, stackTrace: st);

      // Report only once to avoid spam (errors can occur every frame).
      if (!_renderErrorReported) {
        _renderErrorReported = true;

        // Check if this is a shader-related error (non-fatal with fallback)
        final errorStr = e.toString();
        final isShaderError =
            errorStr.contains('shader') ||
            errorStr.contains('Unsupported operation') ||
            errorStr.contains('not supported') ||
            errorStr.contains('HTML renderer') ||
            errorStr.contains('FragmentProgram');

        if (isShaderError) {
          // Report as warning (non-blocking, has fallback rendering)
          ErrorService.instance.reportWarning(
            e,
            st,
            context: {
              'source': 'GlobeRenderer',
              'action': 'render',
              'shaderReady': '${ShaderManager.instance.isReady}',
              'gracefulDegradation': 'true',
              'fallbackMode': 'canvas',
            },
          );
          // Log to console but don't block gameplay
          WebErrorBridge.logNonFatal(
            'Shader rendering failed: $e\n\nThe app will use fallback rendering.',
          );
        } else {
          // Unexpected rendering error — report as critical
          ErrorService.instance.reportCritical(
            e,
            st,
            context: {
              'source': 'GlobeRenderer',
              'action': 'render',
              'shaderReady': '${ShaderManager.instance.isReady}',
            },
          );
          // Show error to user via JS overlay (brief message, full details in telemetry).
          WebErrorBridge.show(
            'Shader rendering failed: $e\n\nThe app will use fallback rendering.',
          );
        }
      }

      // Fallback to solid background to prevent blank screen.
      _renderFallback(canvas, _lastSize);
    }
  }

  /// Fallback rendering when the shader is unavailable.
  ///
  /// Draws a solid dark space color so the screen is never blank.
  void _renderFallback(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      _fallbackPaint,
    );
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _lastSize = Size(size.x, size.y);
  }
}
