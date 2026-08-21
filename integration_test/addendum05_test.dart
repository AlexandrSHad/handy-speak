import 'package:integration_test/integration_test.dart';

import 'addendum05_suite.dart';

/// On-device entry point for the ADDENDUM-05 suite:
/// `flutter test integration_test/addendum05_test.dart -d <device>`
/// (or via `test_driver/integration_test.dart` with `flutter drive`).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  runAddendum05Suite();
}
