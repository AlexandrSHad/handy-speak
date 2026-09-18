// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/core/app_language.dart';
import 'package:handy_speak/services/speech_service.dart';

import '../../support/fake_tts_engine.dart';

// Unit tests for SpeechService's defensive contract around flutter_tts
// (testing-strategy §4 "Speech / TTS · Unit"). The service takes an injected
// FakeTtsEngine over the TtsEngine seam, so every branch is reached directly —
// no widget tree, no platform-channel mocking.
//
// Coverage:
//  - hasVoiceFor(AppLanguage) shape checks (ADDENDUM-03 risk) — present/absent/
//    malformed/not-ready.
//  - init: a hung engine times out to `unavailable` (never completing with an
//    error); a throwing bind is swallowed to `unavailable`.
//  - speak: early-returns on empty/whitespace/not-ready/unavailable; engine
//    errors are swallowed; the happy path records the text and settles.
//  - status transitions: the onSpeakingStateChanged callback flips isSpeaking
//    and notifies once per change; stop clears it.
//
// SpeechService._bind() (during init()) drives the engine to success by
// default, so status settles on ready; hasVoiceFor then reads
// FakeTtsEngine.voices, whose shape each test controls.

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

  group('init — timeout resolves to unavailable', () {
    test(
        'a hung engine settles on unavailable after the bind ceiling, and '
        'init() completes without ever surfacing an error', () {
      fakeAsync((async) {
        final speech = SpeechService(engine: FakeTtsEngine(hangInit: true));
        expect(speech.status, SpeechStatus.initializing);

        Object? initError;
        var initDone = false;
        speech.init().then(
          (_) => initDone = true,
          onError: (Object e) => initError = e,
        );

        // Short of the 16s ceiling the bind is still hanging.
        async.elapse(const Duration(seconds: 15));
        async.flushMicrotasks();
        expect(speech.status, SpeechStatus.initializing);

        // Past the ceiling the timeout fires and degrades the engine.
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(speech.status, SpeechStatus.unavailable);
        expect(speech.isReady, isFalse);
        // Resolved normally — the init future is observed only as a status and
        // must never complete with an error.
        expect(initDone, isTrue);
        expect(initError, isNull);
      });
    });
  });

  group('init — engine error is swallowed', () {
    test('a bind that throws degrades to unavailable; init() does not throw',
        () async {
      final speech = SpeechService(engine: FakeTtsEngine(throwOnInit: true));
      // Awaiting a poisoned future would rethrow here and fail the test.
      await speech.init();
      expect(speech.status, SpeechStatus.unavailable);
      expect(speech.isReady, isFalse);
    });
  });

  group('speak — early-returns without touching the engine', () {
    test('does nothing when the text is empty', () async {
      final engine = FakeTtsEngine();
      final speech = SpeechService(engine: engine);
      await speech.init();
      expect(speech.isReady, isTrue);

      await speech.speak('');
      expect(engine.spoken, isEmpty);
      expect(engine.stopped, isFalse);
      expect(speech.isSpeaking, isFalse);
    });

    test('does nothing when the text is whitespace only', () async {
      final engine = FakeTtsEngine();
      final speech = SpeechService(engine: engine);
      await speech.init();

      await speech.speak('   \n\t ');
      expect(engine.spoken, isEmpty);
      expect(engine.stopped, isFalse);
    });

    test('does nothing while the service is still initializing', () async {
      final engine = FakeTtsEngine();
      final speech = SpeechService(engine: engine);
      // Constructor kicked off _init() but we do NOT await it: status is still
      // `initializing`, so speak must no-op.
      expect(speech.isReady, isFalse);

      await speech.speak('hello');
      expect(engine.spoken, isEmpty);

      await speech.init(); // settle the pending init so it can't leak
    });

    test('does nothing when the engine is unavailable', () async {
      final engine = FakeTtsEngine(throwOnInit: true);
      final speech = SpeechService(engine: engine);
      await speech.init();
      expect(speech.status, SpeechStatus.unavailable);

      await speech.speak('hello');
      expect(engine.spoken, isEmpty);
      expect(speech.isSpeaking, isFalse);
    });
  });

  group('speak — engine errors are swallowed', () {
    test('a throwing speak does not escape and leaves isSpeaking false',
        () async {
      final engine = FakeTtsEngine(throwOnSpeak: true);
      final speech = SpeechService(engine: engine);
      await speech.init();
      expect(speech.isReady, isTrue);

      // Must not rethrow to the caller.
      await speech.speak('hello');
      expect(engine.spoken, isEmpty); // threw before recording
      expect(speech.isSpeaking, isFalse); // cleared in the catch
    });
  });

  group('speak — happy path', () {
    test('stops any prior utterance, records the text, ends not speaking',
        () async {
      final engine = FakeTtsEngine();
      final speech = SpeechService(engine: engine);
      await speech.init();

      await speech.speak('hello world');
      expect(engine.stopped, isTrue); // speak() stops first
      expect(engine.spoken, ['hello world']);
      expect(speech.isSpeaking, isFalse); // settled after completion
    });
  });

  group('status transitions via onSpeakingStateChanged', () {
    test('the engine callback flips isSpeaking and notifies once per change',
        () async {
      final engine = FakeTtsEngine();
      final speech = SpeechService(engine: engine);
      await speech.init();

      var notifications = 0;
      speech.addListener(() => notifications++);

      engine.emitSpeakingState(true);
      expect(speech.isSpeaking, isTrue);
      expect(notifications, 1);

      engine.emitSpeakingState(false);
      expect(speech.isSpeaking, isFalse);
      expect(notifications, 2);

      // Idempotent: re-emitting the current value notifies no one.
      engine.emitSpeakingState(false);
      expect(notifications, 2);
    });
  });

  group('stop', () {
    test('stops the engine and clears the speaking flag when ready', () async {
      final engine = FakeTtsEngine();
      final speech = SpeechService(engine: engine);
      await speech.init();
      engine.emitSpeakingState(true);
      expect(speech.isSpeaking, isTrue);

      await speech.stop();
      expect(engine.stopped, isTrue);
      expect(speech.isSpeaking, isFalse);
    });

    test('no-ops when the engine is not ready', () async {
      final engine = FakeTtsEngine(throwOnInit: true);
      final speech = SpeechService(engine: engine);
      await speech.init();
      expect(speech.isReady, isFalse);

      await speech.stop();
      expect(engine.stopped, isFalse);
    });
  });
}
