import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/core/app_language.dart';
import 'package:handy_speak/core/app_version.dart';
import 'package:handy_speak/core/theme.dart';
import 'package:handy_speak/l10n/app_localizations_cs.dart';
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
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verifies the ADDENDUM-05 settings **dialog** (ADR-0003): the three-category
/// rail, the pane that swaps beneath it, both presentations (fixed 896×624 and
/// full-screen below the breakpoint), the capped measure, dismissal, and the
/// pinned Phrases add row — end to end against the real widget tree, with
/// `flutter_tts` and `shared_preferences` faked at the platform-channel level.
///
/// Shared between `test/addendum05_test.dart` (headless `flutter test`) and
/// `integration_test/addendum05_test.dart` (on-device). Mirrors the
/// ADDENDUM-03 suite shape. Deliberately does NOT initialise any binding —
/// each entry point does its own.
void runAddendum05Suite() {
  final en = AppLocalizationsEn();
  final cs = AppLocalizationsCs();
  final uk = AppLocalizationsUk();

  group('ADDENDUM-05 · Category rail', () {
    testWidgets('the dialog opens on Language every time, never remembering',
        (tester) async {
      await pumpApp(tester);

      await openSettings(tester);
      expectLanguagePane(en);

      // Wander off to Phrases…
      await openCategory(tester, 'phrases');
      expectPhrasesPane(en);

      // …close, reopen: back on Language, not where we left off.
      await closeSettings(tester, en.closeLabel);
      await openSettings(tester);
      expectLanguagePane(en);
    });

    testWidgets('the rail shows all three category labels in English',
        (tester) async {
      // Chrome follows the MAIN language (ADR-0002), so `main_lang` is what
      // decides these strings — not the active language.
      await pumpApp(tester, prefs: {'main_lang': 'en'});
      await openSettings(tester);

      expect(railLabel('language', en.settingsLanguage), findsOneWidget);
      expect(railLabel('phrases', en.settingsPhrases), findsOneWidget);
      expect(railLabel('accessibility', en.settingsAccessibility),
          findsOneWidget);
    });

    testWidgets('the rail shows all three category labels in Czech',
        (tester) async {
      await pumpApp(tester, prefs: {'main_lang': 'cs'});
      await openSettings(tester);

      expect(railLabel('language', cs.settingsLanguage), findsOneWidget);
      expect(railLabel('phrases', cs.settingsPhrases), findsOneWidget);
      expect(railLabel('accessibility', cs.settingsAccessibility),
          findsOneWidget);
      // Not merely present in *some* locale: the English labels are gone.
      expect(railLabel('phrases', en.settingsPhrases), findsNothing);
    });

    testWidgets('the rail shows all three category labels in Ukrainian',
        (tester) async {
      await pumpApp(tester, prefs: {'main_lang': 'uk'});
      await openSettings(tester);

      expect(railLabel('language', uk.settingsLanguage), findsOneWidget);
      expect(railLabel('phrases', uk.settingsPhrases), findsOneWidget);
      expect(railLabel('accessibility', uk.settingsAccessibility),
          findsOneWidget);
      // `settingsPhrases` renders with no "Parent" prefix here too — the
      // string test below pins the ARB value, this pins what the rail
      // actually paints (ADDENDUM-05 step 6).
      expect(railLabel('phrases', en.settingsPhrases), findsNothing);
    });

    testWidgets('tapping a rail entry swaps the pane and leaves the rail',
        (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      await openCategory(tester, 'accessibility');
      expectAccessibilityPane(en);
      expectRailIntact(en);

      await openCategory(tester, 'phrases');
      expectPhrasesPane(en);
      expectRailIntact(en);

      await openCategory(tester, 'language');
      expectLanguagePane(en);
      expectRailIntact(en);
    });

    testWidgets('the rail foot carries the app version', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      final label = tester.widget<Text>(find.byKey(railVersionKey));
      // Built from `kAppVersion` (itself pinned to `pubspec.yaml` by
      // `test/app_version_test.dart`), never a literal — so a version bump
      // cannot leave this test asserting a stale string.
      expect(label.data, 'v$kAppVersion');
    });
  });

  // The panes are held in an `IndexedStack`, not swapped by a `switch`, so a
  // rail tap hides a pane instead of disposing it. These pin the two things
  // that behaviour buys back from the bottom sheet this replaced — both were
  // silently lost while the pane was chosen by type.
  group('ADDENDUM-05 · Pane state', () {
    testWidgets('a half-typed phrase survives a category round-trip',
        (tester) async {
      await pumpApp(tester, prefs: {'main_lang': 'en'});
      await openSettings(tester);
      await openCategory(tester, 'phrases');

      const draft = 'Can I have a break';
      await tester.enterText(addPhraseField(), draft);
      await tester.pumpAndSettle();
      expect(phraseDraft(tester), draft);

      // Deliberately no Add tap: the draft exists only in the pane's own
      // `TextEditingController`, which a remount would dispose.
      await openCategory(tester, 'language');
      await openCategory(tester, 'phrases');

      expect(phraseDraft(tester), draft,
          reason: 'the add field was emptied by the category round-trip — '
              'the Phrases pane was remounted instead of merely hidden');
      // Still a draft, not a phrase: nothing was committed on the way past.
      expect(
        readProvider<PhrasesController>(tester)
            .phrasesFor(AppLanguage.en)
            .map((p) => p.text),
        isNot(contains(draft)),
      );
    });

    testWidgets('the voice check runs once per dialog open, not per visit',
        (tester) async {
      final app = await pumpApp(tester, prefs: {'main_lang': 'en'});

      // Baseline taken AFTER the open, not assumed to be zero: the probe is
      // `SpeechService.hasVoiceFor`, which reaches the engine through the
      // `getVoices` channel method, and other code may reach it too.
      await openSettings(tester);
      final onOpen = app.tts.callCount('getVoices');
      expect(onOpen, greaterThan(0),
          reason: 'the Language pane is expected to probe once on open — if '
              'it never probes, this test can no longer detect a re-probe');

      await openCategory(tester, 'phrases');
      await openCategory(tester, 'language');

      expect(app.tts.callCount('getVoices'), onOpen,
          reason: 'returning to Language re-ran the voice probe: a TTS '
              'round-trip per configured slot plus a spinner flash in the '
              'refresh button, on every single visit');

      // The contract is once per *open*, not once ever: a fresh dialog does
      // re-check, which is how a voice pack installed meanwhile is noticed.
      await closeSettings(tester, en.closeLabel);
      await openSettings(tester);
      expect(app.tts.callCount('getVoices'), greaterThan(onOpen));
    });
  });

  group('ADDENDUM-05 · Instant apply', () {
    testWidgets('a flipped toggle survives a category switch and a restart',
        (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      // Big letters lives in Accessibility; flip it there.
      await openCategory(tester, 'accessibility');
      await tester.tap(toggleSwitch(en.settingsBigLettersName));
      await tester.pumpAndSettle();
      expect(readProvider<SettingsController>(tester).bigLetters, isTrue);

      // Switching category rebuilds the pane — the setting must not ride on
      // pane-local state.
      await openCategory(tester, 'phrases');
      await openCategory(tester, 'accessibility');
      expect(readProvider<SettingsController>(tester).bigLetters, isTrue);

      await closeSettings(tester, en.closeLabel);
      expect(readProvider<SettingsController>(tester).bigLetters, isTrue);
      // …and it is visibly applied to the board, not just held in memory.
      expect(keyboardText('A'), findsOneWidget);
      expect(keyboardText('a'), findsNothing);

      // Simulate a restart: a fresh storage + controller over the same
      // shared_preferences store.
      final storage = StorageService();
      await storage.init();
      final fresh = SettingsController(storage)..load();
      expect(fresh.bigLetters, isTrue);
    });
  });

  group('ADDENDUM-05 · Presentation', () {
    testWidgets('at 1280×800 it is the fixed 896×624 dialog, not full screen',
        (tester) async {
      await pumpApp(tester); // harness default: 1280×800, DPR 1.0
      await openSettings(tester);

      final size = tester.getSize(dialogSurface());
      expect(size.width, AppTokens.dialogW);
      expect(size.height, AppTokens.dialogH);
      // Framed, with the board still readable around it.
      expect(size.width, lessThan(1280));
      expect(size.height, lessThan(800));
    });

    testWidgets('at 900×600 (below the breakpoint) it fills the screen',
        (tester) async {
      // 900 < dialogMinScreenW (944) and 600 < dialogMinScreenH (672): both
      // dimensions are under, so either alone would trigger it.
      await pumpApp(tester, screen: const Size(900, 600));
      await openSettings(tester);

      final size = tester.getSize(dialogSurface());
      expect(size.width, 900);
      expect(size.height, 600);
    });
  });

  group('ADDENDUM-05 · Pane content', () {
    testWidgets('a description line is capped at the measure, not full width',
        (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      // Honest note on what this currently proves: at the shipped 896 pt
      // dialog the pane's content region measures ~558 pt, already inside
      // the 640 pt cap, so the `ConstrainedBox` is not the thing doing the
      // limiting today. The assertion is the guard for the case that
      // motivated the redesign — a pane that grows (a wider dialog, a
      // shorter rail, a locale with tiny labels) and starts running prose
      // the full width again.
      await openCategory(tester, 'accessibility');
      final accessibilityDesc =
          tester.getSize(find.text(en.settingsAccessibilityDesc)).width;
      expect(accessibilityDesc, lessThanOrEqualTo(AppTokens.measureMax));

      await openCategory(tester, 'phrases');
      final phrasesDesc =
          tester.getSize(find.text(en.settingsPhrasesDesc)).width;
      expect(phrasesDesc, lessThanOrEqualTo(AppTokens.measureMax));

      // The pane body itself is capped too, so a longer translation of the
      // same key cannot escape the measure either.
      final paneBody =
          tester.getSize(find.byKey(const ValueKey('settingsPaneScrollable')));
      expect(paneBody.width - AppTokens.s24 * 2,
          lessThanOrEqualTo(AppTokens.measureMax));
    });

    testWidgets('the Phrases add row is reachable without any scrolling',
        (tester) async {
      // Seed a long enough list that the pane body genuinely scrolls —
      // otherwise "no scrolling needed" would be vacuously true.
      await pumpApp(tester, prefs: {
        'main_lang': 'en',
        'phrases_en': seedPhrasesJson(20),
      });
      await openSettings(tester);
      await openCategory(tester, 'phrases');

      // Precondition: the body really is overflowing.
      final position = tester.state<ScrollableState>(paneScrollable()).position;
      expect(position.maxScrollExtent, greaterThan(0),
          reason: 'seed more phrases — the pane body must overflow for this '
              'assertion to mean anything');

      // The add row is pinned outside that scroll view: on screen already,
      // with no scroll action of any kind performed above.
      final field = find.byType(TextField);
      expect(field, findsOneWidget);
      final fieldRect = tester.getRect(field);
      final dialogRect = tester.getRect(dialogSurface());
      expect(dialogRect.contains(fieldRect.topLeft), isTrue,
          reason: 'add field $fieldRect outside dialog $dialogRect');
      expect(dialogRect.contains(fieldRect.bottomRight - const Offset(1, 1)),
          isTrue,
          reason: 'add field $fieldRect outside dialog $dialogRect');
      // Still at the top of the list — nothing scrolled it into view.
      expect(position.pixels, 0);
    });
  });

  group('ADDENDUM-05 · Dismissal', () {
    testWidgets('the pane header X dismisses the dialog', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);
      expect(railEntry('language'), findsOneWidget);

      // By tooltip, not by icon: every phrase row reuses `Icons.close` for
      // its delete control.
      await tester.tap(find.byTooltip(en.closeLabel));
      await tester.pumpAndSettle();

      expectDialogGone();
    });

    testWidgets('a scrim tap dismisses the dialog', (tester) async {
      // The scrim only exists in the FIXED presentation: below the
      // 944×672 breakpoint the dialog covers the whole screen and there is
      // no barrier left to tap. So this runs at the harness default of
      // 1280×800, where the dialog spans x 192–1088 / y 88–712 and
      // (640, 30) is squarely on the barrier above it.
      await pumpApp(tester);
      await openSettings(tester);
      expect(railEntry('language'), findsOneWidget);

      await tester.tapAt(const Offset(640, 30));
      await tester.pumpAndSettle();

      expectDialogGone();
    });
  });

  // The unit-test tier: pure Dart, no pumping. These pin the string and token
  // contracts the widget tests above lean on.
  group('ADDENDUM-05 · Strings and tokens', () {
    test('settingsPhrases carries no "Parent" prefix in any locale', () {
      // The prefix modelled a parent/child settings tier `CONTEXT.md` says
      // must not be modelled (ADDENDUM-05 step 2).
      expect(en.settingsPhrases, 'Phrases');
      expect(cs.settingsPhrases, 'Fráze');
      expect(uk.settingsPhrases, 'Фрази');

      for (final label in [
        en.settingsPhrases,
        cs.settingsPhrases,
        uk.settingsPhrases,
      ]) {
        expect(label, isNot(contains('Parent')));
        expect(label, isNot(contains('Rodič')));
        expect(label, isNot(contains('Батьки')));
      }
    });

    test('the dialog breakpoint derives from the dialog size', () {
      // Assert the RELATIONSHIP, never the literals: the breakpoint is the
      // dialog plus `s24` of margin on every side, so the two can never
      // drift apart (ADR-0003).
      expect(AppTokens.dialogMinScreenW, AppTokens.dialogW + AppTokens.s24 * 2);
      expect(AppTokens.dialogMinScreenH, AppTokens.dialogH + AppTokens.s24 * 2);
    });

    test('the three new keys resolve in EN, CS and UK', () {
      final byKey = <String, List<String>>{
        'settingsLanguageSet': [
          en.settingsLanguageSet,
          cs.settingsLanguageSet,
          uk.settingsLanguageSet,
        ],
        'settingsPhrasesDesc': [
          en.settingsPhrasesDesc,
          cs.settingsPhrasesDesc,
          uk.settingsPhrasesDesc,
        ],
        'settingsAccessibilityDesc': [
          en.settingsAccessibilityDesc,
          cs.settingsAccessibilityDesc,
          uk.settingsAccessibilityDesc,
        ],
      };

      byKey.forEach((key, values) {
        for (final v in values) {
          expect(v.trim(), isNotEmpty, reason: '$key is blank in some locale');
        }
        // Three distinct translations — a copy-paste of the English into a
        // secondary ARB would slip through a mere non-empty check.
        expect(values.toSet(), hasLength(3),
            reason: '$key is not translated per locale: $values');
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Assertion helpers
// ---------------------------------------------------------------------------

/// The Language pane is showing (and no other). `settingsLanguageSet` is the
/// Language section title and appears nowhere else; `settingsPhrasesDesc` /
/// `settingsAccessibilityDesc` are the other two panes' subtitles.
void expectLanguagePane(AppLocalizationsEn l10n) {
  expect(find.text(l10n.settingsLanguageSet), findsOneWidget);
  expect(find.text(l10n.settingsPhrasesDesc), findsNothing);
  expect(find.text(l10n.settingsAccessibilityDesc), findsNothing);
}

void expectPhrasesPane(AppLocalizationsEn l10n) {
  expect(find.text(l10n.settingsPhrasesDesc), findsOneWidget);
  expect(find.text(l10n.settingsLanguageSet), findsNothing);
  expect(find.text(l10n.settingsAccessibilityDesc), findsNothing);
}

void expectAccessibilityPane(AppLocalizationsEn l10n) {
  expect(find.text(l10n.settingsAccessibilityDesc), findsOneWidget);
  expect(find.text(l10n.settingsLanguageSet), findsNothing);
  expect(find.text(l10n.settingsPhrasesDesc), findsNothing);
}

/// All three rail entries are still mounted and still labelled — the rail is
/// pinned, only the pane swaps.
void expectRailIntact(AppLocalizationsEn l10n) {
  expect(railLabel('language', l10n.settingsLanguage), findsOneWidget);
  expect(railLabel('phrases', l10n.settingsPhrases), findsOneWidget);
  expect(railLabel('accessibility', l10n.settingsAccessibility),
      findsOneWidget);
}

/// The dialog is gone — rail and pane both. Checked by content rather than by
/// the `Dialog` type, which lingers for a frame during the exit transition.
void expectDialogGone() {
  expect(railEntry('language'), findsNothing);
  expect(railEntry('phrases'), findsNothing);
  expect(railEntry('accessibility'), findsNothing);
  expect(find.byType(Dialog), findsNothing);
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

/// Records every `flutter_tts` platform-channel call and answers `getVoices`
/// with a mutable [voices] list (defaults to en/cs only, so a uk set starts
/// from the realistic "no pack installed" state).
class FakeTts {
  final List<MethodCall> calls = [];

  List<Map<String, String>> voices = List.of(_defaultVoices);

  /// How many times [method] has been invoked so far. Tests that care about
  /// *re*-work (a probe repeating on every category visit) diff this rather
  /// than asserting an absolute count.
  int callCount(String method) =>
      calls.where((c) => c.method == method).length;

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
///
/// [screen] defaults to 1280×800 — comfortably above the 944×672 dialog
/// breakpoint, so the dialog presents fixed. Pass something smaller to
/// exercise the full-screen presentation.
Future<TestApp> pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  Size screen = const Size(1280, 800),
}) async {
  tester.view.physicalSize = screen;
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

/// The JSON `PhrasesController` persists under `phrases_<lang>` — seeded
/// directly, because the controller decides fresh-install vs. restore by key
/// presence and hand-rolled controller state would not survive a reload.
String seedPhrasesJson(int count) => jsonEncode([
      for (var i = 0; i < count; i++)
        {'text': 'Seeded phrase ${i + 1}', 'pinned': false, 'uses': 0},
    ]);

// --- Settings-dialog helpers -----------------------------------------------

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
}

/// Closes the dialog via the pane header's X, found by its tooltip: the
/// phrase rows reuse `Icons.close` for delete, and the label follows the main
/// language (ADR-0002), so the localized string has to be passed in.
Future<void> closeSettings(WidgetTester tester, String closeLabel) async {
  await tester.tap(find.byTooltip(closeLabel));
  await tester.pumpAndSettle();
}

/// A rail entry, by test key — never by its localized label, which copy edits
/// and locale flips would break.
Finder railEntry(String name) => find.byKey(ValueKey('settingsCategory_$name'));

/// The unlocalized version label at the rail's foot.
const railVersionKey = ValueKey('settingsVersion');

/// The [Text] inside a given rail entry — the one place a localized label is
/// asserted, and only ever against a generated locale class.
Finder railLabel(String name, String label) =>
    find.descendant(of: railEntry(name), matching: find.text(label));

/// Opens a Settings category from the rail (`language`, `phrases`,
/// `accessibility`). The dialog always opens on Language and never remembers
/// the last category.
Future<void> openCategory(WidgetTester tester, String name) async {
  await tester.tap(railEntry(name));
  await tester.pumpAndSettle();
}

/// The [Scrollable] inside the open category's pane — the scroll view carries
/// the key, the `Scrollable` it builds is its descendant.
Finder paneScrollable() => find.descendant(
      of: find.byKey(const ValueKey('settingsPaneScrollable')),
      matching: find.byType(Scrollable),
    );

/// The dialog's own [Material] — the surface whose size *is* the dialog's
/// presentation. `Dialog` itself renders as a full-screen `AnimatedPadding`,
/// so measuring `find.byType(Dialog)` would always report the screen.
Finder dialogSurface() =>
    find.descendant(of: find.byType(Dialog), matching: find.byType(Material))
        .first;

/// The Phrases pane's pinned add field, by test key — the Language pane is
/// mounted alongside it, so `find.byType(TextField)` is no longer a safe way
/// to name it.
Finder addPhraseField() =>
    find.byKey(const ValueKey('settingsAddPhraseField'));

/// What is currently typed into the add field — the field's own contents, not
/// merely "some Text with this string exists somewhere".
String phraseDraft(WidgetTester tester) =>
    tester.widget<TextField>(addPhraseField()).controller!.text;

/// The [Switch] sitting in the same toggle row as the [name] label.
Finder toggleSwitch(String name) => find.descendant(
      of: find.ancestor(of: find.text(name), matching: find.byType(Row)).first,
      matching: find.byType(Switch),
    );

// --- Board helpers ---------------------------------------------------------

/// A [Text] scoped to the keyboard.
Finder keyboardText(String label) => find.descendant(
      of: find.byType(KeyboardView),
      matching: find.text(label),
    );
