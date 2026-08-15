import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_speak/core/app_language.dart';
import 'package:handy_speak/services/speech_service.dart';

// Unit tests for SpeechService.hasVoiceFor(AppLanguage), mocked against the
// `flutter_tts` platform MethodChannel (ADDENDUM-03 risk: "getVoices() shape
// assumptions... worth an explicit unit test with a mocked shape"). Follows
// the FakeTts mocking pattern from integration_test/addendum02_suite.dart
// (~line 282-306), adapted so `getVoices` can return a controlled shape per
// test case.
//
// SpeechService._bind() (during init()) calls, in order:
//   awaitSpeakCompletion, setLanguage
// plus registers local handlers (setStartHandler etc. — no channel calls).
// hasVoiceFor additionally calls `getVoices`. The mock handler below answers
// every method with `1` (a generic "ok" platform response) except
// `getVoices`, which returns whatever the test configures — mirroring
// FakeTts's `default: return 1`.

/// Installs a mock `flutter_tts` channel handler where `getVoices` returns
/// [voicesResponse] and every other method call succeeds with `1`.
void installMockTts(dynamic voicesResponse) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('flutter_tts'),
          (call) async {
    switch (call.method) {
      case 'getVoices':
        return voicesResponse;
      case 'isLanguageAvailable':
        return true;
      default:
        return 1;
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
  });

  group('hasVoiceFor — present', () {
    test('resolves true when a matching uk-UA voice is installed', () async {
      installMockTts([
        {'name': 'English Voice', 'locale': 'en-US'},
        {'name': 'Ukrainian Voice', 'locale': 'uk-UA'},
      ]);
      final speech = SpeechService();
      await speech.init();
      expect(speech.status, SpeechStatus.ready);

      expect(await speech.hasVoiceFor(AppLanguage.uk), isTrue);
    });

    test('matches case-insensitively (mixed-case locale)', () async {
      installMockTts([
        {'name': 'Ukrainian Voice', 'locale': 'UK-UA'},
      ]);
      final speech = SpeechService();
      await speech.init();
      expect(speech.status, SpeechStatus.ready);

      expect(await speech.hasVoiceFor(AppLanguage.uk), isTrue);
    });
  });

  group('hasVoiceFor — absent', () {
    test('resolves false when no voice locale starts with the language key',
        () async {
      installMockTts([
        {'name': 'English Voice', 'locale': 'en-US'},
        {'name': 'Czech Voice', 'locale': 'cs-CZ'},
      ]);
      final speech = SpeechService();
      await speech.init();
      expect(speech.status, SpeechStatus.ready);

      expect(await speech.hasVoiceFor(AppLanguage.uk), isFalse);
    });
  });

  group('hasVoiceFor — malformed shape (fail-open)', () {
    test('resolves true when getVoices returns null', () async {
      installMockTts(null);
      final speech = SpeechService();
      await speech.init();
      expect(speech.status, SpeechStatus.ready);

      expect(await speech.hasVoiceFor(AppLanguage.uk), isTrue);
    });

    test('resolves true when getVoices returns a non-List (String)',
        () async {
      installMockTts('not-a-list');
      final speech = SpeechService();
      await speech.init();
      expect(speech.status, SpeechStatus.ready);

      expect(await speech.hasVoiceFor(AppLanguage.uk), isTrue);
    });
  });

  group('hasVoiceFor — not ready (fail-open)', () {
    test('resolves true immediately, before init() completes', () async {
      installMockTts([
        {'name': 'English Voice', 'locale': 'en-US'},
      ]);
      final speech = SpeechService();
      // Constructor kicks off _init() in the background but does not await
      // it, so status is still `initializing` right here.
      expect(speech.isReady, isFalse);

      expect(await speech.hasVoiceFor(AppLanguage.uk), isTrue);

      // Let the pending init() settle so it doesn't leak into other tests.
      await speech.init();
    });
  });
}
