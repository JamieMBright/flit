import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/error_service.dart';
import '../theme/flit_colors.dart';

/// A standalone "Report Bug" button that can be dropped into any screen.
///
/// On tap: shows a dialog with a text field for the user's description.
/// On submit: bundles the description + last 5 errors from
/// [ErrorService.displayErrors] + device info + app version, and submits
/// as a `critical` error with `context.source = 'user_report'`.
///
/// Usage:
/// ```dart
/// const ReportBugButton();
/// // or with a custom label:
/// const ReportBugButton(label: 'Send Feedback');
/// ```
class ReportBugButton extends StatelessWidget {
  const ReportBugButton({
    super.key,
    this.label = 'Report Bug',
    this.icon = Icons.bug_report_outlined,
    this.compact = false,
  });

  /// Button label text.
  final String label;

  /// Leading icon.
  final IconData icon;

  /// If true, renders as an IconButton instead of a full button.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return IconButton(
        icon: Icon(icon, color: FlitColors.textSecondary),
        tooltip: label,
        onPressed: () => _showReportDialog(context),
      );
    }

    return Material(
      color: FlitColors.cardBackground,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _showReportDialog(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FlitColors.cardBorder),
          ),
          child: Row(
            children: [
              Icon(icon, color: FlitColors.textSecondary),
              const SizedBox(width: 16),
              Text(
                label,
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right, color: FlitColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  /// Show the bug report dialog with a text field for user description.
  static void _showReportDialog(BuildContext context) {
    final descriptionController = TextEditingController();
    bool submitting = false;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: FlitColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: FlitColors.cardBorder),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.bug_report_outlined,
                color: FlitColors.accent,
                size: 24,
              ),
              SizedBox(width: 10),
              Text(
                'Report a Bug',
                style: TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Describe what went wrong. Include what you were doing '
                'when the issue occurred.',
                style: TextStyle(
                  color: FlitColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: descriptionController,
                maxLines: 4,
                maxLength: 500,
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. The game froze when I tapped on Brazil...',
                  hintStyle: const TextStyle(
                    color: FlitColors.textMuted,
                    fontSize: 13,
                  ),
                  counterStyle: const TextStyle(
                    color: FlitColors.textMuted,
                    fontSize: 10,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: FlitColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: FlitColors.accent),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Recent errors and device info will be included '
                'automatically.',
                style: TextStyle(
                  color: FlitColors.textMuted.withAlpha(180),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: FlitColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: submitting
                  ? null
                  : () {
                      final description = descriptionController.text.trim();
                      if (description.isEmpty) return;

                      setDialogState(() => submitting = true);
                      _submitReport(description);
                      Navigator.of(dialogContext).pop();

                      // Show confirmation.
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      if (messenger != null) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Bug report sent. Thank you!',
                              style: TextStyle(color: FlitColors.textPrimary),
                            ),
                            duration: const Duration(seconds: 3),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: FlitColors.success,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        );
                      }
                    },
              child: Text(
                submitting ? 'Sending...' : 'Submit',
                style: TextStyle(
                  color: submitting ? FlitColors.textMuted : FlitColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bundle description + recent errors + device info and submit as a
  /// critical error with `source = 'user_report'`.
  static void _submitReport(String description) {
    final errorService = ErrorService.instance;

    // Collect last 5 display errors (newest first).
    final recentErrors = errorService.displayErrors.take(5).toList();
    final recentErrorsSummary = recentErrors.isEmpty
        ? 'none'
        : recentErrors
              .map(
                (e) =>
                    '[${e.severity.label}] ${e.error.length > 120 ? '${e.error.substring(0, 120)}...' : e.error}',
              )
              .join(' | ');

    // Detect platform and device info using ErrorService's own detection
    // (accessible through the fields on CapturedError after report).
    final platform = _detectPlatform();
    final deviceInfo = _detectDeviceInfo();

    errorService.reportCritical(
      'User bug report: $description',
      StackTrace.current,
      context: {
        'source': 'user_report',
        'userDescription': description,
        'recentErrors': recentErrorsSummary,
        'platform': platform,
        'deviceInfo': deviceInfo,
        'appVersion': ErrorService.appVersion,
      },
    );
  }

  /// Detect platform string (mirrors ErrorService logic).
  static String _detectPlatform() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return 'desktop';
      case TargetPlatform.fuchsia:
        return 'android';
    }
  }

  /// Detect device info string (mirrors ErrorService logic).
  static String _detectDeviceInfo() {
    if (kIsWeb) return 'web-browser';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios-device';
      case TargetPlatform.android:
        return 'android-device';
      default:
        return 'desktop-${defaultTargetPlatform.name}';
    }
  }
}
