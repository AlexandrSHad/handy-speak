import 'package:integration_test/integration_test.dart';

import 'addendum01_suite.dart';

/// On-device / web entry point for the ADDENDUM-01 suite:
/// `flutter test integration_test/addendum01_test.dart -d <device>`
/// (or via `test_driver/integration_test.dart` with `flutter drive`).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  runAddendum01Suite();
}
