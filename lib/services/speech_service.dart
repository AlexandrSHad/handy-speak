import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Wraps `flutter_tts` (IMPLEMENTATION_PLAN Task 1). The highest-risk piece:
/// proven first, kept defensive so a TTS error never crashes the app.
///
/// [speak] accepts **optional** rate/pitch so moods can be re-enabled later as
/// a wiring change, not a refactor (§2). The POC always passes the engine
/// defaults (null → leave the engine's current rate/pitch untouched).
class SpeechService extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();

  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  /// Soft signal only (§ Task 1): `true` can mean "engine supports the
  /// language" while the voice data pack is absent. Drives the in-app
  /// "No Czech voice…" warning, not a hard gate.
  bool csAvailable = true;
  bool enAvailable = true;

  String _locale = 'en-US';

  Future<void> init() async {
    // Make speak() future resolve on completion so isSpeaking is reliable.
    await _tts.awaitSpeakCompletion(true);

    _tts.setStartHandler(() => _setSpeaking(true));
    _tts.setCompletionHandler(() => _setSpeaking(false));
    _tts.setCancelHandler(() => _setSpeaking(false));
    _tts.setPauseHandler(() => _setSpeaking(false));
    _tts.setErrorHandler((_) => _setSpeaking(false));

    try {
      csAvailable = (await _tts.isLanguageAvailable('cs-CZ')) == true;
      enAvailable = (await _tts.isLanguageAvailable('en-US')) == true;
    } catch (_) {
      // Leave optimistic defaults; the audible check is the real proof.
    }

    await setLanguage(_locale);
  }

  Future<void> setLanguage(String locale) async {
    _locale = locale;
    try {
      await _tts.setLanguage(locale);
    } catch (_) {
      // Non-fatal: an unsupported locale must not crash composition.
    }
  }

  /// Speaks [text] in the active language. [rate]/[pitch] are optional and
  /// unused by the POC (moods off, §2) — when null, the engine default stands.
  Future<void> speak(String text, {double? rate, double? pitch}) async {
    if (text.trim().isEmpty) return;
    try {
      await _tts.stop();
      if (rate != null) await _tts.setSpeechRate(rate);
      if (pitch != null) await _tts.setPitch(pitch);
      _setSpeaking(true);
      await _tts.speak(text);
      // With awaitSpeakCompletion(true) this resolves when playback ends.
      _setSpeaking(false);
    } catch (_) {
      _setSpeaking(false);
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // ignore
    }
    _setSpeaking(false);
  }

  void _setSpeaking(bool value) {
    if (_isSpeaking == value) return;
    _isSpeaking = value;
    notifyListeners();
  }
}
