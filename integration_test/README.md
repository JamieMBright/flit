# Flit Integration Tests

End-to-end widget-level integration tests for the Flit geography game.

## Structure

```
test/integration/             # Host-runner tests (no device required, runs in CI)
  helpers/test_harness.dart   # Shared helpers: pumpApp, pumpAndSettleSafely, tap, screenshot
  app_boot_test.dart          # App renders without crashing
  navigation_test.dart        # Push/pop navigation between screens
  interactions_test.dart      # Button taps, text input, toggle state

integration_test/             # Device-based tests (flutter test --device-id=<id>)
  helpers/test_harness.dart   # Same API but wraps IntegrationTestWidgetsFlutterBinding
  app_boot_test.dart          # Boot tests on real device
  navigation_test.dart        # Navigation on real device
  interactions_test.dart      # Interactions on real device

test_driver/
  integration_test.dart       # flutter_driver entry point (legacy drive protocol)
```

## Running the tests

### Host runner (no device required — CI-safe)

```bash
export PATH="/tmp/flutter/bin:/tmp/flutter/bin/cache/dart-sdk/bin:$PATH"
flutter test test/integration/
```

Or via the project script:

```bash
./scripts/test-e2e.sh
```

### Real device / emulator

```bash
flutter devices
flutter test --device-id=<device-id> integration_test/
./scripts/test-e2e.sh --device <device-id>
```

### flutter drive (legacy protocol)

```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_boot_test.dart \
  -d <device-id>
```

## Design decisions

### pumpAndSettleSafely

`WidgetTester.pumpAndSettle()` loops until all animations settle. Flit has a
continuously-animated globe shader that never stops, so pumpAndSettle deadlocks.
All tests use `TestHarness.pumpAndSettleSafely(tester, frames: N)` which pumps
exactly N frames of ~16 ms each and returns.

### Stub screens

The real Flit screens require Supabase.initialize, AudioManager.initialize, and
FragmentProgram.fromAsset — all need a real device, network, and GPU. Integration
tests use lightweight stub widgets that exercise navigation and interaction
plumbing without external dependencies. Tests requiring a real device are marked
`skip: true`.

### Keys

No Keys were added to app production code. All Keys are on stub widgets defined
inside the integration test files themselves.

### Screenshots

`TestHarness.takeScreenshot(tester, 'name')` wraps
`IntegrationTestWidgetsFlutterBinding.takeScreenshot()` in a try/catch. On the
host runner it silently no-ops. On a real device it captures a PNG.
