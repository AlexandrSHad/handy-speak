import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/core/app_language.dart';
import 'package:handy_speak/services/speech_service.dart';

import 'support/fake_tts_engine.dart';

// Unit tests for SpeechService.hasVoiceFor(AppLanguage) (ADDENDUM-03 risk:
// "getVoices() shape assumptions... worth an explicit unit test with a mocked
// shape"). Rewired onto the TtsEngine seam (testing-prep stage): the service
// takes an injected FakeTtsEngine, so these reach the defensive branches
// directly — no platform-channel mocking.
//
// SpeechService._bind() (during init()) drives the engine to success, so status
// settles on ready; hasVoiceFor then reads FakeTtsEngine.voices, whose shape
// each test controls.

void main() {
  group('hasVoiceFor — present', () {
    test('resolves true when a matching uk-UA voice is installed', () async {
      final speech = SpeechService(
        engine: FakeTtsEngine(voices: [
          {'name': 'English Voice', 'locale': 'en-US'},
          {'name': 'Ukrainian Voice', 'locale': 'uk-UA'},
        ]),
      );
      await speech.init();
      expect(speech.status, SpeechStatus.ready);

      expect(await speech.hasVoiceFor(AppLanguage.uk), isTrue);
    });

    test('matches case-insensitively (mixed-case locale)', () async {
      final speech = SpeechService(
        engine: FakeTtsEngine(voices: [
          {'name': 'Ukrainian Voice', 'locale': 'UK-UA'},
        ]),
      );
      await speech.init();
      expect(speech.status, SpeechStatus.ready);

      expect(await speech.hasVoiceFor(AppLanguage.uk), isTrue);
    });
  });

  group('hasVoiceFor — absent', () {
    test('resolves false when no voice locale starts with the language key',
        () async {
      final speech = SpeechService(
        engine: FakeTtsEngine(voices: [
          {'name': 'English Voice', 'locale': 'en-US'},
          {'name': 'Czech Voice', 'locale': 'cs-CZ'},
        ]),
      );
      await speech.init();
      expect(speech.status, SpeechStatus.ready);

      expect(await speech.hasVoiceFor(AppLanguage.uk), isFalse);
    });
  });

  group('hasVoiceFor — malformed shape (fail-open)', () {
    test('resolves true when getVoices returns null', () async {
      final speech = SpeechService(engine: FakeTtsEngine(voices: null));
      await speech.init();
      expect(speech.status, SpeechStatus.ready);

      expect(await speech.hasVoiceFor(AppLanguage.uk), isTrue);
    });

    test('resolves true when getVoices returns a non-List (String)', () async {
      final speech = SpeechService(engine: FakeTtsEngine(voices: 'not-a-list'));
      await speech.init();
      expect(speech.status, SpeechStatus.ready);

      expect(await speech.hasVoiceFor(AppLanguage.uk), isTrue);
    });
  });

  group('hasVoiceFor — not ready (fail-open)', () {
    test('resolves true immediately, before init() completes', () async {
      final speech = SpeechService(
        engine: FakeTtsEngine(voices: [
          {'name': 'English Voice', 'locale': 'en-US'},
        ]),
      );
      // Constructor kicks off _init() in the background but does not await it,
      // so status is still `initializing` right here.
      expect(speech.isReady, isFalse);

      expect(await speech.hasVoiceFor(AppLanguage.uk), isTrue);

      // Let the pending init() settle so it doesn't leak into other tests.
      await speech.init();
    });
  });
}
