import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/audio_manager.dart';
import 'core/services/dev_overlay.dart';
import 'core/services/error_sender_http.dart';
import 'core/services/error_service.dart';
import 'core/theme/flit_theme.dart';
import 'core/utils/game_log.dart';
import 'features/auth/login_screen.dart';

final _log = GameLog.instance;

/// Periodic flush interval for error telemetry.
const _flushInterval = Duration(seconds: 60);

/// Global error message holder. When non-null, [ErrorWidget.builder] and
/// [FlitApp] both render a frozen error screen instead of the normal UI.
String? _fatalError;

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

  // Register the cross-platform HTTP sender so flush() can POST errors.
  errorService.setSender(errorSenderHttp);

  // Periodically flush queued errors to the Vercel endpoint.
  Timer.periodic(_flushInterval, (_) => errorService.flush());

  // Initialize audio system.
  AudioManager.instance.initialize();

  _log.info('app', 'Flit starting up');

  // ── NUCLEAR ERROR BOUNDARY ──
  // Override ErrorWidget.builder so that ANY widget build failure shows a
  // frozen dark screen with the full error text instead of the default
  // grey/red error widget. This is the absolute last line of defence —
  // it fires at the Flutter framework level, BEFORE the Navigator can
  // reset and dump the user back to the login screen.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    _fatalError ??=
        '${details.exceptionAsString()}\n\n${details.stack ?? "no stack"}';
    return Material(
      color: const Color(0xFF0A0E1A),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.error_outline,
                      color: Color(0xFFFF4444), size: 28),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'FLIT CRASH — ErrorWidget',
                      style: TextStyle(
                        color: Color(0xFFFF4444),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    _fatalError!,
                    style: const TextStyle(
                      color: Color(0xFFAAAAAA),
                      fontSize: 12,
                      fontFamily: 'monospace',
                      height: 1.5,
                      fontWeight: FontWeight.normal,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  };

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

class FlitApp extends StatefulWidget {
  const FlitApp({super.key});

  @override
  State<FlitApp> createState() => _FlitAppState();
}

class _FlitAppState extends State<FlitApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Flush queued errors when the app goes to background or is about to close.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ErrorService.instance.flush();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flit',
      debugShowCheckedModeBanner: false,
      theme: FlitTheme.dark,
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            if (!kReleaseMode) const DevOverlay(),
          ],
        );
      },
      home: const LoginScreen(),
    );
  }
}
