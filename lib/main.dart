import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/flit_theme.dart';
import 'core/utils/game_log.dart';
import 'features/auth/login_screen.dart';

final _log = GameLog.instance;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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
  };

  // Capture async / platform errors that escape the framework.
  PlatformDispatcher.instance.onError = (error, stack) {
    _log.error('platform', '$error', error: error, stackTrace: stack);
    return true; // prevent crash, keep app alive
  };

  runApp(
    const ProviderScope(
      child: FlitApp(),
    ),
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
            if (kDebugMode) const _DebugErrorOverlay(),
          ],
        );
      },
      home: const LoginScreen(),
    );
  }
}

/// Floating debug overlay that shows runtime errors on screen.
/// Only visible in debug mode and when errors have been captured.
class _DebugErrorOverlay extends StatefulWidget {
  const _DebugErrorOverlay();

  @override
  State<_DebugErrorOverlay> createState() => _DebugErrorOverlayState();
}

class _DebugErrorOverlayState extends State<_DebugErrorOverlay> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final errorCount = _log.errorCount;
    final warningCount = _log.warningCount;
    if (errorCount == 0 && warningCount == 0) return const SizedBox.shrink();

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: SafeArea(
        child: Material(
          color: errorCount > 0
              ? Colors.red.shade900.withAlpha(230)
              : Colors.orange.shade900.withAlpha(200),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '$errorCount error(s), $warningCount warning(s) — tap to ${_expanded ? 'collapse' : 'expand'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                  if (_expanded) ...[
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: SingleChildScrollView(
                        child: Text(
                          _log
                              .entriesAtLevel(LogLevel.warning)
                              .map((e) => e.toString())
                              .join('\n\n'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontFamily: 'monospace',
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
