import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/dev_overlay.dart';
import 'core/services/error_service.dart';
import 'core/theme/flit_theme.dart';
import 'core/utils/game_log.dart';
import 'features/auth/login_screen.dart';

final _log = GameLog.instance;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the error telemetry service (V0).
  final errorService = ErrorService.instance;
  errorService.initialize(
    apiEndpoint: const String.fromEnvironment(
      'ERROR_ENDPOINT',
      defaultValue: 'https://flit-errors.vercel.app/api/errors',
    ),
    apiKey: const String.fromEnvironment('VERCEL_ERRORS_API_KEY'),
  );

  _log.info('app', 'Flit starting up');

  // Capture Flutter framework errors (widget build failures, etc.)
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _log.error(
      'flutter',
      details.exceptionAsString(),
      error: details.exception,
      stackTrace: details.stack,
    );
    errorService.reportError(
      details.exception,
      details.stack,
      context: {'source': 'FlutterError.onError'},
    );
  };

  // Capture async / platform errors that escape the framework.
  PlatformDispatcher.instance.onError = (error, stack) {
    _log.error('platform', '$error', error: error, stackTrace: stack);
    errorService.reportError(
      error,
      stack,
      context: {'source': 'PlatformDispatcher.onError'},
    );
    return true; // prevent crash, keep app alive
  };

  // Wrap in runZonedGuarded to catch any remaining async errors.
  runZonedGuarded(
    () {
      runApp(
        const ProviderScope(
          child: FlitApp(),
        ),
      );
    },
    (error, stack) {
      _log.error('zone', '$error', error: error, stackTrace: stack);
      errorService.reportError(
        error,
        stack,
        context: {'source': 'runZonedGuarded'},
      );
    },
  );
}

class FlitApp extends StatelessWidget {
  const FlitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flit',
      debugShowCheckedModeBanner: false,
      theme: FlitTheme.dark,
      builder: (context, child) {
        // Wrap the entire app in an error boundary with debug overlay.
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            // Enhanced DevOverlay from V0 — only in debug/profile builds.
            if (!kReleaseMode) const DevOverlay(),
          ],
        );
      },
      home: const LoginScreen(),
    );
  }
}
