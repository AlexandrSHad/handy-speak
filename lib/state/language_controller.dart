import 'package:flutter/foundation.dart';

import '../core/app_language.dart';
import '../services/speech_service.dart';
import '../services/storage_service.dart';
import 'composer_controller.dart';

/// Owns the active [AppLanguage] and is the single switch that flips
/// everything (IMPLEMENTATION_PLAN Task 2 / §6.1.1). Changing it:
///   1. cancels any in-progress speech,
///   2. clears the composed message (free text can't be auto-translated),
///   3. points the TTS engine at the new locale,
///   4. flips the app `Locale`, keyboard, symbols and phrase set via notify.
class LanguageController extends ChangeNotifier {
  LanguageController(this._storage, this._speech, this._composer);

  final StorageService _storage;
  final SpeechService _speech;
  final ComposerController _composer;

  static const _kLang = 'language';

  AppLanguage _language = AppLanguage.en;
  AppLanguage get language => _language;

  void load() {
    _language = AppLanguage.fromKey(_storage.getString(_kLang));
    // Align the speech engine with the restored language.
    _speech.setLanguage(_language.ttsLocale);
  }

  void setLanguage(AppLanguage next) {
    if (next == _language) return;
    _language = next;
    _storage.setString(_kLang, next.key);

    // §6.1.1 — cancel speech, clear the message, then flip the voice.
    _speech.stop();
    _composer.clear();
    _speech.setLanguage(next.ttsLocale);

    notifyListeners();
  }
}
