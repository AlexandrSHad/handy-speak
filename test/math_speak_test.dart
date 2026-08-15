import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/core/app_language.dart';
import 'package:handy_speak/core/math_speak.dart';

// Pure-logic tests for the ADDENDUM-02 math helpers. No Flutter binding is
// initialized: these run as plain unit tests.

void main() {
  group('mathSpeak', () {
    test('translates every operator glyph to its EN word', () {
      expect(mathSpeak('+ − × ÷ = < >', AppLanguage.en),
          'plus minus times divided by equals is less than is greater than');
    });

    test('translates every operator glyph to its CS word', () {
      expect(mathSpeak('+ − × ÷ = < >', AppLanguage.cs),
          'plus mínus krát děleno rovná se je menší než je větší než');
    });

    test('numbers pass through untouched (engine reads them)', () {
      expect(mathSpeak('42', AppLanguage.en), '42');
      expect(mathSpeak('3.5', AppLanguage.cs), '3.5');
    });

    test('mixed number/glyph problem composes to spoken words (EN)', () {
      // The engine is responsible for reading "12" as "twelve"; we only assert
      // that glyphs become words and numbers are passed through verbatim.
      expect(mathSpeak('12 × 5 =', AppLanguage.en), '12 times 5 equals');
    });

    test('mixed number/glyph problem composes to spoken words (CS)', () {
      expect(mathSpeak('12 × 5 =', AppLanguage.cs), '12 krát 5 rovná se');
    });

    test('translates every operator glyph to its UK word', () {
      expect(mathSpeak('+ − × ÷ = < >', AppLanguage.uk),
          'плюс мінус помножити на поділити на дорівнює менше ніж більше ніж');
    });

    test('mixed number/glyph problem composes to spoken words (UK)', () {
      expect(mathSpeak('12 × 5 =', AppLanguage.uk), '12 помножити на 5 дорівнює');
    });

    test('minus is the true glyph U+2212, never ASCII hyphen', () {
      // The map key is '−' (U+2212). An ASCII '-' must NOT match — it passes
      // through verbatim (the engine would read "hyphen"), proving the lookup
      // keys on the true minus.
      expect(mathSpeak('−', AppLanguage.en), 'minus');
      expect(mathSpeak('-', AppLanguage.en), '-');
    });

    test('empty input yields empty output', () {
      expect(mathSpeak('', AppLanguage.en), '');
      expect(mathSpeak('   ', AppLanguage.en), '');
    });
  });

  group('mathAppendDigit', () {
    test('first digit on empty buffer', () {
      expect(mathAppendDigit('', '4'), '4');
    });

    test('groups consecutive digits into one tile', () {
      expect(mathAppendDigit('4', '2'), '42');
    });

    test('joins a decimal point to the trailing number', () {
      expect(mathAppendDigit('3', '.'), '3.');
      expect(mathAppendDigit('3.', '5'), '3.5');
    });

    test('starts a fresh number after a spaced operator', () {
      // mathAppendOp leaves trailing space: '3 + ' — appending a digit glues
      // directly, keeping the number one tile.
      expect(mathAppendDigit('3 + ', '4'), '3 + 4');
    });

    test('fresh number after an operator that was just spaced', () {
      expect(mathAppendDigit('7 ÷ ', '2'), '7 ÷ 2');
    });
  });

  group('mathAppendOp', () {
    test('own tile: appends with surrounding spaces', () {
      expect(mathAppendOp('3', '+'), '3 + ');
    });

    test('never leads with a sign on an empty buffer', () {
      expect(mathAppendOp('', '+'), '');
    });

    test('never leads with a sign on a whitespace-only buffer', () {
      expect(mathAppendOp('   ', '−'), '');
    });

    test('collapses trailing whitespace before appending', () {
      expect(mathAppendOp('3 + 4 ', '='), '3 + 4 = ');
    });

    test('minus glyph appended is the true U+2212', () {
      expect(mathAppendOp('5', '−'), '5 − ');
    });
  });

  group('mathDeleteLast', () {
    test('trims a digit off a trailing number', () {
      expect(mathDeleteLast('42'), '4');
    });

    test('drops one glyph then strips trailing whitespace (POC parity)', () {
      // POC: text.replace(/\s+$/, '').slice(0,-1).replace(/\s+$/, '')
      // '3 + 4' → '3 + 4' → drop '4' → '3 + ' → strip ws → '3 +'
      expect(mathDeleteLast('3 + 4'), '3 +');
      // '3 +' → '3 +' → drop '+' → '3 ' → strip ws → '3'
      expect(mathDeleteLast('3 +'), '3');
    });

    test('empty buffer stays empty', () {
      expect(mathDeleteLast(''), '');
      expect(mathDeleteLast('   '), '');
    });

    test('deletes a leading number entirely', () {
      expect(mathDeleteLast('5'), '');
    });
  });
}
