import 'web_flush_bridge_stub.dart'
    if (dart.library.html) 'web_flush_bridge_web.dart';

/// Registers page lifecycle handlers on web (`pagehide`, `visibilitychange`,
/// `beforeunload`) that call [flush] before the page is torn down.
///
/// This is the last-chance safety net for persisting dirty state when iOS
/// Safari PWA is killed without Flutter lifecycle events. Multiple events
/// are registered for redundancy since iOS Safari is unreliable about which
/// events fire on swipe-to-kill.
///
/// On non-web platforms this is a no-op.
class WebFlushBridge {
  WebFlushBridge._();

  static void register(Future<void> Function() flush) =>
      registerBeforeUnloadFlush(flush);
}
