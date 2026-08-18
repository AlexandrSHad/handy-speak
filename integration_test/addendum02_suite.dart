import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:handy_speak/widgets/math_board.dart';
import 'package:handy_speak/widgets/message_blocks.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verifies the ADDENDUM-02 features (Math board + Czech inline numbers +
/// dual message-bar workspaces) end to end against the real widget tree,
/// with `flutter_tts` and `shared_preferences` faked at the platform-channel
/// level.
///
/// Shared between `test/addendum02_test.dart` (headless `flutter test`) and
/// `integration_test/addendum02_test.dart` (on-device / web). Mirrors the
/// ADDENDUM-01 suite shape. Deliberately does NOT initialise any binding —
/// each entry point does its own.
void runAddendum02Suite() {
  final en = AppLocalizationsEn();
  final cs = AppLocalizationsCs();

  group('ADDENDUM-02 · Math pill', () {
    testWidgets('third pill "Math" appears and switches to the board (EN)',
        (tester) async {
      await pumpApp(tester);
      expect(find.byIcon(Icons.calculate_outlined), findsOneWidget);
      expect(find.text(en.modeMath), findsOneWidget);

      await tester.tap(find.text(en.modeMath));
      await tester.pumpAndSettle();
      expect(find.byType(MathBoard), findsOneWidget);
      expect(find.byType(KeyboardView), findsNothing);
    });

    testWidgets('third pill "Počítání" switches to the board (CS)',
        (tester) async {
      // Single-language cs install: main (and thus UI chrome + board) is cs
      // — ADDENDUM-04 keys; chrome follows main per ADR-0002.
      await pumpApp(tester, prefs: {'main_lang': 'cs'});
      expect(find.text(cs.modeMath), findsOneWidget);

      await tester.tap(find.text(cs.modeMath));
      await tester.pumpAndSettle();
      expect(find.byType(MathBoard), findsOneWidget);
    });
  });

  group('ADDENDUM-02 · Math grid', () {
    testWidgets('renders the true glyphs ÷ × − < > = and ⌫', (tester) async {
      await pumpApp(tester);
      await enterMath(tester);

      for (final g in ['÷', '×', '−', '<', '>', '=']) {
        expect(mathText(g), findsOneWidget,
            reason: '$g must be the true glyph, not an ASCII stand-in');
      }
      expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
    });

    testWidgets('0 spans two columns (~2× a normal key)', (tester) async {
      await pumpApp(tester);
      await enterMath(tester);

      final zero = tester.getSize(
          find.ancestor(of: mathText('0'), matching: find.byType(Material)).first);
      final seven = tester.getSize(
          find.ancestor(of: mathText('7'), matching: find.byType(Material)).first);
      expect(zero.width, greaterThan(seven.width * 1.8));
      expect(zero.width, lessThan(seven.width * 2.2));
    });
  });

  group('ADDENDUM-02 · Math composition', () {
    testWidgets('4,2 yields a single tile "42"', (tester) async {
      await pumpApp(tester);
      await enterMath(tester);

      await tapMath(tester, '4');
      await tapMath(tester, '2');

      expect(readProvider<ComposerController>(tester).tokens, ['42']);
      expect(messageTile('42'), findsOneWidget);
    });

    testWidgets('3 + 4 = 7 yields five tiles', (tester) async {
      await pumpApp(tester);
      await enterMath(tester);

      for (final k in ['3', '+', '4', '=', '7']) {
        await tapMath(tester, k);
      }

      expect(readProvider<ComposerController>(tester).tokens,
          ['3', '+', '4', '=', '7']);
      for (final t in ['3', '+', '4', '=', '7']) {
        expect(messageTile(t), findsOneWidget);
      }
    });

    testWidgets('⌫ deletes one glyph (digit off a number)', (tester) async {
      await pumpApp(tester);
      await enterMath(tester);

      await tapMath(tester, '4');
      await tapMath(tester, '2');
      expect(readProvider<ComposerController>(tester).text, '42');

      await tapMathBackspace(tester);
      expect(readProvider<ComposerController>(tester).text, '4');
    });

    testWidgets('⌫ drops a whole sign tile', (tester) async {
      await pumpApp(tester);
      await enterMath(tester);

      await tapMath(tester, '3');
      await tapMath(tester, '+');
      await tapMath(tester, '4');
      // '3 + 4' → backspace trims '4' → '3 +' (POC strips trailing ws)
      await tapMathBackspace(tester);
      expect(readProvider<ComposerController>(tester).text, '3 +');
      // → backspace drops the whole '+' tile → '3'
      await tapMathBackspace(tester);
      expect(readProvider<ComposerController>(tester).text, '3');
    });

    testWidgets('completed math tiles are tap-to-✕ removable', (tester) async {
      await pumpApp(tester);
      await enterMath(tester);

      await tapMath(tester, '3');
      await tapMath(tester, '+');
      await tapMath(tester, '4');
      // tokens: ['3','+','4']; trailing '4' is active (caret), '3'/'+' removable.

      await tester.tap(messageTile('+'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(readProvider<ComposerController>(tester).tokens, ['3', '4']);
    });
  });

  group('ADDENDUM-02 · Speak voices math glyphs', () {
    testWidgets('EN: 12 × 5 = speaks "12 times 5 equals"', (tester) async {
      final app = await pumpApp(tester);
      await enterMath(tester);

      await tapMath(tester, '1');
      await tapMath(tester, '2');
      await tapMath(tester, '×');
      await tapMath(tester, '5');
      await tapMath(tester, '=');

      await tester.tap(find.text(en.speak));
      await tester.pumpAndSettle();

      expect(app.tts.spokenTexts, isNotEmpty);
      expect(app.tts.spokenTexts.last, '12 times 5 equals');
    });

    testWidgets('CS: 12 × 5 = speaks "12 krát 5 rovná se"', (tester) async {
      final app = await pumpApp(tester, prefs: {'main_lang': 'cs'});
      await enterMath(tester);

      await tapMath(tester, '1');
      await tapMath(tester, '2');
      await tapMath(tester, '×');
      await tapMath(tester, '5');
      await tapMath(tester, '=');

      await tester.tap(find.text(cs.speak));
      await tester.pumpAndSettle();

      expect(app.tts.spokenTexts.last, '12 krát 5 rovná se');
    });
  });

  group('ADDENDUM-02 · Czech inline numbers', () {
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

  group('ADDENDUM-02 · Workspaces', () {
    testWidgets('Math→Keyboard→Math preserves both buffers', (tester) async {
      await pumpApp(tester);
      await enterMath(tester);
      await tapMath(tester, '7');

      await tester.tap(find.text(en.modeKeyboard));
      await tester.pumpAndSettle();
      await tapKey(tester, 'h');
      expect(readProvider<ComposerController>(tester).text, 'h');

      await tester.tap(find.text(en.modeMath));
      await tester.pumpAndSettle();
      expect(readProvider<ComposerController>(tester).text, '7');
    });

    testWidgets('EN⇄CS clears the sentence but preserves the math problem',
        (tester) async {
      // Two-language set (en main + cs second), starting on the en board.
      await pumpApp(tester, prefs: {
        'main_lang': 'en',
        'second_lang': 'cs',
      });
      await enterMath(tester);
      await tapMath(tester, '3');
      await tapMath(tester, '+');
      await tapMath(tester, '4');

      await tester.tap(find.text(en.modeKeyboard));
      await tester.pumpAndSettle();
      await tapKey(tester, 'h');
      await tapKey(tester, 'i');
      expect(readProvider<ComposerController>(tester).text, 'hi');

      // EN → CS: sentence cleared, math survives.
      await tester.tap(find.text('CZ'));
      await tester.pumpAndSettle();
      expect(readProvider<ComposerController>(tester).text, '');

      await tester.tap(find.text(cs.modeMath));
      await tester.pumpAndSettle();
      expect(readProvider<ComposerController>(tester).text.trim(), '3 + 4');

      // CS → EN: still survives.
      await tester.tap(find.text('EN'));
      await tester.pumpAndSettle();
      expect(readProvider<ComposerController>(tester).text.trim(), '3 + 4');
    });
  });
}

// ---------------------------------------------------------------------------
// Harness (mirrors ADDENDUM-01; duplicated to keep suites independent)
// ---------------------------------------------------------------------------

/// Live pieces of a pumped app a test may want to inspect.
class TestApp {
  TestApp(this.storage, this.tts);

  final StorageService storage;
  final FakeTts tts;
}

/// Records every `flutter_tts` platform-channel call so tests can assert on
/// exactly what the TTS engine would receive.
class FakeTts {
  final List<MethodCall> calls = [];

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

// --- Math helpers ----------------------------------------------------------

/// Switch to the Math board (taps the pill by icon — locale-independent).
Future<void> enterMath(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.calculate_outlined));
  await tester.pumpAndSettle();
}

/// Tap the math `⌫` key (rendered as an icon, not a Text label).
Future<void> tapMathBackspace(WidgetTester tester) async {
  await tester.tap(find.descendant(
    of: find.byType(MathBoard),
    matching: find.byIcon(Icons.backspace_outlined),
  ));
  await tester.pumpAndSettle();
}

/// A [Text] scoped to the math board.
Finder mathText(String label) => find.descendant(
      of: find.byType(MathBoard),
      matching: find.text(label),
    );

Future<void> tapMath(WidgetTester tester, String label) async {
  await tester.tap(mathText(label));
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

// --- Message-bar helpers ---------------------------------------------------

/// A word-tile [Text] scoped to the message area (never matches a key label).
Finder messageTile(String label) => find.descendant(
      of: find.byType(MessageBlocks),
      matching: find.text(label),
    );
