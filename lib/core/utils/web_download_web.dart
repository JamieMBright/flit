// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;

/// Triggers a browser download of [content] as a file named [filename].
///
/// Creates a temporary Blob URL, clicks an invisible anchor element, then
/// cleans up. This is the standard web approach for client-generated files.
void triggerWebDownload(String content, String filename) {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

/// Returns true on web platforms.
bool get isWebPlatform => true;
