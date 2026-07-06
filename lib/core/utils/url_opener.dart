import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/flit_colors.dart';

/// Safe external-URL opener.
///
/// [launchUrl] can throw (no browser/handler available, platform channel
/// missing in tests, malformed intent) — every call site MUST guard against
/// that or the whole screen crashes. This helper tries to open the URL and,
/// on any failure, falls back to a dialog showing a copyable link so the user
/// is never stranded.
class UrlOpener {
  UrlOpener._();

  /// Attempts to open [url] externally. Returns true on success. On any
  /// failure it shows a copyable-URL dialog (if [context] is still mounted)
  /// and returns false. Never throws.
  static Future<bool> open(
    BuildContext context,
    String url, {
    String title = 'Open Link',
    LaunchMode mode = LaunchMode.externalApplication,
  }) async {
    try {
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: mode);
      if (ok) return true;
    } catch (_) {
      // Fall through to the copyable fallback below.
    }
    if (context.mounted) {
      await _showCopyDialog(context, url, title);
    }
    return false;
  }

  /// Attempts to open a `mailto:` link. Never throws.
  static Future<bool> openMailto(
    BuildContext context,
    String email, {
    String? subject,
    String title = 'Contact Support',
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: subject == null ? null : {'subject': subject},
    );
    try {
      final ok = await launchUrl(uri);
      if (ok) return true;
    } catch (_) {
      // Fall through.
    }
    if (context.mounted) {
      await _showCopyDialog(context, email, title);
    }
    return false;
  }

  static Future<void> _showCopyDialog(
    BuildContext context,
    String url,
    String title,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FlitColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: FlitColors.cardBorder),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: FlitColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Couldn't open this automatically. Copy the link and open it "
              'in your browser:',
              style: TextStyle(color: FlitColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: FlitColors.backgroundDark,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: FlitColors.cardBorder),
              ),
              child: SelectableText(
                url,
                style: const TextStyle(
                  color: FlitColors.oceanHighlight,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              Navigator.of(context).pop();
            },
            child: const Text(
              'Copy',
              style: TextStyle(color: FlitColors.accent),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: FlitColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
