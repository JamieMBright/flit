// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js_util' as js_util;
import 'dart:html' as html;

/// Calls `window._flitShowError(message)` defined in index.html.
/// This takes over the full screen with the error text.
void showErrorOnWeb(String message) {
  try {
    final fn = js_util.getProperty<Object?>(html.window, '_flitShowError');
    if (fn != null) {
      js_util.callMethod<void>(html.window, '_flitShowError', [message]);
    }
  } catch (_) {
    // If even this fails, nothing more we can do.
  }
}
