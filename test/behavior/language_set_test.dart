import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/core/app_language.dart';
import 'package:handy_speak/l10n/app_localizations_cs.dart';
import 'package:handy_speak/l10n/app_localizations_en.dart';
import 'package:handy_speak/l10n/app_localizations_uk.dart';
import 'package:handy_speak/services/speech_service.dart';
import 'package:handy_speak/services/storage_service.dart';
import 'package:handy_speak/state/composer_controller.dart';
import 'package:handy_speak/state/language_controller.dart';
import 'package:handy_speak/widgets/keyboard_view.dart';
import 'package:handy_speak/widgets/top_bar.dart';

import '../support/app_harness.dart';

/// Language set & localization behaviour: the Ukrainian UI chrome, the
/// main/second language pair in the top bar, the Settings language pickers,
/// first-run device-language seeding, the second-language Switch, the ADR-0002
/// UI-locale pin, the dropdown field, and persistence. Migrated from the
/// ADDENDUM-03 (Ukrainian chrome / language pair / pickers) and ADDENDUM-04
/// (all groups) suites.
void main() {
  final en = AppLocalizationsEn();
  final cs = AppLocalizationsCs();
  final uk = AppLocalizationsUk();

  group('Ukrainian UI chrome', () {
    testWidgets(
        'with uk main, ARB-driven UI strings render Ukrainian, not English',
        (tester) async {
      // ADR-0002: chrome follows the MAIN language, so uk must be seeded as
      // main (a uk *active* language no longer moves chrome). `uk` must be
      // registered in MaterialApp.supportedLocales, or Flutter's locale
      // resolution silently falls back to the first supported locale (en) for
      // every AppLocalizations string.
      await pumpApp(tester, prefs: {'main_lang': 'uk'});

      expect(find.text(uk.settings), findsNothing); // gear icon, not open yet
      expect(find.text(uk.modeMath), findsOneWidget);
      expect(find.text(en.modeMath), findsNothing);

      await openSettings(tester);
      expect(find.text(uk.settings), findsOneWidget);
      expect(find.text(en.settings), findsNothing);
    });
  });

  group('Language pair (top bar)', () {
    testWidgets('a two-language set shows exactly its two pills, never a third',
        (tester) async {
      await pumpApp(tester, prefs: {
        'main_lang': 'en',
        'second_lang': 'cs',
      });

      expect(topBarPillText('EN'), findsOneWidget);
      expect(topBarPillText('CZ'), findsOneWidget);
      expect(topBarPillText('UK'), findsNothing);
    });

    testWidgets('a set including uk shows exactly those two pills',
        (tester) async {
      await pumpApp(tester, prefs: {
        'main_lang': 'en',
        'second_lang': 'uk',
      });

      expect(topBarPillText('EN'), findsOneWidget);
      expect(topBarPillText('UK'), findsOneWidget);
      expect(topBarPillText('CZ'), findsNothing);
    });
  });

  group('Settings language pickers', () {
    testWidgets('main dropdown offers all 3 languages; second excludes main',
        (tester) async {
      await pumpApp(tester, prefs: {
        'main_lang': 'en',
        'second_lang': 'cs',
      });
      await openSettings(tester);

      expect(find.text(en.settingsMainLangName), findsOneWidget);
      expect(find.text(en.settingsSecondLangName), findsOneWidget);

      // Main slot: every supported language is offered. (The currently
      // selected item renders twice — closed field + open menu — so
      // presence, not count.)
      await tester
          .tap(find.byKey(const ValueKey('settingsLangDropdown_main')));
      await tester.pumpAndSettle();
      for (final l in AppLanguage.values) {
        expect(find.byKey(ValueKey('settingsLangItem_main_${l.name}')),
            findsWidgets);
      }
      // Tap outside the menu to close it without changing anything. Only the
      // MENU closes: its full-screen barrier sits above the dialog. The point
      // is kept INSIDE the dialog frame on pane-header whitespace.
      await tester.tapAt(const Offset(900, 120));
      await tester.pumpAndSettle();

      // Second slot: the main language is never offered (Q12).
      await tester
          .tap(find.byKey(const ValueKey('settingsLangDropdown_second')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settingsLangItem_second_cs')),
          findsWidgets);
      expect(find.byKey(const ValueKey('settingsLangItem_second_uk')),
          findsWidgets);
      expect(find.byKey(const ValueKey('settingsLangItem_second_en')),
          findsNothing);
    });

    testWidgets(
        'picking the current second language as main swaps the set (Q12)',
        (tester) async {
      await pumpApp(tester, prefs: {
        'main_lang': 'en',
        'second_lang': 'cs',
      }); // main=en, second=cs
      await openSettings(tester);

      // Main dropdown's "Čeština" row (the second slot's language) — swaps.
      await tester
          .tap(find.byKey(const ValueKey('settingsLangDropdown_main')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('settingsLangItem_main_cs')));
      await tester.pumpAndSettle();

      // Set swapped: main=cs, second=en. Verify via the top-bar pills.
      expect(topBarPillText('CZ'), findsOneWidget);
      expect(topBarPillText('EN'), findsOneWidget);
      expect(topBarPillText('UK'), findsNothing);
    });

    testWidgets('picking a non-conflicting language as main works',
        (tester) async {
      await pumpApp(tester, prefs: {
        'main_lang': 'en',
        'second_lang': 'cs',
      }); // main=en, second=cs
      await openSettings(tester);

      await tester
          .tap(find.byKey(const ValueKey('settingsLangDropdown_main')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('settingsLangItem_main_uk')));
      await tester.pumpAndSettle();

      expect(topBarPillText('UK'), findsOneWidget);
      expect(topBarPillText('CZ'), findsOneWidget);
      expect(topBarPillText('EN'), findsNothing);
    });

    testWidgets('close button has an accessible tooltip label',
        (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      expect(find.byTooltip(en.closeLabel), findsOneWidget);
    });
  });

  group('First run / device-language seeding', () {
    testWidgets(
        'device cs first run: Czech chrome, single language, hidden toggle',
        (tester) async {
      await pumpApp(tester, deviceLocale: const Locale('cs'));

      // Chrome follows main (cs) — ADR-0002.
      expect(find.text(cs.modeMath), findsOneWidget);
      expect(find.text(en.modeMath), findsNothing);

      // Single language: no toggle pills at all (Q15).
      expect(topBarPillText('CZ'), findsNothing);
      expect(topBarPillText('EN'), findsNothing);

      await openSettings(tester);
      expect(find.text(cs.settingsMainLangName), findsOneWidget);
      expect(find.text(cs.settingsSecondOffHint), findsOneWidget);
    });

    testWidgets(
        'unsupported device language: en fallback + persistent banner naming '
        'the code', (tester) async {
      await pumpApp(tester, deviceLocale: const Locale('de'));

      expect(find.text(en.modeMath), findsOneWidget);

      await openSettings(tester);
      expect(find.text(en.settingsUnsupportedDeviceLang('DE')),
          findsOneWidget);
      expect(readProvider<LanguageController>(tester).deviceLangUnsupported,
          isTrue);
    });

    testWidgets('no device locale: en, no banner', (tester) async {
      await pumpApp(tester);

      await openSettings(tester);
      expect(find.textContaining("doesn't speak yet"), findsNothing);
      expect(readProvider<LanguageController>(tester).deviceLangUnsupported,
          isFalse);
    });
  });

  group('Second-language Switch', () {
    testWidgets(
        'off: hint shown, no dropdown, toggle hidden; on: dropdown with a '
        'default != main and toggle visible; off again undoes both',
        (tester) async {
      await pumpApp(tester); // fresh install: single en
      await openSettings(tester);

      // Off state.
      expect(find.text(en.settingsSecondOffHint), findsOneWidget);
      expect(find.byKey(const ValueKey('settingsLangDropdown_second')),
          findsNothing);
      expect(topBarPillText('EN'), findsNothing);

      // Switch on — dropdown appears with the default (cs, first != main).
      await tester.tap(find.byKey(const ValueKey('settingsSecondLangSwitch')));
      await tester.pumpAndSettle();

      expect(find.text(en.settingsSecondOffHint), findsNothing);
      expect(find.byKey(const ValueKey('settingsLangDropdown_second')),
          findsOneWidget);
      expect(readProvider<LanguageController>(tester).secondLang,
          AppLanguage.cs);
      expect(topBarPillText('EN'), findsOneWidget);
      expect(topBarPillText('CZ'), findsOneWidget);

      // Switch off — back to the hint, no stale dropdown, toggle hidden.
      await tester.tap(find.byKey(const ValueKey('settingsSecondLangSwitch')));
      await tester.pumpAndSettle();

      expect(find.text(en.settingsSecondOffHint), findsOneWidget);
      expect(find.byKey(const ValueKey('settingsLangDropdown_second')),
          findsNothing);
      expect(topBarPillText('CZ'), findsNothing);
    });

    testWidgets(
        'disabling while the second language is active snaps the board to '
        'main', (tester) async {
      await pumpApp(tester, prefs: {
        'main_lang': 'en',
        'second_lang': 'cs',
        'active_lang': 'cs',
      });

      // cs board: the diacritics-toggle key is a cs-only affordance.
      expect(keyboardText('123'), findsOneWidget);

      await openSettings(tester);
      await tester.tap(find.byKey(const ValueKey('settingsSecondLangSwitch')));
      await tester.pumpAndSettle();

      expect(readProvider<LanguageController>(tester).secondLang, isNull);
      expect(readProvider<LanguageController>(tester).language,
          AppLanguage.en);
      expect(keyboardText('123'), findsNothing); // en board
    });
  });

  group('ADR-0002 locale pin', () {
    testWidgets(
        'flipping the active language keeps chrome in main; board + voice '
        'flip', (tester) async {
      final app = await pumpApp(tester, prefs: {
        'main_lang': 'en',
        'second_lang': 'cs',
        'active_lang': 'cs',
      });

      // Board is cs, chrome is en.
      expect(keyboardText('123'), findsOneWidget);
      expect(find.text(en.modeMath), findsOneWidget);
      expect(find.text(cs.modeMath), findsNothing);
      expect(find.text(en.speak), findsOneWidget);

      // Child flips to the en board.
      await tester.tap(topBarPillText('EN'));
      await tester.pumpAndSettle();

      expect(keyboardText('123'), findsNothing);
      expect(readProvider<LanguageController>(tester).language,
          AppLanguage.en);
      // Chrome unchanged — still the main language.
      expect(find.text(en.modeMath), findsOneWidget);
      expect(find.text(cs.modeMath), findsNothing);

      // The TTS voice flipped with the board.
      expect(
        app.tts.calls
            .lastWhere((c) => c.method == 'setLanguage')
            .arguments,
        'en-US',
      );
    });

    testWidgets('changing the main language moves the chrome with it',
        (tester) async {
      await pumpApp(tester, prefs: {
        'main_lang': 'en',
        'second_lang': 'cs',
        'active_lang': 'en',
      });
      await openSettings(tester);

      // Main dropdown: pick Čeština (== current second) — swaps the set,
      // active (en) stays in [cs, en].
      await tester
          .tap(find.byKey(const ValueKey('settingsLangDropdown_main')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('settingsLangItem_main_cs')));
      await tester.pumpAndSettle();

      final lang = readProvider<LanguageController>(tester);
      expect(lang.mainLang, AppLanguage.cs);
      expect(lang.secondLang, AppLanguage.en);
      expect(lang.language, AppLanguage.en); // preserved by the swap

      // The locale moved with main: dialog chrome is now Czech…
      expect(find.text(cs.settingsMainLangName), findsOneWidget);
      expect(find.text(en.settingsMainLangName), findsNothing);

      await closeSettings(tester, cs.closeLabel);
      // …and so is the top chrome, while the board stays en.
      expect(find.text(cs.modeMath), findsOneWidget);
      expect(find.text(en.modeMath), findsNothing);
      expect(keyboardText('123'), findsNothing); // en board (no 123 key)
    });
  });

  group('Dropdown field', () {
    // The phrase input is the dialog's other input — the dropdown must match
    // its height at every text scale. The two inputs live in different
    // categories now (ADDENDUM-05), so the measurement spans two rail visits.
    Future<void> expectDropdownMatchesInput(WidgetTester tester) async {
      await pumpApp(tester, prefs: {
        'main_lang': 'en',
        'second_lang': 'cs',
      });
      await openSettings(tester);

      // Language category — the dialog always opens here.
      final dropdownH = tester
          .getSize(find.byKey(const ValueKey('settingsLangDropdown_main')))
          .height;

      // Phrases category: the add row is pinned to the pane bottom, on screen
      // at every text scale — no scrolling to reach it.
      await openCategory(tester, 'phrases');
      final input = find.byType(TextField);
      final inputH = tester.getSize(input).height;

      expect(dropdownH, closeTo(inputH, 1.0),
          reason: 'dropdown $dropdownH vs phrase input $inputH');
    }

    testWidgets('closed field matches other inputs at text scale 1.0',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.0;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await expectDropdownMatchesInput(tester);
    });

    testWidgets('closed field matches other inputs at text scale 1.3',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await expectDropdownMatchesInput(tester);
    });
  });

  group('Persistence', () {
    testWidgets('set + active language survive a restart', (tester) async {
      await pumpApp(tester, prefs: {
        'main_lang': 'en',
        'second_lang': 'cs',
        'active_lang': 'cs',
      });

      // Child flips to en, then the app "restarts" over the same store.
      await tester.tap(topBarPillText('EN'));
      await tester.pumpAndSettle();

      final storage = StorageService();
      await storage.init();
      final speech = SpeechService();
      await speech.init();
      final fresh = LanguageController(storage, speech, ComposerController())
        ..load();

      expect(fresh.mainLang, AppLanguage.en);
      expect(fresh.secondLang, AppLanguage.cs);
      expect(fresh.language, AppLanguage.en); // last active restored (Q17)
    });
  });
}

// ---------------------------------------------------------------------------
// Finder helpers (ported from the ADDENDUM-03/04 suites)
// ---------------------------------------------------------------------------

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
}

/// Closes the settings dialog via the pane header's close button by its tooltip
/// label (the phrase rows reuse `Icons.close`; the label follows the main
/// language per ADR-0002, so pass the localized [closeLabel]).
Future<void> closeSettings(WidgetTester tester, String closeLabel) async {
  await tester.tap(find.byTooltip(closeLabel));
  await tester.pumpAndSettle();
}

/// Opens a Settings category from the rail (`language`, `phrases`,
/// `accessibility`). The dialog always opens on Language.
Future<void> openCategory(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(ValueKey('settingsCategory_$name')));
  await tester.pumpAndSettle();
}

/// A [Text] scoped to the keyboard.
Finder keyboardText(String label) => find.descendant(
      of: find.byType(KeyboardView),
      matching: find.text(label),
    );

/// A [Text] scoped to the top bar's language-pill toggle.
Finder topBarPillText(String label) => find.descendant(
      of: find.byType(TopBar),
      matching: find.text(label),
    );
