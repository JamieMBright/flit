import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// Severity levels for reported errors.
enum ErrorSeverity {
  warning,
  error,
  critical;

  String get label => name;
}

/// A single captured error with full context for telemetry.
class CapturedError {
  CapturedError({
    required this.timestamp,
    required this.sessionId,
    required this.appVersion,
    required this.platform,
    required this.deviceInfo,
    required this.severity,
    required this.error,
    this.stackTrace,
    this.context,
  });

  final DateTime timestamp;
  final String sessionId;
  final String appVersion;
  final String platform;
  final String deviceInfo;
  final ErrorSeverity severity;
  final String error;
  final String? stackTrace;
  final Map<String, String>? context;

  /// Serialize to the JSON schema expected by the Vercel endpoint.
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toUtc().toIso8601String(),
      'sessionId': sessionId,
      'appVersion': appVersion,
      'platform': platform,
      'deviceInfo': deviceInfo,
      'severity': severity.label,
      'error': error,
      if (stackTrace != null) 'stackTrace': stackTrace,
      if (context != null) 'context': context,
    };
  }

  /// Serialize the entire error payload to a JSON string.
  String toJsonString() => jsonEncode(toJson());

  @override
  String toString() =>
      '[${severity.label.toUpperCase()}] $error (${timestamp.toIso8601String()})';
}

/// An error event intended for user-facing display.
///
/// The [severity] determines how the error is surfaced:
/// - [ErrorSeverity.warning]: silent (telemetry only, never shown to users)
/// - [ErrorSeverity.error]: brief auto-dismiss toast ("Something went wrong")
/// - [ErrorSeverity.critical]: dialog with optional "Send Report" button
class UserFacingError {
  const UserFacingError({required this.error, required this.severity});

  final CapturedError error;
  final ErrorSeverity severity;
}

/// Callback signature for error listeners.
typedef ErrorListener = void Function(CapturedError error);

/// Callback signature for the HTTP sender used by [ErrorService.flush].
///
/// Accepts a JSON-encoded request body (a list of error payloads) plus the
/// endpoint URL and API key. Returns `true` if the server accepted the batch.
///
/// This is injected externally so ErrorService itself needs no HTTP dependency,
/// making it safe to import on all platforms (web, iOS, Android).
typedef ErrorSender =
    Future<bool> Function({
      required String url,
      required String apiKey,
      required String jsonBody,
    });

/// Singleton service that captures, queues, and batches runtime errors
/// for remote telemetry.
///
/// **Usage:**
/// ```dart
/// final errorService = ErrorService.instance;
/// errorService.initialize(
///   apiEndpoint: 'https://flit-olive.vercel.app/api/errors',
///   apiKey: const String.fromEnvironment('VERCEL_ERRORS_API_KEY'),
/// );
///
/// errorService.reportError(
///   'Something broke',
///   StackTrace.current,
///   context: {'screen': 'game', 'gameState': 'playing'},
/// );
/// ```
///
/// The actual HTTP posting is performed by an [ErrorSender] callback
/// registered via [setSender]. This keeps `dart:io` / `package:http`
/// out of this file, ensuring clean cross-platform compilation.
class ErrorService {
  ErrorService._() {
    _sessionId = _generateUuidV4();
  }

  static final ErrorService instance = ErrorService._();

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  String? _apiEndpoint;
  String? _apiKey;
  ErrorSender? _sender;
  late final String _sessionId;

  /// Application version reported with every error payload.
  /// Defaults to the value from pubspec.yaml.
  static const String appVersion = 'v1.178';

  // ---------------------------------------------------------------------------
  // Queue
  // ---------------------------------------------------------------------------

  /// Maximum number of errors retained in the in-memory queue.
  static const int maxQueueSize = 100;

  final List<CapturedError> _queue = [];
  bool _flushing = false;

  /// Unmodifiable view of the current error queue (oldest first).
  List<CapturedError> get pendingErrors => List.unmodifiable(_queue);

  /// Number of errors currently queued.
  int get pendingCount => _queue.length;

  // ---------------------------------------------------------------------------
  // User-facing error stream
  // ---------------------------------------------------------------------------

  /// Stream of errors that should be surfaced to the user.
  ///
  /// UI widgets (toast, dialog) listen to this stream to display errors.
  /// Only `error` and `critical` severity events are emitted — warnings are
  /// telemetry-only and never shown to users.
  final StreamController<UserFacingError> _userFacingController =
      StreamController<UserFacingError>.broadcast();

  /// Public stream for UI widgets to listen to user-facing errors.
  Stream<UserFacingError> get userFacingErrors => _userFacingController.stream;

  void _emitUserFacingError(CapturedError captured) {
    // Warnings are NEVER shown to users — telemetry only.
    if (captured.severity == ErrorSeverity.warning) return;

    _userFacingController.add(
      UserFacingError(error: captured, severity: captured.severity),
    );
  }

