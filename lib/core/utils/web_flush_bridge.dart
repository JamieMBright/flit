import 'web_flush_bridge_stub.dart'
    if (dart.library.html) 'web_flush_bridge_web.dart';

/// Registers a `beforeunload` handler on web that calls [flush] before
/// the page unloads. This is the last-chance safety net for persisting
/// dirty state when iOS Safari PWA is killed without lifecycle events.
///
/// On non-web platforms this is a no-op.
class WebFlushBridge {
  WebFlushBridge._();

  static void register(Future<void> Function() flush) =>
      registerBeforeUnloadFlush(flush);
}
