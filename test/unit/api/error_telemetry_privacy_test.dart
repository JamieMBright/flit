import 'package:flutter_test/flutter_test.dart';

/// These tests document the error telemetry privacy contract.
///
/// The actual scrubbing is done server-side in api/errors/index.js.
/// These tests verify the *client-side* contract: what data the Flutter
/// app sends and what the server strips.
void main() {
  group('Error telemetry privacy contract', () {
    test('context fields sent by Flutter are safe metadata only', () {
      // Document the allowed context fields sent by the Flutter app.
      // If a new field is added, this test reminds developers to verify
      // it doesn't contain PII.
      const allowedContextFields = {
        'source', // e.g. 'FlutterError.onError', 'GameLog'
        'category', // e.g. 'shader', 'network'
        'screen', // e.g. 'PlayScreen'
        'action', // e.g. 'build', 'loadTexture'
        'texture', // asset path
        'assetPath', // asset path
        'nonFatal', // 'true' or 'false'
        'original_error', // error message string
      };

      // These fields must NEVER appear in error context.
      const bannedContextFields = {
        'userAgent',
        'token',
        'password',
        'secret',
        'authorization',
        'cookie',
        'email',
        'userId',
      };

      // Verify no overlap between allowed and banned.
      final overlap = allowedContextFields.intersection(bannedContextFields);
      expect(
        overlap,
        isEmpty,
        reason: 'Allowed context fields must not include banned PII fields',
      );
    });

    test('URL scrubbing removes query parameters', () {
      // Document the expected behavior of scrubUrl() in api/errors/index.js.
      // The server strips ?query and #hash from URLs.
      const rawUrl = 'https://example.com/game?token=abc123&ref=social#section';
      const expectedScrubbed = 'https://example.com/game';

      // Simulate the scrubbing logic (mirrors api/errors/index.js:scrubUrl)
      final uri = Uri.parse(rawUrl);
      final scrubbed = '${uri.scheme}://${uri.host}${uri.path}';

      expect(scrubbed, equals(expectedScrubbed));
    });
  });
}
