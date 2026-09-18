import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/l10n/app_localizations_cs.dart';
import 'package:handy_speak/l10n/app_localizations_en.dart';
import 'package:handy_speak/l10n/app_localizations_uk.dart';

// Pure-logic test for the generated wordCount(int) pluralization in all three
// UI locales (testing-strategy §4 "Language set & localization · Unit"). No
// Flutter binding is initialized: this exercises the generated
// intl.Intl.pluralLogic directly, driven by each locale's CLDR plural rule as
// encoded in the ARB-generated class. Each locale draws the 0/1/few/many
// boundaries differently, so the contrast is deliberate — note that Czech
// keeps 22 in `other` while Ukrainian's last-digit rule pulls 22 into `few`.

void main() {
  final en = AppLocalizationsEn();
  final cs = AppLocalizationsCs();
  final uk = AppLocalizationsUk();

  test('en word count pluralizes correctly (one vs other)', () {
    // English CLDR: only `one` (exactly 1) is special; everything else is
    // `other`. `0` has no `zero` category in English, so it falls to `other`.
    expect(en.wordCount(0), '0 words');
    expect(en.wordCount(1), '1 word');
    expect(en.wordCount(2), '2 words');
    expect(en.wordCount(5), '5 words');
    expect(en.wordCount(21), '21 words');
    expect(en.wordCount(100), '100 words');
  });

  test('cs word count pluralizes correctly (one / few 2-4 / other)', () {
    // Czech CLDR: `one` = exactly 1, `few` = 2-4, everything else `other`.
    // Unlike the Slavic last-digit rule, 22 stays `other` here.
    expect(cs.wordCount(0), '0 slov');
    expect(cs.wordCount(1), '1 slovo');
    expect(cs.wordCount(2), '2 slova');
    expect(cs.wordCount(3), '3 slova');
    expect(cs.wordCount(4), '4 slova');
    expect(cs.wordCount(5), '5 slov');
    expect(cs.wordCount(10), '10 slov');
    expect(cs.wordCount(22), '22 slov');
  });

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
