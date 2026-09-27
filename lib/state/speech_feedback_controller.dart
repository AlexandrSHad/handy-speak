import '../core/math_speak.dart';
import '../services/speech_service.dart';
import 'composer_controller.dart';
import 'language_controller.dart';
import 'settings_controller.dart';

/// Typing speech feedback (logoped request): listens to [ComposerController]
/// input events and speaks them per the parent's Accessibility toggles —
///   - **Read letters while typing** ([SettingsController.speakLetters]):
///     each letter/digit key (keyboard and math digits) echoes its name in the
///     active TTS language;
///   - **Read finished words** ([SettingsController.speakWords]): a keyboard
///     word is spoken when finished with the space or a punctuation key; in
///     math, an operator press speaks the just-completed number;
///   - **Read symbols on tap** ([SettingsController.speakSymbols]): a
///     pictogram tap speaks the inserted word;
///   - **Read selected phrases** ([SettingsController.speakPhrases]): a
///     phrase chip tap speaks the loaded phrase.
///
/// Pure policy, no state: it owns nothing and never notifies, so it lives
/// outside the widget tree (wired next to the controllers in `main.dart`).
/// Every utterance goes through [SpeechService.speak]'s feedback channel —
/// one audio channel where the newest intent preempts whatever is playing,
/// and the Speak button never flickers on a keystroke.
class SpeechFeedbackController {
  SpeechFeedbackController({
    required ComposerController composer,
    required SettingsController settings,
    required LanguageController language,
    required SpeechService speech,
  })  : _composer = composer,
        _settings = settings,
        _language = language,
        _speech = speech {
    _composer.addListener(_onComposerEvent);
  }

  final ComposerController _composer;
  final SettingsController _settings;
  final LanguageController _language;
  final SpeechService _speech;

  void _onComposerEvent() {
    final event = _composer.lastEvent;
    if (event == null) return;
    switch (event) {
      case CharTyped(:final char, :final completedWord):
        if (completedWord != null) {
          // A terminator press: word-speak owns the keystroke, and terminator
          // keys themselves never echo (space/punctuation stay silent).
          if (_settings.speakWords) _say(completedWord);
        } else if (_settings.speakLetters &&
            !kWordTerminators.contains(char)) {
          _say(char);
        }
      case WordAppended(:final word):
        if (_settings.speakSymbols) _say(word);
      case TextLoaded(:final text):
        if (_settings.speakPhrases) _say(text);
      case MathDigitTyped(:final digit):
        if (_settings.speakLetters) _say(digit);
      case MathOpTyped(:final op, :final completedNumber):
        if (_settings.speakWords && completedNumber != null) {
          _say(completedNumber);
        } else if (_settings.speakLetters) {
          // No number was completed (or words is off): echo the operator's
          // spoken word in the active language, like any other key.
          // mathSpeak maps a lone glyph token to its word ('×' → 'times').
          _say(mathSpeak(op, _language.language));
        }
    }
  }

  void _say(String text) => _speech.speak(text, feedback: true);

  void dispose() => _composer.removeListener(_onComposerEvent);
}
