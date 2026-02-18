import 'error_sender_http_stub.dart'
    if (dart.library.html) 'error_sender_http_web.dart';

import 'error_service.dart';

/// HTTP implementation of [ErrorSender] with platform-specific optimizations.
///
/// On web, uses native fetch() API with keepalive flag to ensure error
/// telemetry survives page unloads (critical for iOS Safari PWA).
/// On other platforms, uses the standard `http` package.
///
/// This is a standalone file so that `error_service.dart` stays free of
/// HTTP imports and compiles cleanly on all platforms.
///
/// Usage:
/// ```dart
/// ErrorService.instance.setSender(errorSenderHttp);
/// ```
Future<bool> errorSenderHttp({
  required String url,
  required String apiKey,
  required String jsonBody,
}) async {
  // Delegates to platform-specific implementation
  return errorSenderHttpImpl(url: url, apiKey: apiKey, jsonBody: jsonBody);
}
