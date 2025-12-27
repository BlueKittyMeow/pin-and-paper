import 'package:integration_test/integration_test_driver.dart';

/// Test driver for running integration tests on real devices/emulators
///
/// Usage:
/// flutter drive \
///   --driver=test_driver/integration_test.dart \
///   --target=integration_test/phase_3_2_integration_test.dart \
///   -d <device_id>
Future<void> main() => integrationDriver();
