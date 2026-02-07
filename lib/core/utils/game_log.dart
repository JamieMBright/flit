import 'dart:developer' as developer;

import '../services/error_service.dart';

/// Log severity levels.
enum LogLevel { debug, info, warning, error }

/// A single structured log entry.
class LogEntry {
  LogEntry({
    required this.level,
    required this.category,
    required this.message,
    this.data,
    this.error,
    this.stackTrace,
  }) : timestamp = DateTime.now();

  final DateTime timestamp;
  final LogLevel level;
  final String category;
  final String message;
  final Map<String, dynamic>? data;
  final Object? error;
  final StackTrace? stackTrace;

  String get timeString {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  String get levelTag => switch (level) {
        LogLevel.debug => 'DBG',
        LogLevel.info => 'INF',
        LogLevel.warning => 'WRN',
        LogLevel.error => 'ERR',
      };

  @override
  String toString() {
    final buf = StringBuffer('[$timeString $levelTag $category] $message');
    if (data != null && data!.isNotEmpty) {
      buf.write(' | $data');
    }
    if (error != null) {
      buf.write('\n  error: $error');
    }
    if (stackTrace != null) {
      // Only first 5 frames to keep it readable
      final frames = stackTrace.toString().split('\n').take(5).join('\n  ');
      buf.write('\n  $frames');
    }
    return buf.toString();
  }
}

/// Singleton game logger with ring buffer storage.
///
/// Captures structured events across the app lifecycle.
/// Accessible from the debug screen for live inspection.
class GameLog {
  GameLog._();
  static final GameLog instance = GameLog._();

  /// Ring buffer capacity — enough for a full session, small enough to not leak.
  static const int maxEntries = 500;

  final List<LogEntry> _entries = [];

  /// All log entries (oldest first).
  List<LogEntry> get entries => List.unmodifiable(_entries);

  /// Entries filtered by minimum level.
  List<LogEntry> entriesAtLevel(LogLevel minLevel) =>
      _entries.where((e) => e.level.index >= minLevel.index).toList();

  /// Number of errors captured this session.
  int get errorCount => _entries.where((e) => e.level == LogLevel.error).length;

  /// Number of warnings captured this session.
  int get warningCount =>
      _entries.where((e) => e.level == LogLevel.warning).length;

  /// Guards against re-entrant calls (e.g. if ErrorService ever logs back).
  bool _bridging = false;

  void _add(LogEntry entry) {
    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeAt(0);
    }
    // Mirror to dart:developer so DevTools still works
    developer.log(
      entry.toString(),
      name: 'flit.${entry.category}',
      level: entry.level == LogLevel.error ? 1000 : 800,
      error: entry.error,
      stackTrace: entry.stackTrace,
    );

    // Bridge errors/warnings to ErrorService for telemetry and DevOverlay.
    if (!_bridging) {
      _bridging = true;
      try {
        if (entry.level == LogLevel.error) {
          ErrorService.instance.reportError(
            '[${entry.category}] ${entry.message}',
            entry.stackTrace,
            context: {
              'source': 'GameLog',
              'category': entry.category,
              if (entry.error != null) 'original_error': '${entry.error}',
            },
          );
        } else if (entry.level == LogLevel.warning) {
          ErrorService.instance.reportWarning(
            '[${entry.category}] ${entry.message}',
            entry.stackTrace,
            context: {
              'source': 'GameLog',
              'category': entry.category,
              if (entry.error != null) 'original_error': '${entry.error}',
            },
          );
        }
      } finally {
        _bridging = false;
      }
    }
  }

  /// Log a debug-level event.
  void debug(String category, String message, {Map<String, dynamic>? data}) {
    _add(LogEntry(level: LogLevel.debug, category: category, message: message, data: data));
  }

  /// Log an info-level event.
  void info(String category, String message, {Map<String, dynamic>? data}) {
    _add(LogEntry(level: LogLevel.info, category: category, message: message, data: data));
  }

  /// Log a warning.
  void warning(String category, String message, {Map<String, dynamic>? data, Object? error}) {
    _add(LogEntry(level: LogLevel.warning, category: category, message: message, data: data, error: error));
  }

  /// Log an error with optional stack trace.
  void error(String category, String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? data}) {
    _add(LogEntry(
      level: LogLevel.error,
      category: category,
      message: message,
      data: data,
      error: error,
      stackTrace: stackTrace,
    ));
  }

  /// Clear all entries.
  void clear() => _entries.clear();

  /// Export the entire log as a single string (for sharing / copying).
  String export() {
    final buf = StringBuffer();
    buf.writeln('=== Flit Game Log ===');
    buf.writeln('Exported: ${DateTime.now().toIso8601String()}');
    buf.writeln('Entries: ${_entries.length}  Errors: $errorCount  Warnings: $warningCount');
    buf.writeln('');
    for (final entry in _entries) {
      buf.writeln(entry);
    }
    return buf.toString();
  }
}
