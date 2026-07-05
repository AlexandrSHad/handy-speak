import 'package:integration_test/integration_test.dart';

import 'addendum02_suite.dart';

/// On-device / web entry point for the ADDENDUM-02 suite:
/// `flutter test integration_test/addendum02_test.dart -d <device>`
/// (or via `test_driver/integration_test.dart` with `flutter drive`).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  runAddendum02Suite();
}
