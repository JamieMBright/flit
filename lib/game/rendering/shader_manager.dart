import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../../core/services/error_service.dart';
import '../../core/services/game_settings.dart';
import '../../core/utils/game_log.dart';
import '../../core/utils/web_error_bridge.dart';
import 'camera_state.dart';

final _log = GameLog.instance;

/// Singleton that loads, caches, and configures the globe fragment shader.
///
/// Handles loading the [FragmentProgram] from the asset bundle, decoding
/// the two texture samplers (satellite, city lights), and setting all
/// uniforms each frame according to the shader uniform contract.
///
/// Uniform layout (must match shaders/globe.frag):
/// ```
/// Index 0-1 : uResolution (vec2) - viewport size
/// Index 2-4 : uCameraPos  (vec3) - camera position
/// Index 5-7 : uCameraUp   (vec3) - heading-aligned up vector
/// Index 8-10: uSunDir     (vec3) - sun direction
/// Index 11  : uTime
/// Index 12  : uGlobeRadius (1.0)
/// Index 13  : uCloudRadius (1.02)
/// Index 14  : uFOV (field of view radians)
/// Index 15  : uEnableShading (0.0 = raw texture, 1.0 = full shading)
/// Index 16  : uEnableNight   (0.0 = always day,  1.0 = day/night cycle)
/// Index 17  : uEnableClouds  (0.0 = no clouds,   1.0 = clouds on)
/// Index 18  : uCloudCoverage (cloud coverage threshold, 0.0–1.0)
/// Index 19  : uCloudOpacity  (cloud blend opacity, 0.0–1.0)
/// Index 20  : uCameraDist (camera distance from globe center)
/// ```
/// 2 image samplers: uSatellite, uCityLights
class ShaderManager {
  ShaderManager._();

  /// Singleton instance.
  static final ShaderManager instance = ShaderManager._();

  // -- Cached assets --

  ui.FragmentProgram? _program;
  ui.Image? _satelliteTexture;
  ui.Image? _cityLightsTexture;

  // Fallback 1x1 black texture for missing optional samplers.
  ui.Image? _blackTexture;

  bool _initialized = false;
  bool _loading = false;

  /// Whether all assets have been successfully loaded.
  bool get isReady => _initialized;

  /// The cached satellite texture, or null if not yet loaded.
  ui.Image? get satelliteTexture => _satelliteTexture;

  /// Whether a shader configuration error has been reported (to avoid spam).
  bool _configErrorReported = false;

  /// Load the fragment shader program and all texture images.
  ///
  /// Safe to call multiple times; subsequent calls are no-ops if already
  /// initialized or currently loading.
  Future<void> initialize() async {
    if (_initialized || _loading) return;
    _loading = true;

    _log.info('shader', 'ShaderManager.initialize() starting');

    // Create a 1x1 black fallback texture for missing optional samplers.
    // This ensures all shader samplers have a valid binding even if textures
    // fail to load, preventing shader errors on strict platforms.
    try {
      _blackTexture = await _createSolidTexture(0, 0, 0);
      _log.debug('shader', 'Created fallback texture (black)');
    } catch (e, st) {
      _log.error(
        'shader',
        'Failed to create fallback texture',
        error: e,
        stackTrace: st,
      );
      // If we can't even create a 1x1 texture, something is very wrong.
      ErrorService.instance.reportCritical(
        e,
        st,
        context: {'source': 'ShaderManager', 'action': 'createFallbackTexture'},
      );
      WebErrorBridge.show(
        'Critical rendering error.\n\nThe game cannot initialize graphics.',
      );
      _loading = false;
      return;
    }

    try {
      // Load the fragment shader program.
      _program = await ui.FragmentProgram.fromAsset('shaders/globe.frag');
      _log.info('shader', 'Fragment program loaded');
    } catch (e, st) {
      _log.error(
        'shader',
        'Failed to load fragment shader',
        error: e,
        stackTrace: st,
      );

      // Check if this is an "unsupported operation" error (e.g., HTML renderer on web)
      final errorStr = e.toString();
      final isUnsupportedError =
          errorStr.contains('Unsupported operation') ||
          errorStr.contains('not supported') ||
          errorStr.contains('HTML renderer');

      if (isUnsupportedError) {
        // This is expected on web with HTML renderer — report as warning but don't block
        _log.info(
          'shader',
          'FragmentProgram not supported (HTML renderer). Using fallback rendering.',
        );

        // Report to telemetry as warning (non-blocking)
        ErrorService.instance.reportWarning(
          e,
          st,
          context: {
            'source': 'ShaderManager',
            'action': 'loadFragmentProgram',
            'asset': 'shaders/globe.frag',
            'gracefulDegradation': 'true',
            'fallbackMode': 'canvas',
          },
        );

        // Log to JS console but don't block gameplay
        WebErrorBridge.logNonFatal(
          'Shader configuration failed: $e\n\nThe app will use fallback rendering.',
        );
      } else {
        // Unexpected shader error — report as critical
        ErrorService.instance.reportCritical(
          e,
          st,
          context: {
            'source': 'ShaderManager',
            'action': 'loadFragmentProgram',
            'asset': 'shaders/globe.frag',
          },
        );
        // Show error to user via JS overlay (critical for iOS PWA).
        WebErrorBridge.show(
          'Shader loading failed:\n$e\n\nThe game will fall back to Canvas rendering.',
        );
      }

      _loading = false;
      return;
    }

    // Load textures in parallel. Satellite is required; city lights is
    // optional (falls back to black if missing or fails to load).
    final results = await Future.wait([
      _loadImage(
        'assets/textures/blue_marble.png',
      ).then<ui.Image?>((img) => img).catchError((Object e, StackTrace st) {
        _log.error(
          'shader',
          'Failed to load satellite texture',
          error: e,
          stackTrace: st,
        );
        ErrorService.instance.reportError(
          'Satellite texture failed to load.\nError: $e',
          st,
          severity: ErrorSeverity.error,
          context: {
            'source': 'ShaderManager',
            'action': 'loadTexture',
            'texture': 'satellite',
          },
        );
        return null;
      }),
      _loadImage(
        'assets/textures/city_lights.png',
      ).then<ui.Image?>((img) => img).catchError((Object e, StackTrace st) {
        _log.warning(
          'shader',
          'City lights texture not found — using black fallback',
          error: e,
        );
        return null;
      }),
    ]);

    _satelliteTexture = results[0];
    _cityLightsTexture = results[1];

    if (_satelliteTexture != null) {
      _log.info(
        'shader',
        'Loaded satellite (${_satelliteTexture!.width}x${_satelliteTexture!.height})',
      );
    }
    if (_cityLightsTexture != null) {
      _log.info(
        'shader',
        'Loaded city lights (${_cityLightsTexture!.width}x${_cityLightsTexture!.height})',
      );
    }

    // Only mark as initialized if we have at least the satellite texture.
    // Without it, the shader renders as all black, so we should fall back
    // to the Canvas renderer which has Köppen-Geiger colors and blue ocean.
    if (_satelliteTexture != null) {
      _initialized = true;
      _log.info('shader', 'ShaderManager.initialize() complete');
    } else {
      _initialized = false;
      _log.warning(
        'shader',
        'ShaderManager.initialize() failed: satellite texture missing. Falling back to Canvas renderer.',
      );
    }

    _loading = false;
  }

