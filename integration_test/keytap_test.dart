import 'package:integration_test/integration_test.dart';

import 'keytap_suite.dart';

/// On-device / web entry point for the key-tap reliability suite:
/// `flutter test integration_test/keytap_test.dart -d <device>`
/// (or via `test_driver/integration_test.dart` with `flutter drive`).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  runKeyTapSuite();
}
