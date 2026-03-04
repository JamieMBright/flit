import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/flit_colors.dart';

/// A brief auto-dismiss toast for `error`-severity errors.
///
/// Displayed via [ScaffoldMessenger.showSnackBar] when an error is surfaced
/// through [ErrorService.userFacingErrors]. Shows error details and can be
/// tapped to expand / copy the full message.
///
/// This widget is not directly instantiated — use [ErrorToast.show] to
/// display a toast from any context that has a [ScaffoldMessenger].
abstract final class ErrorToast {
  /// Show an error toast with the error message.
  ///
  /// Tap the toast to copy the full error to the clipboard.
  /// Auto-dismisses after 5 seconds (longer than before so users can read it).
  static void show(BuildContext context, {String? message}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final displayMessage = message ?? 'Something went wrong';

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: GestureDetector(
          onTap: () {
            // Copy full error to clipboard on tap
            Clipboard.setData(ClipboardData(text: displayMessage));
            messenger.clearSnackBars();
            messenger.showSnackBar(
              SnackBar(
                content: const Text(
                  'Error copied to clipboard',
                  style: TextStyle(color: FlitColors.textPrimary, fontSize: 13),
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xE6444444),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: FlitColors.textPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      displayMessage,
                      style: const TextStyle(
                        color: FlitColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap to copy full error',
                style: TextStyle(color: FlitColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xE6CC4444),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }
}
