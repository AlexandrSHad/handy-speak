import 'package:flutter_tts/flutter_tts.dart';

/// Seam over `flutter_tts` (testing-prep stage). [SpeechService] depends on this
/// abstraction rather than the plugin directly, so its defensive branches can be
/// unit-tested against an injected fake instead of a mocked platform channel.
///
/// The one production implementation, [FlutterTtsEngine], is the **only** place
/// `package:flutter_tts` is imported — the rest of the app talks to [TtsEngine].
abstract class TtsEngine {
  /// See `FlutterTts.awaitSpeakCompletion`: makes the [speak] future resolve on
  /// playback completion so speaking-state tracking is reliable.
  Future<void> awaitSpeakCompletion(bool awaitCompletion);

  /// Collapses the plugin's five speaking-state handlers (start / completion /
  /// cancel / pause / error) into a single signal: `true` when playback starts,
  /// `false` when it ends for any reason. Registering the callback here is what
  /// the adapter wires those five handlers onto.
  set onSpeakingStateChanged(void Function(bool speaking) callback);

  Future<void> setLanguage(String locale);

  /// Returns the raw plugin shape (a `List` of voice `Map`s, typically) — kept
  /// `dynamic` on purpose so [SpeechService.hasVoiceFor]'s defensive shape
  /// checks stay meaningful.
  Future<dynamic> getVoices();

  Future<void> setSpeechRate(double rate);

  Future<void> setPitch(double pitch);

  Future<void> speak(String text);

  Future<void> stop();
}

/// Production [TtsEngine] backed by `flutter_tts`. Deliberately dumb: it forwards
/// calls and fans the plugin's five handlers into [onSpeakingStateChanged]. It
/// holds no logic worth unit-testing, which is the point — the testable
/// behaviour lives in [SpeechService], reached through the [TtsEngine] seam.
class FlutterTtsEngine implements TtsEngine {
  FlutterTtsEngine([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  @override
  Future<void> awaitSpeakCompletion(bool awaitCompletion) =>
      _tts.awaitSpeakCompletion(awaitCompletion);

  @override
  set onSpeakingStateChanged(void Function(bool speaking) callback) {
    _tts.setStartHandler(() => callback(true));
    _tts.setCompletionHandler(() => callback(false));
    _tts.setCancelHandler(() => callback(false));
    _tts.setPauseHandler(() => callback(false));
    _tts.setErrorHandler((_) => callback(false));
  }

  @override
  Future<void> setLanguage(String locale) => _tts.setLanguage(locale);

  @override
  Future<dynamic> getVoices() => _tts.getVoices;

  @override
  Future<void> setSpeechRate(double rate) => _tts.setSpeechRate(rate);

  @override
  Future<void> setPitch(double pitch) => _tts.setPitch(pitch);

  @override
  Future<void> speak(String text) => _tts.speak(text);

  @override
  Future<void> stop() => _tts.stop();
}
