import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../../core/services/error_service.dart';
import '../../core/utils/game_log.dart';
import '../../core/utils/web_error_bridge.dart';
import 'camera_state.dart';

final _log = GameLog.instance;

/// Singleton that loads, caches, and configures the globe fragment shader.
///
/// Handles loading the [FragmentProgram] from the asset bundle, decoding
/// the four texture samplers (satellite, heightmap, shore distance, city
/// lights), and setting all uniforms each frame according to the shader
/// uniform contract.
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
/// ```
/// Plus 4 image samplers: uSatellite, uHeightmap, uShoreDist, uCityLights
class ShaderManager {
  ShaderManager._();

  /// Singleton instance.
  static final ShaderManager instance = ShaderManager._();

  // -- Cached assets --

  ui.FragmentProgram? _program;
  ui.Image? _satelliteTexture;
  ui.Image? _heightmapTexture;
  ui.Image? _shoreDistTexture;
  ui.Image? _cityLightsTexture;

  bool _initialized = false;
  bool _loading = false;

  /// Whether all assets have been successfully loaded.
  bool get isReady => _initialized;

  /// The cached satellite texture, or null if not yet loaded.
  ui.Image? get satelliteTexture => _satelliteTexture;

  /// The cached heightmap texture, or null if not yet loaded.
  ui.Image? get heightmapTexture => _heightmapTexture;

  /// The cached shore distance texture, or null if not yet loaded.
  ui.Image? get shoreDistTexture => _shoreDistTexture;

  /// The cached city lights texture, or null if not yet loaded.
  ui.Image? get cityLightsTexture => _cityLightsTexture;

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

    try {
      // Load the fragment shader program.
      _program = await ui.FragmentProgram.fromAsset('shaders/globe.frag');
      _log.info('shader', 'Fragment program loaded');
    } catch (e, st) {
      _log.error('shader', 'Failed to load fragment shader',
          error: e, stackTrace: st);
      // Report critical error to telemetry — iOS Safari may reload before
      // the periodic flush, so mark as critical for immediate send.
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
          'Shader loading failed:\n$e\n\nThe game will fall back to Canvas rendering.');
      _loading = false;
      return;
    }

    // Load textures in parallel.
    try {
      final results = await Future.wait([
        _loadImage('assets/textures/blue_marble.png'),
        _loadImage('assets/textures/heightmap.png'),
        _loadImage('assets/textures/shore_distance.png'),
        _loadImage('assets/textures/city_lights.png'),
      ]);
      _satelliteTexture = results[0];
      _heightmapTexture = results[1];
      _shoreDistTexture = results[2];
      _cityLightsTexture = results[3];
      _log.info('shader', 'All textures loaded');
    } catch (e, st) {
      _log.error('shader', 'Failed to load one or more textures',
          error: e, stackTrace: st);
      // Report critical error to telemetry.
      ErrorService.instance.reportCritical(
        e,
        st,
        context: {
          'source': 'ShaderManager',
          'action': 'loadTextures',
        },
      );
      // Show error to user via JS overlay.
      WebErrorBridge.show(
          'Texture loading failed:\n$e\n\nThe game will fall back to Canvas rendering.');
      _loading = false;
      return;
    }

    _initialized = true;
    _loading = false;
    _log.info('shader', 'ShaderManager.initialize() complete');
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
  /// Returns null if the shader or any texture is not yet loaded, or if
  /// shader configuration fails.
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

      // -- Image samplers (indices 0-3) --
      if (_satelliteTexture != null) {
        s.setImageSampler(0, _satelliteTexture!);
      }
      if (_heightmapTexture != null) {
        s.setImageSampler(1, _heightmapTexture!);
      }
      if (_shoreDistTexture != null) {
        s.setImageSampler(2, _shoreDistTexture!);
      }
      if (_cityLightsTexture != null) {
        s.setImageSampler(3, _cityLightsTexture!);
      }

      return s;
    } catch (e, st) {
      _log.error('shader', 'Failed to configure shader', error: e, stackTrace: st);
      
      // Report once to avoid spam — configureShader() is called every frame.
      // This catches errors that might not be caught by render() try-catch.
      if (!_configErrorReported) {
        _configErrorReported = true;
        ErrorService.instance.reportCritical(
          e,
          st,
          context: {
            'source': 'ShaderManager',
            'action': 'configureShader',
          },
        );
        WebErrorBridge.show(
            'Shader configuration failed: $e\n\nThe app will use fallback rendering.');
      }
      
      return null;
    }
  }

  /// Load an image from the asset bundle, decode it, and return the first
  /// frame as a [ui.Image].
  Future<ui.Image> _loadImage(String assetPath) async {
    _log.debug('shader', 'Loading texture: $assetPath');
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
    );
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// Release all cached resources. Primarily useful for testing.
  void dispose() {
    _satelliteTexture?.dispose();
    _heightmapTexture?.dispose();
    _shoreDistTexture?.dispose();
    _cityLightsTexture?.dispose();
    _satelliteTexture = null;
    _heightmapTexture = null;
    _shoreDistTexture = null;
    _cityLightsTexture = null;
    _program = null;
    _initialized = false;
    _loading = false;
    _log.info('shader', 'ShaderManager disposed');
  }
}
