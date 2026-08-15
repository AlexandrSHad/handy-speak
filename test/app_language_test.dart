import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/core/app_language.dart';

// Pure-logic tests for AppLanguage (ADDENDUM-03: adds Ukrainian as a third
// supported language). No Flutter binding is initialized: these run as plain
// unit tests, mirroring test/math_speak_test.dart's style.

void main() {
  group('AppLanguage.ttsLocale', () {
    test('en -> en-US', () {
      expect(AppLanguage.en.ttsLocale, 'en-US');
    });
    test('cs -> cs-CZ', () {
      expect(AppLanguage.cs.ttsLocale, 'cs-CZ');
    });
    test('uk -> uk-UA', () {
      expect(AppLanguage.uk.ttsLocale, 'uk-UA');
    });
  });

  group('AppLanguage.short', () {
    test('en -> EN', () {
      expect(AppLanguage.en.short, 'EN');
    });
    test('cs -> CZ', () {
      expect(AppLanguage.cs.short, 'CZ');
    });
    test('uk -> UK', () {
      expect(AppLanguage.uk.short, 'UK');
    });
  });

  group('AppLanguage.nativeName', () {
    test('en -> English', () {
      expect(AppLanguage.en.nativeName, 'English');
    });
    test('cs -> Čeština', () {
      expect(AppLanguage.cs.nativeName, 'Čeština');
    });
    test('uk -> Українська', () {
      expect(AppLanguage.uk.nativeName, 'Українська');
    });
  });

  group('AppLanguage.key', () {
    test('en -> en', () {
      expect(AppLanguage.en.key, 'en');
    });
    test('cs -> cs', () {
      expect(AppLanguage.cs.key, 'cs');
    });
    test('uk -> uk', () {
      expect(AppLanguage.uk.key, 'uk');
    });
  });

  group('AppLanguage.fromKey', () {
    test("'en' -> AppLanguage.en", () {
      expect(AppLanguage.fromKey('en'), AppLanguage.en);
    });
    test("'cs' -> AppLanguage.cs", () {
      expect(AppLanguage.fromKey('cs'), AppLanguage.cs);
    });
    test("'uk' -> AppLanguage.uk", () {
      expect(AppLanguage.fromKey('uk'), AppLanguage.uk);
    });
    test('null falls back to AppLanguage.en', () {
      expect(AppLanguage.fromKey(null), AppLanguage.en);
    });
    test('unrecognized key falls back to AppLanguage.en', () {
      expect(AppLanguage.fromKey('garbage'), AppLanguage.en);
    });
  });

  group('AppLanguage.locale', () {
    test('locale.languageCode matches the enum name for every value', () {
      for (final lang in AppLanguage.values) {
        expect(lang.locale.languageCode, lang.name);
      }
    });

    test('uk locale.languageCode is uk', () {
      expect(AppLanguage.uk.locale.languageCode, 'uk');
    });
  });
}
