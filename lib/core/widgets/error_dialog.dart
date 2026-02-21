import 'package:flutter/material.dart';

import '../services/error_service.dart';
import '../theme/flit_colors.dart';

/// A dialog shown for `critical`-severity errors.
///
/// Presents a user-friendly message with an optional "Send Report" button
/// that triggers [ErrorService.flush] to immediately send queued errors
/// to the telemetry endpoint.
///
/// Use [ErrorDialog.show] to display the dialog from any context.
abstract final class ErrorDialog {
  /// Show a critical error dialog with a "Send Report" button.
  ///
  /// The user can dismiss the dialog or tap "Send Report" to flush
  /// all queued errors to the backend immediately.
  static void show(BuildContext context, {CapturedError? error}) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: FlitColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: FlitColors.error, width: 1),
        ),
        icon: const Icon(
          Icons.error_outline,
          color: FlitColors.error,
          size: 40,
        ),
        title: const Text(
          'We hit a problem',
          style: TextStyle(
            color: FlitColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'An unexpected error occurred. You can send a report '
              'to help us fix it.',
              style: TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: FlitColors.backgroundDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                constraints: const BoxConstraints(maxHeight: 80),
                child: SingleChildScrollView(
                  child: Text(
                    error.error,
                    style: const TextStyle(
                      color: FlitColors.textMuted,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      height: 1.3,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Dismiss',
              style: TextStyle(color: FlitColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              ErrorService.instance.flush();
              Navigator.of(dialogContext).pop();

              // Show confirmation via SnackBar if ScaffoldMessenger available.
              final messenger = ScaffoldMessenger.maybeOf(context);
              if (messenger != null) {
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Report sent. Thank you!',
                      style: TextStyle(color: FlitColors.textPrimary),
                    ),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: FlitColors.success,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }
            },
            child: const Text(
              'Send Report',
              style: TextStyle(
                color: FlitColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
