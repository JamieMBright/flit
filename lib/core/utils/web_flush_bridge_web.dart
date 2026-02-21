// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Registers a `beforeunload` listener that synchronously triggers [flush].
///
/// On iOS Safari PWA, `visibilitychange` (AppLifecycleState.hidden) sometimes
/// doesn't fire when the user swipes away. `beforeunload` is the last-chance
/// fallback. The flush is fire-and-forget — we can't await it because
/// `beforeunload` handlers must return synchronously.
void registerBeforeUnloadFlush(Future<void> Function() flush) {
  html.window.addEventListener('beforeunload', (html.Event event) {
    // Fire the async flush — we can't await it, but it gives the Dart
    // microtask queue a chance to run the upsert before the page unloads.
    flush();
  });
}
