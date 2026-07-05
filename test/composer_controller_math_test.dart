import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/core/app_language.dart';
import 'package:handy_speak/services/speech_service.dart';
import 'package:handy_speak/services/storage_service.dart';
import 'package:handy_speak/state/composer_controller.dart';
import 'package:handy_speak/state/language_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ADDENDUM-02 controller tests. The ComposerController groups are pure
// (no binding, no services). The LanguageController group initializes the
// binding once to fake `flutter_tts` at the platform-channel level — the
// same pattern as the ADDENDUM-01 widget suite, but without pumping widgets.

void main() {
  group('ComposerController · dual buffers', () {
    test('Keyboard and Symbols share one (sentence) buffer', () {
      final c = ComposerController();
      c.addChar('h');
      c.addChar('i');
      expect(c.text, 'hi');

      c.setMode(InputMode.symbols);
      c.appendWord('help');
      expect(c.text, 'hi help');
      expect(c.tokens, ['hi', 'help']);

      c.setMode(InputMode.keyboard);
      expect(c.text, 'hi help'); // same buffer
    });

    test('Math is a separate buffer; switching is non-destructive', () {
      final c = ComposerController();
      c.addChar('h');
      c.addChar('i');

      c.setMode(InputMode.math);
      expect(c.text, ''); // math starts empty
      c.appendMathDigit('3');
      c.appendMathOp('+');
      c.appendMathDigit('4');

      // Switch away and back — math problem preserved.
      c.setMode(InputMode.keyboard);
      expect(c.text, 'hi'); // sentence intact
      c.setMode(InputMode.math);
      expect(c.text.trim(), '3 + 4'); // math remembered
    });

    test('clear() clears the active buffer only', () {
      final c = ComposerController();
      c.addChar('h');
      c.setMode(InputMode.math);
      c.appendMathDigit('9');

      c.clear(); // active = math
      expect(c.text, '');

      c.setMode(InputMode.keyboard);
      expect(c.text, 'h'); // sentence survived
    });

    test('clearSentence() wipes the sentence but leaves math intact', () {
      final c = ComposerController();
      c.addChar('h');
      c.setMode(InputMode.math);
      c.appendMathDigit('9');

      c.clearSentence();
      c.setMode(InputMode.keyboard);
      expect(c.text, '');
      c.setMode(InputMode.math);
      expect(c.text.trim(), '9');
    });

    test('clearSentence() is a no-op when already empty (no notify spam)', () {
      final c = ComposerController();
      var notifications = 0;
      c.addListener(() => notifications++);

      c.clearSentence();
      expect(notifications, 0);
    });
  });

  group('ComposerController · activeIndex', () {
    test('keyboard: trailing in-progress token shows the caret', () {
      final c = ComposerController();
      c.addChar('h');
      c.addChar('i');
      expect(c.activeIndex, 0); // one token, no trailing space
    });

    test('keyboard: -1 once a space ends the word', () {
      final c = ComposerController();
      c.addChar('h');
      c.addChar('i');
      c.addChar(' '); // a trailing space ends the in-progress word
      expect(c.activeIndex, -1);
    });

    test('math: trailing in-progress number shows the caret', () {
      final c = ComposerController();
      c.setMode(InputMode.math);
      c.appendMathDigit('4');
      c.appendMathDigit('2');
      expect(c.tokens, ['42']);
      expect(c.activeIndex, 0);
    });

    test('math: -1 after an operator (trailing space)', () {
      final c = ComposerController();
      c.setMode(InputMode.math);
      c.appendMathDigit('3');
      c.appendMathOp('+');
      expect(c.activeIndex, -1); // ends with space
    });

    test('symbols: no caret (not a typing mode)', () {
      final c = ComposerController();
      c.setMode(InputMode.symbols);
      c.appendWord('help');
      expect(c.activeIndex, -1);
    });
  });

  group('ComposerController · math mutators', () {
    test('appendMathDigit groups; appendMathOp tiles; backspace undoes', () {
      final c = ComposerController();
      c.setMode(InputMode.math);

      c.appendMathDigit('4');
      c.appendMathDigit('2');
      expect(c.text, '42');

      c.appendMathOp('×');
      expect(c.text, '42 × ');

      c.appendMathDigit('5');
      expect(c.text, '42 × 5');

      c.mathBackspace();
      expect(c.text, '42 ×');

      c.mathBackspace();
      expect(c.text, '42');
    });

    test('math mutators never touch the sentence buffer', () {
      final c = ComposerController();
      c.addChar('h'); // sentence

      c.setMode(InputMode.math);
      c.appendMathDigit('1');
      c.appendMathOp('+');
      c.mathBackspace();

      c.setMode(InputMode.keyboard);
      expect(c.text, 'h'); // untouched
    });

    test('mathBackspace is a no-op on empty (no notify)', () {
      final c = ComposerController();
      c.setMode(InputMode.math);
      var notifications = 0;
      c.addListener(() => notifications++);
      c.mathBackspace();
      expect(notifications, 0);
    });
  });

  group('LanguageController · setLanguage clears only the sentence', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('an EN⇄CS switch wipes the sentence but preserves the math problem',
        () async {
      final tts = _FakeTts()..install();
      addTearDown(tts.uninstall);

      final storage = StorageService();
      await storage.init();
      final speech = SpeechService();
      await speech.init();
      final composer = ComposerController();
      final lang = LanguageController(storage, speech, composer)..load();

      // Seed both workspaces.
      composer.setMode(InputMode.math);
      composer.appendMathDigit('3');
      composer.appendMathOp('+');
      composer.appendMathDigit('4');
      composer.setMode(InputMode.keyboard);
      composer.addChar('h');
      composer.addChar('i');

      lang.setLanguage(AppLanguage.cs);

      // Active (keyboard) buffer is the sentence — cleared.
      expect(composer.text, '');
      // Math survived.
      composer.setMode(InputMode.math);
      expect(composer.text.trim(), '3 + 4');

      // And switching back still has it.
      lang.setLanguage(AppLanguage.en);
      composer.setMode(InputMode.math);
      expect(composer.text.trim(), '3 + 4');
    });
  });
}

/// Minimal `flutter_tts` platform-channel fake: records calls and answers
/// every method as success (1) so SpeechService binds to `ready`.
class _FakeTts {
  final List<MethodCall> calls = [];
  static const _channel = MethodChannel('flutter_tts');

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'isLanguageAvailable':
          return true;
        default:
          return 1;
      }
    });
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }
}
