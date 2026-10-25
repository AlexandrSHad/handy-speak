import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/core/app_language.dart';
import 'package:handy_speak/core/letter_sounds.dart';
import 'package:handy_speak/data/keyboard_layouts.dart';

// Pure-logic tests for the ADDENDUM-08 letter-sound table. No Flutter
// binding is initialized: these run as plain unit tests.
//
// The table's spelling *values* are ear-pass drafts (logoped validates on
// the reference device); these tests pin structure, not phonetics:
// coverage against the real layouts, the mixed-echo decision (digits keep
// number names), and graceful fallback.

/// The only keyboard keys deliberately left unmapped: soft sign and
/// apostrophe have no standalone sound (ADDENDUM-08 decision).
const kUnmappedKeys = {'ʼ', 'ь'};

/// Keys of `KbRowType.number` rows and any ASCII digit anywhere: digits
/// never get sound spellings — the engine says their number names.
bool isDigitKey(String key) => RegExp(r'^[0-9]$').hasMatch(key);

void main() {
  group('coverage — derived from kKeyboardLayouts', () {
    test('every letter key of every layout maps, except the unmapped set',
        () {
      for (final entry in kKeyboardLayouts.entries) {
        final lang = entry.key;
        for (final row in entry.value) {
          for (final key in row.keys) {
            if (isDigitKey(key) || kUnmappedKeys.contains(key)) continue;
            expect(
              letterSound(key, lang),
              isNotNull,
              reason: '$key on the ${lang.name} layout has no sound spelling',
            );
          }
        }
      }
    });

    test('the unmapped set really is unmapped (no silent regressions)', () {
      expect(letterSound('ʼ', AppLanguage.uk), isNull);
      expect(letterSound('ь', AppLanguage.uk), isNull);
    });
  });

  group('digits keep their number names (mixed-echo decision)', () {
    test('no digit key maps in any language', () {
      for (final lang in AppLanguage.values) {
        for (var d = 0; d <= 9; d++) {
          expect(letterSound('$d', lang), isNull,
              reason: '$d must fall through to the raw char in ${lang.name}');
        }
        expect(letterSound('.', lang), isNull); // math decimal point
      }
    });
  });

  group('lookup behavior', () {
    test('case normalization: B hits the same entry as b', () {
      expect(letterSound('B', AppLanguage.en), letterSound('b', AppLanguage.en));
      expect(letterSound('É', AppLanguage.cs), 'é');
    });

    test('unknown chars fall back to null (caller speaks the raw char)', () {
      expect(letterSound('5', AppLanguage.en), isNull);
      expect(letterSound('@', AppLanguage.en), isNull);
      expect(letterSound('λ', AppLanguage.cs), isNull);
      expect(letterSound('ї', AppLanguage.cs), isNull); // uk letter, cs lookup
    });

    test('spot checks: draft spellings flow through per language', () {
      expect(letterSound('b', AppLanguage.en), 'buh');
      expect(letterSound('s', AppLanguage.en), 'sss');
      expect(letterSound('ř', AppLanguage.cs), 'ř');
      expect(letterSound('ů', AppLanguage.cs), 'ů');
      expect(letterSound('щ', AppLanguage.uk), 'шч');
      expect(letterSound('ш', AppLanguage.uk), 'шш');
      expect(letterSound('а', AppLanguage.uk), 'а');
    });
  });
}
