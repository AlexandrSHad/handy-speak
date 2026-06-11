import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/core/app_language.dart';
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
import 'package:handy_speak/widgets/phrase_strip.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verifies the ADDENDUM-01 features (Big letters + optional "My phrases"
/// strip) end to end against the real widget tree, with `flutter_tts` and
/// `shared_preferences` faked at the platform-channel level.
///
/// Shared between `test/addendum01_test.dart` (headless `flutter test`) and
/// `integration_test/addendum01_test.dart` (on-device / web). Deliberately
/// does NOT initialise any binding — each entry point does its own.
void runAddendum01Suite() {
  // English strings, resolved exactly like the app resolves them.
  final en = AppLocalizationsEn();

  group('ADDENDUM-01 · Big letters', () {
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
      // section: title above it, the haptics row below it.
      await tester.scrollUntilVisible(
        find.text(en.settingsHapticName),
        100,
        scrollable: settingsScrollable(),
      );
      await tester.pumpAndSettle();
      final titleDy = tester.getTopLeft(find.text(en.settingsAccessibility)).dy;
      final bigDy = tester.getTopLeft(find.text(en.settingsBigLettersName)).dy;
      final hapticDy = tester.getTopLeft(find.text(en.settingsHapticName)).dy;
      expect(titleDy, lessThan(bigDy));
      expect(bigDy, lessThan(hapticDy));

      await tapToggle(tester, en.settingsBigLettersName);
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
      await tapToggle(tester, en.settingsBigLettersName);
      await closeSettings(tester);

      expect(find.text('want'), findsOneWidget); // tile reverts instantly
      expect(find.text('WANT'), findsNothing);
      expect(readProvider<ComposerController>(tester).tokens, ['want']);
    });

    testWidgets(
        'mode survives the EN→CS switch; Czech accents display uppercase, '
        'insert lowercase', (tester) async {
      await pumpApp(tester, prefs: {'big_letters': true});

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

  group('ADDENDUM-01 · Optional phrase strip', () {
    testWidgets(
        'toggle OFF removes the strip and grows keys and symbol tiles',
        (tester) async {
      await pumpApp(tester);
      expect(find.byType(PhraseStrip), findsOneWidget);
      final keyBefore = tester.getSize(keyMaterial('q')).height;

      await tester.tap(find.text(en.modeSymbols));
      await tester.pumpAndSettle();
      final tileBefore = tester.getSize(firstSymbolTile()).height;

      await openSettings(tester);
      await tapToggle(tester, en.settingsShowPhrasesName);
      // The "hidden" note shows under the toggle while OFF.
      expect(find.text(en.settingsPhrasesHiddenNote), findsOneWidget);
      await closeSettings(tester);

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
      await tester.scrollUntilVisible(
        find.byType(TextField),
        100,
        scrollable: settingsScrollable(),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Good morning');
      await tester.tap(find.text(en.settingsAdd));
      await tester.pumpAndSettle();

      expect(find.text('Good morning'), findsOneWidget); // listed in sheet
      final phrases =
          readProvider<PhrasesController>(tester).phrasesFor(AppLanguage.en);
      expect(phrases.map((p) => p.text), contains('Good morning'));
    });

    testWidgets('toggle back ON restores phrases and pin order',
        (tester) async {
      await pumpApp(tester, prefs: {'show_phrases': false});
      expect(find.byType(PhraseStrip), findsNothing);

      await openSettings(tester);
      await tapToggle(tester, en.settingsShowPhrasesName);
      await closeSettings(tester);

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

  group('ADDENDUM-01 · Combined', () {
    testWidgets('all four toggle combinations render without exceptions',
        (tester) async {
      for (final big in [false, true]) {
        for (final show in [false, true]) {
          await pumpApp(
            tester,
            prefs: {'big_letters': big, 'show_phrases': show},
          );
          expect(tester.takeException(), isNull,
              reason: 'keyboard, big=$big show=$show');
          expect(find.byType(KeyboardView), findsOneWidget);
          expect(find.byType(PhraseStrip),
              show ? findsOneWidget : findsNothing);

          await tester.tap(find.text(en.modeSymbols));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: 'symbols, big=$big show=$show');
        }
      }
    });

    testWidgets('both settings persist across an app restart', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);
      // Phrases section sits above Accessibility — toggle it first so the
      // sheet only ever needs to scroll downward.
      await tapToggle(tester, en.settingsShowPhrasesName);
      await tapToggle(tester, en.settingsBigLettersName);
      await closeSettings(tester);

      // Simulate a restart: a fresh storage + controller over the same
      // shared_preferences store.
      final storage = StorageService();
      await storage.init();
      final fresh = SettingsController(storage)..load();
      expect(fresh.bigLetters, isTrue);
      expect(fresh.showPhrases, isFalse);
    });
  });
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// Live pieces of a pumped app a test may want to inspect.
class TestApp {
  TestApp(this.storage, this.tts);

  final StorageService storage;
  final FakeTts tts;
}

/// Records every `flutter_tts` platform-channel call so tests can assert on
/// exactly what the TTS engine would receive (casing, in particular).
class FakeTts {
  final List<MethodCall> calls = [];

  /// Text of every `speak` call, oldest first. The plugin sends a bare
  /// string on most platforms and a `{text, focus}` map on Android.
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
        // awaitSpeakCompletion / setLanguage / speak / stop / setSpeechRate /
        // setPitch — the plugin treats 1 as success everywhere.
        default:
          return 1;
      }
    });
  }
}

/// Boots the real app root ([HandySpeakApp], same wiring as `main()`) on a
/// landscape-tablet viewport, with storage seeded from [prefs].
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

/// Reads a provider exactly as the widgets do — from the element tree.
T readProvider<T>(WidgetTester tester) =>
    Provider.of<T>(tester.element(find.byType(HomePage)), listen: false);

// ---------------------------------------------------------------------------
// Keyboard helpers
// ---------------------------------------------------------------------------

/// A [Text] scoped to the keyboard, so word tiles in the message bar showing
/// the same string can never be matched (or tapped) by mistake.
Finder keyboardText(String label) => find.descendant(
      of: find.byType(KeyboardView),
      matching: find.text(label),
    );

/// The tappable key surface ([Material]) behind a key label.
Finder keyMaterial(String label) => find
    .ancestor(of: keyboardText(label), matching: find.byType(Material))
    .first;

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

/// First pictogram tile surface in the symbol grid.
Finder firstSymbolTile() => find
    .descendant(of: find.byType(GridView), matching: find.byType(InkWell))
    .first;

// ---------------------------------------------------------------------------
// Settings-sheet helpers
// ---------------------------------------------------------------------------

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
}

Future<void> closeSettings(WidgetTester tester) async {
  // The header close button is the first close icon in tree order (phrase
  // rows further down also use Icons.close for "remove").
  await tester.tap(find.byIcon(Icons.close).first);
  await tester.pumpAndSettle();
}

/// The settings sheet's ListView (first scrollable inside the bottom sheet).
Finder settingsScrollable() => find
    .descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable))
    .first;

/// The [Switch] sitting in the same toggle row as the [name] label.
Finder toggleSwitch(String name) => find.descendant(
      of: find.ancestor(of: find.text(name), matching: find.byType(Row)).first,
      matching: find.byType(Switch),
    );

/// Scrolls the open settings sheet until the [name] toggle row is visible
/// and flips its switch.
Future<void> tapToggle(WidgetTester tester, String name) async {
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
