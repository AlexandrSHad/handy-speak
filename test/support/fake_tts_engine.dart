import 'dart:async';

import 'package:handy_speak/services/tts_engine.dart';

/// In-memory [TtsEngine] for unit tests that construct [SpeechService] directly
/// — no widget tree, no platform channel. Every call succeeds by default;
/// [voices] is the only thing tests usually vary (to drive `hasVoiceFor`'s
/// shape checks), and recorded state is exposed for assertions.
///
/// This is the direct-construction counterpart to the pumped behaviour tests'
/// channel-level `FakeTts`: those go through the real [FlutterTtsEngine] onto a
/// mocked channel, so they need no engine fake.
///
/// Three opt-in failure modes let a test reach [SpeechService]'s defensive
/// branches — all default to off so the happy-path users above stay green:
/// - [hangInit] makes the bind never complete (drives the init timeout under
///   `fakeAsync`);
/// - [throwOnInit] makes the bind throw (init must swallow it → `unavailable`);
/// - [throwOnSpeak] makes [speak] throw (the service must swallow it and clear
///   the speaking flag).
class FakeTtsEngine implements TtsEngine {
  FakeTtsEngine({
    this.voices = const <dynamic>[],
    this.hangInit = false,
    this.throwOnInit = false,
    this.throwOnSpeak = false,
  });

  /// Raw shape [getVoices] returns. Tests pass a `List` of voice `Map`s, or a
  /// deliberately malformed value (null, a `String`) to exercise the fail-open
  /// branches.
  dynamic voices;

  /// When true, [awaitSpeakCompletion] (the first call [SpeechService] makes
  /// while binding) returns a future that never completes, so init only ever
  /// resolves via its timeout.
  final bool hangInit;

  /// When true, the bind throws — init must catch it and degrade to
  /// `unavailable` rather than let the error escape.
  final bool throwOnInit;

  /// When true, [speak] throws — the service must swallow it, not rethrow.
  final bool throwOnSpeak;

  final Completer<void> _neverCompletes = Completer<void>();

  void Function(bool speaking)? _onSpeakingStateChanged;

  final List<String> spoken = <String>[];
  String? language;
  bool stopped = false;

  /// The flag the last `awaitSpeakCompletion` call carried — lets tests pin
  /// the service's queue-mode contract (must be `false`; see
  /// [FakeTtsEngine] class doc and the flutter_tts speak-while-speaking drop).
  bool? requestedAwaitSpeakCompletion;

  /// Directly drives the speaking-state callback [SpeechService] registered,
  /// so a unit test can assert the service's status transitions without a
  /// real playback round-trip. No-op before init has wired the callback.
  void emitSpeakingState(bool speaking) => _onSpeakingStateChanged?.call(speaking);

  @override
  Future<void> awaitSpeakCompletion(bool awaitCompletion) {
    if (throwOnInit) throw Exception('awaitSpeakCompletion boom');
    if (hangInit) return _neverCompletes.future;
    requestedAwaitSpeakCompletion = awaitCompletion;
    return Future<void>.value();
  }

  @override
  set onSpeakingStateChanged(void Function(bool speaking) callback) {
    _onSpeakingStateChanged = callback;
  }

  @override
  Future<dynamic> getVoices() async => voices;

  @override
  Future<void> setLanguage(String locale) async {
    language = locale;
  }

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  Future<void> setPitch(double pitch) async {}

  @override
  Future<void> speak(String text) async {
    if (throwOnSpeak) throw Exception('speak boom');
    _onSpeakingStateChanged?.call(true);
    spoken.add(text);
    _onSpeakingStateChanged?.call(false);
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }
}
