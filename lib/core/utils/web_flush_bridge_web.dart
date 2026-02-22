// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Registers page lifecycle listeners that synchronously trigger [flush].
///
/// iOS Safari PWA is notoriously unreliable with lifecycle events on
/// swipe-to-kill. We register multiple listeners for redundancy:
///
///   1. `pagehide` — Apple's recommended event; most reliable on iOS Safari.
///   2. `visibilitychange` (→ hidden) — fires on tab/app switch.
///   3. `beforeunload` — last-chance fallback for desktop browsers.
///
/// All calls are fire-and-forget because these event handlers must return
/// synchronously. The async flush is kicked off to give the Dart microtask
/// queue a chance to run the Supabase upsert before the page is torn down.
///
/// A simple guard prevents concurrent flushes from overlapping.
void registerBeforeUnloadFlush(Future<void> Function() flush) {
  var _flushing = false;

  void safeFlush() {
    if (_flushing) return;
    _flushing = true;
    flush().whenComplete(() => _flushing = false);
  }

  // pagehide: Apple's recommended lifecycle event for iOS Safari PWA.
  // Fires more reliably than beforeunload on swipe-to-kill.
  html.window.addEventListener('pagehide', (html.Event event) {
    safeFlush();
  });

  // visibilitychange: fires when the user switches tabs or apps.
  html.document.addEventListener('visibilitychange', (html.Event event) {
    if (html.document.visibilityState == 'hidden') {
      safeFlush();
    }
  });

  // beforeunload: traditional last-chance event, mainly for desktop browsers.
  html.window.addEventListener('beforeunload', (html.Event event) {
    safeFlush();
  });
}
