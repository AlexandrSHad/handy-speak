import 'package:flutter/foundation.dart';

import '../services/storage_keys.dart';
import '../services/storage_service.dart';

/// App-wide preferences (IMPLEMENTATION_PLAN Task 8). Dark mode and haptics
/// persist. Mood voices are **off and disabled** for the POC (§2) — exposed as
/// a constant so the settings row can render greyed-out without a toggle path.
class SettingsController extends ChangeNotifier {
  SettingsController(this._storage);

  final StorageService _storage;

  // Key names live in `services/storage_keys.dart` (the schema module, R1
  // C3); this controller owns only the behaviour over them.

  bool _dark = false;
  bool get dark => _dark;

  bool _haptics = true;
  bool get haptics => _haptics;

  bool _bigLetters = false;
  bool get bigLetters => _bigLetters;

  bool _showPhrases = true;
  bool get showPhrases => _showPhrases;

  // --- Typing speech feedback (logoped request): all four default OFF so
  // existing users see no behavior change after update; a parent opts each
  // child in. See SpeechFeedbackController for the policy. ---

  bool _speakLetters = false;
  bool get speakLetters => _speakLetters;

  bool _speakWords = false;
  bool get speakWords => _speakWords;

  bool _speakSymbols = false;
  bool get speakSymbols => _speakSymbols;

  bool _speakPhrases = false;
  bool get speakPhrases => _speakPhrases;

  /// Moods are out of scope for the POC: always off, never toggleable (§2).
  bool get moodEnabled => false;

  void load() {
    _dark = _storage.getBool(kDarkModeKey, fallback: false);
    _haptics = _storage.getBool(kHapticsKey, fallback: true);
    _bigLetters = _storage.getBool(kBigLettersKey, fallback: false);
    _showPhrases = _storage.getBool(kShowPhrasesKey, fallback: true);
    _speakLetters = _storage.getBool(kSpeakLettersKey, fallback: false);
    _speakWords = _storage.getBool(kSpeakWordsKey, fallback: false);
    _speakSymbols = _storage.getBool(kSpeakSymbolsKey, fallback: false);
    _speakPhrases = _storage.getBool(kSpeakPhrasesKey, fallback: false);
  }

  void setDark(bool value) {
    _dark = value;
    _storage.setBool(kDarkModeKey, value);
    notifyListeners();
  }

  void setHaptics(bool value) {
    _haptics = value;
    _storage.setBool(kHapticsKey, value);
    notifyListeners();
  }

  void setBigLetters(bool value) {
    _bigLetters = value;
    _storage.setBool(kBigLettersKey, value);
    notifyListeners();
  }

  void setShowPhrases(bool value) {
    _showPhrases = value;
    _storage.setBool(kShowPhrasesKey, value);
    notifyListeners();
  }

  void setSpeakLetters(bool value) {
    _speakLetters = value;
    _storage.setBool(kSpeakLettersKey, value);
    notifyListeners();
  }

  void setSpeakWords(bool value) {
    _speakWords = value;
    _storage.setBool(kSpeakWordsKey, value);
    notifyListeners();
  }

  void setSpeakSymbols(bool value) {
    _speakSymbols = value;
    _storage.setBool(kSpeakSymbolsKey, value);
    notifyListeners();
  }

  void setSpeakPhrases(bool value) {
    _speakPhrases = value;
    _storage.setBool(kSpeakPhrasesKey, value);
    notifyListeners();
  }
}
