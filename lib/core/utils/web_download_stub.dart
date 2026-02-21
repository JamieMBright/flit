/// No-op implementation for non-web platforms.
///
/// On mobile, sharing is handled via the clipboard — the web download
/// function is not needed.
void triggerWebDownload(String content, String filename) {}

/// Returns false on non-web platforms.
bool get isWebPlatform => false;
