import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/core/app_language.dart';
import 'package:handy_speak/services/speech_service.dart';
import 'package:handy_speak/services/storage_service.dart';
import 'package:handy_speak/state/composer_controller.dart';
import 'package:handy_speak/state/language_controller.dart';
import 'package:handy_speak/state/settings_controller.dart';
import 'package:handy_speak/state/speech_feedback_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_tts_engine.dart';

// Unit tests for typing speech feedback (docs/testing-strategy.md §4 —
// Unit tier). Two halves:
//
//  1. ComposerController's event stream: every input mutation emits the
//     right ComposerEvent (with the word/number it completed), and every
//     non-input mutation emits none. The events are the coordinator's only
//     input — no text-diffing.
//  2. SpeechFeedbackController's policy: the four Accessibility toggles
//     gate exactly which utterances reach the engine, asserted through the
//     FakeTtsEngine seam (what would actually be spoken, in order).
//
// All four toggles default OFF — the settled contract is that an update
// changes nothing for existing users until a parent opts a child in.

void main() {
  group('ComposerController events', () {
    late ComposerController composer;

    setUp(() {
      composer = ComposerController()..setMode(InputMode.keyboard);
    });

    test('a letter keystroke emits CharTyped with no completed word', () async {
      composer.addChar('a');
      final event = composer.lastEvent;
      expect(event, isA<CharTyped>());
      final typed = event! as CharTyped;
      expect(typed.char, 'a');
      expect(typed.completedWord, isNull);
    });

    test('space emits the word it just finished', () async {
      composer
        ..addChar('h')
        ..addChar('i')
        ..addChar(' ');
      final typed = composer.lastEvent! as CharTyped;
      expect(typed.char, ' ');
      expect(typed.completedWord, 'hi');
    });

    test('punctuation keys finish a word too', () async {
      for (final terminator in const [',', '.', '!', '?']) {
        composer
          ..clear()
          ..addChar('h')
          ..addChar('i')
          ..addChar(terminator);
        final typed = composer.lastEvent! as CharTyped;
        expect(typed.completedWord, 'hi', reason: "'$terminator' finishes a word");
      }
    });

    test('a terminator with no word on screen completes nothing', () async {
      composer
        ..addChar('h')
        ..addChar('i')
        ..addChar(' ')
        ..addChar(' '); // second space: nothing left in progress
      expect((composer.lastEvent! as CharTyped).completedWord, isNull);

      composer
        ..clear()
        ..addChar(','); // leading punctuation on an empty buffer
      expect((composer.lastEvent! as CharTyped).completedWord, isNull);
    });

    test('symbol tap emits WordAppended; phrase selection emits TextLoaded',
        () {
      composer.appendWord('water');
      expect(composer.lastEvent, isA<WordAppended>());
      expect((composer.lastEvent! as WordAppended).word, 'water');

      composer.loadText('I need help');
      expect(composer.lastEvent, isA<TextLoaded>());
      expect((composer.lastEvent! as TextLoaded).text, 'I need help');
    });

    test('non-input mutations emit no event', () async {
      composer
        ..addChar('h')
        ..backspace();
      expect(composer.lastEvent, isNull);

      composer
        ..addChar('i')
        ..clear();
      expect(composer.lastEvent, isNull);

      composer.appendWord('water');
      composer.removeWordAt(0);
      expect(composer.lastEvent, isNull);

      composer.setMode(InputMode.symbols);
      expect(composer.lastEvent, isNull);
    });

    test('math digit emits MathDigitTyped; op emits the number it completed',
        () {
      composer
        ..setMode(InputMode.math)
        ..appendMathDigit('2')
        ..appendMathDigit('2');
      expect((composer.lastEvent! as MathDigitTyped).digit, '2');

      composer.appendMathOp('+');
      final op = composer.lastEvent! as MathOpTyped;
      expect(op.op, '+');
      expect(op.completedNumber, '22');
    });

    test('op on an empty math buffer no-ops with no event; op after op has no number',
        () {
      composer.setMode(InputMode.math);
      composer.appendMathOp('+');
      expect(composer.lastEvent, isNull);

      composer
        ..appendMathDigit('3')
        ..appendMathOp('+')
        ..appendMathOp('+'); // second op: previous tile is '+', not a number
      final second = composer.lastEvent! as MathOpTyped;
      expect(second.completedNumber, isNull);
    });

    test('math backspace emits no event', () async {
      composer
        ..setMode(InputMode.math)
        ..appendMathDigit('3')
        ..mathBackspace();
      expect(composer.lastEvent, isNull);
    });
  });

  group('SpeechFeedbackController policy', () {
    late FakeTtsEngine engine;
    late SpeechService speech;
    late SettingsController settings;
    late LanguageController language;
    late ComposerController composer;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      engine = FakeTtsEngine();
      speech = SpeechService(engine: engine);
      await speech.init();
      settings = SettingsController(storage)..load();
      composer = ComposerController();
      language = LanguageController(storage, speech, composer)..load();
      SpeechFeedbackController(
        composer: composer,
        settings: settings,
        language: language,
        speech: speech,
      );
    });

    List<String> spoken() => engine.spoken;

    test('all toggles off: typing a full word + space speaks nothing', () async {
      composer
        ..addChar('h')
        ..addChar('i')
        ..addChar(' ');
      await pumpEventQueue();
      expect(spoken(), isEmpty);
    });

    test('letters: letters and digits echo; terminator keys never do', () async {
      settings.setSpeakLetters(true);
      composer
        ..addChar('a')
        ..addChar('1')
        ..addChar(' ');
      await pumpEventQueue();
      expect(spoken(), ['a', '1']);
    });

    test('words: a terminator speaks the finished word, not the terminator',
        () async {
      settings.setSpeakWords(true);
      composer
        ..addChar('h')
        ..addChar('i')
        ..addChar(' ')
        ..addChar('o')
        ..addChar('k')
        ..addChar('.');
      await pumpEventQueue();
      expect(spoken(), ['hi', 'ok']);
    });

    test('words: double space speaks nothing', () async {
      settings.setSpeakWords(true);
      composer
        ..addChar('h')
        ..addChar('i')
        ..addChar(' ')
        ..addChar(' ');
      await pumpEventQueue();
      expect(spoken(), ['hi']);
    });

    test('letters + words: a terminator produces exactly one utterance', () async {
      settings
        ..setSpeakLetters(true)
        ..setSpeakWords(true);
      composer
        ..addChar('a')
        ..addChar('h')
        ..addChar(' ');
      await pumpEventQueue();
      expect(spoken(), ['a', 'h', 'ah']);
    });

    test('symbol tap speech is gated by its own toggle, not words', () async {
      settings.setSpeakWords(true);
      composer.appendWord('water');
      await pumpEventQueue();
      expect(spoken(), isEmpty);

      settings.setSpeakSymbols(true);
      composer.appendWord('water');
      await pumpEventQueue();
      expect(spoken(), ['water']);
    });

    test('phrase speech is gated by its own toggle', () async {
      composer.loadText('I need help');
      await pumpEventQueue();
      expect(spoken(), isEmpty);

      settings.setSpeakPhrases(true);
      composer.loadText('I need help');
      await pumpEventQueue();
      expect(spoken(), ['I need help']);
    });

    test('math: digits echo when letters is on', () async {
      settings.setSpeakLetters(true);
      composer
        ..setMode(InputMode.math)
        ..appendMathDigit('7');
      await pumpEventQueue();
      expect(spoken(), ['7']);
    });

    test('math: op speaks the completed number when words is on', () async {
      settings.setSpeakWords(true);
      composer
        ..setMode(InputMode.math)
        ..appendMathDigit('2')
        ..appendMathDigit('2')
        ..appendMathOp('+');
      await pumpEventQueue();
      expect(spoken(), ['22']); // digits silent: letters is off
    });

    test('math: op echoes its spoken word when only letters is on', () async {
      settings.setSpeakLetters(true);
      composer
        ..setMode(InputMode.math)
        ..appendMathDigit('2')
        ..appendMathOp('+');
      await pumpEventQueue();
      expect(spoken(), ['2', 'plus']);
    });

    test('math: words wins for an op press; op-without-number falls back to echo',
        () async {
      settings
        ..setSpeakLetters(true)
        ..setSpeakWords(true);
      composer
        ..setMode(InputMode.math)
        ..appendMathDigit('2')
        ..appendMathOp('+') // completes "2" → word-speak owns the press
        ..appendMathOp('+'); // no number completed → echo the op word
      await pumpEventQueue();
      expect(spoken(), ['2', '2', 'plus']);
    });

    test('math: the op word follows the active language', () async {
      settings.setSpeakLetters(true);
      language.setLanguage(AppLanguage.cs);
      composer
        ..setMode(InputMode.math)
        ..appendMathDigit('3')
        ..appendMathOp('−'); // true minus U+2212, never ASCII '-'
      await pumpEventQueue();
      expect(spoken(), ['3', 'mínus']);
    });
  });
}
