# Flit Integration Tests

End-to-end widget-level integration tests for the Flit geography game. These
tests drive the **real** app screens (HomeScreen, the game-launch setup
screens, and the menu screens) — not stub look-alikes.

## Structure

```
test/integration/             # Host-runner tests (no device required, runs in CI)
  helpers/test_harness.dart   # pumpRealScreen, ensureTestEnv, loggedInOverrides, settle
  app_boot_test.dart          # Real HomeScreen: title, PLAY, mode sheet
  navigation_test.dart        # Real launch screens (Campaign, Free Flight, Practice,
                              #   Daily Challenge, Daily Briefing, Flight School, Uncharted)
  interactions_test.dart      # Real menu screens (Shop, Profile, Friends, Leaderboard,
                              #   Country Clues, Guide) + real control interactions

integration_test/             # Device-based tests (flutter test --device-id=<id>)
  helpers/test_harness.dart   # Same API, wraps IntegrationTestWidgetsFlutterBinding
  app_boot_test.dart          # Real HomeScreen on a real device (+ screenshots)
  navigation_test.dart        # Real launch screens on a real device
  interactions_test.dart      # Real menu screens on a real device

test_driver/
  integration_test.dart       # flutter_driver entry point (legacy drive protocol)
```

## Running the tests

### Host runner (no device required — CI-safe)

```bash
export PATH="/tmp/flutter/bin:/tmp/flutter/bin/cache/dart-sdk/bin:$PATH"
flutter test test/integration/
```

### Real device / emulator

```bash
flutter devices
flutter test --device-id=<device-id> integration_test/
```

### flutter drive (legacy protocol)

```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_boot_test.dart \
  -d <device-id>
```

## Design decisions

### Real screens, no stubs

These tests pump the actual production screens. To do that under `flutter test`
without a real backend, the harness `setUpAll` calls `TestHarness.ensureTestEnv()`,
which:

- Mocks `SharedPreferences` (`setMockInitialValues({})`).
- Initialises Supabase against an **unreachable** URL (`http://localhost:1`).
  This is deliberate: screens that read `Supabase.instance.client.auth.currentUser`
  synchronously (e.g. ProfileScreen, LeaderboardScreen) get a clean `null` session
  instead of an `AssertionError`, and every real query fails fast (connection
  refused) and is swallowed by each screen's own try/catch, falling back to its
  empty/default state. No real network traffic leaves the test, and `main()` is
  never called (so audio / error-telemetry / real Supabase init are skipped).

`TestHarness.loggedInOverrides()` seeds `accountProvider` with a fake level-99
pilot (`AccountNotifier()..switchAccount(fakePlayer)`) so every game mode is
unlocked and the real menus render fully.

`TestHarness.pumpRealScreen(tester, screen)` wraps the screen in
`ProviderScope(overrides: ...) + MaterialApp`, pumps a fixed number of frames,
and drains the background async exceptions raised by the dead-URL fetches.

### settle, never pumpAndSettle

`WidgetTester.pumpAndSettle()` loops until all animations settle. Flit has a
continuously-animated globe background (and pulse controllers) that never stop,
so pumpAndSettle deadlocks. All tests use `TestHarness.settle(tester, frames: N)`
(an alias for fixed-frame pumping) which pumps exactly N ~16 ms frames and
returns, draining any async exception per frame.

### Keys

No Keys were added to production code. All finders use real on-screen text or
widget types (e.g. `find.text('PLAY')`, `find.byType(ShopScreen)`).

### Screenshots

`TestHarness.takeScreenshot(tester, 'name')` captures a PNG on a real device
(via `IntegrationTestWidgetsFlutterBinding`). On the host runner it asserts a
rendered surface and no-ops the capture.
```
