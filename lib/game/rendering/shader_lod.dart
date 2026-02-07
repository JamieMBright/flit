import 'dart:collection';

/// Shader Level-of-Detail levels.
///
/// Each level disables progressively more visual features to maintain
/// acceptable frame rates on lower-end hardware.
enum ShaderLOD {
  /// All features enabled: full cloud octaves, foam noise, atmospheric
  /// scattering, city lights, etc.
  high,

  /// Reduced cloud octaves (4 instead of 8), no foam noise,
  /// simplified atmospheric scattering.
  medium,

  /// No clouds, simple flat-color ocean, minimal atmosphere.
  /// Maximum performance for low-end devices.
  low,
}

/// Manages shader quality levels based on real-time performance.
///
/// Tracks frame times over a rolling window, computes average FPS, and
/// automatically adjusts the [ShaderLOD] level to maintain smooth gameplay.
///
/// Hysteresis is built in: the system requires a sustained period of
/// frames above or below the threshold before switching, preventing
/// distracting flip-flopping between quality levels.
class ShaderLODManager {
  ShaderLODManager({
    this.windowSize = 60,
    this.upgradeThresholdFps = 55.0,
    this.downgradeThresholdFps = 45.0,
    this.hysteresisFrames = 90,
  });

  /// Number of frames in the rolling average window.
  final int windowSize;

  /// FPS above which the system considers upgrading LOD.
  final double upgradeThresholdFps;

  /// FPS below which the system considers downgrading LOD.
  final double downgradeThresholdFps;

  /// Number of consecutive frames that must exceed a threshold before
  /// the LOD level actually changes. Prevents flip-flopping.
  final int hysteresisFrames;

  /// Rolling buffer of recent frame times (in seconds).
  final Queue<double> _frameTimes = Queue<double>();

  /// Current LOD level.
  ShaderLOD _currentLOD = ShaderLOD.high;

  /// Counter for how many consecutive frames have been above upgrade threshold.
  int _upgradeCounter = 0;

  /// Counter for how many consecutive frames have been below downgrade threshold.
  int _downgradeCounter = 0;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// The current shader LOD level.
  ShaderLOD get currentLOD => _currentLOD;

  /// Average FPS computed from the rolling frame-time window.
  ///
  /// Returns 60.0 if no frames have been recorded yet.
  double get averageFPS {
    if (_frameTimes.isEmpty) return 60.0;

    double sum = 0.0;
    for (final dt in _frameTimes) {
      sum += dt;
    }
    final avgDt = sum / _frameTimes.length;
    return avgDt > 0 ? 1.0 / avgDt : 60.0;
  }

  /// Records a single frame time (delta time in seconds) and
  /// evaluates whether the LOD level should change.
  void recordFrameTime(double dt) {
    // Ignore absurd values (e.g. first frame after pause).
    if (dt <= 0 || dt > 1.0) return;

    _frameTimes.addLast(dt);
    while (_frameTimes.length > windowSize) {
      _frameTimes.removeFirst();
    }

    // Only evaluate after we have a full window of data.
    if (_frameTimes.length < windowSize) return;

    _evaluateLOD();
  }

  /// Returns a map of uniform override values that the shader should use
  /// for the current LOD level.
  ///
  /// Keys correspond to shader uniform names (without the `u` prefix):
  /// - `cloudIterations`  : number of noise octaves for clouds
  /// - `foamQuality`      : 0.0 = off, 1.0 = full
  /// - `atmosphereQuality`: 0.0 = minimal, 1.0 = full scattering
  /// - `cityLightsEnabled`: 0.0 = off, 1.0 = on
  Map<String, double> get lodUniforms {
    switch (_currentLOD) {
      case ShaderLOD.high:
        return const {
          'cloudIterations': 8.0,
          'foamQuality': 1.0,
          'atmosphereQuality': 1.0,
          'cityLightsEnabled': 1.0,
        };
      case ShaderLOD.medium:
        return const {
          'cloudIterations': 4.0,
          'foamQuality': 0.0,
          'atmosphereQuality': 0.6,
          'cityLightsEnabled': 1.0,
        };
      case ShaderLOD.low:
        return const {
          'cloudIterations': 0.0,
          'foamQuality': 0.0,
          'atmosphereQuality': 0.3,
          'cityLightsEnabled': 0.0,
        };
    }
  }

  /// Resets all tracking state and restores LOD to high.
  void reset() {
    _frameTimes.clear();
    _currentLOD = ShaderLOD.high;
    _upgradeCounter = 0;
    _downgradeCounter = 0;
  }

  /// Forces a specific LOD level, bypassing automatic management.
  ///
  /// Useful for settings menus or debug controls.
  void forceLevel(ShaderLOD level) {
    _currentLOD = level;
    _upgradeCounter = 0;
    _downgradeCounter = 0;
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _evaluateLOD() {
    final fps = averageFPS;

    // --- Downgrade check ---
    if (fps < downgradeThresholdFps) {
      _downgradeCounter++;
      _upgradeCounter = 0;

      if (_downgradeCounter >= hysteresisFrames) {
        _downgrade();
        _downgradeCounter = 0;
      }
    }
    // --- Upgrade check ---
    else if (fps > upgradeThresholdFps) {
      _upgradeCounter++;
      _downgradeCounter = 0;

      if (_upgradeCounter >= hysteresisFrames) {
        _upgrade();
        _upgradeCounter = 0;
      }
    }
    // --- In the "OK" zone: reset both counters ---
    else {
      _upgradeCounter = 0;
      _downgradeCounter = 0;
    }
  }

  void _downgrade() {
    switch (_currentLOD) {
      case ShaderLOD.high:
        _currentLOD = ShaderLOD.medium;
      case ShaderLOD.medium:
        _currentLOD = ShaderLOD.low;
      case ShaderLOD.low:
        break; // Already at lowest.
    }
  }

  void _upgrade() {
    switch (_currentLOD) {
      case ShaderLOD.low:
        _currentLOD = ShaderLOD.medium;
      case ShaderLOD.medium:
        _currentLOD = ShaderLOD.high;
      case ShaderLOD.high:
        break; // Already at highest.
    }
  }
}