  /// Get a fresh [FragmentShader] instance from the cached program.
  ///
  /// Returns null if the program has not been loaded yet.
  ui.FragmentShader? shader() {
    return _program?.fragmentShader();
  }

  /// Create a fully configured [FragmentShader] with all uniforms and
  /// samplers set, ready to be used as a [Paint.shader].
  ///
  /// Returns null if the shader program is not loaded or if shader
  /// configuration fails. Optional textures (city_lights)
  /// are skipped if not loaded, allowing graceful degradation.
  ///
  /// [size] - viewport dimensions.
  /// [camera] - current camera state (position, target, FOV).
  /// [sunDirX], [sunDirY], [sunDirZ] - normalized sun direction vector.
  /// [time] - elapsed time in seconds.
  ui.FragmentShader? configureShader({
    required ui.Size size,
    required CameraState camera,
    required double sunDirX,
    required double sunDirY,
    required double sunDirZ,
    required double time,
    required double cameraDist,
  }) {
    if (!_initialized || _program == null) return null;

    try {
      final s = _program!.fragmentShader();

      // -- Float uniforms (indices 0-14) --
      // uResolution (vec2)
      s.setFloat(0, size.width);
      s.setFloat(1, size.height);

      // uCameraPos (vec3)
      s.setFloat(2, camera.cameraX);
      s.setFloat(3, camera.cameraY);
      s.setFloat(4, camera.cameraZ);

      // uCameraUp (vec3) - heading-aligned up vector
      s.setFloat(5, camera.upX);
      s.setFloat(6, camera.upY);
      s.setFloat(7, camera.upZ);

      // uSunDir (vec3)
      s.setFloat(8, sunDirX);
      s.setFloat(9, sunDirY);
      s.setFloat(10, sunDirZ);

      // uTime
      s.setFloat(11, time);

      // uGlobeRadius
      s.setFloat(12, CameraState.globeRadius);

      // uCloudRadius
      s.setFloat(13, 1.02);

      // uFOV
      s.setFloat(14, camera.fov);

      // uEnableShading — full shading pipeline enabled (ocean, foam, atmosphere,
      // clouds, city lights, tone-mapping). Set to 0.0 to revert to raw
      // satellite texture mode for debugging texture projection.
      s.setFloat(15, 1.0);

      // uEnableNight (0.0 = always day, 1.0 = day/night cycle)
      s.setFloat(16, GameSettings.instance.enableNight ? 1.0 : 0.0);

      // uEnableClouds (0.0 = no clouds, 1.0 = clouds on)
      s.setFloat(17, GameSettings.instance.enableClouds ? 1.0 : 0.0);

      // uCloudCoverage (cloud coverage threshold, 0.0–1.0)
      s.setFloat(18, GameSettings.instance.cloudCoverage);

      // uCloudOpacity (cloud blend opacity, 0.0–1.0)
      s.setFloat(19, GameSettings.instance.cloudOpacity);

      // uCameraDist (camera distance from globe center)
      s.setFloat(20, cameraDist);

      // -- Image samplers (indices 0-1) --
      // Always bind all 2 samplers to prevent shader errors on platforms that
      // require all declared samplers to be bound.
      s.setImageSampler(0, _satelliteTexture ?? _blackTexture!);
      s.setImageSampler(1, _cityLightsTexture ?? _blackTexture!);

      return s;
    } catch (e, st) {
      _log.error(
        'shader',
        'Failed to configure shader',
        error: e,
        stackTrace: st,
      );

      // Report once to avoid spam — configureShader() is called every frame.
      // This catches errors that might not be caught by render() try-catch.
      if (!_configErrorReported) {
        _configErrorReported = true;

        // Check if this is a known non-fatal error
        final errorStr = e.toString();
        final isUnsupportedError =
            errorStr.contains('Unsupported operation') ||
            errorStr.contains('not supported') ||
            errorStr.contains('HTML renderer');

        if (isUnsupportedError) {
          // Report as warning (non-blocking)
          ErrorService.instance.reportWarning(
            e,
            st,
            context: {
              'source': 'ShaderManager',
              'action': 'configureShader',
              'gracefulDegradation': 'true',
              'fallbackMode': 'canvas',
            },
          );
          // Log to JS console but don't block gameplay
          WebErrorBridge.logNonFatal(
            'Shader configuration failed: $e\n\nThe app will use fallback rendering.',
          );
        } else {
          // Unexpected error — report as critical
          ErrorService.instance.reportCritical(
            e,
            st,
            context: {'source': 'ShaderManager', 'action': 'configureShader'},
          );
          WebErrorBridge.show(
            'Shader configuration failed: $e\n\nThe app will use fallback rendering.',
          );
        }
      }

      return null;
    }
  }

