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
/// Index 15  : uEnableShading (0.0 = raw texture, 1.0 = full shading)
/// Index 16  : uEnableNight   (0.0 = always day,  1.0 = day/night cycle)
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
  
  // Fallback 1x1 textures for missing optional samplers.
  // Each fallback uses a value that produces sensible shader output:
  //   - Black (0): for city lights (no lights when missing)
  //   - Gray (128 ≈ 0.5): for heightmap (above SEA_LEVEL, renders as land)
  //   - White (255 ≈ 1.0): for shore distance (far from shore, no foam)
  ui.Image? _blackTexture;
  ui.Image? _grayTexture;
  ui.Image? _whiteTexture;

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

    // Create a 1x1 black fallback texture for missing optional samplers.
    // This ensures all shader samplers have a valid binding even if textures
    // fail to load, preventing shader errors on strict platforms.
    try {
      _blackTexture = await _createSolidTexture(0, 0, 0);
      _grayTexture = await _createSolidTexture(128, 128, 128);
      _whiteTexture = await _createSolidTexture(255, 255, 255);
      _log.debug('shader', 'Created fallback textures (black, gray, white)');
    } catch (e, st) {
      _log.error('shader', 'Failed to create fallback texture',
          error: e, stackTrace: st);
      // If we can't even create a 1x1 texture, something is very wrong.
      ErrorService.instance.reportCritical(
        e,
        st,
        context: {
          'source': 'ShaderManager',
          'action': 'createFallbackTexture',
        },
      );
      WebErrorBridge.show(
          'Critical rendering error.\n\nThe game cannot initialize graphics.');
      _loading = false;
      return;
    }

    try {
      // Load the fragment shader program.
      _program = await ui.FragmentProgram.fromAsset('shaders/globe.frag');
      _log.info('shader', 'Fragment program loaded');
    } catch (e, st) {
      _log.error('shader', 'Failed to load fragment shader',
          error: e, stackTrace: st);
      
      // Check if this is an "unsupported operation" error (e.g., HTML renderer on web)
      final errorStr = e.toString();
      final isUnsupportedError = errorStr.contains('Unsupported operation') || 
                                  errorStr.contains('not supported') ||
                                  errorStr.contains('HTML renderer');
      
      if (isUnsupportedError) {
        // This is expected on web with HTML renderer — report as warning but don't block
        _log.info('shader', 'FragmentProgram not supported (HTML renderer). Using fallback rendering.');
        
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
            'Shader configuration failed: $e\n\nThe app will use fallback rendering.');
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
            'Shader loading failed:\n$e\n\nThe game will fall back to Canvas rendering.');
      }
      
      _loading = false;
      return;
    }

    // Load textures in parallel. Load each texture independently so that
    // missing or failed textures don't prevent the shader from working.
    // All textures are optional - the game will run with black fallback
    // textures if any fail to load.
    final textureResults = await Future.wait<Map<String, dynamic>>([
      _loadImage('assets/textures/blue_marble.png')
          .then((img) => <String, dynamic>{'name': 'satellite', 'image': img})
          .catchError((e, st) => <String, dynamic>{'name': 'satellite', 'error': e, 'stack': st}),
      _loadImage('assets/textures/heightmap.png')
          .then((img) => <String, dynamic>{'name': 'heightmap', 'image': img})
          .catchError((e, st) => <String, dynamic>{'name': 'heightmap', 'error': e, 'stack': st}),
      _loadImage('assets/textures/shore_distance.png')
          .then((img) => <String, dynamic>{'name': 'shore_distance', 'image': img})
          .catchError((e, st) => <String, dynamic>{'name': 'shore_distance', 'error': e, 'stack': st}),
      _loadImage('assets/textures/city_lights.png')
          .then((img) => <String, dynamic>{'name': 'city_lights', 'image': img})
          .catchError((e, st) => <String, dynamic>{'name': 'city_lights', 'error': e, 'stack': st}),
    ]);

    // Process results and report errors for missing textures.
    // All textures are now optional - failures are logged but don't prevent
    // the game from running.
    for (final result in textureResults) {
      final name = result['name'] as String;
      if (result.containsKey('image')) {
        final image = result['image'] as ui.Image;
        switch (name) {
          case 'satellite':
            _satelliteTexture = image;
            _log.info('shader', 'Loaded texture: $name (${image.width}x${image.height})');
            break;
          case 'heightmap':
            _heightmapTexture = image;
            _log.info('shader', 'Loaded texture: $name (${image.width}x${image.height})');
            break;
          case 'shore_distance':
            _shoreDistTexture = image;
            _log.info('shader', 'Loaded texture: $name (${image.width}x${image.height})');
            break;
          case 'city_lights':
            _cityLightsTexture = image;
            _log.info('shader', 'Loaded texture: $name (${image.width}x${image.height})');
            break;
        }
      } else {
        final error = result['error'];
        final stack = result['stack'];
        
        // Extract more details from the error for better debugging
        final errorStr = error.toString();
        final assetPath = name == 'satellite' ? 'assets/textures/blue_marble.png'
            : name == 'heightmap' ? 'assets/textures/heightmap.png'
            : name == 'shore_distance' ? 'assets/textures/shore_distance.png'
            : 'assets/textures/city_lights.png';
        
        // Log the error (all textures are now treated as optional)
        _log.error('shader', 
            'Failed to load texture: $name from $assetPath (will use black fallback)',
            error: error, stackTrace: stack);
        
        // Report to telemetry with enhanced context
        final context = <String, String>{
          'source': 'ShaderManager',
          'action': 'loadTexture',
          'texture': name,
          'assetPath': assetPath,
          'gracefulDegradation': 'true',
          'errorType': errorStr.contains('404') ? 'not_found'
              : errorStr.contains('network') ? 'network_failure'
              : errorStr.contains('decode') ? 'decode_failure'
              : errorStr.contains('quota') ? 'storage_quota'
              : 'unknown',
        };
        
        // Report as error (not critical) so it gets logged but doesn't halt execution
        ErrorService.instance.reportError(
          'Texture failed to load: $name\n'
          'Path: $assetPath\n'
          'Error: $errorStr\n'
          'Game will continue with black fallback texture.',
          stack,
          severity: ErrorSeverity.error,
          context: context,
        );
      }
    }

    // Log summary of loaded textures.
    final loadedCount = [
      _satelliteTexture,
      _heightmapTexture,
      _shoreDistTexture,
      _cityLightsTexture,
    ].where((t) => t != null).length;
    _log.info('shader', 'Textures loaded: $loadedCount/4');

    // Only mark as initialized if we have at least the satellite texture.
    // Without it, the shader renders as all black, so we should fall back
    // to the Canvas renderer which has Köppen-Geiger colors and blue ocean.
    if (_satelliteTexture != null) {
      _initialized = true;
      _log.info('shader', 'ShaderManager.initialize() complete');
    } else {
      _initialized = false;
      _log.warning('shader', 'ShaderManager.initialize() failed: satellite texture missing. Falling back to Canvas renderer.');
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

      // uEnableShading — always disabled (raw satellite texture, no lighting)
      s.setFloat(15, 0.0);

      // uEnableNight (0.0 = always day, 1.0 = day/night cycle)
      s.setFloat(16, GameSettings.instance.enableNight ? 1.0 : 0.0);

      // -- Image samplers (indices 0-3) --
      // Always bind all 4 samplers to prevent shader errors on platforms that
      // require all declared samplers to be bound. Each uses an appropriate
      // fallback: gray for heightmap (renders as land, not ocean), white for
      // shore distance (far from shore, no foam), black for city lights (none).
      s.setImageSampler(0, _satelliteTexture ?? _blackTexture!);
      s.setImageSampler(1, _heightmapTexture ?? _grayTexture!);
      s.setImageSampler(2, _shoreDistTexture ?? _whiteTexture!);
      s.setImageSampler(3, _cityLightsTexture ?? _blackTexture!);

      return s;
    } catch (e, st) {
      _log.error('shader', 'Failed to configure shader', error: e, stackTrace: st);
      
      // Report once to avoid spam — configureShader() is called every frame.
      // This catches errors that might not be caught by render() try-catch.
      if (!_configErrorReported) {
        _configErrorReported = true;
        
        // Check if this is a known non-fatal error
        final errorStr = e.toString();
        final isUnsupportedError = errorStr.contains('Unsupported operation') || 
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
              'Shader configuration failed: $e\n\nThe app will use fallback rendering.');
        } else {
          // Unexpected error — report as critical
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
      }
      
      return null;
    }
  }

  /// Load an image from the asset bundle, decode it, and return the first
  /// frame as a [ui.Image].
  Future<ui.Image> _loadImage(String assetPath) async {
    _log.debug('shader', 'Loading texture: $assetPath');
    try {
      final data = await rootBundle.load(assetPath);
      final sizeBytes = data.lengthInBytes;
      _log.debug('shader', 'Texture loaded: $assetPath ($sizeBytes bytes)');
      
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      
      _log.debug('shader', 
          'Texture decoded: $assetPath (${image.width}x${image.height})');
      
      return image;
    } catch (e, st) {
      // Add detailed error context for better debugging
      _log.error('shader', 
          'Failed to load/decode texture: $assetPath', 
          error: e, 
          stackTrace: st);
      
      // Re-throw with enhanced context for caller to handle
      throw Exception(
          'Texture load failed: $assetPath\n'
          'Error: $e\n'
          'This may be due to:\n'
          '- Missing asset file in pubspec.yaml\n'
          '- Network failure (web platform)\n'
          '- Corrupted image file\n'
          '- Unsupported image format\n'
          '- iOS Safari storage quota exceeded');
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
    _heightmapTexture?.dispose();
    _shoreDistTexture?.dispose();
    _cityLightsTexture?.dispose();
    _blackTexture?.dispose();
    _grayTexture?.dispose();
    _whiteTexture?.dispose();
    _satelliteTexture = null;
    _heightmapTexture = null;
    _shoreDistTexture = null;
    _cityLightsTexture = null;
    _blackTexture = null;
    _grayTexture = null;
    _whiteTexture = null;
    _program = null;
    _initialized = false;
    _loading = false;
    _log.info('shader', 'ShaderManager disposed');
  }
}
