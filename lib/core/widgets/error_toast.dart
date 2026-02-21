import 'package:flutter/material.dart';

import '../theme/flit_colors.dart';

/// A brief auto-dismiss toast for `error`-severity errors.
///
/// Displayed via [ScaffoldMessenger.showSnackBar] when an error is surfaced
/// through [ErrorService.userFacingErrors]. Auto-dismisses after 3 seconds.
///
/// This widget is not directly instantiated — use [ErrorToast.show] to
/// display a toast from any context that has a [ScaffoldMessenger].
abstract final class ErrorToast {
  /// Show a brief error toast that auto-dismisses after 3 seconds.
  ///
  /// Uses Material [SnackBar] for cross-platform consistency.
  static void show(BuildContext context, {String? message}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: FlitColors.textPrimary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message ?? 'Something went wrong',
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xE6CC4444),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }
}
