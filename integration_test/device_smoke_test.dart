import 'package:integration_test/integration_test.dart';

import 'device_smoke_suite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  runDeviceSmokeSuite();
}
