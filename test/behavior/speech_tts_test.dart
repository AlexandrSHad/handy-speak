import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/core/app_language.dart';
import 'package:handy_speak/l10n/app_localizations_en.dart';
import 'package:handy_speak/widgets/keyboard_view.dart';

import '../support/app_harness.dart';

/// Speech / TTS behaviour: the per-language voice-pack warning shown in
/// Settings, and the Speak button's enabled/disabled gating on speech status
/// and message text. Migrated from the ADDENDUM-03 "Per-language voice-pack
/// warning" group, plus the net-new speak-button gating (strategy §4
/// "Speech/TTS · Behavior").
void main() {
  final en = AppLocalizationsEn();

  group('Per-language voice-pack warning', () {
    testWidgets(
        'warns for a pair slot with no matching installed voice, silent for '
        'the other', (tester) async {
      // Default fake voice list only has en-US/cs-CZ installed.
      await pumpApp(tester, prefs: {
        'main_lang': 'en',
        'second_lang': 'uk',
      }); // set: en, uk
      await openSettings(tester);
      await tester.pumpAndSettle();

      expect(find.text(en.voiceMissingNamed(AppLanguage.uk.nativeName)),
          findsOneWidget);
      expect(find.text(en.voiceMissingNamed(AppLanguage.en.nativeName)),
          findsNothing);
    });

    testWidgets('no warning when every pair slot has a matching voice',
        (tester) async {
      await pumpApp(tester); // set: en only — main voice installed
      await openSettings(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('voice on this tablet yet'), findsNothing);
    });

    testWidgets('manual refresh re-checks and clears a stale warning',
        (tester) async {
      final app = await pumpApp(tester, prefs: {
        'main_lang': 'en',
        'second_lang': 'uk',
      });
      await openSettings(tester);
      await tester.pumpAndSettle();
      expect(find.text(en.voiceMissingNamed(AppLanguage.uk.nativeName)),
          findsOneWidget);

      // A uk voice pack just got installed — update the fake and refresh.
      app.tts.voices = [_voice('en-US'), _voice('cs-CZ'), _voice('uk-UA')];
      await tester.tap(find.byTooltip(en.settingsRefreshVoices));
      await tester.pumpAndSettle();

      expect(find.text(en.voiceMissingNamed(AppLanguage.uk.nativeName)),
          findsNothing);
    });
  });

  group('Speak button gating', () {
    testWidgets('a ready engine with no message keeps the button disabled',
        (tester) async {
      await pumpApp(tester);

      // Status is ready (the fake engine binds), but the buffer is empty.
      expect(find.text(en.speak), findsOneWidget); // ready label, not spinner
      expect(speakButton(tester).onPressed, isNull);
    });

    testWidgets('typing a message enables the button', (tester) async {
      await pumpApp(tester);
      expect(speakButton(tester).onPressed, isNull);

      await typeWord(tester, 'hi'); // taps h·i + space

      expect(speakButton(tester).onPressed, isNotNull);
      expect(find.text(en.speak), findsOneWidget);
    });

    testWidgets('the enabled button speaks the composed message', (tester) async {
      final app = await pumpApp(tester);

      await typeWord(tester, 'hi');
      await tester.tap(find.text(en.speak));
      await tester.pumpAndSettle();

      expect(app.tts.spokenTexts, isNotEmpty);
      expect(app.tts.spokenTexts.last, contains('hi'));
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, String> _voice(String locale) => {'name': locale, 'locale': locale};

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
}

/// The Speak button widget, resolved through its label so its `onPressed`
/// (null when disabled) can be inspected directly.
FilledButton speakButton(WidgetTester tester) => tester.widget<FilledButton>(
      find
          .ancestor(
            of: find.text(AppLocalizationsEn().speak),
            matching: find.byType(FilledButton),
          )
          .first,
    );

/// A [Text] scoped to the keyboard.
Finder keyboardText(String label) => find.descendant(
      of: find.byType(KeyboardView),
      matching: find.text(label),
    );

Future<void> tapKey(WidgetTester tester, String label) async {
  await tester.tap(keyboardText(label));
  await tester.pumpAndSettle();
}

/// Types a word by tapping its key labels, then space.
Future<void> typeWord(WidgetTester tester, String labels) async {
  for (final ch in labels.split('')) {
    await tapKey(tester, ch);
  }
  await tapKey(tester, AppLocalizationsEn().keySpace);
}
