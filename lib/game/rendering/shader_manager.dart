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

    // Load textures in parallel. Load each texture independently so that
    // missing or failed textures don't prevent the shader from working.
    // Critical textures (satellite, heightmap) are required; optional ones
    // (shore_distance, city_lights) will degrade gracefully if missing.
    final textureResults = await Future.wait([
      _loadImage('assets/textures/blue_marble.png')
          .then((img) => {'name': 'satellite', 'image': img})
          .catchError((e, st) => {'name': 'satellite', 'error': e, 'stack': st}),
      _loadImage('assets/textures/heightmap.png')
          .then((img) => {'name': 'heightmap', 'image': img})
          .catchError((e, st) => {'name': 'heightmap', 'error': e, 'stack': st}),
      _loadImage('assets/textures/shore_distance.png')
          .then((img) => {'name': 'shore_distance', 'image': img})
          .catchError((e, st) => {'name': 'shore_distance', 'error': e, 'stack': st}),
      _loadImage('assets/textures/city_lights.png')
          .then((img) => {'name': 'city_lights', 'image': img})
          .catchError((e, st) => {'name': 'city_lights', 'error': e, 'stack': st}),
    ]);

    // Process results and report errors for missing textures.
    bool hasCriticalFailure = false;
    for (final result in textureResults) {
      final name = result['name'] as String;
      if (result.containsKey('image')) {
        final image = result['image'] as ui.Image;
        switch (name) {
          case 'satellite':
            _satelliteTexture = image;
            _log.info('shader', 'Loaded texture: $name');
            break;
          case 'heightmap':
            _heightmapTexture = image;
            _log.info('shader', 'Loaded texture: $name');
            break;
          case 'shore_distance':
            _shoreDistTexture = image;
            _log.info('shader', 'Loaded texture: $name');
            break;
          case 'city_lights':
            _cityLightsTexture = image;
            _log.info('shader', 'Loaded texture: $name');
            break;
        }
      } else {
        final error = result['error'];
        final stack = result['stack'];
        final isCritical = name == 'satellite' || name == 'heightmap';
        
        if (isCritical) {
          hasCriticalFailure = true;
          _log.error('shader', 'Failed to load critical texture: $name',
              error: error, stackTrace: stack);
        } else {
          _log.warning('shader', 'Failed to load optional texture: $name (will degrade gracefully)',
              error: error, stackTrace: stack);
        }
        
        // Report to telemetry (non-critical errors are warnings, critical are errors).
        ErrorService.instance.report(
          error,
          stack,
          context: {
            'source': 'ShaderManager',
            'action': 'loadTexture',
            'texture': name,
            'critical': isCritical.toString(),
          },
        );
      }
    }

    // If critical textures failed, abort shader initialization.
    if (hasCriticalFailure) {
      _log.error('shader', 'One or more critical textures failed to load');
      WebErrorBridge.show(
          'Critical textures failed to load.\n\nThe game will fall back to Canvas rendering.');
      _loading = false;
      return;
    }

    // Log summary of loaded textures.
    final loadedCount = [
      _satelliteTexture,
      _heightmapTexture,
      _shoreDistTexture,
      _cityLightsTexture,
    ].where((t) => t != null).length;
    _log.info('shader', 'Textures loaded: $loadedCount/4');

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
  /// Returns null if the shader program is not loaded or if shader
  /// configuration fails. Optional textures (shore_distance, city_lights)
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
