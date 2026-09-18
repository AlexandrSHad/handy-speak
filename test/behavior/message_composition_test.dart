import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/l10n/app_localizations_en.dart';
import 'package:handy_speak/state/composer_controller.dart';
import 'package:handy_speak/widgets/keyboard_view.dart';
import 'package:handy_speak/widgets/math_board.dart';
import 'package:handy_speak/widgets/message_blocks.dart';

import '../support/app_harness.dart';

// Message composition feature (docs/testing-strategy.md §4 "Message
// composition").
//
// The shared sentence buffer and its word-tiles: typing a real sentence onto
// the board, seeing the message bar and its word count reflect it, editing a
// tile away, and the dual-buffer rule that keeps the math problem alive across
// a language switch while clearing the sentence. The "Workspaces" cases are
// ported from ADDENDUM-02; the sentence-editing cases are net-new behaviour.
void main() {
  final en = AppLocalizationsEn();

  group('Sentence editing', () {
    testWidgets('typing words fills the message bar and word count',
        (tester) async {
      await pumpApp(tester);

      // Placeholder shows until anything is typed: 0 words.
      expect(find.text(en.wordCount(0)), findsOneWidget);

      await typeWord(tester, 'i'); // taps 'i' + space
      await typeWord(tester, 'want'); // taps w·a·n·t + space

      final composer = readProvider<ComposerController>(tester);
      expect(composer.tokens, ['i', 'want']);
      expect(messageTile('i'), findsOneWidget);
      expect(messageTile('want'), findsOneWidget);
      // Trailing space → both are settled tiles, no in-progress word.
      expect(composer.activeIndex, -1);
      expect(find.text(en.wordCount(2)), findsOneWidget);
    });

    testWidgets('the in-progress word counts and renders with a caret',
        (tester) async {
      await pumpApp(tester);

      await tapKey(tester, 'h');
      await tapKey(tester, 'i'); // no trailing space → still being typed

      final composer = readProvider<ComposerController>(tester);
      expect(composer.tokens, ['hi']);
      expect(composer.activeIndex, 0); // active word, not a removable tile
      expect(messageTile('hi'), findsOneWidget);
      expect(find.text(en.wordCount(1)), findsOneWidget);
    });

    testWidgets('removing a word tile drops it from the message',
        (tester) async {
      await pumpApp(tester);

      await typeWord(tester, 'i');
      await typeWord(tester, 'want');
      expect(readProvider<ComposerController>(tester).tokens, ['i', 'want']);

      // Tap-to-select the tile, then tap its ✕ remove button.
      await tester.tap(messageTile('i'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(readProvider<ComposerController>(tester).tokens, ['want']);
      expect(messageTile('i'), findsNothing);
      expect(messageTile('want'), findsOneWidget);
      expect(find.text(en.wordCount(1)), findsOneWidget);
    });
  });

  group('Workspaces', () {
    testWidgets('Math→Keyboard→Math preserves both buffers', (tester) async {
      await pumpApp(tester);
      await enterMath(tester);
      await tapMath(tester, '7');

      await tester.tap(find.text(en.modeKeyboard));
      await tester.pumpAndSettle();
      await tapKey(tester, 'h');
      expect(readProvider<ComposerController>(tester).text, 'h');

      await tester.tap(find.text(en.modeMath));
      await tester.pumpAndSettle();
      expect(readProvider<ComposerController>(tester).text, '7');
    });

    testWidgets('EN⇄CS clears the sentence but preserves the math problem',
        (tester) async {
      // Two-language set (en main + cs second), starting on the en board.
      await pumpApp(tester, prefs: {
        'main_lang': 'en',
        'second_lang': 'cs',
      });
      await enterMath(tester);
      await tapMath(tester, '3');
      await tapMath(tester, '+');
      await tapMath(tester, '4');

      await tester.tap(find.text(en.modeKeyboard));
      await tester.pumpAndSettle();
      await tapKey(tester, 'h');
      await tapKey(tester, 'i');
      expect(readProvider<ComposerController>(tester).text, 'hi');

      // EN → CS: sentence cleared, math survives. Chrome (mode tabs, Speak
      // label) stays EN — it's pinned to main per ADR-0002.
      await tester.tap(find.text('CZ'));
      await tester.pumpAndSettle();
      expect(readProvider<ComposerController>(tester).text, '');

      await tester.tap(find.text(en.modeMath));
      await tester.pumpAndSettle();
      expect(readProvider<ComposerController>(tester).text.trim(), '3 + 4');

      // CS → EN: still survives.
      await tester.tap(find.text('EN'));
      await tester.pumpAndSettle();
      expect(readProvider<ComposerController>(tester).text.trim(), '3 + 4');
    });
  });
}

// --- Keyboard helpers ------------------------------------------------------

/// A [Text] scoped to the keyboard.
Finder keyboardText(String label) => find.descendant(
      of: find.byType(KeyboardView),
      matching: find.text(label),
    );

Future<void> tapKey(WidgetTester tester, String label) async {
  await tester.tap(keyboardText(label));
  await tester.pumpAndSettle();
}

/// Types a word by tapping its (displayed) key labels, then space.
Future<void> typeWord(WidgetTester tester, String labels) async {
  for (final ch in labels.split('')) {
    await tapKey(tester, ch);
  }
  await tapKey(tester, AppLocalizationsEn().keySpace);
}

// --- Math helpers ----------------------------------------------------------

/// Switch to the Math board (taps the pill by icon — locale-independent).
Future<void> enterMath(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.calculate_outlined));
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

// --- Message-bar helpers ---------------------------------------------------

/// A word-tile [Text] scoped to the message area (never matches a key label).
Finder messageTile(String label) => find.descendant(
      of: find.byType(MessageBlocks),
      matching: find.text(label),
    );
