import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/l10n/app_localizations_uk.dart';

// Pure-logic test for the generated Ukrainian wordCount(int) pluralization
// (ADDENDUM-03). No Flutter binding is initialized: this exercises the
// generated intl.Intl.pluralLogic directly, driven by the CLDR `uk` plural
// rule already encoded in the ARB-generated class.

void main() {
  final uk = AppLocalizationsUk();

  test('uk word count pluralizes correctly', () {
    expect(uk.wordCount(0), '0 слів');
    expect(uk.wordCount(1), '1 слово');
    expect(uk.wordCount(2), '2 слова');
    expect(uk.wordCount(4), '4 слова');
    expect(uk.wordCount(5), '5 слів');
    expect(uk.wordCount(10), '10 слів');
    expect(uk.wordCount(11), '11 слів');
    expect(uk.wordCount(12), '12 слів');
    expect(uk.wordCount(14), '14 слів');
    expect(uk.wordCount(21), '21 слово');
    expect(uk.wordCount(22), '22 слова');
  });
}
