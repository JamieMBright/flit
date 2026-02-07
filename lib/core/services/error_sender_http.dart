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
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
      },
      body: jsonBody,
    );
    // 2xx means the server accepted the batch.
    return response.statusCode >= 200 && response.statusCode < 300;
  } catch (_) {
    // Network failure — caller (ErrorService.flush) handles retry.
    return false;
  }
}
