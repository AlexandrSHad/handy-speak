import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';

import '../core/app_language.dart';
import 'telemetry_service.dart';
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
  /// [telemetry] is the ADDENDUM-06 capture seam; defaulted so tests and older
  /// constructions stay unchanged (a default instance is disabled-mode and
  /// records into a sink nobody reads).
  SpeechService({TtsEngine? engine, TelemetryService? telemetry})
      : _engine = engine ?? FlutterTtsEngine(),
        _telemetry = telemetry ?? TelemetryService() {
    _ready = _init();
  }

  final TtsEngine _engine;
  final TelemetryService _telemetry;

  /// Hard ceiling on the service bind. A hung engine must still resolve to
  /// [SpeechStatus.unavailable] so the "Preparing…" spinner can't spin forever.
  static const _initTimeout = Duration(seconds: 16);

  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  SpeechStatus _status = SpeechStatus.initializing;
  SpeechStatus get status => _status;
  bool get isReady => _status == SpeechStatus.ready;

  /// The engine's collapse of its five speaking-state handlers (registered
  /// in [_bind]). Events only drive [isSpeaking] for **main-channel**
  /// utterances (the Speak button): typing-feedback utterances share the
  /// audio channel but their start/end events are dropped, so the button
  /// never flickers on a keystroke. [_mainUtterance] is set by the newest
  /// [speak] call — the plugin fires these events around playback, so by the
  /// time one arrives it belongs to that newest utterance.
  void _onEngineSpeakingState(bool speaking) {
    if (!_mainUtterance) return;
    _setSpeaking(speaking);
  }

  /// Whether the newest utterance is a main-channel one (see
  /// [_onEngineSpeakingState]).
  bool _mainUtterance = true;

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
    } catch (e, st) {
      // Timed out or threw — the engine is unusable on this device.
      _status = SpeechStatus.unavailable;
      unawaited(_telemetry.captureError(e, st,
          scope: 'tts/init', tags: const {'tts_status': 'unavailable'}));
    } finally {
      notifyListeners();
      // One breadcrumb per settled init (ADDENDUM-06) — later `init()` calls
      // merely re-await the same future and must not duplicate it.
      _telemetry.addBreadcrumb('tts_status',
          data: {'tts_status': _status.name});
    }
  }

  /// The actual (slow) engine setup, bounded by [_initTimeout] in [_init].
  Future<void> _bind() async {
    // Deliberately NOT awaiting speak completion. flutter_tts 4.x (Android)
    // discards any speak() that arrives while a previous one is still
    // awaiting completion — with the flag on, a quickly-typed second letter
    // was silently dropped (rapid a→s spoke only "a"). With it off, every
    // speak() reaches the engine, where QUEUE_FLUSH natively preempts the
    // playing utterance (the settled "newest intent wins" semantics).
    // isSpeaking is driven by the engine-state events registered below, not
    // by awaiting speak futures, so nothing else depends on the flag.
    await _engine.awaitSpeakCompletion(false);

    // One signal collapses the plugin's five speaking-state handlers; the
    // adapter fans it back out to start/completion/cancel/pause/error.
    _engine.onSpeakingStateChanged = _onEngineSpeakingState;

    // Call the engine directly, NOT the public setLanguage(): that one is gated
    // on [isReady], which is still false here, so it would no-op.
    await _engine.setLanguage(_locale);
  }

  Future<void> setLanguage(String locale) async {
    _locale = locale; // record intent; _bind() applies it if we're not ready yet
    if (!isReady) return;
    try {
      await _engine.setLanguage(locale);
      _telemetry.addBreadcrumb('tts_language', data: {'ui_locale': locale});
    } catch (e, st) {
      // Non-fatal: an unsupported locale must not crash composition.
      unawaited(_telemetry.captureError(e, st,
          scope: 'tts/set_language', tags: {'ui_locale': _locale}));
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
    } catch (e, st) {
      unawaited(_telemetry.captureError(e, st, scope: 'tts/voices'));
      return true;
    }
  }

  /// Speaks [text] in the active language. [rate]/[pitch] are optional and
  /// unused by the POC (moods off, §2) — when null, the engine default stands.
  ///
  /// [feedback] marks typing-feedback utterances (letter echo, finished
  /// words, symbol/phrase confirmations). They share the single audio channel
  /// — preempting whatever is playing and preempted by the next utterance —
  /// but never drive [isSpeaking], so the Speak button doesn't flicker
  /// "Speaking…" on every keystroke.
  ///
  /// The speak future resolves when the utterance is ENQUEUED, not played
  /// (see [_bind]); [isSpeaking] for main-channel utterances is driven by the
  /// engine's start/stop events via [_onEngineSpeakingState].
  Future<void> speak(String text,
      {double? rate, double? pitch, bool feedback = false}) async {
    // Even a dropped utterance is a secret worth redacting (ADDENDUM-06) —
    // register before any early return.
    _telemetry.registerUtterance(text);
    if (!isReady || text.trim().isEmpty) return;
    // The newest utterance defines the channel its engine events belong to.
    _mainUtterance = !feedback;
    try {
      // A new utterance ends the previous one's reign NOW: its cancel event
      // would otherwise arrive after _mainUtterance flipped and be gated
      // below, leaving a cancelled main utterance's isSpeaking stuck true.
      _setSpeaking(false);
      await _engine.stop();
      if (rate != null) await _engine.setSpeechRate(rate);
      if (pitch != null) await _engine.setPitch(pitch);
      await _engine.speak(text);
    } catch (e, st) {
      // Defensive clear: never leave the button stuck if the engine throws.
      _setSpeaking(false);
      unawaited(_telemetry.captureError(e, st, scope: 'tts/speak'));
    }
  }

  Future<void> stop() async {
    if (!isReady) return;
    try {
      await _engine.stop();
    } catch (e, st) {
      // ignore
      unawaited(_telemetry.captureError(e, st, scope: 'tts/stop'));
    }
    _setSpeaking(false);
  }

  void _setSpeaking(bool value) {
    if (_isSpeaking == value) return;
    _isSpeaking = value;
    notifyListeners();
  }
}
