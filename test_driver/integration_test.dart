/// Standard flutter_driver entry point for running integration tests on a
/// real device or emulator.
///
/// Usage:
///   flutter drive \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/app_boot_test.dart \
///     -d <device-id>
library integration_test_driver;

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