  /// Per-texture load timeout to prevent stalled network/decode from
  /// hanging the entire shader initialization (and thus the game).
  static const _textureTimeout = Duration(seconds: 15);

  /// Load an image from the asset bundle, decode it, and return the first
  /// frame as a [ui.Image]. Times out after [_textureTimeout] to avoid
  /// hanging the game if a network request or decode stalls.
  Future<ui.Image> _loadImage(String assetPath) async {
    _log.debug('shader', 'Loading texture: $assetPath');
    try {
      final data = await rootBundle
          .load(assetPath)
          .timeout(
            _textureTimeout,
            onTimeout: () => throw TimeoutException(
              'Texture load timed out: $assetPath',
              _textureTimeout,
            ),
          );
      final sizeBytes = data.lengthInBytes;
      _log.debug('shader', 'Texture loaded: $assetPath ($sizeBytes bytes)');

      final codec = await ui
          .instantiateImageCodec(data.buffer.asUint8List())
          .timeout(
            _textureTimeout,
            onTimeout: () => throw TimeoutException(
              'Texture decode timed out: $assetPath',
              _textureTimeout,
            ),
          );
      final frame = await codec.getNextFrame();
      final image = frame.image;

      _log.debug(
        'shader',
        'Texture decoded: $assetPath (${image.width}x${image.height})',
      );

      return image;
    } catch (e, st) {
      // Add detailed error context for better debugging
      _log.error(
        'shader',
        'Failed to load/decode texture: $assetPath',
        error: e,
        stackTrace: st,
      );

      // Re-throw with enhanced context for caller to handle
      throw Exception(
        'Texture load failed: $assetPath\n'
        'Error: $e\n'
        'This may be due to:\n'
        '- Missing asset file in pubspec.yaml\n'
        '- Network failure (web platform)\n'
        '- Corrupted image file\n'
        '- Unsupported image format\n'
        '- iOS Safari storage quota exceeded\n'
        '- Load/decode timed out',
      );
    }
  }

  /// Create a 1x1 solid-colour texture for use as a shader sampler fallback.
  ///
  /// [r], [g], [b] are 0-255 channel values. The alpha is always 255 (opaque).
  Future<ui.Image> _createSolidTexture(int r, int g, int b) async {
    final completer = Completer<ui.Image>();
    final pixels = Uint8List.fromList([r, g, b, 255]);

    ui.decodeImageFromPixels(
      pixels,
      1, // width
      1, // height
      ui.PixelFormat.rgba8888,
      (ui.Image image) {
        completer.complete(image);
      },
    );

    return completer.future;
  }

  /// Release all cached resources. Primarily useful for testing.
  void dispose() {
    _satelliteTexture?.dispose();
    _cityLightsTexture?.dispose();
    _blackTexture?.dispose();
    _satelliteTexture = null;
    _cityLightsTexture = null;
    _blackTexture = null;
    _program = null;
    _initialized = false;
    _loading = false;
    _log.info('shader', 'ShaderManager disposed');
  }
}
