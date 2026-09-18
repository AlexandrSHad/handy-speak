import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/l10n/app_localizations_cs.dart';
import 'package:handy_speak/l10n/app_localizations_en.dart';
import 'package:handy_speak/state/composer_controller.dart';
import 'package:handy_speak/widgets/message_blocks.dart';

import '../support/app_harness.dart';

// Symbols & pictograms feature (docs/testing-strategy.md §4 "Symbols &
// pictograms").
//
// Tapping a pictogram appends its language-resolved word to the shared message
// buffer as an editable tile. Net-new behaviour, driven against the real
// SymbolBoard: a category rail (kSymbolCategories) plus a pictogram grid
// (kPictograms) whose tiles show the emoji and the active-language word.
void main() {
  final en = AppLocalizationsEn();
  final cs = AppLocalizationsCs();

  group('Pictogram tap appends its word', () {
    testWidgets('EN: tapping pictograms appends their words to the message',
        (tester) async {
      await pumpApp(tester);
      await enterSymbols(tester, en.modeSymbols);

      // Default category is "Feelings" (kSymbolCategories.first).
      await tapPictogram(tester, 'happy');
      await tapPictogram(tester, 'sad');

      final composer = readProvider<ComposerController>(tester);
      expect(composer.tokens, ['happy', 'sad']);
      expect(messageTile('happy'), findsOneWidget);
      expect(messageTile('sad'), findsOneWidget);
      // Symbols mode leaves every word a settled, removable tile.
      expect(composer.activeIndex, -1);
      expect(find.text(en.wordCount(2)), findsOneWidget);
    });

    testWidgets('appends the word resolved for the active language (CS)',
        (tester) async {
      // Single-language cs install: the board resolves pictogram words to cs.
      await pumpApp(tester, prefs: {'main_lang': 'cs'});
      await enterSymbols(tester, cs.modeSymbols);

      // "happy" in the default Feelings category resolves to "šťastný".
      await tapPictogram(tester, 'šťastný');

      expect(readProvider<ComposerController>(tester).tokens, ['šťastný']);
      expect(messageTile('šťastný'), findsOneWidget);
    });

    testWidgets('selecting another category switches its pictogram set',
        (tester) async {
      await pumpApp(tester);
      await enterSymbols(tester, en.modeSymbols);

      // Rail label casing (Title-case) never collides with a pictogram word.
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();

      await tapPictogram(tester, 'apple');
      expect(readProvider<ComposerController>(tester).tokens, ['apple']);
      expect(messageTile('apple'), findsOneWidget);
    });
  });
}

// --- Symbol-board helpers --------------------------------------------------

/// Switch to the Symbols board via its mode pill.
Future<void> enterSymbols(WidgetTester tester, String symbolsLabel) async {
  await tester.tap(find.text(symbolsLabel));
  await tester.pumpAndSettle();
}

/// A pictogram-tile [Text] scoped to the grid (never a message-bar tile).
Finder gridWord(String word) => find.descendant(
      of: find.byType(GridView),
      matching: find.text(word),
    );

Future<void> tapPictogram(WidgetTester tester, String word) async {
  await tester.tap(gridWord(word));
  await tester.pumpAndSettle();
}

/// A word-tile [Text] scoped to the message area (never matches a grid tile).
Finder messageTile(String word) => find.descendant(
      of: find.byType(MessageBlocks),
      matching: find.text(word),
    );
