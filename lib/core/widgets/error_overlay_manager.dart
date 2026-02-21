import 'dart:async';

import 'package:flutter/material.dart';

import '../services/error_service.dart';
import 'error_dialog.dart';
import 'error_toast.dart';

/// Widget that listens to [ErrorService.userFacingErrors] and surfaces
/// errors to the user based on severity:
///
/// - [ErrorSeverity.error] -> brief auto-dismiss toast (3 seconds)
/// - [ErrorSeverity.critical] -> dialog with "Send Report" button
/// - [ErrorSeverity.warning] -> never emitted (filtered in ErrorService)
///
/// Place this widget in the widget tree above [MaterialApp]'s builder
/// or inside it, so that [ScaffoldMessenger] and [Navigator] are available.
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) {
///     return Stack(
///       children: [
///         child ?? const SizedBox.shrink(),
///         const ErrorOverlayManager(),
///       ],
///     );
///   },
/// );
/// ```
class ErrorOverlayManager extends StatefulWidget {
  const ErrorOverlayManager({super.key});

  @override
  State<ErrorOverlayManager> createState() => _ErrorOverlayManagerState();
}

class _ErrorOverlayManagerState extends State<ErrorOverlayManager> {
  StreamSubscription<UserFacingError>? _subscription;

  /// Prevent dialog stacking — only show one critical dialog at a time.
  bool _dialogVisible = false;

  @override
  void initState() {
    super.initState();
    _subscription = ErrorService.instance.userFacingErrors.listen(_onError);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onError(UserFacingError event) {
    if (!mounted) return;

    switch (event.severity) {
      case ErrorSeverity.error:
        ErrorToast.show(context);

      case ErrorSeverity.critical:
        if (!_dialogVisible) {
          _dialogVisible = true;
          ErrorDialog.show(context, error: event.error);
          // Reset flag after dialog is shown (a short delay to allow
          // the dialog to be presented before accepting new ones).
          Future<void>.delayed(const Duration(seconds: 1), () {
            _dialogVisible = false;
          });
        }

      case ErrorSeverity.warning:
        // Warnings are never surfaced to users. This case should not
        // be reached because ErrorService filters them out, but we
        // handle it defensively.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // This widget is invisible — it only listens to the error stream
    // and triggers toasts/dialogs imperatively.
    return const SizedBox.shrink();
  }
}