  // ---------------------------------------------------------------------------
  // Listeners (reactive updates for DevOverlay)
  // ---------------------------------------------------------------------------

  final List<ErrorListener> _listeners = [];

  /// Register a callback invoked whenever a new error is captured.
  void addListener(ErrorListener listener) {
    _listeners.add(listener);
  }

  /// Remove a previously registered listener.
  void removeListener(ErrorListener listener) {
    _listeners.remove(listener);
  }

  /// A [ValueNotifier] that increments on every captured error, suitable for
  /// use with [ValueListenableBuilder] in the DevOverlay.
  final ValueNotifier<int> errorCountNotifier = ValueNotifier<int>(0);

  void _notifyListeners(CapturedError captured) {
    errorCountNotifier.value++;
    for (final listener in _listeners) {
      try {
        listener(captured);
      } catch (_) {
        // Never let a listener exception propagate back into error handling.
      }
    }
  }

  // ---------------------------------------------------------------------------
  // All-time captured errors (for DevOverlay display)
  // ---------------------------------------------------------------------------

  /// Maximum errors retained for display (separate from the send queue).
  static const int maxDisplayErrors = 50;

  final List<CapturedError> _displayErrors = [];

  /// The most recent errors for display in the DevOverlay (newest first).
  List<CapturedError> get displayErrors => List.unmodifiable(_displayErrors);

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Configure the telemetry endpoint.
  ///
  /// Call once at app startup, after reading environment variables.
  /// If [apiEndpoint] or [apiKey] are empty, errors are still captured
  /// locally but [flush] will be a no-op.
  void initialize({required String apiEndpoint, required String apiKey}) {
    _apiEndpoint = apiEndpoint.isNotEmpty ? apiEndpoint : null;
    _apiKey = apiKey.isNotEmpty ? apiKey : null;

    if (kDebugMode) {
      debugPrint('[ErrorService] Initialized:');
      debugPrint('[ErrorService]   Endpoint: ${_apiEndpoint ?? "NOT SET"}');
      debugPrint(
        '[ErrorService]   API Key: ${_apiKey?.isNotEmpty == true ? "SET (${_apiKey!.length} chars)" : "NOT SET"}',
      );
      debugPrint('[ErrorService]   Session ID: $_sessionId');
    }
  }

  /// Register the HTTP sender callback.
  ///
  /// This must be called before [flush] can actually transmit errors.
  void setSender(ErrorSender sender) {
    _sender = sender;
  }

  // ---------------------------------------------------------------------------
  // Reporting
  // ---------------------------------------------------------------------------

  /// Report an error with optional stack trace and context metadata.
  void reportError(
    Object error,
    StackTrace? stackTrace, {
    ErrorSeverity severity = ErrorSeverity.error,
    Map<String, String>? context,
  }) {
    final captured = CapturedError(
      timestamp: DateTime.now(),
      sessionId: _sessionId,
      appVersion: appVersion,
      platform: _detectPlatform(),
      deviceInfo: _detectDeviceInfo(),
      severity: severity,
      error: error.toString(),
      stackTrace: stackTrace?.toString(),
      context: context,
    );

    _enqueue(captured);
    _addToDisplay(captured);
    _notifyListeners(captured);
    _emitUserFacingError(captured);
  }

  /// Convenience: report with [ErrorSeverity.warning].
  void reportWarning(
    Object error,
    StackTrace? stackTrace, {
    Map<String, String>? context,
  }) {
    reportError(
      error,
      stackTrace,
      severity: ErrorSeverity.warning,
      context: context,
    );
  }

  /// Report with [ErrorSeverity.critical] and flush immediately.
  ///
  /// Critical errors also trigger an immediate flush (fire-and-forget)
  /// because the app may be about to crash/reload — we can't wait for
  /// the periodic flush timer.
  void reportCritical(
    Object error,
    StackTrace? stackTrace, {
    Map<String, String>? context,
  }) {
    if (kDebugMode) {
      debugPrint('[ErrorService] reportCritical() called: $error');
      debugPrint('[ErrorService] Context: $context');
    }

    reportError(
      error,
      stackTrace,
      severity: ErrorSeverity.critical,
      context: context,
    );

    // Fire-and-forget immediate flush — don't await.
    if (kDebugMode) {
      debugPrint(
        '[ErrorService] Triggering immediate flush for critical error',
      );
    }
    flush();
  }

  // ---------------------------------------------------------------------------
  // Queue management
  // ---------------------------------------------------------------------------

  void _enqueue(CapturedError captured) {
    _queue.add(captured);
    if (_queue.length > maxQueueSize) {
      _queue.removeAt(0);
    }
  }

  void _addToDisplay(CapturedError captured) {
    _displayErrors.insert(0, captured);
    if (_displayErrors.length > maxDisplayErrors) {
      _displayErrors.removeLast();
    }
  }

