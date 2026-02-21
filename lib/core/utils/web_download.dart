import 'web_download_stub.dart'
    if (dart.library.html) 'web_download_web.dart';

/// Cross-platform file download/share helper.
///
/// On web, triggers a browser download via Blob URL.
/// On mobile, this is a no-op — the caller should use clipboard or other
/// native sharing mechanisms.
class WebDownload {
  WebDownload._();

  /// Trigger a file download on web. No-op on mobile.
  static void download(String content, String filename) =>
      triggerWebDownload(content, filename);

  /// Whether the current platform is web.
  static bool get isWeb => isWebPlatform;
}
