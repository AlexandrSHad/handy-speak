import 'package:integration_test/integration_test.dart';

import 'addendum03_suite.dart';

/// On-device / web entry point for the ADDENDUM-03 suite:
/// `flutter test integration_test/addendum03_test.dart -d <device>`
/// (or via `test_driver/integration_test.dart` with `flutter drive`).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  runAddendum03Suite();
}
