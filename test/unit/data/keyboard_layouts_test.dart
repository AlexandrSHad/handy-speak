import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/core/app_language.dart';
import 'package:handy_speak/data/keyboard_layouts.dart';

// Static-data invariants for the per-language keyboard layouts
// (`kKeyboardLayouts`). Pure data-shape assertions — no widget tree, no
// binding. Guards row counts, the expected key set per language, the Czech
// QWERTZ y/z swap versus English QWERTY, and the Ukrainian Cyrillic set.

void main() {
  group('kKeyboardLayouts · shape', () {
    test('defines a layout for every supported language', () {
      expect(kKeyboardLayouts.keys.toSet(), AppLanguage.values.toSet());
    });

    test('every language has exactly four rows', () {
      for (final lang in AppLanguage.values) {
        expect(kKeyboardLayouts[lang]!.length, 4,
            reason: '${lang.name} should have 4 rows');
      }
    });

    test('every row carries at least one key', () {
      for (final entry in kKeyboardLayouts.entries) {
        for (final row in entry.value) {
          expect(row.keys, isNotEmpty,
              reason: 'a ${entry.key.name} row is empty');
        }
      }
    });

    test('keys are single, lowercase, non-blank characters', () {
      for (final rows in kKeyboardLayouts.values) {
        for (final row in rows) {
          if (row.type != KbRowType.letters) continue;
          for (final key in row.keys) {
            expect(key.trim(), isNotEmpty, reason: 'blank key');
            expect(key, key.toLowerCase(), reason: '"$key" is not lowercase');
          }
        }
      }
    });

    test('within a language every key is unique', () {
      for (final entry in kKeyboardLayouts.entries) {
        final all = [for (final row in entry.value) ...row.keys];
        expect(all.toSet().length, all.length,
            reason: '${entry.key.name} has duplicate keys');
      }
    });
  });

  group('kKeyboardLayouts · row types', () {
    test('English & Ukrainian lead with a number row; Czech leads with accents',
        () {
      expect(kKeyboardLayouts[AppLanguage.en]!.first.type, KbRowType.number);
      expect(kKeyboardLayouts[AppLanguage.uk]!.first.type, KbRowType.number);
      expect(kKeyboardLayouts[AppLanguage.cs]!.first.type, KbRowType.accent);
    });

    test('the number rows are the ten digits 0-9', () {
      const digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
      expect(kKeyboardLayouts[AppLanguage.en]!.first.keys, digits);
      expect(kKeyboardLayouts[AppLanguage.uk]!.first.keys, digits);
    });
  });

  group('English (QWERTY) key set', () {
    test('carries the full a-z alphabet across its letter rows', () {
      final letters = <String>{
        for (final row in kKeyboardLayouts[AppLanguage.en]!)
          if (row.type == KbRowType.letters) ...row.keys,
      };
      final az = {for (var c = 0; c < 26; c++) String.fromCharCode(97 + c)};
      expect(letters, az);
    });

    test('top letter row is the QWERTY home sequence', () {
      final topLetterRow = kKeyboardLayouts[AppLanguage.en]!
          .firstWhere((r) => r.type == KbRowType.letters);
      expect(topLetterRow.keys,
          ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p']);
    });
  });

  group('Czech (QWERTZ) key set', () {
    List<KbRow> letterRows() => kKeyboardLayouts[AppLanguage.cs]!
        .where((r) => r.type == KbRowType.letters)
        .toList();

    test('shares the base a-z alphabet with English', () {
      final cs = <String>{for (final row in letterRows()) ...row.keys};
      final az = {for (var c = 0; c < 26; c++) String.fromCharCode(97 + c)};
      expect(cs, az);
    });

    test('exposes an accent row: ů/ú lead per logoped, rest in ČSN key order', () {
      final accentRow = kKeyboardLayouts[AppLanguage.cs]!
          .firstWhere((r) => r.type == KbRowType.accent);
      // ů/ú lead (logoped-requested order; on the physical ČSN QWERTZ
      // keyboard they sit on different rows). Then the number-row keys
      // ě š č ř ž ý á í é left→right, then the dead-key letters ď ť ň, and
      // ó (composed ´+o) last.
      expect(accentRow.keys,
          ['ů', 'ú', 'ě', 'š', 'č', 'ř', 'ž', 'ý', 'á', 'í', 'é', 'ď', 'ť', 'ň', 'ó']);
    });

    test('QWERTZ swap: Czech has z where English has y (top letter row)', () {
      final enTop = kKeyboardLayouts[AppLanguage.en]!
          .firstWhere((r) => r.type == KbRowType.letters);
      final csTop = kKeyboardLayouts[AppLanguage.cs]!
          .firstWhere((r) => r.type == KbRowType.letters);
      // English top row has 'y' at index 5; Czech puts 'z' there instead.
      expect(enTop.keys[5], 'y');
      expect(csTop.keys[5], 'z');
    });

    test('QWERTZ swap: Czech has y where English has z (bottom letter row)', () {
      final enBottom = kKeyboardLayouts[AppLanguage.en]!.last;
      final csBottom = kKeyboardLayouts[AppLanguage.cs]!.last;
      // English bottom row leads with 'z'; Czech leads with 'y'.
      expect(enBottom.keys.first, 'z');
      expect(csBottom.keys.first, 'y');
    });
  });

  group('Ukrainian (Cyrillic) key set', () {
    test('letter rows are all Cyrillic (or the apostrophe), no Latin', () {
      final cyrillic = RegExp(r'[Ѐ-ӿ]');
      for (final row in kKeyboardLayouts[AppLanguage.uk]!) {
        if (row.type != KbRowType.letters) continue;
        for (final key in row.keys) {
          final isApostrophe = key == 'ʼ';
          expect(cyrillic.hasMatch(key) || isApostrophe, isTrue,
              reason: '"$key" is not a Cyrillic letter');
        }
      }
    });

    test('includes the distinctly Ukrainian letters і, ї, є, ґ', () {
      final letters = <String>{
        for (final row in kKeyboardLayouts[AppLanguage.uk]!)
          if (row.type == KbRowType.letters) ...row.keys,
      };
      expect(letters, containsAll(<String>['і', 'ї', 'є', 'ґ']));
    });

    test('opens the top letter row with the ЙЦУКЕН sequence', () {
      final topLetterRow = kKeyboardLayouts[AppLanguage.uk]!
          .firstWhere((r) => r.type == KbRowType.letters);
      expect(topLetterRow.keys.take(6).toList(),
          ['й', 'ц', 'у', 'к', 'е', 'н']);
    });
  });
}
