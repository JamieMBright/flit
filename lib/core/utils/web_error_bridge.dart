import 'web_error_bridge_stub.dart'
    if (dart.library.html) 'web_error_bridge_web.dart';

/// Pushes error messages to the JS-level error overlay in index.html.
///
/// On non-web platforms this is a no-op. On web, it calls
/// `window._flitShowError(msg)` which is defined in index.html and takes
/// over the full screen with the error text — critical for iOS PWA where
/// Dart-level error widgets never render because the WebView reloads.
class WebErrorBridge {
  WebErrorBridge._();

  /// Show [message] in the JS error overlay. No-op on non-web platforms.
  static void show(String message) => showErrorOnWeb(message);
}
