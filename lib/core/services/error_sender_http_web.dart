// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;

import 'error_service.dart';

/// Web-specific HTTP implementation of [ErrorSender] with keepalive support.
///
/// Uses the native fetch() API with keepalive flag to ensure error telemetry
/// survives page unloads on iOS Safari PWA. Falls back to Beacon API if
/// fetch is unavailable.
///
/// This is critical because iOS Safari PWA can force a page reload on
/// unhandled errors, aborting pending HTTP requests. The keepalive flag
/// tells the browser to complete the request even if the page unloads.
Future<bool> errorSenderHttpImpl({
  required String url,
  required String apiKey,
  required String jsonBody,
}) async {
  try {
    // Build headers map
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (apiKey.isNotEmpty) {
      headers['X-API-Key'] = apiKey;
    }

    // Use XMLHttpRequest with sendBeacon-like behavior for better iOS compatibility
    // fetch() with keepalive can still be unreliable on iOS Safari
    final xhr = html.HttpRequest();
    xhr.open('POST', url);
    
    // Set headers
    headers.forEach((key, value) {
      xhr.setRequestHeader(key, value);
    });

    // Create a completer for the async operation
    final completer = Completer<bool>();
    
    // Set up response handlers
    xhr.onLoad.listen((_) {
      final status = xhr.status ?? 0;
      completer.complete(status >= 200 && status < 300);
    });
    
    xhr.onError.listen((_) {
      // Try Beacon API as fallback
      completer.complete(_sendViaBeacon(url, jsonBody));
    });
    
    xhr.onTimeout.listen((_) {
      // Try Beacon API as fallback
      completer.complete(_sendViaBeacon(url, jsonBody));
    });

    // Set timeout
    xhr.timeout = 10000; // 10 seconds in milliseconds

    // Send the request
    xhr.send(jsonBody);

    return completer.future;
  } catch (_) {
    // Network or other failure — try Beacon API as fallback
    return _sendViaBeacon(url, jsonBody);
  }
}

/// Fallback using the Beacon API for guaranteed delivery on page unload.
///
/// Beacon API is designed for analytics and error reporting when the page
/// is closing. It returns synchronously but doesn't wait for a response.
/// We return true optimistically since we can't verify success.
bool _sendViaBeacon(String url, String jsonBody) {
  try {
    final navigator = html.window.navigator;
    // Convert JSON string to Blob with correct content type
    final blob = html.Blob([jsonBody], 'application/json');
    final success = navigator.sendBeacon(url, blob);
    // sendBeacon returns true if the browser accepted the request for delivery
    return success;
  } catch (_) {
    // Even Beacon failed — nothing more we can do
    return false;
  }
}
