import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/l10n/app_localizations_cs.dart';
import 'package:handy_speak/l10n/app_localizations_en.dart';
import 'package:handy_speak/state/composer_controller.dart';
import 'package:handy_speak/widgets/keyboard_view.dart';
import 'package:handy_speak/widgets/math_board.dart';
import 'package:handy_speak/widgets/message_blocks.dart';

import '../support/app_harness.dart';

// Math board feature (docs/testing-strategy.md §4 "Math board").
//
// The Math board is a separate glyph buffer that never evaluates; Speak
// translates its glyphs into per-language words. Ported from the ADDENDUM-02
// "Math pill", "Math grid", "Math composition" and "Speak voices math glyphs"
// suites onto the shared headless harness.
void main() {
  final en = AppLocalizationsEn();
  final cs = AppLocalizationsCs();

  group('Math pill', () {
    testWidgets('third pill "Math" appears and switches to the board (EN)',
        (tester) async {
      await pumpApp(tester);
      expect(find.byIcon(Icons.calculate_outlined), findsOneWidget);
      expect(find.text(en.modeMath), findsOneWidget);

      await tester.tap(find.text(en.modeMath));
      await tester.pumpAndSettle();
      expect(find.byType(MathBoard), findsOneWidget);
      expect(find.byType(KeyboardView), findsNothing);
    });

    testWidgets('third pill "Počítání" switches to the board (CS)',
        (tester) async {
      // Single-language cs install: main (and thus UI chrome + board) is cs
      // — ADDENDUM-04 keys; chrome follows main per ADR-0002.
      await pumpApp(tester, prefs: {'main_lang': 'cs'});
      expect(find.text(cs.modeMath), findsOneWidget);

      await tester.tap(find.text(cs.modeMath));
      await tester.pumpAndSettle();
      expect(find.byType(MathBoard), findsOneWidget);
    });
  });

  group('Math grid', () {
    testWidgets('renders the true glyphs ÷ × − < > = and ⌫', (tester) async {
      await pumpApp(tester);
      await enterMath(tester);

      for (final g in ['÷', '×', '−', '<', '>', '=']) {
        expect(mathText(g), findsOneWidget,
            reason: '$g must be the true glyph, not an ASCII stand-in');
      }
      expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
    });

    testWidgets('0 spans two columns (~2× a normal key)', (tester) async {
      await pumpApp(tester);
      await enterMath(tester);

      final zero = tester.getSize(
          find.ancestor(of: mathText('0'), matching: find.byType(Material)).first);
      final seven = tester.getSize(
          find.ancestor(of: mathText('7'), matching: find.byType(Material)).first);
      expect(zero.width, greaterThan(seven.width * 1.8));
      expect(zero.width, lessThan(seven.width * 2.2));
    });
  });

  group('Math composition', () {
    testWidgets('4,2 yields a single tile "42"', (tester) async {
      await pumpApp(tester);
      await enterMath(tester);

      await tapMath(tester, '4');
      await tapMath(tester, '2');

      expect(readProvider<ComposerController>(tester).tokens, ['42']);
      expect(messageTile('42'), findsOneWidget);
    });

    testWidgets('3 + 4 = 7 yields five tiles', (tester) async {
      await pumpApp(tester);
      await enterMath(tester);

      for (final k in ['3', '+', '4', '=', '7']) {
        await tapMath(tester, k);
      }

      expect(readProvider<ComposerController>(tester).tokens,
          ['3', '+', '4', '=', '7']);
      for (final t in ['3', '+', '4', '=', '7']) {
        expect(messageTile(t), findsOneWidget);
      }
    });

    testWidgets('⌫ deletes one glyph (digit off a number)', (tester) async {
      await pumpApp(tester);
      await enterMath(tester);

      await tapMath(tester, '4');
      await tapMath(tester, '2');
      expect(readProvider<ComposerController>(tester).text, '42');

      await tapMathBackspace(tester);
      expect(readProvider<ComposerController>(tester).text, '4');
    });

    testWidgets('⌫ drops a whole sign tile', (tester) async {
      await pumpApp(tester);
      await enterMath(tester);

      await tapMath(tester, '3');
      await tapMath(tester, '+');
      await tapMath(tester, '4');
      // '3 + 4' → backspace trims '4' → '3 +' (POC strips trailing ws)
      await tapMathBackspace(tester);
      expect(readProvider<ComposerController>(tester).text, '3 +');
      // → backspace drops the whole '+' tile → '3'
      await tapMathBackspace(tester);
      expect(readProvider<ComposerController>(tester).text, '3');
    });

    testWidgets('completed math tiles are tap-to-✕ removable', (tester) async {
      await pumpApp(tester);
      await enterMath(tester);

      await tapMath(tester, '3');
      await tapMath(tester, '+');
      await tapMath(tester, '4');
      // tokens: ['3','+','4']; trailing '4' is active (caret), '3'/'+' removable.

      await tester.tap(messageTile('+'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(readProvider<ComposerController>(tester).tokens, ['3', '4']);
    });
  });

  group('Speak voices math glyphs', () {
    testWidgets('EN: 12 × 5 = speaks "12 times 5 equals"', (tester) async {
      final app = await pumpApp(tester);
      await enterMath(tester);

      await tapMath(tester, '1');
      await tapMath(tester, '2');
      await tapMath(tester, '×');
      await tapMath(tester, '5');
      await tapMath(tester, '=');

      await tester.tap(find.text(en.speak));
      await tester.pumpAndSettle();

      expect(app.tts.spokenTexts, isNotEmpty);
      expect(app.tts.spokenTexts.last, '12 times 5 equals');
    });

    testWidgets('CS: 12 × 5 = speaks "12 krát 5 rovná se"', (tester) async {
      final app = await pumpApp(tester, prefs: {'main_lang': 'cs'});
      await enterMath(tester);

      await tapMath(tester, '1');
      await tapMath(tester, '2');
      await tapMath(tester, '×');
      await tapMath(tester, '5');
      await tapMath(tester, '=');

      await tester.tap(find.text(cs.speak));
      await tester.pumpAndSettle();

      expect(app.tts.spokenTexts.last, '12 krát 5 rovná se');
    });
  });
}

// --- Math helpers ----------------------------------------------------------

/// Switch to the Math board (taps the pill by icon — locale-independent).
Future<void> enterMath(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.calculate_outlined));
  await tester.pumpAndSettle();
}

/// Tap the math `⌫` key (rendered as an icon, not a Text label).
Future<void> tapMathBackspace(WidgetTester tester) async {
  await tester.tap(find.descendant(
    of: find.byType(MathBoard),
    matching: find.byIcon(Icons.backspace_outlined),
  ));
  await tester.pumpAndSettle();
}

/// A [Text] scoped to the math board.
Finder mathText(String label) => find.descendant(
      of: find.byType(MathBoard),
      matching: find.text(label),
    );

Future<void> tapMath(WidgetTester tester, String label) async {
  await tester.tap(mathText(label));
  await tester.pumpAndSettle();
}

/// A word-tile [Text] scoped to the message area (never matches a key label).
Finder messageTile(String label) => find.descendant(
      of: find.byType(MessageBlocks),
      matching: find.text(label),
    );
