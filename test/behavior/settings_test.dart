import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/core/app_language.dart';
import 'package:handy_speak/core/app_version.dart';
import 'package:handy_speak/core/theme.dart';
import 'package:handy_speak/l10n/app_localizations_cs.dart';
import 'package:handy_speak/l10n/app_localizations_en.dart';
import 'package:handy_speak/l10n/app_localizations_uk.dart';
import 'package:handy_speak/state/phrases_controller.dart';
import 'package:handy_speak/state/settings_controller.dart';
import 'package:handy_speak/services/storage_service.dart';
import 'package:handy_speak/widgets/keyboard_view.dart';
import 'package:handy_speak/widgets/phrase_strip.dart';

import '../support/app_harness.dart';

/// Settings-dialog behaviour (ADR-0003): the three-category rail, the pane that
/// swaps beneath it, instant apply, both presentations, the capped measure, the
/// pinned Phrases add row, and dismissal — plus the two board-affecting toggles
/// rendering together and persisting across a restart. Migrated from the
/// ADDENDUM-05 suite (all groups except the pure-unit "Strings and tokens")
/// and the ADDENDUM-01 "Combined" group.
void main() {
  final en = AppLocalizationsEn();
  final cs = AppLocalizationsCs();
  final uk = AppLocalizationsUk();

  group('Category rail', () {
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
      // Built from `kAppVersion`, never a literal — so a version bump cannot
      // leave this test asserting a stale string.
      expect(label.data, 'v$kAppVersion');
    });
  });

  // The panes are held in an `IndexedStack`, so a rail tap hides a pane instead
  // of disposing it. These pin the two things that buys back.
  group('Pane state', () {
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

      // Baseline taken AFTER the open, not assumed to be zero.
      await openSettings(tester);
      final onOpen = getVoicesCalls(app);
      expect(onOpen, greaterThan(0),
          reason: 'the Language pane is expected to probe once on open — if '
              'it never probes, this test can no longer detect a re-probe');

      await openCategory(tester, 'phrases');
      await openCategory(tester, 'language');

      expect(getVoicesCalls(app), onOpen,
          reason: 'returning to Language re-ran the voice probe: a TTS '
              'round-trip per configured slot plus a spinner flash in the '
              'refresh button, on every single visit');

      // The contract is once per *open*, not once ever: a fresh dialog does
      // re-check, which is how a voice pack installed meanwhile is noticed.
      await closeSettings(tester, en.closeLabel);
      await openSettings(tester);
      expect(getVoicesCalls(app), greaterThan(onOpen));
    });
  });

  group('Instant apply', () {
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

      // Simulate a restart: a fresh storage + controller over the same store.
      final storage = StorageService();
      await storage.init();
      final fresh = SettingsController(storage)..load();
      expect(fresh.bigLetters, isTrue);
    });
  });

  group('Presentation', () {
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
      // 900 < dialogMinScreenW (944) and 600 < dialogMinScreenH (672).
      await pumpApp(tester, screen: const Size(900, 600));
      await openSettings(tester);

      final size = tester.getSize(dialogSurface());
      expect(size.width, 900);
      expect(size.height, 600);
    });
  });

  group('Pane content', () {
    testWidgets('a description line is capped at the measure, not full width',
        (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

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
      // Seed a long enough list that the pane body genuinely scrolls.
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

  group('Dismissal', () {
    testWidgets('the pane header X dismisses the dialog', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);
      expect(railEntry('language'), findsOneWidget);

      // By tooltip, not by icon: every phrase row reuses `Icons.close`.
      await tester.tap(find.byTooltip(en.closeLabel));
      await tester.pumpAndSettle();

      expectDialogGone();
    });

    testWidgets('a scrim tap dismisses the dialog', (tester) async {
      // The scrim only exists in the FIXED presentation. At the harness
      // default 1280×800 the dialog spans x 192–1088 / y 88–712 and (640, 30)
      // is squarely on the barrier above it.
      await pumpApp(tester);
      await openSettings(tester);
      expect(railEntry('language'), findsOneWidget);

      await tester.tapAt(const Offset(640, 30));
      await tester.pumpAndSettle();

      expectDialogGone();
    });
  });

  group('Toggles combined', () {
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
      await tapToggle(tester, 'phrases', en.settingsShowPhrasesName);
      await tapToggle(tester, 'accessibility', en.settingsBigLettersName);
      await closeSettings(tester, en.closeLabel);

      // Simulate a restart: a fresh storage + controller over the same store.
      final storage = StorageService();
      await storage.init();
      final fresh = SettingsController(storage)..load();
      expect(fresh.bigLetters, isTrue);
      expect(fresh.showPhrases, isFalse);
    });
  });
}

