import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/core/app_language.dart';
import 'package:handy_speak/l10n/app_localizations_cs.dart';
import 'package:handy_speak/l10n/app_localizations_en.dart';
import 'package:handy_speak/main.dart';
import 'package:handy_speak/services/speech_service.dart';
import 'package:handy_speak/services/storage_service.dart';
import 'package:handy_speak/state/composer_controller.dart';
import 'package:handy_speak/state/language_controller.dart';
import 'package:handy_speak/state/phrases_controller.dart';
import 'package:handy_speak/state/settings_controller.dart';
import 'package:handy_speak/widgets/home_page.dart';
import 'package:handy_speak/widgets/keyboard_view.dart';
import 'package:handy_speak/widgets/top_bar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verifies the ADDENDUM-04 features (language set: main + optional second,
/// device-language seeding, the unsupported-device banner, the second-
/// language Switch, and the ADR-0002 UI-locale pin) end to end against the
/// real widget tree, with `flutter_tts` and `shared_preferences` faked at
/// the platform-channel level.
///
/// Swap-via-main-dropdown and per-slot voice warnings are regression-covered
/// by the (migrated) ADDENDUM-03 suite; not duplicated here.
///
/// Shared between `test/addendum04_test.dart` (headless `flutter test`) and
/// `integration_test/addendum04_test.dart` (on-device). Mirrors the
/// ADDENDUM-03 suite shape. Deliberately does NOT initialise any binding —
/// each entry point does its own.
void runAddendum04Suite() {
  final en = AppLocalizationsEn();
  final cs = AppLocalizationsCs();

  group('ADDENDUM-04 · first run / device-language seeding', () {
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

  group('ADDENDUM-04 · second-language Switch', () {
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

  group('ADDENDUM-04 · ADR-0002 locale pin', () {
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

      // The locale moved with main: sheet chrome is now Czech…
      expect(find.text(cs.settingsMainLangName), findsOneWidget);
      expect(find.text(en.settingsMainLangName), findsNothing);

      await closeSettings(tester, cs.closeLabel);
      // …and so is the top chrome, while the board stays en.
      expect(find.text(cs.modeMath), findsOneWidget);
      expect(find.text(en.modeMath), findsNothing);
      expect(keyboardText('123'), findsNothing); // en board (no 123 key)
    });
  });

  group('ADDENDUM-04 · dropdown field', () {
    // The phrase input is the sheet's other input — the dropdown must
    // match its height at every text scale (kids' tablets commonly run
    // accessibility font scaling; a fixed-height dropdown shrinks relative
    // to inputs that scale).
    Future<void> expectDropdownMatchesInput(WidgetTester tester) async {
      await pumpApp(tester, prefs: {
        'main_lang': 'en',
        'second_lang': 'cs',
      });
      await openSettings(tester);

      final dropdownH = tester
          .getSize(find.byKey(const ValueKey('settingsLangDropdown_main')))
          .height;

      // The phrase section may not be built yet (lazy ListView below the
      // fold at larger text scales) — scroll until it exists, then pin it.
      var attempts = 0;
      while (find.byType(TextField).evaluate().isEmpty && attempts++ < 10) {
        await tester.drag(
            find.descendant(
                of: find.byType(BottomSheet),
                matching: find.byType(ListView)),
            const Offset(0, -500));
        await tester.pumpAndSettle();
      }
      final input = find.byType(TextField);
      await tester.ensureVisible(input);
      await tester.pumpAndSettle();
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

  group('ADDENDUM-04 · persistence', () {
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
// Harness (mirrors ADDENDUM-03; duplicated to keep suites independent)
// ---------------------------------------------------------------------------

Map<String, String> _voice(String locale) => {'name': locale, 'locale': locale};
final _defaultVoices = [_voice('en-US'), _voice('cs-CZ')];

/// Live pieces of a pumped app a test may want to inspect/mutate.
class TestApp {
  TestApp(this.storage, this.tts);

  final StorageService storage;
  final FakeTts tts;
}

/// Records every `flutter_tts` platform-channel call so tests can assert on
/// exactly what the TTS engine would receive, and answers `getVoices` with a
/// mutable [voices] list (defaults to en/cs only).
class FakeTts {
  final List<MethodCall> calls = [];
  List<Map<String, String>> voices = List.of(_defaultVoices);

  List<String> get spokenTexts => [
        for (final call in calls)
          if (call.method == 'speak')
              call.arguments is Map
                  ? (call.arguments as Map)['text'] as String
                  : call.arguments as String,
      ];

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'),
            (call) async {
      calls.add(call);
      switch (call.method) {
        case 'isLanguageAvailable':
          return true;
        case 'getVoices':
          return voices;
        default:
          return 1;
      }
    });
  }
}

/// Boots the real app root on a landscape-tablet viewport, storage seeded
/// from [prefs]; [deviceLocale] is what the platform reports at first run
/// (only consulted when no `main_lang` is stored — fresh install).
Future<TestApp> pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  Locale? deviceLocale,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(prefs);
  final tts = FakeTts()..install();

  final storage = StorageService();
  await storage.init();
  final speech = SpeechService();
  await speech.init();
  final settings = SettingsController(storage)..load();
  final phrases = PhrasesController(storage)..load();
  final composer = ComposerController();
  final language = LanguageController(storage, speech, composer)
    ..load(deviceLocale: deviceLocale);

  await tester.pumpWidget(HandySpeakApp(
    storage: storage,
    speech: speech,
    settings: settings,
    phrases: phrases,
    composer: composer,
    language: language,
  ));
  await tester.pumpAndSettle();
  return TestApp(storage, tts);
}

T readProvider<T>(WidgetTester tester) =>
    Provider.of<T>(tester.element(find.byType(HomePage)), listen: false);

/// Opens the settings sheet via the gear icon and waits for the sheet
/// animation to finish.
Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
}

/// Closes the settings sheet via the header's close button by its tooltip
/// label (the phrase rows reuse `Icons.close`; the label follows the main
/// language per ADR-0002, so pass the localized [closeLabel]).
Future<void> closeSettings(WidgetTester tester, String closeLabel) async {
  await tester.tap(find.byTooltip(closeLabel));
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
