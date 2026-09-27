import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/l10n/app_localizations_en.dart';
import 'package:handy_speak/widgets/keyboard_view.dart';

import '../support/app_harness.dart';

// Typing speech feedback (docs/testing-strategy.md §4 — Behavior tier): the
// logoped-requested Accessibility toggles end to end, through the real widget
// tree and the channel-level FakeTts. Unit-tier policy coverage lives in
// test/unit/state/speech_feedback_test.dart; this file proves the wiring —
// key taps really emit composer events, the coordinator really reaches the
// engine, and the settings toggles really persist and gate it all.
//
// Seeding mirrors the exact storage keys SettingsController writes
// ('speak_letters', 'speak_words', 'speak_symbols', 'speak_phrases').
void main() {
  final en = AppLocalizationsEn();

  testWidgets('all toggles default OFF: typing speaks nothing', (tester) async {
    final app = await pumpApp(tester);

    await tapKey(tester, 'a');
    await tapKey(tester, '1');
    await tapKey(tester, en.keySpace);

    expect(app.tts.spokenTexts, isEmpty);
  });

  testWidgets('speak_letters: letters and digits echo, terminators stay silent',
      (tester) async {
    final app = await pumpApp(tester, prefs: {'speak_letters': true});

    await tapKey(tester, 'a');
    await tapKey(tester, '1');
    expect(app.tts.spokenTexts, ['a', '1']);

    // Space and backspace never echo.
    await tapKey(tester, en.keySpace);
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pumpAndSettle();
    expect(app.tts.spokenTexts, ['a', '1']);
  });

  testWidgets('speak_words: space and punctuation keys speak the finished word',
      (tester) async {
    final app = await pumpApp(tester, prefs: {'speak_words': true});

    await tapKey(tester, 'h');
    await tapKey(tester, 'i');
    await tapKey(tester, en.keySpace);
    await tapKey(tester, 'o');
    await tapKey(tester, 'k');
    await tapKey(tester, '.');

    expect(app.tts.spokenTexts, ['hi', 'ok']);
  });

  testWidgets('letters + words: a terminator produces exactly one utterance',
      (tester) async {
    final app =
        await pumpApp(tester, prefs: {'speak_letters': true, 'speak_words': true});

    await tapKey(tester, 'a');
    await tapKey(tester, 'h');
    await tapKey(tester, en.keySpace);

    expect(app.tts.spokenTexts, ['a', 'h', 'ah']);
  });

  testWidgets('speak_symbols: a pictogram tap speaks its word', (tester) async {
    final app = await pumpApp(tester, prefs: {'speak_symbols': true});
    await enterSymbols(tester, en.modeSymbols);

    // Default category is "Feelings" (kSymbolCategories.first).
    await tapPictogram(tester, 'happy');

    expect(app.tts.spokenTexts, ['happy']);
  });

  testWidgets('speak_symbols stays gated when only speak_words is on',
      (tester) async {
    final app = await pumpApp(tester, prefs: {'speak_words': true});
    await enterSymbols(tester, en.modeSymbols);

    await tapPictogram(tester, 'happy');

    expect(app.tts.spokenTexts, isEmpty);
  });

  testWidgets('speak_phrases: a phrase chip speaks the whole phrase',
      (tester) async {
    final app = await pumpApp(tester, prefs: {'speak_phrases': true});

    await tester.tap(find.text('I need help'));
    await tester.pumpAndSettle();

    expect(app.tts.spokenTexts, ['I need help']);
  });

  testWidgets('math board: digits echo and an op speaks the completed number',
      (tester) async {
    final app = await pumpApp(
      tester,
      prefs: {'speak_letters': true, 'speak_words': true},
    );
    await tester.tap(find.text(en.modeMath));
    await tester.pumpAndSettle();

    await tapMathKey(tester, '2');
    await tapMathKey(tester, '2');
    expect(app.tts.spokenTexts, ['2', '2']);

    await tapMathKey(tester, '+');
    expect(app.tts.spokenTexts, ['2', '2', '22']);
  });

  testWidgets('toggling the switches in Settings gates feedback live',
      (tester) async {
    final app = await pumpApp(tester);

    await openSettings(tester);
    await tapToggle(tester, 'accessibility', en.settingsSpeakLettersName);
    await tapToggle(tester, 'accessibility', en.settingsSpeakWordsName);
    await closeSettings(tester);

    // Persisted under the keys SettingsController owns.
    expect(app.storage.getBool('speak_letters', fallback: false), isTrue);
    expect(app.storage.getBool('speak_words', fallback: false), isTrue);

    await tapKey(tester, 'a');
    await tapKey(tester, 'h');
    await tapKey(tester, en.keySpace);
    expect(app.tts.spokenTexts, ['a', 'h', 'ah']);
  });

  testWidgets('the four speech rows sit in the Accessibility pane',
      (tester) async {
    await pumpApp(tester);
    await openSettings(tester);
    await openCategory(tester, 'accessibility');

    for (final label in [
      en.settingsSpeakLettersName,
      en.settingsSpeakWordsName,
      en.settingsSpeakSymbolsName,
      en.settingsSpeakPhrasesName,
    ]) {
      await tester.scrollUntilVisible(
        find.text(label),
        100,
        scrollable: settingsScrollable(),
      );
      await tester.pumpAndSettle();
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text(en.settingsSpeechFeedback), findsOneWidget);
  });
}

// --- Tap helpers (shared idioms, kept local per the suite convention) --------

Finder keyboardText(String label) => find.descendant(
      of: find.byType(KeyboardView),
      matching: find.text(label),
    );

Future<void> tapKey(WidgetTester tester, String label) async {
  await tester.tap(keyboardText(label));
  await tester.pumpAndSettle();
}

Future<void> tapMathKey(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> enterSymbols(WidgetTester tester, String symbolsLabel) async {
  await tester.tap(find.text(symbolsLabel));
  await tester.pumpAndSettle();
}

Future<void> tapPictogram(WidgetTester tester, String word) async {
  await tester.tap(find.descendant(
    of: find.byType(GridView),
    matching: find.text(word),
  ));
  await tester.pumpAndSettle();
}

// --- Settings-dialog helpers (same shapes as keyboard_input_test) -----------

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
}

Future<void> closeSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.close).first);
  await tester.pumpAndSettle();
}

Future<void> openCategory(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(ValueKey('settingsCategory_$name')));
  await tester.pumpAndSettle();
}

Finder settingsScrollable() => find.descendant(
      of: find.byKey(const ValueKey('settingsPaneScrollable')),
      matching: find.byType(Scrollable),
    );

Finder toggleSwitch(String name) => find.descendant(
      of: find.ancestor(of: find.text(name), matching: find.byType(Row)).first,
      matching: find.byType(Switch),
    );

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
