import 'dart:async';

// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/core/app_language.dart';
import 'package:handy_speak/services/speech_service.dart';
import 'package:handy_speak/services/telemetry_service.dart';

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

  group('speak — feedback channel (typing echo)', () {
    test(
        'bind does NOT await speak completion: flutter_tts drops concurrent speaks',
        () async {
      // Regression: with awaitSpeakCompletion(true), flutter_tts 4.x silently
      // discards any speak() that arrives while a previous one is still
      // awaiting completion — quickly typing a→s spoke only "a". With the
      // flag off, every utterance reaches the engine and QUEUE_FLUSH preempts
      // the playing one natively.
      final engine = FakeTtsEngine();
      final speech = SpeechService(engine: engine);
      await speech.init();

      expect(engine.requestedAwaitSpeakCompletion, isFalse);
    });

    test('rapid-fire feedback utterances all reach the engine', () async {
      // The service must never swallow or await-and-drop a newer echo: both
      // letters are enqueued, the newest preempting the older engine-side.
      final engine = FakeTtsEngine();
      final speech = SpeechService(engine: engine);
      await speech.init();

      final first = speech.speak('a', feedback: true);
      final second = speech.speak('s', feedback: true); // before first settles
      await Future.wait([first, second]);

      expect(engine.spoken, ['a', 's']);
    });

    test('feedback utterances never drive isSpeaking', () async {
      final engine = FakeTtsEngine();
      final speech = SpeechService(engine: engine);
      await speech.init();

      // The fake's speak() emits start/end engine events synchronously —
      // both must be dropped for a feedback utterance, or the Speak button
      // would flicker "Speaking…" on every keystroke.
      var everSpeaking = false;
      speech.addListener(() {
        if (speech.isSpeaking) everSpeaking = true;
      });

      await speech.speak('a', feedback: true);
      expect(engine.spoken, ['a']);
      expect(speech.isSpeaking, isFalse);
      expect(everSpeaking, isFalse);
    });

    test('a feedback utterance preempts a playing message', () async {
      final engine = _HangingSpeakEngine();
      final speech = SpeechService(engine: engine);
      await speech.init();

      final message = speech.speak('hello world');
      await Future<void>.delayed(Duration.zero);
      // isSpeaking is engine-event driven now — the hanging engine reports
      // onStart when speak begins, so the message reads as mid-playback.
      expect(speech.isSpeaking, isTrue);

      engine.hangNextSpeak = false; // the echo itself may finish normally
      await speech.speak('a', feedback: true);
      await message;
      expect(engine.spoken, ['hello world', 'a']);
      expect(engine.stopped, isTrue); // preemption went through stop()
      // The preempted message's utterance must not leave the flag stuck —
      // the eager clear in speak() owns that now.
      expect(speech.isSpeaking, isFalse);
    });

    test('a message preempts feedback and drives isSpeaking again', () async {
      final engine = FakeTtsEngine();
      final speech = SpeechService(engine: engine);
      await speech.init();

      await speech.speak('a', feedback: true);
      await speech.speak('hello world');
      expect(engine.spoken, ['a', 'hello world']);
      expect(speech.isSpeaking, isFalse); // completed within the fake
    });
  });

  group('telemetry captures (ADDENDUM-06)', () {
    test('a throwing bind captures one tts/init error with the unavailable '
        'tag and one tts_status breadcrumb', () async {
      final telemetry = TelemetryService();
      final speech = SpeechService(
        engine: FakeTtsEngine(throwOnInit: true),
        telemetry: telemetry,
      );
      await speech.init();

      expect(speech.status, SpeechStatus.unavailable);
      expect(telemetry.capturedErrors, hasLength(1));
      expect(telemetry.capturedErrors.single.scope, 'tts/init');
      expect(telemetry.capturedErrors.single.tags['tts_status'],
          'unavailable');
      final statusCrumbs = telemetry.recordedBreadcrumbs
          .where((c) => c.name == 'tts_status')
          .toList();
      expect(statusCrumbs, hasLength(1));
      expect(statusCrumbs.single.data['tts_status'], 'unavailable');
    });

    test('a hung engine times out and captures tts/init', () {
      fakeAsync((async) {
        final telemetry = TelemetryService();
        final speech = SpeechService(
          engine: FakeTtsEngine(hangInit: true),
          telemetry: telemetry,
        );
        async.elapse(const Duration(seconds: 17));

        expect(speech.status, SpeechStatus.unavailable);
        expect(telemetry.capturedErrors.single.scope, 'tts/init');
      });
    });

    test('a healthy init emits exactly one ready tts_status breadcrumb and '
        'no errors', () async {
      final telemetry = TelemetryService();
      final speech =
          SpeechService(engine: FakeTtsEngine(), telemetry: telemetry);
      await speech.init();
      await speech.init(); // re-await must not duplicate the breadcrumb

      expect(telemetry.capturedErrors, isEmpty);
      final statusCrumbs = telemetry.recordedBreadcrumbs
          .where((c) => c.name == 'tts_status')
          .toList();
      expect(statusCrumbs, hasLength(1));
      expect(statusCrumbs.single.data['tts_status'], 'ready');
    });

    test('a throwing speak captures one tts/speak error; the utterance is '
        'ledgered and redacted from the payload', () async {
      final telemetry = TelemetryService();
      final speech = SpeechService(
        engine: FakeTtsEngine(
          throwOnSpeak: true,
          speakErrorMessage: 'engine refused CANARYQQ7X',
        ),
        telemetry: telemetry,
      );
      await speech.init();
      await speech.speak('CANARYQQ7X');

      expect(telemetry.capturedErrors, hasLength(1));
      final captured = telemetry.capturedErrors.single;
      expect(captured.scope, 'tts/speak');
      expect(captured.message, contains('[redacted]'));
      expect(captured.message?.contains('CANARYQQ7X'), isFalse);
      // The utterance stays in the ledger for later payloads.
      expect(telemetry.redact('later leak: CANARYQQ7X'),
          'later leak: [redacted]');
    });

    test('a dropped utterance (engine unavailable) is still ledgered', () async {
      final telemetry = TelemetryService();
      final speech = SpeechService(
        engine: FakeTtsEngine(throwOnInit: true),
        telemetry: telemetry,
      );
      await speech.init();
      await speech.speak('secret words');

      // The init failure captured (tts/init); the dropped speak did not.
      expect(telemetry.capturedErrors.map((e) => e.scope), ['tts/init']);
      expect(telemetry.redact('leak: secret words'), 'leak: [redacted]');
    });

    test('a successful setLanguage emits a tts_language breadcrumb', () async {
      final telemetry = TelemetryService();
      final speech =
          SpeechService(engine: FakeTtsEngine(), telemetry: telemetry);
      await speech.init();

      await speech.setLanguage('cs-CZ');

      final crumbs = telemetry.recordedBreadcrumbs
          .where((c) => c.name == 'tts_language')
          .toList();
      expect(crumbs, hasLength(1));
      expect(crumbs.single.data['ui_locale'], 'cs-CZ');
    });
  });
}

/// A [FakeTtsEngine] that can hold its NEXT `speak` mid-playback until
/// `stop()` cancels it — like a real engine where playback outlives the
/// enqueue. Playback state is reported through the engine-state callback
/// (start on speak, end on stop), mirroring how the real plugin reports it.
class _HangingSpeakEngine extends FakeTtsEngine {
  /// When true (the default), the next `speak` hangs until stopped; flip to
  /// false for the preempting utterance so it completes normally.
  bool hangNextSpeak = true;

  Completer<void>? _pending;

  @override
  Future<void> speak(String text) {
    if (throwOnSpeak) throw Exception('speak boom');
    spoken.add(text);
    emitSpeakingState(true);
    if (!hangNextSpeak) {
      emitSpeakingState(false);
      return Future<void>.value();
    }
    _pending = Completer<void>();
    return _pending!.future;
  }

  @override
  Future<void> stop() {
    _pending?.complete();
    emitSpeakingState(false);
    return super.stop();
  }
}
