import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/core/app_language.dart';
import 'package:handy_speak/l10n/app_localizations_en.dart';
import 'package:handy_speak/l10n/app_localizations_uk.dart';
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

/// Verifies the ADDENDUM-03 features (Ukrainian locale + parent-chosen
/// base/second language pair + per-language voice-pack warnings + a11y
/// bugfixes) end to end against the real widget tree, with `flutter_tts`
/// and `shared_preferences` faked at the platform-channel level.
///
/// Shared between `test/addendum03_test.dart` (headless `flutter test`) and
/// `integration_test/addendum03_test.dart` (on-device / web). Mirrors the
/// ADDENDUM-02 suite shape. Deliberately does NOT initialise any binding —
/// each entry point does its own.
void runAddendum03Suite() {
  final en = AppLocalizationsEn();
  final uk = AppLocalizationsUk();

  group('ADDENDUM-03 · Ukrainian UI chrome', () {
    testWidgets(
        'with uk active, ARB-driven UI strings render Ukrainian, not English',
        (tester) async {
      // Regression coverage for a real bug caught in review: `uk` must be
      // registered in MaterialApp.supportedLocales, or Flutter's locale
      // resolution silently falls back to the first supported locale (en)
      // for every AppLocalizations string, even though data-driven surfaces
      // (keyboard layout, pictograms) switch correctly since they don't go
      // through Localizations at all — a gap the keyboard-only tests above
      // could not have caught.
      await pumpApp(tester,
          prefs: {'language': 'uk', 'second_lang': 'uk'});

      expect(find.text(uk.settings), findsNothing); // gear icon, not open yet
      expect(find.text(uk.modeMath), findsOneWidget);
      expect(find.text(en.modeMath), findsNothing);

      await openSettings(tester);
      expect(find.text(uk.settings), findsOneWidget);
      expect(find.text(en.settings), findsNothing);
    });
  });

  group('ADDENDUM-03 · Ukrainian keyboard', () {
    testWidgets(
        'uk keyboard renders a permanent digit row and ЙЦУКЕН rows, no 123 key',
        (tester) async {
      await pumpApp(tester,
          prefs: {'language': 'uk', 'second_lang': 'uk'});

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
      await pumpApp(tester, prefs: {'language': 'uk', 'second_lang': 'uk'});

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
        'language': 'uk',
        'second_lang': 'uk',
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

  group('ADDENDUM-03 · Language pair (top bar)', () {
    testWidgets('default pair shows exactly EN/CZ, never a third pill',
        (tester) async {
      await pumpApp(tester);

      expect(topBarPillText('EN'), findsOneWidget);
      expect(topBarPillText('CZ'), findsOneWidget);
      expect(topBarPillText('UK'), findsNothing);
    });

    testWidgets('a pair including uk shows exactly those two pills',
        (tester) async {
      await pumpApp(tester, prefs: {'second_lang': 'uk'});

      expect(topBarPillText('EN'), findsOneWidget);
      expect(topBarPillText('UK'), findsOneWidget);
      expect(topBarPillText('CZ'), findsNothing);
    });
  });

  group('ADDENDUM-03 · Settings language pickers', () {
    testWidgets('Base and Second sections each offer all 3 languages',
        (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      expect(find.text(en.settingsBaseLangName), findsOneWidget);
      expect(find.text(en.settingsSecondLangName), findsOneWidget);
      // Each language's native name appears once per picker → 2 occurrences.
      expect(find.text('English'), findsNWidgets(2));
      expect(find.text('Čeština'), findsNWidgets(2));
      expect(find.text('Українська'), findsNWidgets(2));
    });

    testWidgets(
        'picking the second slot\'s language equal to base swaps the pair',
        (tester) async {
      await pumpApp(tester); // base=en, second=cs
      await openSettings(tester);

      // Second picker's "English" row (base's current language) — swaps.
      await tester.tap(find.byKey(const ValueKey('settingsLangPicker_second_en')));
      await tester.pumpAndSettle();

      // Pair swapped: base=cs, second=en. Verify via the top-bar pills,
      // which mirror the controller's pair directly.
      expect(topBarPillText('CZ'), findsOneWidget);
      expect(topBarPillText('EN'), findsOneWidget);
      expect(topBarPillText('UK'), findsNothing);
    });

    testWidgets('picking a non-conflicting language in the base picker works',
        (tester) async {
      await pumpApp(tester); // base=en, second=cs
      await openSettings(tester);

      await tester.tap(find.byKey(const ValueKey('settingsLangPicker_base_uk')));
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

  group('ADDENDUM-03 · Per-language voice-pack warning', () {
    testWidgets(
        'warns for a pair slot with no matching installed voice, silent for the other',
        (tester) async {
      // Default fake voice list only has en-US/cs-CZ installed.
      await pumpApp(tester, prefs: {'second_lang': 'uk'}); // pair: en, uk
      await openSettings(tester);
      await tester.pumpAndSettle();

      expect(
          find.text(en.voiceMissingNamed(AppLanguage.uk.nativeName)),
          findsOneWidget);
      expect(
          find.text(en.voiceMissingNamed(AppLanguage.en.nativeName)),
          findsNothing);
    });

    testWidgets('no warning when every pair slot has a matching voice',
        (tester) async {
      await pumpApp(tester); // pair: en, cs — both installed by default
      await openSettings(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('voice on this tablet yet'), findsNothing);
    });

    testWidgets('manual refresh re-checks and clears a stale warning',
        (tester) async {
      final app = await pumpApp(tester, prefs: {'second_lang': 'uk'});
      await openSettings(tester);
      await tester.pumpAndSettle();
      expect(
          find.text(en.voiceMissingNamed(AppLanguage.uk.nativeName)),
          findsOneWidget);

      // A uk voice pack just got installed — update the fake and refresh.
      app.tts.voices = _defaultVoices + [_voice('uk-UA')];
      await tester.tap(find.byTooltip(en.settingsRefreshVoices));
      await tester.pumpAndSettle();

      expect(
          find.text(en.voiceMissingNamed(AppLanguage.uk.nativeName)),
          findsNothing);
    });
  });
}

// ---------------------------------------------------------------------------
// Harness (mirrors ADDENDUM-01/02; duplicated to keep suites independent)
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
/// mutable [voices] list so `SpeechService.hasVoiceFor` can be exercised
/// against a controlled "installed voice packs" shape.
class FakeTts {
  final List<MethodCall> calls = [];

  /// Simulated installed voices. Defaults to en/cs only (uk missing), the
  /// realistic "device without a Ukrainian pack" starting point these tests
  /// want. Mutate between actions to simulate a pack being installed.
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
/// from [prefs].
Future<TestApp> pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
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
  final language = LanguageController(storage, speech, composer)..load();

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

// --- Top-bar helpers ---------------------------------------------------

/// A [Text] scoped to the top bar's language-pill toggle.
Finder topBarPillText(String label) => find.descendant(
      of: find.byType(TopBar),
      matching: find.text(label),
    );
