import 'package:flutter/foundation.dart';

import '../core/app_language.dart';
import 'tts_engine.dart';

/// Readiness of the text-to-speech engine. The UI gates the Speak button on
/// this: [initializing] shows a spinner, [unavailable] shows an error.
enum SpeechStatus { initializing, ready, unavailable }

/// Wraps `flutter_tts` (IMPLEMENTATION_PLAN Task 1). The highest-risk piece:
/// proven first, kept defensive so a TTS error never crashes the app.
///
/// Initialization runs in the **background** (constructor), so the first frame
/// paints immediately instead of blocking for seconds while the Android TTS
/// service binds on old tablets. [status] drives the Speak button: a spinner
/// while [SpeechStatus.initializing], an error banner on
/// [SpeechStatus.unavailable].
///
/// [speak] accepts **optional** rate/pitch so moods can be re-enabled later as
/// a wiring change, not a refactor (§2). The POC always passes the engine
/// defaults (null → leave the engine's current rate/pitch untouched).
class SpeechService extends ChangeNotifier {
  /// [engine] is the seam over `flutter_tts` (testing-prep stage). Production
  /// wiring passes a real [FlutterTtsEngine] (see `main.dart`); unit tests inject
  /// a fake. Defaulted so existing call sites keep working — the default lives in
  /// `tts_engine.dart`, so this class never imports `flutter_tts` itself.
  SpeechService({TtsEngine? engine}) : _engine = engine ?? FlutterTtsEngine() {
    _ready = _init();
  }

  final TtsEngine _engine;

  /// Hard ceiling on the service bind. A hung engine must still resolve to
  /// [SpeechStatus.unavailable] so the "Preparing…" spinner can't spin forever.
  static const _initTimeout = Duration(seconds: 16);

  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  SpeechStatus _status = SpeechStatus.initializing;
  SpeechStatus get status => _status;
  bool get isReady => _status == SpeechStatus.ready;

  String _locale = 'en-US';

  late final Future<void> _ready;

  /// Idempotent readiness handle. Returns the in-flight init started in the
  /// constructor — safe for tests to `await`, and never re-runs setup.
  Future<void> init() => _ready;

  Future<void> _init() async {
    // This future must NEVER complete with an error: it is observed only as a
    // [status], and a dead engine degrades to a visible "unavailable" — never a
    // crash and never a poisoned future for fire-and-forget callers.
    try {
      await _bind().timeout(_initTimeout);
      _status = SpeechStatus.ready;
    } catch (_) {
      // Timed out or threw — the engine is unusable on this device.
      _status = SpeechStatus.unavailable;
    } finally {
      notifyListeners();
    }
  }

  /// The actual (slow) engine setup, bounded by [_initTimeout] in [_init].
  Future<void> _bind() async {
    // Make speak() future resolve on completion so isSpeaking is reliable.
    await _engine.awaitSpeakCompletion(true);

    // One signal collapses the plugin's five speaking-state handlers; the
    // adapter fans it back out to start/completion/cancel/pause/error.
    _engine.onSpeakingStateChanged = _setSpeaking;

    // Call the engine directly, NOT the public setLanguage(): that one is gated
    // on [isReady], which is still false here, so it would no-op.
    await _engine.setLanguage(_locale);
  }

  Future<void> setLanguage(String locale) async {
    _locale = locale; // record intent; _bind() applies it if we're not ready yet
    if (!isReady) return;
    try {
      await _engine.setLanguage(locale);
    } catch (_) {
      // Non-fatal: an unsupported locale must not crash composition.
    }
  }

  /// Checks whether an installed TTS voice matches [lang] (soft signal:
  /// distinguishes "engine supports it" from "voice pack installed", unlike
  /// the old isLanguageAvailable check). Returns `true` (never warn) if the
  /// engine isn't ready yet, or if the check itself fails for any reason —
  /// this only ever gates a soft warning banner, never a hard block.
  Future<bool> hasVoiceFor(AppLanguage lang) async {
    if (!isReady) return true;
    try {
      final voices = await _engine.getVoices();
      if (voices is! List) return true;
      // A per-entry `is Map` guard (rather than an unchecked cast inside the
      // outer try/catch) means one malformed voice entry is skipped, not
      // treated as a reason to fail-open the whole check.
      return voices.any((v) => v is Map && (v['locale']
          ?.toString().toLowerCase().startsWith(lang.key) ?? false));
    } catch (_) {
      return true;
    }
  }

  /// Speaks [text] in the active language. [rate]/[pitch] are optional and
  /// unused by the POC (moods off, §2) — when null, the engine default stands.
  Future<void> speak(String text, {double? rate, double? pitch}) async {
    if (!isReady || text.trim().isEmpty) return;
    try {
      await _engine.stop();
      if (rate != null) await _engine.setSpeechRate(rate);
      if (pitch != null) await _engine.setPitch(pitch);
      _setSpeaking(true);
      await _engine.speak(text);
      // With awaitSpeakCompletion(true) this resolves when playback ends.
      _setSpeaking(false);
    } catch (_) {
      _setSpeaking(false);
    }
  }

  Future<void> stop() async {
    if (!isReady) return;
    try {
      await _engine.stop();
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
