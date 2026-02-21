import 'dart:collection';
import 'dart:io' show ProcessInfo;

import 'package:flutter/foundation.dart';

/// Lightweight performance monitor singleton for Flit.
///
/// Tracks frame timing, per-pass shader timing, and memory snapshots.
/// All measurement methods are no-ops in release builds (`kReleaseMode`).
/// Use [beginFrame]/[endFrame] from the game loop and
/// [beginShaderPass]/[endShaderPass] around shader dispatch.
///
/// Access the live summary via [summary] for the debug overlay, or call
/// [generateReport] to produce a JSON-serializable snapshot.
class PerfMonitor {
  PerfMonitor._();

  /// Singleton instance.
  static final PerfMonitor instance = PerfMonitor._();

  // -- Frame timing --

  /// Rolling window of the last 120 frame durations (microseconds).
  final Queue<int> _frameDurationsUs = Queue<int>();

  /// Maximum number of frames kept in the rolling window.
  static const int _windowSize = 120;

  /// Stopwatch used to measure a single frame's wall-clock duration.
  final Stopwatch _frameWatch = Stopwatch();

  /// Total frames recorded since monitor was reset / app started.
  int _totalFrames = 0;

  /// Frames that took longer than 16.67 ms (i.e. dropped below 60 fps).
  int _jankFrames = 0;

  // -- Shader pass timing --

  /// Per-pass stopwatches keyed by pass name.
  final Map<String, Stopwatch> _passWatches = {};

  /// Accumulated totals (microseconds) and counts per pass.
  final Map<String, int> _passTotalUs = {};
  final Map<String, int> _passCounts = {};

  // -- Memory --

  /// Last recorded Dart heap usage in bytes (0 if unavailable).
  int _lastHeapBytes = 0;

  // -- Session --

  /// Stopwatch running from the first [beginFrame] call.
  final Stopwatch _sessionWatch = Stopwatch();

  // --------------------------------------------------------------------------
  // Frame timing
  // --------------------------------------------------------------------------

  /// Mark the start of a frame. Call once at the top of the game loop update.
  void beginFrame() {
    if (kReleaseMode) return;
    if (!_sessionWatch.isRunning) _sessionWatch.start();
    _frameWatch
      ..reset()
      ..start();
  }

  /// Mark the end of a frame. Call once at the bottom of the game loop update.
  void endFrame() {
    if (kReleaseMode) return;
    _frameWatch.stop();
    final us = _frameWatch.elapsedMicroseconds;

    _frameDurationsUs.addLast(us);
    if (_frameDurationsUs.length > _windowSize) {
      _frameDurationsUs.removeFirst();
    }

    _totalFrames++;
    if (us > 16667) _jankFrames++; // > 16.67 ms = below 60 fps
  }

  // --------------------------------------------------------------------------
  // Shader pass timing
  // --------------------------------------------------------------------------

  /// Mark the start of a named shader pass (e.g. `'globe'`).
  void beginShaderPass(String name) {
    if (kReleaseMode) return;
    (_passWatches[name] ??= Stopwatch())
      ..reset()
      ..start();
  }

  /// Mark the end of a named shader pass and record the elapsed time.
  void endShaderPass(String name) {
    if (kReleaseMode) return;
    final sw = _passWatches[name];
    if (sw == null) return;
    sw.stop();
    final us = sw.elapsedMicroseconds;
    _passTotalUs[name] = (_passTotalUs[name] ?? 0) + us;
    _passCounts[name] = (_passCounts[name] ?? 0) + 1;
  }

  // --------------------------------------------------------------------------
  // Memory tracking
  // --------------------------------------------------------------------------

  /// Record a snapshot of current Dart heap usage.
  ///
  /// Uses [ProcessInfo.currentRss] where available (native targets).
  /// On Web, the value stays 0 (no process API available).
  void recordMemorySnapshot() {
    if (kReleaseMode) return;
    try {
      _lastHeapBytes = ProcessInfo.currentRss;
    } catch (_) {
      _lastHeapBytes = 0;
    }
  }

  // --------------------------------------------------------------------------
  // Derived metrics
  // --------------------------------------------------------------------------

  /// Average FPS over the rolling window. Returns 0.0 if no frames recorded.
  double get avgFps {
    if (_frameDurationsUs.isEmpty) return 0.0;
    final avgUs =
        _frameDurationsUs.fold(0, (a, b) => a + b) / _frameDurationsUs.length;
    return avgUs > 0 ? 1e6 / avgUs : 0.0;
  }

  /// Minimum FPS (worst frame) in the rolling window.
  double get minFps {
    if (_frameDurationsUs.isEmpty) return 0.0;
    final worstUs = _frameDurationsUs.reduce((a, b) => a > b ? a : b);
    return worstUs > 0 ? 1e6 / worstUs : 0.0;
  }

  /// 95th-percentile frame time in milliseconds over the rolling window.
  double get p95FrameTimeMs {
    if (_frameDurationsUs.isEmpty) return 0.0;
    final sorted = _frameDurationsUs.toList()..sort();
    final idx = (sorted.length * 0.95).floor().clamp(0, sorted.length - 1);
    return sorted[idx] / 1000.0;
  }

  /// Number of jank frames recorded over the entire session.
  int get jankFrameCount => kReleaseMode ? 0 : _jankFrames;

  /// Total frames recorded over the entire session.
  int get totalFrames => kReleaseMode ? 0 : _totalFrames;

  // --------------------------------------------------------------------------
  // Report generation
  // --------------------------------------------------------------------------

  /// Returns a JSON-serializable performance summary snapshot.
  Map<String, dynamic> generateReport() {
    if (kReleaseMode) return const {};

    final passes = <String, dynamic>{};
    for (final name in _passCounts.keys) {
      final count = _passCounts[name]!;
      final avgMs = count > 0 ? (_passTotalUs[name]! / count) / 1000.0 : 0.0;
      passes[name] = {'avgMs': double.parse(avgMs.toStringAsFixed(2))};
    }

    return {
      'avgFps': double.parse(avgFps.toStringAsFixed(1)),
      'minFps': double.parse(minFps.toStringAsFixed(1)),
      'p95FrameTimeMs': double.parse(p95FrameTimeMs.toStringAsFixed(2)),
      'jankFrames': _jankFrames,
      'totalFrames': _totalFrames,
      'shaderPasses': passes,
      'sessionDurationSec': _sessionWatch.elapsed.inMilliseconds ~/ 1000,
    };
  }

  /// Two-line string for the debug overlay.
  ///
  /// Line 1: `FPS: 60 | P95: 14ms | Jank: 0`
  /// Line 2: `Heap: 42MB | Shader: 8ms`
  String get summary {
    if (kReleaseMode) return '';

    final fps = avgFps.toStringAsFixed(0);
    final p95 = p95FrameTimeMs.toStringAsFixed(0);
    final heapMb = (_lastHeapBytes / (1024 * 1024)).toStringAsFixed(0);

    // Pick the first registered shader pass for the overlay (typically 'globe').
    double shaderMs = 0;
    if (_passCounts.isNotEmpty) {
      final name = _passCounts.keys.first;
      final count = _passCounts[name]!;
      if (count > 0) shaderMs = (_passTotalUs[name]! / count) / 1000.0;
    }

    final line1 = 'FPS: $fps | P95: ${p95}ms | Jank: $_jankFrames';
    final line2 =
        'Heap: ${heapMb}MB | Shader: ${shaderMs.toStringAsFixed(0)}ms';
    return '$line1\n$line2';
  }
}