// ---------------------------------------------------------------------------
// Assertion helpers (ported from the ADDENDUM-05 suite)
// ---------------------------------------------------------------------------

/// The Language pane is showing (and no other). `settingsLanguageSet` is the
/// Language section title; the other two strings are the sibling panes'
/// subtitles.
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
// Finder helpers (ported from the ADDENDUM-05/01 suites)
// ---------------------------------------------------------------------------

/// How many times `getVoices` has been sent to the fake TTS engine. The shared
/// `FakeTts` records every channel call but exposes no counter, so tests that
/// care about *re*-work diff this rather than asserting an absolute count.
int getVoicesCalls(TestApp app) =>
    app.tts.calls.where((c) => c.method == 'getVoices').length;

/// The JSON `PhrasesController` persists under `phrases_<lang>` — seeded
/// directly, because the controller decides fresh-install vs. restore by key
/// presence.
String seedPhrasesJson(int count) => jsonEncode([
      for (var i = 0; i < count; i++)
        {'text': 'Seeded phrase ${i + 1}', 'pinned': false, 'uses': 0},
    ]);

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
}

/// Closes the dialog via the pane header's X, found by its tooltip: the phrase
/// rows reuse `Icons.close` for delete, and the label follows the main
/// language (ADR-0002), so the localized string has to be passed in.
Future<void> closeSettings(WidgetTester tester, String closeLabel) async {
  await tester.tap(find.byTooltip(closeLabel));
  await tester.pumpAndSettle();
}

/// A rail entry, by test key — never by its localized label.
Finder railEntry(String name) => find.byKey(ValueKey('settingsCategory_$name'));

/// The unlocalized version label at the rail's foot.
const railVersionKey = ValueKey('settingsVersion');

/// The [Text] inside a given rail entry — the one place a localized label is
/// asserted, and only ever against a generated locale class.
Finder railLabel(String name, String label) =>
    find.descendant(of: railEntry(name), matching: find.text(label));

/// Opens a Settings category from the rail (`language`, `phrases`,
/// `accessibility`). The dialog always opens on Language.
Future<void> openCategory(WidgetTester tester, String name) async {
  await tester.tap(railEntry(name));
  await tester.pumpAndSettle();
}

/// The [Scrollable] inside the open category's pane.
Finder paneScrollable() => find.descendant(
      of: find.byKey(const ValueKey('settingsPaneScrollable')),
      matching: find.byType(Scrollable),
    );

/// The dialog's own [Material] — the surface whose size *is* the dialog's
/// presentation.
Finder dialogSurface() =>
    find.descendant(of: find.byType(Dialog), matching: find.byType(Material))
        .first;

/// The Phrases pane's pinned add field, by test key — the Language pane is
/// mounted alongside it, so `find.byType(TextField)` is no longer a safe way to
/// name it.
Finder addPhraseField() =>
    find.byKey(const ValueKey('settingsAddPhraseField'));

/// What is currently typed into the add field.
String phraseDraft(WidgetTester tester) =>
    tester.widget<TextField>(addPhraseField()).controller!.text;

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

/// A [Text] scoped to the keyboard.
Finder keyboardText(String label) => find.descendant(
      of: find.byType(KeyboardView),
      matching: find.text(label),
    );
