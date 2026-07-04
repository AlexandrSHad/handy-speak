import '../integration_test/keytap_suite.dart';

/// Headless entry point for the key-tap reliability suite:
/// `flutter test test/keytap_test.dart`
///
/// NOTE: the "slides within the key" tests are EXPECTED to fail until the
/// release-within-bounds key handling lands — see keytap_suite.dart.
void main() {
  runKeyTapSuite();
}
