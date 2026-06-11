import 'package:flutter/foundation.dart';

import '../services/storage_service.dart';

/// App-wide preferences (IMPLEMENTATION_PLAN Task 8). Dark mode and haptics
/// persist. Mood voices are **off and disabled** for the POC (§2) — exposed as
/// a constant so the settings row can render greyed-out without a toggle path.
class SettingsController extends ChangeNotifier {
  SettingsController(this._storage);

  final StorageService _storage;

  static const _kDark = 'dark_mode';
  static const _kHaptics = 'haptics';
  static const _kBigLetters = 'big_letters';
  static const _kShowPhrases = 'show_phrases';

  bool _dark = false;
  bool get dark => _dark;

  bool _haptics = true;
  bool get haptics => _haptics;

  bool _bigLetters = false;
  bool get bigLetters => _bigLetters;

  bool _showPhrases = true;
  bool get showPhrases => _showPhrases;

  /// Moods are out of scope for the POC: always off, never toggleable (§2).
  bool get moodEnabled => false;

  void load() {
    _dark = _storage.getBool(_kDark, fallback: false);
    _haptics = _storage.getBool(_kHaptics, fallback: true);
    _bigLetters = _storage.getBool(_kBigLetters, fallback: false);
    _showPhrases = _storage.getBool(_kShowPhrases, fallback: true);
  }

  void setDark(bool value) {
    _dark = value;
    _storage.setBool(_kDark, value);
    notifyListeners();
  }

  void setHaptics(bool value) {
    _haptics = value;
    _storage.setBool(_kHaptics, value);
    notifyListeners();
  }

  void setBigLetters(bool value) {
    _bigLetters = value;
    _storage.setBool(_kBigLetters, value);
    notifyListeners();
  }

  void setShowPhrases(bool value) {
    _showPhrases = value;
    _storage.setBool(_kShowPhrases, value);
    notifyListeners();
  }
}
