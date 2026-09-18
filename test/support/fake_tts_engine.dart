import 'package:handy_speak/services/tts_engine.dart';

/// In-memory [TtsEngine] for unit tests that construct [SpeechService] directly
/// — no widget tree, no platform channel. Every call succeeds; [voices] is the
/// only thing tests usually vary (to drive `hasVoiceFor`'s shape checks), and
/// recorded state is exposed for assertions.
///
/// This is the direct-construction counterpart to the pumped behaviour tests'
/// channel-level `FakeTts`: those go through the real [FlutterTtsEngine] onto a
/// mocked channel, so they need no engine fake.
class FakeTtsEngine implements TtsEngine {
  FakeTtsEngine({this.voices = const <dynamic>[]});

  /// Raw shape [getVoices] returns. Tests pass a `List` of voice `Map`s, or a
  /// deliberately malformed value (null, a `String`) to exercise the fail-open
  /// branches.
  dynamic voices;

  void Function(bool speaking)? _onSpeakingStateChanged;

  final List<String> spoken = <String>[];
  String? language;
  bool stopped = false;

  @override
  Future<void> awaitSpeakCompletion(bool awaitCompletion) async {}

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
    _onSpeakingStateChanged?.call(true);
    spoken.add(text);
    _onSpeakingStateChanged?.call(false);
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }
}
