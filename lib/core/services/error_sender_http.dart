import 'package:http/http.dart' as http;

import 'error_service.dart';

/// HTTP implementation of [ErrorSender] using the `http` package.
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
  try {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    // Only include the API key if one was configured. The Vercel POST
    // endpoint is unauthenticated, so this header is optional.
    if (apiKey.isNotEmpty) {
      headers['X-API-Key'] = apiKey;
    }
    // Add timeout to prevent hanging on slow networks (critical for iOS PWA
    // where the app may be about to reload).
    final response = await http
        .post(
          Uri.parse(url),
          headers: headers,
          body: jsonBody,
        )
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            // Return a failed response if the request times out
            return http.Response('Request timeout', 408);
          },
        );
    // 2xx means the server accepted the batch.
    return response.statusCode >= 200 && response.statusCode < 300;
  } catch (_) {
    // Network failure — caller (ErrorService.flush) handles retry.
    return false;
  }
}