  // ---------------------------------------------------------------------------
  // Flushing (send queued errors to the backend)
  // ---------------------------------------------------------------------------

  /// Maximum number of retry attempts per flush.
  static const int maxRetries = 3;

  /// Attempt to send all queued errors to the configured endpoint.
  ///
  /// Returns `true` if the batch was accepted (or the queue was empty).
  /// Returns `false` if sending failed after retries.
  ///
  /// Uses exponential backoff: 1 s, 2 s, 4 s between attempts.
  Future<bool> flush() async {
    // Guard: nothing to do.
    if (_queue.isEmpty) {
      if (kDebugMode) {
        debugPrint('[ErrorService] flush() called but queue is empty');
      }
      return true;
    }

    // Guard: no endpoint or sender configured.
    if (_apiEndpoint == null || _sender == null) {
      if (kDebugMode) {
        debugPrint(
          '[ErrorService] flush() failed: no endpoint or sender configured',
        );
        debugPrint('[ErrorService]   endpoint: $_apiEndpoint');
        debugPrint('[ErrorService]   sender: $_sender');
      }
      return false;
    }

    // Guard: another flush is already in progress.
    if (_flushing) {
      if (kDebugMode) {
        debugPrint('[ErrorService] flush() skipped: already flushing');
      }
      return false;
    }

    if (kDebugMode) {
      debugPrint(
        '[ErrorService] flush() starting: ${_queue.length} errors queued',
      );
    }

    _flushing = true;

    try {
      // Snapshot the current queue so new errors captured during flush
      // don't interfere.
      final batch = List<CapturedError>.from(_queue);
      final body = jsonEncode(batch.map((e) => e.toJson()).toList());

      if (kDebugMode) {
        debugPrint(
          '[ErrorService] Sending ${batch.length} errors (${body.length} bytes)',
        );
        debugPrint('[ErrorService] Endpoint: $_apiEndpoint');
      }

      for (int attempt = 0; attempt < maxRetries; attempt++) {
        try {
          if (kDebugMode && attempt > 0) {
            debugPrint('[ErrorService] Retry attempt $attempt');
          }

          final success = await _sender!(
            url: _apiEndpoint!,
            apiKey: _apiKey ?? '',
            jsonBody: body,
          );

          if (success) {
            // Remove only the errors we successfully sent.
            _queue.removeWhere((e) => batch.contains(e));
            if (kDebugMode) {
              debugPrint(
                '[ErrorService] flush() SUCCESS: ${batch.length} errors sent',
              );
            }
            return true;
          } else {
            if (kDebugMode) {
              debugPrint(
                '[ErrorService] flush() returned false on attempt $attempt',
              );
            }
          }
        } catch (e) {
          // Network or serialization error — retry after backoff.
          if (kDebugMode) {
            debugPrint(
              '[ErrorService] flush() exception on attempt $attempt: $e',
            );
          }
        }

        // Exponential backoff: 1s, 2s, 4s.
        if (attempt < maxRetries - 1) {
          final delay = Duration(seconds: pow(2, attempt).toInt());
          if (kDebugMode) {
            debugPrint('[ErrorService] Backing off for ${delay.inSeconds}s');
          }
          await Future<void>.delayed(delay);
        }
      }

      if (kDebugMode) {
        debugPrint('[ErrorService] flush() FAILED: all retries exhausted');
      }
      return false; // All retries exhausted.
    } finally {
      _flushing = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Platform detection
  // ---------------------------------------------------------------------------

  String _detectPlatform() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.macOS:
        return 'web'; // Desktop treated as web for telemetry.
      case TargetPlatform.windows:
        return 'web';
      case TargetPlatform.linux:
        return 'web';
      case TargetPlatform.fuchsia:
        return 'android';
    }
  }

  String _detectDeviceInfo() {
    if (kIsWeb) return 'web-browser';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios-device';
      case TargetPlatform.android:
        return 'android-device';
      default:
        return 'desktop-${defaultTargetPlatform.name}';
    }
  }

  // ---------------------------------------------------------------------------
  // UUID v4 generation (no external dependency)
  // ---------------------------------------------------------------------------

  /// Generate a RFC 4122 version 4 UUID using [Random.secure].
  static String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    // Set version (4) and variant (10xx) bits per RFC 4122.
    bytes[6] = (bytes[6] & 0x0F) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80; // variant 1

    String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');

    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
        '${hex(bytes[4])}${hex(bytes[5])}-'
        '${hex(bytes[6])}${hex(bytes[7])}-'
        '${hex(bytes[8])}${hex(bytes[9])}-'
        '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}'
        '${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }

  // ---------------------------------------------------------------------------
  // Teardown
  // ---------------------------------------------------------------------------

  /// Clear all queued and displayed errors. Primarily for testing.
  @visibleForTesting
  void reset() {
    _queue.clear();
    _displayErrors.clear();
    _listeners.clear();
    errorCountNotifier.value = 0;
    _flushing = false;
  }
}
