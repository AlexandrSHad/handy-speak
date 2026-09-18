import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/core/app_language.dart';
import 'package:handy_speak/l10n/app_localizations_en.dart';
import 'package:handy_speak/state/composer_controller.dart';
import 'package:handy_speak/state/phrases_controller.dart';
import 'package:handy_speak/widgets/keyboard_view.dart';
import 'package:handy_speak/widgets/phrase_strip.dart';

import '../support/app_harness.dart';

/// Saved-phrases behaviour: the optional "My phrases" strip (show/hide via the
/// Settings toggle, editing while hidden, pinned-first order) and loading a
/// phrase into the message. Migrated from the ADDENDUM-01 "Optional phrase
/// strip" group, plus the net-new load-into-message behaviour (strategy §4
/// "Saved phrases · Behavior").
void main() {
  final en = AppLocalizationsEn();

  group('Phrase strip', () {
    testWidgets('toggle OFF removes the strip and grows keys and symbol tiles',
        (tester) async {
      await pumpApp(tester);
      expect(find.byType(PhraseStrip), findsOneWidget);
      final keyBefore = tester.getSize(keyMaterial('q')).height;

      await tester.tap(find.text(en.modeSymbols));
      await tester.pumpAndSettle();
      final tileBefore = tester.getSize(firstSymbolTile()).height;

      await openSettings(tester);
      await tapToggle(tester, 'phrases', en.settingsShowPhrasesName);
      // The "hidden" note shows under the toggle while OFF.
      expect(find.text(en.settingsPhrasesHiddenNote), findsOneWidget);
      await closeSettings(tester, en.closeLabel);

      expect(find.byType(PhraseStrip), findsNothing);
      final tileAfter = tester.getSize(firstSymbolTile()).height;
      expect(tileAfter, greaterThan(tileBefore));

      await tester.tap(find.text(en.modeKeyboard));
      await tester.pumpAndSettle();
      final keyAfter = tester.getSize(keyMaterial('q')).height;
      expect(keyAfter, greaterThan(keyBefore));
    });

    testWidgets('phrase editor in settings still works while hidden',
        (tester) async {
      await pumpApp(tester, prefs: {'show_phrases': false});
      expect(find.byType(PhraseStrip), findsNothing);

      await openSettings(tester);
      await openCategory(tester, 'phrases');
      // The add row is pinned to the pane bottom, outside the scroll view —
      // always on screen, whatever the phrase list does (ADDENDUM-05).
      await tester.enterText(find.byType(TextField), 'Good morning');
      await tester.tap(find.text(en.settingsAdd));
      await tester.pumpAndSettle();

      expect(find.text('Good morning'), findsOneWidget); // listed in the pane
      final phrases =
          readProvider<PhrasesController>(tester).phrasesFor(AppLanguage.en);
      expect(phrases.map((p) => p.text), contains('Good morning'));
    });

    testWidgets('toggle back ON restores phrases and pin order',
        (tester) async {
      await pumpApp(tester, prefs: {'show_phrases': false});
      expect(find.byType(PhraseStrip), findsNothing);

      await openSettings(tester);
      await tapToggle(tester, 'phrases', en.settingsShowPhrasesName);
      await closeSettings(tester, en.closeLabel);

      expect(find.byType(PhraseStrip), findsOneWidget);
      // Pinned-first order intact: "I need help" (pinned, 42 uses) leads
      // "Bathroom please" (pinned, 31 uses).
      final helpDx = tester.getTopLeft(find.text('I need help')).dx;
      final bathroomDx = tester.getTopLeft(find.text('Bathroom please')).dx;
      expect(helpDx, lessThan(bathroomDx));
      expect(
        find.descendant(
          of: find.byType(PhraseStrip),
          matching: find.byIcon(Icons.push_pin),
        ),
        findsWidgets,
      );
    });
  });

  group('Loading a phrase', () {
    testWidgets('tapping a phrase chip loads it into the message',
        (tester) async {
      await pumpApp(tester);
      expect(readProvider<ComposerController>(tester).text, isEmpty);

      // Tap the leading pinned chip. Scoped to the strip so the pane copy in
      // any other surface can never be tapped by mistake.
      await tester.tap(find.descendant(
        of: find.byType(PhraseStrip),
        matching: find.text('I need help'),
      ));
      await tester.pumpAndSettle();

      // The stored casing is loaded verbatim into the active buffer.
      expect(readProvider<ComposerController>(tester).text, 'I need help');
    });
  });
}

// ---------------------------------------------------------------------------
// Finder helpers (ported from the ADDENDUM-01/05 suites)
// ---------------------------------------------------------------------------

/// A [Text] scoped to the keyboard, so word tiles in the message bar showing
/// the same string can never be matched by mistake.
Finder keyboardText(String label) => find.descendant(
      of: find.byType(KeyboardView),
      matching: find.text(label),
    );

/// The tappable key surface ([Material]) behind a key label.
Finder keyMaterial(String label) => find
    .ancestor(of: keyboardText(label), matching: find.byType(Material))
    .first;

/// First pictogram tile surface in the symbol grid.
Finder firstSymbolTile() => find
    .descendant(of: find.byType(GridView), matching: find.byType(InkWell))
    .first;

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
}

/// Closes the dialog via the pane header's X, found by its tooltip: the phrase
/// rows reuse `Icons.close` for delete, so the icon alone is ambiguous.
Future<void> closeSettings(WidgetTester tester, String closeLabel) async {
  await tester.tap(find.byTooltip(closeLabel));
  await tester.pumpAndSettle();
}

/// Opens a Settings category from the rail (`language`, `phrases`,
/// `accessibility`). The dialog always opens on Language and never remembers
/// the last category.
Future<void> openCategory(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(ValueKey('settingsCategory_$name')));
  await tester.pumpAndSettle();
}

/// The [Scrollable] inside the open category's pane.
Finder paneScrollable() => find.descendant(
      of: find.byKey(const ValueKey('settingsPaneScrollable')),
      matching: find.byType(Scrollable),
    );

/// The [Switch] sitting in the same toggle row as the [name] label.
Finder toggleSwitch(String name) => find.descendant(
      of: find.ancestor(of: find.text(name), matching: find.byType(Row)).first,
      matching: find.byType(Switch),
    );

/// Opens the [category] that owns the [name] toggle, scrolls its pane until the
/// row is visible, and flips its switch.
Future<void> tapToggle(
  WidgetTester tester,
  String category,
  String name,
) async {
  await openCategory(tester, category);
  await tester.scrollUntilVisible(
    find.text(name),
    100,
    scrollable: paneScrollable(),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(toggleSwitch(name));
  await tester.pumpAndSettle();
  await tester.tap(toggleSwitch(name));
  await tester.pumpAndSettle();
}
