import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/l10n/app_localizations_en.dart';
import 'package:handy_speak/state/composer_controller.dart';
import 'package:handy_speak/state/settings_controller.dart';
import 'package:handy_speak/widgets/keyboard_view.dart';

import '../support/app_harness.dart';

// Keyboard input feature (docs/testing-strategy.md §4 "Keyboard input").
//
// Tapping the per-language key layouts inserts the right glyph into the
// sentence buffer, and the Big-letters mode changes only what is displayed —
// never the stored/spoken text. Ported from the ADDENDUM-01 "Big letters",
// ADDENDUM-02 "Czech inline numbers" and ADDENDUM-03 "Ukrainian keyboard"
// suites onto the shared headless harness.
void main() {
  final en = AppLocalizationsEn();

  group('Big letters', () {
    testWidgets('defaults OFF: key labels render lowercase', (tester) async {
      await pumpApp(tester);

      expect(keyboardText('q'), findsOneWidget);
      expect(keyboardText('Q'), findsNothing);
      expect(find.text(en.composePlaceholder), findsOneWidget);
    });

    testWidgets(
        'toggle ON via settings uppercases content surfaces but not chrome',
        (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      // The Big letters row must be the FIRST toggle in the Accessibility
      // category: the pane title above it, the haptics row below it.
      await openCategory(tester, 'accessibility');
      await tester.scrollUntilVisible(
        find.text(en.settingsHapticName),
        100,
        scrollable: settingsScrollable(),
      );
      await tester.pumpAndSettle();
      // The category name renders twice — once in the rail, once as the pane
      // header title. The rail comes first in the Row, so `.last` is the
      // header, which is the one this ordering is about.
      final titleDy =
          tester.getTopLeft(find.text(en.settingsAccessibility).last).dy;
      final bigDy = tester.getTopLeft(find.text(en.settingsBigLettersName)).dy;
      final hapticDy = tester.getTopLeft(find.text(en.settingsHapticName)).dy;
      expect(titleDy, lessThan(bigDy));
      expect(bigDy, lessThan(hapticDy));

      await tapToggle(tester, 'accessibility', en.settingsBigLettersName);
      await closeSettings(tester);

      // Content surfaces uppercase…
      expect(keyboardText('Q'), findsOneWidget);
      expect(keyboardText('q'), findsNothing);
      expect(find.text('I NEED HELP'), findsOneWidget); // phrase chip
      expect(find.text('I need help'), findsNothing);
      expect(find.text(en.composePlaceholder.toUpperCase()), findsOneWidget);

      // …UI chrome does not.
      expect(find.text(en.speak), findsOneWidget); // Speak button
      expect(find.text(en.speak.toUpperCase()), findsNothing);
      expect(keyboardText(en.keySpace), findsOneWidget); // space key label
      expect(keyboardText(en.keySpace.toUpperCase()), findsNothing);
    });

    testWidgets('typed text displays uppercase but is stored lowercase',
        (tester) async {
      await pumpApp(tester, prefs: {'big_letters': true});

      await typeWord(tester, 'WANT'); // taps W·A·N·T + space

      expect(find.text('WANT'), findsOneWidget); // word tile
      expect(find.text('want'), findsNothing);
      expect(readProvider<ComposerController>(tester).tokens, ['want']);
    });

    testWidgets('TTS receives the stored (lowercase) text', (tester) async {
      final app = await pumpApp(tester, prefs: {'big_letters': true});

      await typeWord(tester, 'WANT');
      await tester.tap(find.text(en.speak));
      await tester.pumpAndSettle();

      expect(app.tts.spokenTexts, isNotEmpty);
      expect(app.tts.spokenTexts.last, contains('want'));
      expect(app.tts.spokenTexts.last, isNot(contains('WANT')));
    });

    testWidgets('shift key is dimmed and inert while ON', (tester) async {
      await pumpApp(tester, prefs: {'big_letters': true});

      final shiftIcon = find.byIcon(Icons.arrow_upward_rounded);
      final opacity = tester.widget<Opacity>(
        find.ancestor(of: shiftIcon, matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, 0.35);
      final inkWell = tester.widget<InkWell>(
        find.ancestor(of: shiftIcon, matching: find.byType(InkWell)).first,
      );
      expect(inkWell.onTap, isNull);

      // Tapping shift then a letter still inserts lowercase.
      await tester.tap(shiftIcon, warnIfMissed: false);
      await tester.pumpAndSettle();
      await tapKey(tester, 'Q');
      expect(readProvider<ComposerController>(tester).text, 'q');
    });

    testWidgets('shift works normally while OFF (and auto-resets)',
        (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();
      expect(keyboardText('Q'), findsOneWidget); // labels follow shift

      await tapKey(tester, 'Q');
      expect(readProvider<ComposerController>(tester).text, 'Q');

      // Shift auto-resets after one keypress.
      expect(keyboardText('q'), findsOneWidget);
      expect(keyboardText('W'), findsNothing);
    });

    testWidgets('toggle OFF restores normal casing with the message intact',
        (tester) async {
      await pumpApp(tester, prefs: {'big_letters': true});

      await typeWord(tester, 'WANT');
      expect(find.text('WANT'), findsOneWidget);

      await openSettings(tester);
      await tapToggle(tester, 'accessibility', en.settingsBigLettersName);
      await closeSettings(tester);

      expect(find.text('want'), findsOneWidget); // tile reverts instantly
      expect(find.text('WANT'), findsNothing);
      expect(readProvider<ComposerController>(tester).tokens, ['want']);
    });

    testWidgets(
        'mode survives the EN→CS switch; Czech accents display uppercase, '
        'insert lowercase', (tester) async {
      // Two-language set (en main + cs second) — the CZ pill only exists
      // with a second language configured (ADDENDUM-04).
      await pumpApp(tester, prefs: {
        'big_letters': true,
        'main_lang': 'en',
        'second_lang': 'cs',
      });

      // Switching language clears the message by design (§6.1.1).
      await tester.tap(find.text('CZ'));
      await tester.pumpAndSettle();

      expect(readProvider<SettingsController>(tester).bigLetters, isTrue);
      expect(keyboardText('Á'), findsOneWidget); // accent row, uppercased
      expect(keyboardText('á'), findsNothing);

      await tapKey(tester, 'Á');
      expect(readProvider<ComposerController>(tester).text, 'á');
    });
  });

  group('Czech inline numbers', () {
    testWidgets('English has no 123 key; Czech does', (tester) async {
      await pumpApp(tester);
      expect(keyboardText('123'), findsNothing);
      expect(keyboardText('ABC'), findsNothing);

      await pumpApp(tester, prefs: {'main_lang': 'cs'});
      expect(keyboardText('123'), findsOneWidget);
    });

    testWidgets('tapping 123 swaps the diacritics row to digits in place',
        (tester) async {
      await pumpApp(tester, prefs: {'main_lang': 'cs'});
      expect(keyboardText('á'), findsOneWidget); // diacritics row visible
      expect(keyboardText('1'), findsNothing);

      await tester.tap(keyboardText('123'));
      await tester.pumpAndSettle();

      // Label flipped; diacritics gone; digits revealed (teal-tinted).
      expect(keyboardText('ABC'), findsOneWidget);
      expect(keyboardText('á'), findsNothing);
      expect(keyboardText('1'), findsOneWidget);
      expect(keyboardText('0'), findsOneWidget);

      // Typing a digit writes to the sentence buffer like any letter.
      await tester.tap(keyboardText('2'));
      await tester.pumpAndSettle();
      expect(readProvider<ComposerController>(tester).tokens, ['2']);
    });
  });

  group('Ukrainian keyboard', () {
    testWidgets(
        'uk keyboard renders a permanent digit row and ЙЦУКЕН rows, no 123 key',
        (tester) async {
      await pumpApp(tester, prefs: {
        'main_lang': 'en',
        'second_lang': 'uk',
        'active_lang': 'uk',
      });

      // Permanent digit row (uk has one, unlike Czech) — never a 123 toggle.
      expect(keyboardText('1'), findsOneWidget);
      expect(keyboardText('0'), findsOneWidget);
      expect(keyboardText('123'), findsNothing);
      expect(keyboardText('ABC'), findsNothing);

      // Row 2 (ЙЦУКЕН) ends with ї, row 3 with ґ; row 4 ends with the
      // apostrophe key.
      expect(keyboardText('й'), findsOneWidget);
      expect(keyboardText('ї'), findsOneWidget);
      expect(keyboardText('ґ'), findsOneWidget);
      expect(keyboardText('ʼ'), findsOneWidget); // U+02BC
    });

    testWidgets('apostrophe key inserts U+02BC and the word stays one tile',
        (tester) async {
      await pumpApp(tester, prefs: {
        'main_lang': 'en',
        'second_lang': 'uk',
        'active_lang': 'uk',
      });

      // Types "мʼяч" (ball) without ever touching space.
      await tapKey(tester, 'м');
      await tapKey(tester, 'ʼ');
      await tapKey(tester, 'я');
      await tapKey(tester, 'ч');

      expect(readProvider<ComposerController>(tester).tokens, ['мʼяч']);
    });

    testWidgets('big letters uppercases Cyrillic (ґ→Ґ, є→Є, і→І, ї→Ї)',
        (tester) async {
      await pumpApp(tester, prefs: {
        'main_lang': 'en',
        'second_lang': 'uk',
        'active_lang': 'uk',
        'big_letters': true,
      });

      expect(keyboardText('Ґ'), findsOneWidget);
      expect(keyboardText('Є'), findsOneWidget);
      expect(keyboardText('І'), findsOneWidget);
      expect(keyboardText('Ї'), findsOneWidget);
      // Lowercase forms must be gone — big letters, not both cases shown.
      expect(keyboardText('ґ'), findsNothing);
    });
  });
}

// --- Keyboard helpers ------------------------------------------------------

/// A [Text] scoped to the keyboard, so word tiles in the message bar showing
/// the same string can never be matched (or tapped) by mistake.
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

// --- Settings-dialog helpers -----------------------------------------------

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
}

Future<void> closeSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.close).first);
  await tester.pumpAndSettle();
}

/// Opens a Settings category from the rail (`language`, `phrases`,
/// `accessibility`).
Future<void> openCategory(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(ValueKey('settingsCategory_$name')));
  await tester.pumpAndSettle();
}

/// The [Scrollable] inside the open category's pane.
Finder settingsScrollable() => find.descendant(
      of: find.byKey(const ValueKey('settingsPaneScrollable')),
      matching: find.byType(Scrollable),
    );

/// The [Switch] sitting in the same toggle row as the [name] label.
Finder toggleSwitch(String name) => find.descendant(
      of: find.ancestor(of: find.text(name), matching: find.byType(Row)).first,
      matching: find.byType(Switch),
    );

/// Opens the [category] that owns the [name] toggle, scrolls its pane until
/// the row is visible, and flips its switch.
Future<void> tapToggle(
  WidgetTester tester,
  String category,
  String name,
) async {
  await openCategory(tester, category);
  await tester.scrollUntilVisible(
    find.text(name),
    100,
    scrollable: settingsScrollable(),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(toggleSwitch(name));
  await tester.pumpAndSettle();
  await tester.tap(toggleSwitch(name));
  await tester.pumpAndSettle();
}
