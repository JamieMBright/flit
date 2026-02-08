import 'package:http/http.dart' as http;

import 'error_service.dart';

/// Stub implementation of [ErrorSender] for non-web platforms.
///
/// Uses the standard `http` package without web-specific keepalive support.
Future<bool> errorSenderHttpImpl({
  required String url,
  required String apiKey,
  required String jsonBody,
}) async {
  try {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (apiKey.isNotEmpty) {
      headers['X-API-Key'] = apiKey;
    }
    // Add timeout to prevent hanging on slow networks
    final response = await http
        .post(
          Uri.parse(url),
          headers: headers,
          body: jsonBody,
        )
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            return http.Response('Request timeout', 408);
          },
        );
    return response.statusCode >= 200 && response.statusCode < 300;
  } catch (_) {
    return false;
  }
}
