import 'package:integration_test/integration_test.dart';

import 'addendum04_suite.dart';

/// On-device entry point for the ADDENDUM-04 suite:
/// `puro flutter test integration_test/addendum04_test.dart -d <device>`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  runAddendum04Suite();
}
